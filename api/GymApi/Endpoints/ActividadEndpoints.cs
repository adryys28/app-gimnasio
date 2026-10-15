using System.Data;
using System.Text.Json;
using Dapper;
using GymApi.Infraestructura;
using GymApi.Modelos;

namespace GymApi.Endpoints;

/// <summary>Cardio con GPS: iniciar, enviar puntos por lotes, finalizar y consultar.</summary>
public static class ActividadEndpoints
{
    private const int MaxPuntosPorLote = 500;
    private static readonly HashSet<string> Origenes = ["MOVIL", "APPLE_WATCH", "WEAR_OS", "GARMIN", "IMPORTADA"];
    private static readonly JsonSerializerOptions JsonPuntos = new(JsonSerializerDefaults.Web);

    public static void MapActividadEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/actividades/tipos", Tipos).WithTags("Actividades");

        var g = app.MapGroup("/actividades").WithTags("Actividades").RequiereUsuario();
        g.MapGet("/", Listar);
        g.MapPost("/", Iniciar);
        g.MapGet("/{actividadId:long}", Obtener);
        g.MapPost("/{actividadId:long}/puntos", RegistrarPuntos);
        g.MapPost("/{actividadId:long}/finalizar", Finalizar);
        g.MapDelete("/{actividadId:long}", Eliminar);
    }

    private static async Task<IResult> Tipos(Db db, CancellationToken ct) =>
        Results.Ok(await db.QueryAsync<FilaTipoActividad>(
            "SELECT TipoActividadId, Nombre, Exterior FROM gym.TipoActividad ORDER BY TipoActividadId", null, ct));

    /// <summary>Historial paginado. Respeta el límite de días del plan gratuito.</summary>
    private static async Task<IResult> Listar(int? pagina, int? tamPagina, HttpContext http, Db db, CancellationToken ct)
    {
        var (actividades, ocultas) = await db.ProcMultipleAsync<FilaActividadLista, int>(
            "gym.usp_ListarActividades",
            new { UsuarioId = http.UsuarioId(), Pagina = pagina ?? 1, TamPagina = tamPagina ?? 20 }, ct);

        return Results.Ok(new { Actividades = actividades, OcultasPorPlan = ocultas.FirstOrDefault() });
    }

    private static async Task<IResult> Iniciar(IniciarActividadDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        // Se valida aquí porque SQL Server truncaría en silencio un texto largo a VARCHAR(15)
        var origen = dto.Origen ?? "MOVIL";
        if (!Origenes.Contains(origen))
            return Results.Problem(title: "Origen no válido.", statusCode: StatusCodes.Status400BadRequest);

        var p = new DynamicParameters(new { UsuarioId = http.UsuarioId(), dto.TipoActividadId, Origen = origen });
        p.Add("ActividadId", dbType: DbType.Int64, direction: ParameterDirection.Output);

        await db.ExecAsync("gym.usp_IniciarActividad", p, ct);

        var id = p.Get<long>("ActividadId");
        return Results.Created($"/actividades/{id}", new { ActividadId = id });
    }

    /// <summary>
    /// Lote de puntos GPS (máximo 500). Idempotente: si la app reenvía un lote
    /// por un fallo de red, los puntos ya guardados se ignoran.
    /// </summary>
    private static async Task<IResult> RegistrarPuntos(long actividadId, List<PuntoDto> puntos, HttpContext http, Db db, CancellationToken ct)
    {
        if (puntos.Count is 0 or > MaxPuntosPorLote)
            return Results.Problem(title: $"El lote debe tener entre 1 y {MaxPuntosPorLote} puntos.",
                                   statusCode: StatusCodes.Status400BadRequest);

        var guardados = await db.ProcAsync<int>("gym.usp_RegistrarPuntos", new
        {
            UsuarioId = http.UsuarioId(),
            ActividadId = actividadId,
            PuntosJson = JsonSerializer.Serialize(puntos, JsonPuntos)
        }, ct);

        return Results.Ok(new { PuntosGuardados = guardados.FirstOrDefault() });
    }

    /// <summary>Procesa la ruta y devuelve el resumen con parciales por km. El cuerpo es opcional.</summary>
    private static async Task<IResult> Finalizar(long actividadId, FinalizarActividadDto? dto, HttpContext http, Db db, CancellationToken ct)
    {
        var (resumen, parciales) = await db.ProcMultipleAsync<FilaActividad, FilaParcial>(
            "gym.usp_FinalizarActividad",
            new { UsuarioId = http.UsuarioId(), ActividadId = actividadId, KcalDispositivo = dto?.KcalDispositivo }, ct);

        return Results.Ok(Detalle(resumen, parciales));
    }

    private static async Task<IResult> Obtener(long actividadId, HttpContext http, Db db, CancellationToken ct)
    {
        var (resumen, parciales) = await db.ProcMultipleAsync<FilaActividad, FilaParcial>(
            "gym.usp_ObtenerActividad",
            new { UsuarioId = http.UsuarioId(), ActividadId = actividadId }, ct);

        return Results.Ok(Detalle(resumen, parciales));
    }

    /// <summary>Derecho de supresión: borra la actividad, sus puntos y sus parciales.</summary>
    private static async Task<IResult> Eliminar(long actividadId, HttpContext http, Db db, CancellationToken ct)
    {
        await db.ExecAsync("gym.usp_EliminarActividad", new { UsuarioId = http.UsuarioId(), ActividadId = actividadId }, ct);
        return Results.NoContent();
    }

    private static ActividadDetalleDto Detalle(List<FilaActividad> resumen, List<FilaParcial> parciales)
    {
        var a = resumen.Single();
        return new ActividadDetalleDto(a, parciales, Geo.AGeoJson(a.RutaWkt), Geo.AGeoJson(a.RutaPublicaWkt));
    }
}
