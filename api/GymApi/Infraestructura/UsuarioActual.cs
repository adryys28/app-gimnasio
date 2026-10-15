using System.Security.Claims;
using Microsoft.Extensions.Caching.Memory;

namespace GymApi.Infraestructura;

/// <summary>Traduce el claim "sub" del token al UsuarioId interno, con caché.</summary>
public sealed class UsuarioActual(Db db, IMemoryCache cache)
{
    public static string? Sub(ClaimsPrincipal usuario) => usuario.FindFirstValue("sub");

    public async Task<int?> IdAsync(ClaimsPrincipal usuario, CancellationToken ct)
    {
        var sub = Sub(usuario);
        if (sub is null) return null;

        var clave = ("usuario", sub);
        if (cache.TryGetValue(clave, out int id)) return id;

        var encontrado = await db.QuerySingleOrDefaultAsync<int?>(
            "SELECT UsuarioId FROM gym.Usuario WHERE IdExterno = @sub", new { sub }, ct);

        // Solo se cachean usuarios existentes, para que el registro surta efecto al momento
        if (encontrado is int valor)
            cache.Set(clave, valor, TimeSpan.FromMinutes(30));

        return encontrado;
    }
}

public static class FiltroUsuario
{
    private const string Clave = "UsuarioId";

    /// <summary>Exige autenticación y usuario registrado; deja el UsuarioId en HttpContext.Items.</summary>
    public static RouteGroupBuilder RequiereUsuario(this RouteGroupBuilder grupo)
    {
        grupo.RequireAuthorization();
        grupo.AddEndpointFilter(async (ctx, siguiente) =>
        {
            var http = ctx.HttpContext;
            var id = await http.RequestServices.GetRequiredService<UsuarioActual>()
                               .IdAsync(http.User, http.RequestAborted);

            if (id is null)
                return Results.Problem(
                    title: "Usuario no registrado. Completa el registro en POST /usuarios/me.",
                    statusCode: StatusCodes.Status403Forbidden);

            http.Items[Clave] = id.Value;
            return await siguiente(ctx);
        });
        return grupo;
    }

    public static int UsuarioId(this HttpContext http) => (int)http.Items[Clave]!;
}
