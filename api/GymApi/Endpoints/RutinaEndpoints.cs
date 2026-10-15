using System.Data;
using Dapper;
using GymApi.Infraestructura;
using GymApi.Modelos;

namespace GymApi.Endpoints;

/// <summary>
/// Rutinas, días y ejercicios de la rutina. Todas las operaciones de
/// modificación devuelven la rutina completa actualizada, para que la
/// app móvil no tenga que hacer una segunda petición.
/// </summary>
public static class RutinaEndpoints
{
    public static void MapRutinaEndpoints(this IEndpointRouteBuilder app)
    {
        var rutinas = app.MapGroup("/rutinas").WithTags("Rutinas").RequiereUsuario();
        rutinas.MapGet("/", Listar);
        rutinas.MapGet("/activa", Activa);
        rutinas.MapGet("/{rutinaId:int}", Obtener);
        rutinas.MapPost("/sugerida", GenerarSugerida);
        rutinas.MapPost("/", CrearManual);
        rutinas.MapPost("/{rutinaId:int}/dias", AgregarDia);

        var dias = app.MapGroup("/dias").WithTags("Días").RequiereUsuario();
        dias.MapPatch("/{diaId:int}", RenombrarDia);
        dias.MapPut("/{diaId:int}/posicion", MoverDia);
        dias.MapDelete("/{diaId:int}", QuitarDia);
        dias.MapPost("/{diaId:int}/ejercicios", AgregarEjercicio);

        var ejercicios = app.MapGroup("/rutina-ejercicios").WithTags("Ejercicios de la rutina").RequiereUsuario();
        ejercicios.MapPatch("/{id:int}", Configurar);
        ejercicios.MapPut("/{id:int}/posicion", MoverEjercicio);
        ejercicios.MapPut("/{id:int}/peso", FijarPeso);
        ejercicios.MapDelete("/{id:int}", QuitarEjercicio);
        ejercicios.MapGet("/{id:int}/ajustes", Ajustes);
    }

    /* ---------- Consultas ---------- */

    private static async Task<IResult> Listar(HttpContext http, Db db, CancellationToken ct) =>
        Results.Ok(await db.QueryAsync<FilaRutina>("""
            SELECT RutinaId, Nombre, Origen, Activa, FechaAlta
            FROM gym.Rutina
            WHERE UsuarioId = @uid AND EsPlantilla = 0
            ORDER BY Activa DESC, FechaAlta DESC
            """, new { uid = http.UsuarioId() }, ct));

    private static async Task<IResult> Activa(HttpContext http, Db db, CancellationToken ct)
    {
        var filas = await db.QueryAsync<FilaRutinaDetalle>(
            "SELECT * FROM gym.vw_RutinaDetalle WHERE UsuarioId = @uid AND Activa = 1",
            new { uid = http.UsuarioId() }, ct);

        var rutina = Mapeo.Agrupar(filas).FirstOrDefault();
        return rutina is null ? Results.NotFound() : Results.Ok(rutina);
    }

    private static async Task<IResult> Obtener(int rutinaId, HttpContext http, Db db, CancellationToken ct)
    {
        var rutina = await CargarRutinaAsync(db, rutinaId, http.UsuarioId(), ct);
        return rutina is null ? Results.NotFound() : Results.Ok(rutina);
    }

    private static async Task<IResult> Ajustes(int id, HttpContext http, Db db, CancellationToken ct) =>
        Results.Ok(await db.QueryAsync<FilaAjuste>("""
            SELECT a.Fecha, a.Accion, a.Motivo, a.PesoAntes, a.PesoDespues,
                   a.RepsMinAntes, a.RepsMaxAntes, a.RepsMinDespues, a.RepsMaxDespues,
                   a.DurMinAntes, a.DurMaxAntes, a.DurMinDespues, a.DurMaxDespues
            FROM gym.AjusteRutina a
            JOIN gym.RutinaDiaEjercicio rde ON rde.RutinaDiaEjercicioId = a.RutinaDiaEjercicioId
            JOIN gym.RutinaDia d            ON d.RutinaDiaId = rde.RutinaDiaId
            JOIN gym.Rutina r               ON r.RutinaId = d.RutinaId
            WHERE a.RutinaDiaEjercicioId = @id AND r.UsuarioId = @uid
            ORDER BY a.Fecha DESC, a.AjusteId DESC
            """, new { id, uid = http.UsuarioId() }, ct));

