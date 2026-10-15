namespace GymApi.Modelos;

/* =====================================================================
   Filas leídas de SQL Server (Dapper). Los tipos coinciden con las
   columnas: TINYINT -> byte, SMALLINT -> short, BIGINT -> long.
   ===================================================================== */

public sealed class ItemCatalogo
{
    public int Id { get; set; }
    public string Nombre { get; set; } = "";
}

public sealed class FilaEjercicio
{
    public int EjercicioId { get; set; }
    public string Nombre { get; set; } = "";
    public string? Descripcion { get; set; }
    public string? ErroresComunes { get; set; }
    public string? VideoUrl { get; set; }
    public string? MiniaturaUrl { get; set; }
    public byte NivelMinimoId { get; set; }
    public string TipoMedida { get; set; } = "R";
}

public sealed class FilaMusculo
{
    public string Nombre { get; set; } = "";
    public bool EsPrincipal { get; set; }
}

public sealed class FilaUsuario
{
    public int UsuarioId { get; set; }
    public string Nombre { get; set; } = "";
    public string Email { get; set; } = "";
    public DateTime? FechaNacimiento { get; set; }
    public byte NivelId { get; set; }
    public byte? ObjetivoId { get; set; }
    public byte? DiasSemana { get; set; }
}

public sealed class FilaRutina
{
    public int RutinaId { get; set; }
    public string Nombre { get; set; } = "";
    public string Origen { get; set; } = "";
    public bool Activa { get; set; }
    public DateTime FechaAlta { get; set; }
}

/// <summary>Una fila de gym.vw_RutinaDetalle.</summary>
public sealed class FilaRutinaDetalle
{
    public int RutinaId { get; set; }
    public int? UsuarioId { get; set; }
    public string Rutina { get; set; } = "";
    public string Origen { get; set; } = "";
    public bool Activa { get; set; }
    public int RutinaDiaId { get; set; }
    public byte Dia { get; set; }
    public string NombreDia { get; set; } = "";
    public int? RutinaDiaEjercicioId { get; set; }
    public byte? Orden { get; set; }
    public int? EjercicioId { get; set; }
    public string? Ejercicio { get; set; }
    public string? VideoUrl { get; set; }
    public string? MiniaturaUrl { get; set; }
    public byte? Series { get; set; }
    public string? TipoMedida { get; set; }
    public byte? RepsMin { get; set; }
    public byte? RepsMax { get; set; }
    public short? DuracionSegMin { get; set; }
    public short? DuracionSegMax { get; set; }
    public decimal? PesoObjetivoKg { get; set; }
    public short? DescansoSeg { get; set; }
    public decimal? RpeObjetivo { get; set; }
}

/// <summary>Resumen que devuelve usp_AdaptarRutinaPorSesion al finalizar una sesión.</summary>
public sealed class FilaAdaptacion
{
    public string Ejercicio { get; set; } = "";
    public string Accion { get; set; } = "";
    public string Motivo { get; set; } = "";
    public int SeriesHechas { get; set; }
    public decimal? RpeMedio { get; set; }
    public decimal? PesoAntes { get; set; }
    public decimal? PesoNuevo { get; set; }
    public byte? RepsMinAntes { get; set; }
    public byte? RepsMaxAntes { get; set; }
    public int? RepsMinNuevo { get; set; }
    public int? RepsMaxNuevo { get; set; }
    public short? DurMinAntes { get; set; }
    public short? DurMaxAntes { get; set; }
    public int? DurMinNueva { get; set; }
    public int? DurMaxNueva { get; set; }
}

/// <summary>Una fila de gym.AjusteRutina.</summary>
public sealed class FilaAjuste
{
    public DateTime Fecha { get; set; }
    public string Accion { get; set; } = "";
    public string Motivo { get; set; } = "";
    public decimal? PesoAntes { get; set; }
    public decimal? PesoDespues { get; set; }
    public byte? RepsMinAntes { get; set; }
    public byte? RepsMaxAntes { get; set; }
    public byte? RepsMinDespues { get; set; }
    public byte? RepsMaxDespues { get; set; }
    public short? DurMinAntes { get; set; }
    public short? DurMaxAntes { get; set; }
    public short? DurMinDespues { get; set; }
    public short? DurMaxDespues { get; set; }
}

/* =====================================================================
   Respuestas (JSON)
   ===================================================================== */

