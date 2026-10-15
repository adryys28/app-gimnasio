using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace GymApi.Infraestructura;

/// <summary>
/// Convierte los errores de negocio lanzados con THROW (50000-50999) en respuestas ProblemDetails.
/// El resto de excepciones siguen al manejador por defecto (500).
/// </summary>
public sealed class ManejadorErroresSql(IProblemDetailsService problemas) : IExceptionHandler
{
    // "No existe o no pertenece al usuario": 404 para no revelar recursos ajenos
    private static readonly HashSet<int> NoEncontrado = [50001, 50010, 50020, 50021, 50030, 50040];
    private static readonly HashSet<int> Conflicto = [50053, 50054, 2601, 2627];

    public async ValueTask<bool> TryHandleAsync(HttpContext ctx, Exception ex, CancellationToken ct)
    {
        if (ex is not SqlException sql)
            return false;

        var negocio = sql.Number is >= 50000 and <= 50999;
        if (!negocio && !Conflicto.Contains(sql.Number))
            return false;

        var estado = NoEncontrado.Contains(sql.Number) ? StatusCodes.Status404NotFound
                   : Conflicto.Contains(sql.Number)    ? StatusCodes.Status409Conflict
                   : sql.Number == 50002               ? StatusCodes.Status422UnprocessableEntity
                   : StatusCodes.Status400BadRequest;

        var detalle = new ProblemDetails
        {
            Status = estado,
            // Los errores 2601/2627 traen texto técnico de SQL Server: no se exponen
            Title = negocio ? sql.Message : "El registro ya existe."
        };
        detalle.Extensions["codigo"] = sql.Number;

        ctx.Response.StatusCode = estado;
        return await problemas.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = ctx,
            Exception = ex,
            ProblemDetails = detalle
        });
    }
}
