using Dapper;
using GymApi.Infraestructura;
using GymApi.Modelos;

namespace GymApi.Endpoints;

/// <summary>Catálogo público: se usa también antes del registro (onboarding).</summary>
public static class CatalogoEndpoints
{
    public static void MapCatalogoEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("").WithTags("Catálogo");
        g.MapGet("/catalogos", Catalogos);
        g.MapGet("/ejercicios", BuscarEjercicios);
        g.MapGet("/ejercicios/{id:int}", ObtenerEjercicio);
    }

    private static async Task<IResult> Catalogos(Db db, CancellationToken ct)
    {
        const string sql = """
            SELECT CAST(NivelId AS INT) AS Id, Nombre FROM gym.Nivel ORDER BY NivelId;
            SELECT CAST(ObjetivoId AS INT) AS Id, Nombre FROM gym.Objetivo ORDER BY ObjetivoId;
            SELECT CAST(GrupoMuscularId AS INT) AS Id, Nombre FROM gym.GrupoMuscular ORDER BY Nombre;
            SELECT CAST(MaterialId AS INT) AS Id, Nombre FROM gym.Material ORDER BY Nombre;
            """;

        await using var cn = db.Abrir();
        using var m = await cn.QueryMultipleAsync(new CommandDefinition(sql, cancellationToken: ct));

        return Results.Ok(new
        {
            Niveles = (await m.ReadAsync<ItemCatalogo>()).AsList(),
            Objetivos = (await m.ReadAsync<ItemCatalogo>()).AsList(),
            GruposMusculares = (await m.ReadAsync<ItemCatalogo>()).AsList(),
            Materiales = (await m.ReadAsync<ItemCatalogo>()).AsList()
        });
    }

    private static async Task<IResult> BuscarEjercicios(
        int? nivelId, int? grupoMuscularId, int? materialId, string? texto,
        Db db, CancellationToken ct)
    {
        // OPTION (RECOMPILE): consulta con filtros opcionales; evita un plan malo reutilizado
        const string sql = """
            SELECT e.EjercicioId, e.Nombre, e.Descripcion, e.VideoUrl, e.MiniaturaUrl,
                   e.NivelMinimoId, e.TipoMedida
            FROM gym.Ejercicio e
            WHERE e.Activo = 1
              AND (@nivelId IS NULL OR e.NivelMinimoId <= @nivelId)
              AND (@grupoMuscularId IS NULL OR EXISTS (
                     SELECT 1 FROM gym.EjercicioMusculo em
                     WHERE em.EjercicioId = e.EjercicioId AND em.GrupoMuscularId = @grupoMuscularId))
              AND (@materialId IS NULL OR EXISTS (
                     SELECT 1 FROM gym.EjercicioMaterial x
                     WHERE x.EjercicioId = e.EjercicioId AND x.MaterialId = @materialId))
              AND (@texto IS NULL OR e.Nombre LIKE N'%' + @texto + N'%')
            ORDER BY e.Nombre
            OPTION (RECOMPILE);
            """;

        texto = string.IsNullOrWhiteSpace(texto) ? null : texto.Trim();
        return Results.Ok(await db.QueryAsync<FilaEjercicio>(sql,
            new { nivelId, grupoMuscularId, materialId, texto }, ct));
    }

    private static async Task<IResult> ObtenerEjercicio(int id, Db db, CancellationToken ct)
    {
        const string sql = """
            SELECT EjercicioId, Nombre, Descripcion, ErroresComunes, VideoUrl, MiniaturaUrl,
                   NivelMinimoId, TipoMedida
            FROM gym.Ejercicio WHERE EjercicioId = @id AND Activo = 1;

            SELECT g.Nombre, em.EsPrincipal
            FROM gym.EjercicioMusculo em
            JOIN gym.GrupoMuscular g ON g.GrupoMuscularId = em.GrupoMuscularId
            WHERE em.EjercicioId = @id
            ORDER BY em.EsPrincipal DESC, g.Nombre;

            SELECT m.Nombre
            FROM gym.EjercicioMaterial x
            JOIN gym.Material m ON m.MaterialId = x.MaterialId
            WHERE x.EjercicioId = @id
            ORDER BY m.Nombre;
            """;

        await using var cn = db.Abrir();
        using var m = await cn.QueryMultipleAsync(new CommandDefinition(sql, new { id }, cancellationToken: ct));

        var ejercicio = await m.ReadSingleOrDefaultAsync<FilaEjercicio>();
        if (ejercicio is null) return Results.NotFound();

        var musculos = (await m.ReadAsync<FilaMusculo>()).AsList();
        var materiales = (await m.ReadAsync<string>()).AsList();

        return Results.Ok(new EjercicioDetalleDto(ejercicio, musculos, materiales));
    }
}