    /* ---------- Rutinas ---------- */

    private static async Task<IResult> GenerarSugerida(SugeridaDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        var uid = http.UsuarioId();
        var p = new DynamicParameters(new { UsuarioId = uid, dto.NivelId, dto.ObjetivoId, dto.DiasSemana });
        p.Add("RutinaId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        p.Add("PlantillaId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await db.ExecAsync("gym.usp_GenerarRutinaSugerida", p, ct);
        return await CreadaAsync(db, p.Get<int>("RutinaId"), uid, ct);
    }

    private static async Task<IResult> CrearManual(RutinaManualDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        var uid = http.UsuarioId();
        var p = new DynamicParameters(new { UsuarioId = uid, dto.Nombre, dto.NumDias, dto.Activar });
        p.Add("RutinaId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await db.ExecAsync("gym.usp_CrearRutinaManual", p, ct);
        return await CreadaAsync(db, p.Get<int>("RutinaId"), uid, ct);
    }

    /* ---------- Días ---------- */

    private static async Task<IResult> AgregarDia(int rutinaId, DiaNuevoDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        var uid = http.UsuarioId();
        return await OperarAsync(db, rutinaId, uid, "gym.usp_AgregarDiaRutina",
            new { UsuarioId = uid, RutinaId = rutinaId, dto.Nombre, dto.Posicion }, ct);
    }

    private static async Task<IResult> RenombrarDia(int diaId, NombreDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        var uid = http.UsuarioId();
        return await OperarAsync(db, await RutinaDeDiaAsync(db, diaId, uid, ct), uid, "gym.usp_RenombrarDiaRutina",
            new { UsuarioId = uid, RutinaDiaId = diaId, dto.Nombre }, ct);
    }

    private static async Task<IResult> MoverDia(int diaId, PosicionDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        var uid = http.UsuarioId();
        return await OperarAsync(db, await RutinaDeDiaAsync(db, diaId, uid, ct), uid, "gym.usp_MoverDiaRutina",
            new { UsuarioId = uid, RutinaDiaId = diaId, NuevaPosicion = dto.Posicion }, ct);
    }

    private static async Task<IResult> QuitarDia(int diaId, HttpContext http, Db db, CancellationToken ct)
    {
        var uid = http.UsuarioId();
        return await OperarAsync(db, await RutinaDeDiaAsync(db, diaId, uid, ct), uid, "gym.usp_QuitarDiaRutina",
            new { UsuarioId = uid, RutinaDiaId = diaId }, ct);
    }

    /* ---------- Ejercicios de la rutina ---------- */

    private static async Task<IResult> AgregarEjercicio(int diaId, EjercicioNuevoDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        if (Mapeo.ValidarTipoMedida(dto.TipoMedida) is { } error) return error;

        var uid = http.UsuarioId();
        return await OperarAsync(db, await RutinaDeDiaAsync(db, diaId, uid, ct), uid, "gym.usp_AgregarEjercicioRutina",
            new
            {
                UsuarioId = uid, RutinaDiaId = diaId, dto.EjercicioId, dto.Posicion,
                dto.Series, dto.TipoMedida, dto.RepsMin, dto.RepsMax,
                dto.DuracionSegMin, dto.DuracionSegMax, dto.DescansoSeg, dto.RpeObjetivo
            }, ct);
    }

    private static async Task<IResult> Configurar(int id, ConfigEjercicioDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        if (Mapeo.ValidarTipoMedida(dto.TipoMedida) is { } error) return error;

        var uid = http.UsuarioId();
        return await OperarAsync(db, await RutinaDeEjercicioAsync(db, id, uid, ct), uid, "gym.usp_ConfigurarEjercicioRutina",
            new
            {
                UsuarioId = uid, RutinaDiaEjercicioId = id,
                dto.Series, dto.TipoMedida, dto.RepsMin, dto.RepsMax,
                dto.DuracionSegMin, dto.DuracionSegMax, dto.DescansoSeg, dto.RpeObjetivo
            }, ct);
    }

    private static async Task<IResult> MoverEjercicio(int id, PosicionDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        var uid = http.UsuarioId();
        return await OperarAsync(db, await RutinaDeEjercicioAsync(db, id, uid, ct), uid, "gym.usp_MoverEjercicioRutina",
            new { UsuarioId = uid, RutinaDiaEjercicioId = id, NuevaPosicion = dto.Posicion }, ct);
    }

    private static async Task<IResult> FijarPeso(int id, PesoDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        var uid = http.UsuarioId();
        return await OperarAsync(db, await RutinaDeEjercicioAsync(db, id, uid, ct), uid, "gym.usp_FijarPesoObjetivo",
            new { UsuarioId = uid, RutinaDiaEjercicioId = id, dto.PesoKg }, ct);
    }

    private static async Task<IResult> QuitarEjercicio(int id, HttpContext http, Db db, CancellationToken ct)
    {
        var uid = http.UsuarioId();
        return await OperarAsync(db, await RutinaDeEjercicioAsync(db, id, uid, ct), uid, "gym.usp_QuitarEjercicioRutina",
            new { UsuarioId = uid, RutinaDiaEjercicioId = id }, ct);
    }

    /* ---------- Auxiliares ---------- */

    /// <summary>
    /// Ejecuta el procedimiento y devuelve la rutina actualizada.
    /// El RutinaId se obtiene antes de ejecutar (necesario al borrar).
    /// </summary>
    private static async Task<IResult> OperarAsync(Db db, int? rutinaId, int uid, string proc, object args, CancellationToken ct)
    {
        if (rutinaId is null) return Results.NotFound();

        await db.ExecAsync(proc, args, ct);
        return Results.Ok(await CargarRutinaAsync(db, rutinaId.Value, uid, ct));
    }

    private static async Task<IResult> CreadaAsync(Db db, int rutinaId, int uid, CancellationToken ct) =>
        Results.Created($"/rutinas/{rutinaId}", await CargarRutinaAsync(db, rutinaId, uid, ct));

    private static async Task<RutinaDto?> CargarRutinaAsync(Db db, int rutinaId, int uid, CancellationToken ct)
    {
        var filas = await db.QueryAsync<FilaRutinaDetalle>(
            "SELECT * FROM gym.vw_RutinaDetalle WHERE RutinaId = @rutinaId AND UsuarioId = @uid",
            new { rutinaId, uid }, ct);
        return Mapeo.Agrupar(filas).FirstOrDefault();
    }

    private static Task<int?> RutinaDeDiaAsync(Db db, int diaId, int uid, CancellationToken ct) =>
        db.QuerySingleOrDefaultAsync<int?>("""
            SELECT r.RutinaId
            FROM gym.RutinaDia d
            JOIN gym.Rutina r ON r.RutinaId = d.RutinaId
            WHERE d.RutinaDiaId = @diaId AND r.UsuarioId = @uid AND r.EsPlantilla = 0
            """, new { diaId, uid }, ct);

    private static Task<int?> RutinaDeEjercicioAsync(Db db, int id, int uid, CancellationToken ct) =>
        db.QuerySingleOrDefaultAsync<int?>("""
            SELECT r.RutinaId
            FROM gym.RutinaDiaEjercicio rde
            JOIN gym.RutinaDia d ON d.RutinaDiaId = rde.RutinaDiaId
            JOIN gym.Rutina r    ON r.RutinaId = d.RutinaId
            WHERE rde.RutinaDiaEjercicioId = @id AND r.UsuarioId = @uid AND r.EsPlantilla = 0
            """, new { id, uid }, ct);
}
