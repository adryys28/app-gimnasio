using System.Data;
using System.Text.Json;
using Dapper;
using GymApi.Infraestructura;
using GymApi.Modelos;
using Microsoft.Data.SqlClient;

namespace GymApi.Endpoints;

/// <summary>
/// Cuestionario inicial: recomendación de días y rutina personalizada.
/// Por defecto la rutina la crea el generador de reglas (determinista y sin coste).
/// La IA solo se usa si se activa expresamente con Ia:Habilitada = true y hay clave.
/// </summary>
public static class EntrenamientoEndpoints
{
    private const int MaxGeneracionesIaPorDia = 5; // control de coste

    public static void MapEntrenamientoEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/entrenamiento/recomendacion-dias", RecomendacionDias).WithTags("Entrenamiento");

        app.MapGroup("/rutinas").WithTags("Entrenamiento").RequiereUsuario()
           .MapPost("/cuestionario", CrearRutinaCuestionario);
    }

    /// <summary>
    /// Días recomendados según el nivel, siguiendo las pautas de progresión del ACSM (2009):
    /// principiante 2-3, intermedio 3-4 y avanzado 4-6 días por semana.
    /// </summary>
    private static IResult RecomendacionDias(int nivelId, int objetivoId)
    {
        if (nivelId is < 1 or > 3 || objetivoId is < 1 or > 3)
            return Results.Problem(title: "Nivel (1-3) u objetivo (1-3) no válidos.", statusCode: StatusCodes.Status400BadRequest);

        var (recomendado, minimo, maximo, motivo) = nivelId switch
        {
            1 => (3, 2, 3, "Para empezar, 2-3 días de cuerpo completo permiten aprender la técnica y recuperarte bien."),
            2 => (4, 3, 4, "Con algo de experiencia, 3-4 días permiten trabajar cada grupo muscular dos veces por semana."),
            _ => (5, 4, 6, "A nivel avanzado, 4-6 días permiten repartir más volumen sin comprometer la recuperación."),
        };
        motivo += objetivoId switch
        {
            1 => " Para ganar fuerza, prioriza los ejercicios básicos y descansos largos entre series.",
            2 => " Para ganar músculo conviene entrenar cada grupo muscular al menos dos veces por semana.",
            _ => " Para perder grasa, combínalo con actividad cardiovascular: la OMS recomienda 150-300 minutos semanales de actividad moderada.",
        };
        return Results.Ok(new RecomendacionDiasDto(recomendado, minimo, maximo, motivo,
            "ACSM (2009), modelos de progresión en entrenamiento de fuerza; OMS (2020), actividad física."));
    }

    /// <summary>
    /// Guarda las respuestas del cuestionario y crea la rutina.
    /// Orden: IA (solo si está habilitada) y, si no, generador de reglas.
    /// </summary>
    private static async Task<IResult> CrearRutinaCuestionario(CuestionarioDto dto, HttpContext http, Db db,
        GeneradorRutinaIa ia, IConfiguration config, ILogger<GeneradorRutinaIa> log, CancellationToken ct)
    {
        if (dto.NivelId is < 1 or > 3 || dto.ObjetivoId is < 1 or > 3 || dto.DiasSemana is < 2 or > 6)
            return Results.Problem(title: "Respuestas del cuestionario no válidas.", statusCode: StatusCodes.Status400BadRequest);

        var uid = http.UsuarioId();
        await db.ExecAsync("gym.usp_ActualizarPerfilEntrenamiento",
            new { UsuarioId = uid, dto.NivelId, dto.ObjetivoId, dto.DiasSemana }, ct);

        int? rutinaId = null;
        var conIa = false;

        if (config.GetValue<bool>("Ia:Habilitada") && ia.Disponible)
        {
            var hoy = await db.QuerySingleOrDefaultAsync<int>("""
                SELECT COUNT(*) FROM gym.Rutina
                WHERE UsuarioId = @uid AND Origen = 'I' AND FechaAlta >= CAST(SYSUTCDATETIME() AS DATE)
                """, new { uid }, ct);

            if (hoy < MaxGeneracionesIaPorDia)
            {
                try
                {
                    var plan = await ia.GenerarPlanJsonAsync(dto.NivelId, dto.ObjetivoId, dto.DiasSemana, ct);
                    rutinaId = await GuardarPlanAsync(db, uid, plan, "I", ct);
                    conIa = true;
                }
                catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException
                                              or SqlException { Number: >= 50130 and <= 50137 })
                {
                    log.LogWarning(ex, "Rutina con IA no disponible; se usa el generador de reglas.");
                }
            }
        }

        if (rutinaId is null)
        {
            var catalogo = await db.QueryAsync<FilaCatalogoReglas>("""
                SELECT e.EjercicioId, e.Nombre, e.NivelMinimoId, e.TipoMedida,
                       COALESCE((SELECT STRING_AGG(g.Nombre, '|') FROM gym.EjercicioMusculo em
                                 JOIN gym.GrupoMuscular g ON g.GrupoMuscularId = em.GrupoMuscularId
                                 WHERE em.EjercicioId = e.EjercicioId AND em.EsPrincipal = 1), '') AS Principales,
                       (SELECT COUNT(*) FROM gym.EjercicioMusculo em WHERE em.EjercicioId = e.EjercicioId) AS NumMusculos
                FROM gym.Ejercicio e
                WHERE e.Activo = 1
                ORDER BY e.EjercicioId
                """, null, ct);

            var plan = GeneradorRutinaReglas.Generar(dto.NivelId, dto.ObjetivoId, dto.DiasSemana, catalogo);
            rutinaId = await GuardarPlanAsync(db, uid, plan.ToJsonString(), "S", ct);
        }

        var rutina = await RutinaEndpoints.CargarRutinaAsync(db, rutinaId.Value, uid, ct);
        return Results.Created($"/rutinas/{rutinaId}", new { Rutina = rutina, GeneradaConIa = conIa });
    }

    /// <summary>Valida y guarda el plan con usp_CrearRutinaDesdeJson (desactiva la rutina anterior).</summary>
    private static async Task<int> GuardarPlanAsync(Db db, int uid, string planJson, string origen, CancellationToken ct)
    {
        var p = new DynamicParameters(new { UsuarioId = uid, PlanJson = planJson, Origen = origen });
        p.Add("RutinaId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await db.ExecAsync("gym.usp_CrearRutinaDesdeJson", p, ct);
        return p.Get<int>("RutinaId");
    }
}
