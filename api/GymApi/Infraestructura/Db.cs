using System.Data;
using System.Data.Common;
using Dapper;
using Microsoft.Data.SqlClient;

namespace GymApi.Infraestructura;

public sealed class Db(IConfiguration config)
{
    private readonly string _cadena = config.GetConnectionString("Gym")
        ?? throw new InvalidOperationException("Falta la cadena de conexión 'Gym'.");

    public SqlConnection Abrir() => new(_cadena);

    /// <summary>Ejecuta un procedimiento sin leer resultados. Los parámetros de salida quedan disponibles al terminar.</summary>
    public async Task ExecAsync(string proc, object parametros, CancellationToken ct)
    {
        await using var cn = Abrir();
        await cn.ExecuteAsync(new CommandDefinition(proc, parametros,
            commandType: CommandType.StoredProcedure, cancellationToken: ct));
    }

    /// <summary>
    /// Ejecuta un procedimiento y lee su primer conjunto de resultados, si lo devuelve.
    /// Algunos procedimientos no devuelven filas en ciertos casos (p. ej. sesión libre),
    /// por eso se comprueba FieldCount antes de leer.
    /// </summary>
    public async Task<List<T>> ProcAsync<T>(string proc, object parametros, CancellationToken ct)
    {
        var filas = new List<T>();

        await using var cn = Abrir();
        await cn.OpenAsync(ct);

        await using (var reader = (DbDataReader)await cn.ExecuteReaderAsync(new CommandDefinition(proc, parametros,
            commandType: CommandType.StoredProcedure, cancellationToken: ct)))
        {
            if (reader.FieldCount > 0)
            {
                var parser = reader.GetRowParser<T>();
                while (await reader.ReadAsync(ct))
                    filas.Add(parser(reader));
            }
        } // al cerrar el lector se procesan los resultados restantes y se rellenan los parámetros de salida

        return filas;
    }

    /// <summary>Ejecuta un procedimiento que devuelve dos conjuntos de resultados (p. ej. resumen + detalle).</summary>
    public async Task<(List<T1> Primero, List<T2> Segundo)> ProcMultipleAsync<T1, T2>(
        string proc, object parametros, CancellationToken ct)
    {
        await using var cn = Abrir();
        using var grid = await cn.QueryMultipleAsync(new CommandDefinition(proc, parametros,
            commandType: CommandType.StoredProcedure, cancellationToken: ct));

        var primero = (await grid.ReadAsync<T1>()).AsList();
        var segundo = (await grid.ReadAsync<T2>()).AsList();
        return (primero, segundo);
    }

    /// <summary>Ejecuta un procedimiento que devuelve tres conjuntos de resultados.</summary>
    public async Task<(List<T1> Primero, List<T2> Segundo, List<T3> Tercero)> ProcMultipleAsync<T1, T2, T3>(
        string proc, object parametros, CancellationToken ct)
    {
        await using var cn = Abrir();
        using var grid = await cn.QueryMultipleAsync(new CommandDefinition(proc, parametros,
            commandType: CommandType.StoredProcedure, cancellationToken: ct));

        var primero = (await grid.ReadAsync<T1>()).AsList();
        var segundo = (await grid.ReadAsync<T2>()).AsList();
        var tercero = (await grid.ReadAsync<T3>()).AsList();
        return (primero, segundo, tercero);
    }

    public async Task<List<T>> QueryAsync<T>(string sql, object? parametros, CancellationToken ct)
    {
        await using var cn = Abrir();
        return (await cn.QueryAsync<T>(new CommandDefinition(sql, parametros, cancellationToken: ct))).AsList();
    }

    public async Task<T?> QuerySingleOrDefaultAsync<T>(string sql, object? parametros, CancellationToken ct)
    {
        await using var cn = Abrir();
        return await cn.QuerySingleOrDefaultAsync<T>(new CommandDefinition(sql, parametros, cancellationToken: ct));
    }
}
