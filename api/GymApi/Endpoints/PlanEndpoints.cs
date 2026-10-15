using Dapper;
using GymApi.Infraestructura;
using GymApi.Modelos;

namespace GymApi.Endpoints;

/// <summary>
/// Estado del plan y gestión de miembros de gimnasios.
/// Las notificaciones de compra de Apple, Google y Stripe van en un bloque aparte,
/// porque requieren verificar firmas con las credenciales de cada tienda.
/// </summary>
public static class PlanEndpoints
{
    private static readonly HashSet<string> Roles = ["SOCIO", "ENTRENADOR", "ADMIN"];

    public static void MapPlanEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGroup("/planes").WithTags("Planes").RequiereUsuario()
           .MapGet("/estado", EstadoPlan);

        var org = app.MapGroup("/organizaciones").WithTags("Gimnasios").RequiereUsuario();
        org.MapGet("/{orgId:int}/miembros", ListarMiembros);
        org.MapPost("/{orgId:int}/miembros", AgregarMiembro);
        org.MapDelete("/{orgId:int}/miembros/{usuarioId:int}", QuitarMiembro);
    }

    /// <summary>Fuentes de acceso vigentes y funciones incluidas. La app lo usa para mostrar u ocultar funciones Premium.</summary>
    private static async Task<IResult> EstadoPlan(HttpContext http, Db db, CancellationToken ct)
    {
        var (fuentes, funciones) = await db.ProcMultipleAsync<FilaFuentePlan, FilaFuncionPlan>(
            "gym.usp_EstadoPlan", new { UsuarioId = http.UsuarioId() }, ct);

        return Results.Ok(new
        {
            Premium = fuentes.Any(f => f.Plan == "PREMIUM"),
            Fuentes = fuentes,
            Funciones = funciones
        });
    }

    /// <summary>Solo administración y equipo de entrenamiento del gimnasio (minimización de datos).</summary>
    private static async Task<IResult> ListarMiembros(int orgId, HttpContext http, Db db, CancellationToken ct)
    {
        var uid = http.UsuarioId();
        var rol = await db.QuerySingleOrDefaultAsync<string>(
            "SELECT Rol FROM gym.OrganizacionMiembro WHERE OrganizacionId = @orgId AND UsuarioId = @uid",
            new { orgId, uid }, ct);

        if (rol is not ("ADMIN" or "ENTRENADOR"))
            return Results.Problem(title: "Solo la administración o el equipo de entrenamiento del gimnasio puede ver sus miembros.",
                                   statusCode: StatusCodes.Status403Forbidden);

        return Results.Ok(await db.QueryAsync<FilaMiembro>("""
            SELECT u.UsuarioId, u.Nombre, u.Email, m.Rol, m.FechaAlta
            FROM gym.OrganizacionMiembro m
            JOIN gym.Usuario u ON u.UsuarioId = m.UsuarioId
            WHERE m.OrganizacionId = @orgId
            ORDER BY m.Rol, u.Nombre
            """, new { orgId }, ct));
    }

    /// <summary>Alta por correo electrónico. El procedimiento comprueba que quien lo pide es ADMIN y que quedan plazas.</summary>
    private static async Task<IResult> AgregarMiembro(int orgId, MiembroNuevoDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        var rolNuevo = dto.Rol ?? "SOCIO";
        if (!Roles.Contains(rolNuevo))
            return Results.Problem(title: "Rol no válido (SOCIO, ENTRENADOR o ADMIN).", statusCode: StatusCodes.Status400BadRequest);

        var usuarioId = await db.QuerySingleOrDefaultAsync<int?>(
            "SELECT UsuarioId FROM gym.Usuario WHERE Email = LOWER(LTRIM(RTRIM(@email)))",
            new { email = dto.Email }, ct);

        if (usuarioId is null)
            return Results.Problem(title: "No hay ninguna cuenta con ese correo electrónico.", statusCode: StatusCodes.Status404NotFound);

        await db.ExecAsync("gym.usp_AgregarMiembroOrganizacion", new
        {
            AdminUsuarioId = http.UsuarioId(),
            OrganizacionId = orgId,
            UsuarioId = usuarioId.Value,
            Rol = rolNuevo
        }, ct);

        return Results.Created($"/organizaciones/{orgId}/miembros/{usuarioId}", new { UsuarioId = usuarioId });
    }

    /// <summary>La administración puede dar de baja a cualquiera; cada persona, a sí misma.</summary>
    private static async Task<IResult> QuitarMiembro(int orgId, int usuarioId, HttpContext http, Db db, CancellationToken ct)
    {
        await db.ExecAsync("gym.usp_QuitarMiembroOrganizacion", new
        {
            SolicitanteId = http.UsuarioId(),
            OrganizacionId = orgId,
            UsuarioId = usuarioId
        }, ct);

        return Results.NoContent();
    }
}
