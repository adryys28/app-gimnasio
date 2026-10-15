using System.Data;
using Dapper;
using GymApi.Infraestructura;
using GymApi.Modelos;

namespace GymApi.Endpoints;

public static class SesionEndpoints
{
    public static void MapSesionEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/sesiones").WithTags("Sesiones").RequiereUsuario();
        g.MapPost("/", Iniciar);
        g.MapPost("/{sesionId:long}/series", RegistrarSerie);
        g.MapPost("/{sesionId:long}/finalizar", Finalizar);
    }

    private static async Task<IResult> Iniciar(SesionNuevaDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        var p = new DynamicParameters(new { UsuarioId = http.UsuarioId(), dto.RutinaDiaId });
        p.Add("SesionId", dbType: DbType.Int64, direction: ParameterDirection.Output);

        // Devuelve el plan del día (vacío si es una sesión libre)
        var filas = await db.ProcAsync<FilaRutinaDetalle>("gym.usp_IniciarSesion", p, ct);
        var plan = Mapeo.Agrupar(filas).FirstOrDefault()?.Dias.FirstOrDefault();

        return Results.Ok(new { SesionId = p.Get<long>("SesionId"), Plan = plan });
    }

    private static async Task<IResult> RegistrarSerie(long sesionId, SerieDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        var p = new DynamicParameters(new
        {
            UsuarioId = http.UsuarioId(), SesionId = sesionId,
            dto.EjercicioId, dto.Reps, dto.DuracionSeg, dto.PesoKg, dto.Rpe
        });
        p.Add("SesionSerieId", dbType: DbType.Int64, direction: ParameterDirection.Output);

        await db.ExecAsync("gym.usp_RegistrarSerie", p, ct);
        return Results.Ok(new { SesionSerieId = p.Get<long>("SesionSerieId") });
    }

    private static async Task<IResult> Finalizar(long sesionId, FinalizarDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        // El resumen de adaptación llega como conjunto de resultados de usp_AdaptarRutinaPorSesion
        var adaptacion = await db.ProcAsync<FilaAdaptacion>("gym.usp_FinalizarSesion",
            new { UsuarioId = http.UsuarioId(), SesionId = sesionId, dto.Notas, dto.Adaptar }, ct);

        return Results.Ok(new { SesionId = sesionId, Adaptacion = adaptacion });
    }
}