public sealed record EjercicioDetalleDto(
    FilaEjercicio Ejercicio, IReadOnlyList<FilaMusculo> Musculos, IReadOnlyList<string> Materiales);

public sealed record RutinaDto(int RutinaId, string Nombre, string Origen, bool Activa, IReadOnlyList<DiaDto> Dias);

public sealed record DiaDto(int RutinaDiaId, byte Orden, string Nombre, IReadOnlyList<EjercicioRutinaDto> Ejercicios);

public sealed record EjercicioRutinaDto(
    int RutinaDiaEjercicioId, byte Orden, int EjercicioId, string Nombre,
    string? VideoUrl, string? MiniaturaUrl,
    byte Series, string TipoMedida,
    byte? RepsMin, byte? RepsMax, short? DuracionSegMin, short? DuracionSegMax,
    decimal? PesoObjetivoKg, short DescansoSeg, decimal? RpeObjetivo);

/* =====================================================================
   Peticiones (JSON). Los campos opcionales a null mantienen el valor
   actual o aplican el valor por defecto del procedimiento.
   ===================================================================== */

public sealed record RegistroUsuarioDto(
    string Nombre, string Email, DateTime? FechaNacimiento,
    byte NivelId, byte? ObjetivoId, byte? DiasSemana);

public sealed record SugeridaDto(byte? NivelId, byte? ObjetivoId, byte? DiasSemana);

public sealed record RutinaManualDto(string Nombre, byte NumDias = 3, bool Activar = true);

public sealed record DiaNuevoDto(string? Nombre, byte? Posicion);

public sealed record NombreDto(string Nombre);

public sealed record PosicionDto(byte Posicion);

public sealed record ConfigEjercicioDto(
    byte? Series, string? TipoMedida,
    byte? RepsMin, byte? RepsMax, short? DuracionSegMin, short? DuracionSegMax,
    short? DescansoSeg, decimal? RpeObjetivo);

public sealed record EjercicioNuevoDto(
    int EjercicioId, byte? Posicion,
    byte? Series, string? TipoMedida,
    byte? RepsMin, byte? RepsMax, short? DuracionSegMin, short? DuracionSegMax,
    short? DescansoSeg, decimal? RpeObjetivo);

public sealed record PesoDto(decimal? PesoKg);

public sealed record SesionNuevaDto(int? RutinaDiaId);

public sealed record SerieDto(int EjercicioId, byte? Reps, short? DuracionSeg, decimal? PesoKg, decimal? Rpe);

public sealed record FinalizarDto(string? Notas, bool Adaptar = true);

/* =====================================================================
   Mapeo de filas planas a estructura Rutina -> Días -> Ejercicios
   ===================================================================== */

public static class Mapeo
{
    public static List<RutinaDto> Agrupar(IEnumerable<FilaRutinaDetalle> filas) =>
        filas.GroupBy(f => f.RutinaId)
             .Select(r =>
             {
                 var cab = r.First();
                 var dias = r.GroupBy(f => f.RutinaDiaId)
                             .OrderBy(d => d.First().Dia)
                             .Select(d => new DiaDto(
                                 d.Key, d.First().Dia, d.First().NombreDia,
                                 d.Where(f => f.RutinaDiaEjercicioId is not null) // días vacíos (LEFT JOIN)
                                  .OrderBy(f => f.Orden)
                                  .Select(f => new EjercicioRutinaDto(
                                      f.RutinaDiaEjercicioId!.Value, f.Orden!.Value, f.EjercicioId!.Value, f.Ejercicio!,
                                      f.VideoUrl, f.MiniaturaUrl,
                                      f.Series!.Value, f.TipoMedida!,
                                      f.RepsMin, f.RepsMax, f.DuracionSegMin, f.DuracionSegMax,
                                      f.PesoObjetivoKg, f.DescansoSeg!.Value, f.RpeObjetivo))
                                  .ToList()))
                             .ToList();
                 return new RutinaDto(cab.RutinaId, cab.Rutina, cab.Origen, cab.Activa, dias);
             })
             .ToList();

    /// <summary>Evita que SQL Server trunque en silencio un valor como "RT" a CHAR(1).</summary>
    public static IResult? ValidarTipoMedida(string? tipo) =>
        tipo is null or "R" or "T"
            ? null
            : Results.Problem(title: "TipoMedida debe ser R (repeticiones) o T (tiempo).",
                              statusCode: StatusCodes.Status400BadRequest);
}
