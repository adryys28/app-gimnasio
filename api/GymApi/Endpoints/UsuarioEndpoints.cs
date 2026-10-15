using System.Data;
using Dapper;
using GymApi.Infraestructura;
using GymApi.Modelos;

namespace GymApi.Endpoints;

public static class UsuarioEndpoints
{
    public static void MapUsuarioEndpoints(this IEndpointRouteBuilder app)
    {
        // Registro: requiere token válido, pero todavía no existe el usuario interno
        app.MapGroup("/usuarios").WithTags("Usuarios")
           .RequireAuthorization()
           .MapPost("/me", Registrar);

        app.MapGroup("/usuarios").WithTags("Usuarios")
           .RequiereUsuario()
           .MapGet("/me", Obtener);
    }

    private static async Task<IResult> Registrar(RegistroUsuarioDto dto, HttpContext http, Db db, CancellationToken ct)
    {
        var sub = UsuarioActual.Sub(http.User);
        if (sub is null) return Results.Unauthorized();

        var p = new DynamicParameters(new
        {
            IdExterno = sub, dto.Nombre, dto.Email, dto.NivelId, dto.ObjetivoId, dto.DiasSemana
        });
        p.Add("FechaNacimiento", dto.FechaNacimiento?.Date, DbType.Date);
        p.Add("UsuarioId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await db.ExecAsync("gym.usp_RegistrarUsuario", p, ct);

        return Results.Created("/usuarios/me", new { UsuarioId = p.Get<int>("UsuarioId") });
    }

    private static async Task<IResult> Obtener(HttpContext http, Db db, CancellationToken ct)
    {
        var u = await db.QuerySingleOrDefaultAsync<FilaUsuario>("""
            SELECT UsuarioId, Nombre, Email, FechaNacimiento, NivelId, ObjetivoId, DiasSemana
            FROM gym.Usuario WHERE UsuarioId = @uid
            """, new { uid = http.UsuarioId() }, ct);

        return u is null ? Results.NotFound() : Results.Ok(u);
    }
}
