using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace GymApi.Infraestructura;

/// <summary>
/// SOLO DESARROLLO. Autentica con la cabecera X-Dev-Sub sin validar nada.
/// Program.cs solo lo registra cuando el entorno es Development.
/// </summary>
public sealed class DevAuthHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> opciones,
    ILoggerFactory logger,
    UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(opciones, logger, encoder)
{
    public const string Esquema = "Dev";

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.TryGetValue("X-Dev-Sub", out var sub) || string.IsNullOrWhiteSpace(sub))
            return Task.FromResult(AuthenticateResult.NoResult());

        var identidad = new ClaimsIdentity([new Claim("sub", sub.ToString())], Esquema);
        var ticket = new AuthenticationTicket(new ClaimsPrincipal(identidad), Esquema);
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
