using System.Data;
using Dapper;
using GymApi.Infraestructura;
using GymApi.Modelos;

namespace GymApi.Endpoints;

/// <summary>Datos fisiológicos, consentimientos RGPD y zonas privadas de la ruta.</summary>
public static class PerfilEndpoints
{
    private static readonly HashSet<string> TiposConsentimiento = ["UBICACION", "SALUD"];

    public static void MapPerfilEndpoints(this IEndpointRouteBuilder app)
    {
        var fisiologia = app.MapGroup("/usuarios/me/fisiologia").WithTags("Perfil").RequiereUsuario();
        fisiologia.MapGet("/", ObtenerFisiologia);
        fisiologia.MapPatch("/", ActualizarFisiologia);

        var consentimientos = app.MapGroup("/consentimientos").WithTags("Consentimientos").RequiereUsuario();
        consentimientos.MapGet("/", ListarConsentimientos);
        consentimientos.MapPost("/", RegistrarConsentimiento);

        var zonas = app.MapGroup("/zonas-privadas").WithTags("Zonas privadas").RequiereUsuario();
        zonas.MapGet("/", ListarZonas);
        zonas.MapPost("/", CrearZona);
        zonas.MapDelete("/{zonaId:int}", QuitarZona);
    }

    /* ---------- Datos fisiológicos ---------- */

    private static async Task<IResult> ObtenerFisiologia(HttpContext http, Db db, CancellationToken ct) =>
        Results.Ok(await LeerFisiologiaAsync(db, http.UsuarioId(), ct));

    /// <summary>Campos null = sin cambios. VO2máx y FC máxima requieren consentimiento SALUD.</summary>
    private static async Task<IResult> ActualizarFisiologia(FisiologiaDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        if (dto.SexoCalculo is not (null or "H" or "M"))
            return Results.Problem(title: "SexoCalculo debe ser H (hombre) o M (mujer).",
                                   statusCode: StatusCodes.Status400BadRequest);

        var uid = http.UsuarioId();
        var p = new DynamicParameters(new
        {
            UsuarioId = uid, dto.PesoCorporalKg, dto.SexoCalculo, dto.Vo2MaxMlKgMin, dto.FcMaxLpm
        });
        p.Add("FechaNacimiento", dto.FechaNacimiento?.Date, DbType.Date);

        await db.ExecAsync("gym.usp_ActualizarDatosFisiologicos", p, ct);
        return Results.Ok(await LeerFisiologiaAsync(db, uid, ct));
    }

    private static Task<FilaFisiologia?> LeerFisiologiaAsync(Db db, int uid, CancellationToken ct) =>
        db.QuerySingleOrDefaultAsync<FilaFisiologia>("""
            SELECT PesoCorporalKg, FechaNacimiento, SexoCalculo, Vo2MaxMlKgMin, FcMaxLpm
            FROM gym.Usuario WHERE UsuarioId = @uid
            """, new { uid }, ct);

    /* ---------- Consentimientos ---------- */

    /// <summary>Estado vigente de cada consentimiento (el último registrado por tipo).</summary>
    private static async Task<IResult> ListarConsentimientos(HttpContext http, Db db, CancellationToken ct) =>
        Results.Ok(await LeerConsentimientosAsync(db, http.UsuarioId(), ct));

    /// <summary>Otorgar o retirar. Al retirar se borran los datos que dependían del consentimiento.</summary>
    private static async Task<IResult> RegistrarConsentimiento(ConsentimientoDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        if (!TiposConsentimiento.Contains(dto.Tipo))
            return Results.Problem(title: "Tipo de consentimiento no válido (UBICACION o SALUD).",
                                   statusCode: StatusCodes.Status400BadRequest);

        var uid = http.UsuarioId();
        await db.ExecAsync("gym.usp_RegistrarConsentimiento",
            new { UsuarioId = uid, dto.Tipo, dto.Otorgado, dto.VersionTexto }, ct);

        return Results.Ok(await LeerConsentimientosAsync(db, uid, ct));
    }

    private static Task<List<FilaConsentimiento>> LeerConsentimientosAsync(Db db, int uid, CancellationToken ct) =>
        db.QueryAsync<FilaConsentimiento>("""
            SELECT Tipo, Otorgado, VersionTexto, Fecha
            FROM (
                SELECT Tipo, Otorgado, VersionTexto, Fecha,
                       ROW_NUMBER() OVER (PARTITION BY Tipo ORDER BY Fecha DESC, ConsentimientoId DESC) AS rn
                FROM gym.Consentimiento
                WHERE UsuarioId = @uid
            ) x
            WHERE rn = 1
            ORDER BY Tipo
            """, new { uid }, ct);

    /* ---------- Zonas privadas ---------- */

    private static async Task<IResult> ListarZonas(HttpContext http, Db db, CancellationToken ct) =>
        Results.Ok(await db.QueryAsync<FilaZonaPrivada>("""
            SELECT ZonaPrivadaId, Nombre, Centro.Lat AS Lat, Centro.Long AS Lon, RadioM
            FROM gym.ZonaPrivada
            WHERE UsuarioId = @uid
            ORDER BY Nombre
            """, new { uid = http.UsuarioId() }, ct));

    /// <summary>Se aplica también a las rutas públicas de las actividades ya registradas.</summary>
    private static async Task<IResult> CrearZona(ZonaNuevaDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        var p = new DynamicParameters(new { UsuarioId = http.UsuarioId(), dto.Nombre, dto.Lat, dto.Lon, dto.RadioM });
        p.Add("ZonaPrivadaId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await db.ExecAsync("gym.usp_GuardarZonaPrivada", p, ct);

        var id = p.Get<int>("ZonaPrivadaId");
        return Results.Created($"/zonas-privadas/{id}", new { ZonaPrivadaId = id });
    }

    private static async Task<IResult> QuitarZona(int zonaId, HttpContext http, Db db, CancellationToken ct)
    {
        await db.ExecAsync("gym.usp_QuitarZonaPrivada", new { UsuarioId = http.UsuarioId(), ZonaPrivadaId = zonaId }, ct);
        return Results.NoContent();
    }
}
