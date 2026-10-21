using GymApi.Infraestructura;
using GymApi.Modelos;

namespace GymApi.Endpoints;

/// <summary>Datos agregados para las pantallas Hoy y Resumen de sesión (diseño V2).</summary>
public static class EstadisticaEndpoints
{
    public static void MapEstadisticaEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGroup("/inicio").WithTags("Estadísticas").RequiereUsuario()
           .MapGet("/resumen", ResumenInicio);

        app.MapGroup("/sesiones").WithTags("Estadísticas").RequiereUsuario()
           .MapGet("/{sesionId:long}/resumen", ResumenSesion);
    }

    /// <summary>Sesiones de la semana, volumen por día, racha y últimos ajustes automáticos.</summary>
    private static async Task<IResult> ResumenInicio(HttpContext http, Db db, CancellationToken ct)
    {
        var (resumen, volumen, ajustes) = await db.ProcMultipleAsync<FilaResumenInicio, FilaVolumenDia, FilaAjusteReciente>(
            "gym.usp_ResumenInicio", new { UsuarioId = http.UsuarioId() }, ct);

        return Results.Ok(new { Resumen = resumen.Single(), VolumenSemana = volumen, Ajustes = ajustes });
    }

    /// <summary>Duración, volumen, récords personales y progresión de una sesión.</summary>
    private static async Task<IResult> ResumenSesion(long sesionId, HttpContext http, Db db, CancellationToken ct)
    {
        var (resumen, records, progresion) = await db.ProcMultipleAsync<FilaResumenSesion, FilaRecord, FilaProgresion>(
            "gym.usp_ResumenSesion", new { UsuarioId = http.UsuarioId(), SesionId = sesionId }, ct);

        return Results.Ok(new { Resumen = resumen.Single(), Records = records, Progresion = progresion });
    }
}
