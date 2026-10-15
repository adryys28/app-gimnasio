using System.Globalization;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace GymApi.Modelos;

/* =====================================================================
   Filas leídas de SQL Server (scripts 09 a 11)
   ===================================================================== */

public sealed class FilaTipoActividad
{
    public byte TipoActividadId { get; set; }
    public string Nombre { get; set; } = "";
    public bool Exterior { get; set; }
}

/// <summary>Primer conjunto de usp_ObtenerActividad.</summary>
public sealed class FilaActividad
{
    public long ActividadId { get; set; }
    public string Tipo { get; set; } = "";
    public string Origen { get; set; } = "";
    public string Estado { get; set; } = "";
    public DateTime FechaInicio { get; set; }
    public DateTime? FechaFin { get; set; }
    public decimal? DistanciaM { get; set; }
    public int? DuracionTotalSeg { get; set; }
    public string? DuracionTotalTxt { get; set; }
    public int? DuracionMovSeg { get; set; }
    public string? DuracionMovTxt { get; set; }
    public int? RitmoMedioSegKm { get; set; }
    public string? RitmoMedioTxt { get; set; }
    public decimal? VelocidadMediaKmh { get; set; }
    public decimal? DesnivelPosM { get; set; }
    public decimal? DesnivelNegM { get; set; }
    public short? FcMedia { get; set; }
    public short? FcMax { get; set; }
    public int? Kcal { get; set; }
    public string? FuenteKcal { get; set; }
    public decimal? CoberturaFcPct { get; set; }

    // Se devuelven convertidas a GeoJSON en ActividadDetalleDto
    [JsonIgnore] public string? RutaWkt { get; set; }
    [JsonIgnore] public string? RutaPublicaWkt { get; set; }
}

/// <summary>Segundo conjunto de usp_ObtenerActividad: un parcial por km.</summary>
public sealed class FilaParcial
{
    public short Km { get; set; }
    public decimal DistanciaM { get; set; }
    public decimal DuracionSeg { get; set; }
    public string? DuracionTxt { get; set; }
    public int? RitmoSegKm { get; set; }
    public string? RitmoTxt { get; set; }
    public decimal? DesnivelPosM { get; set; }
    public decimal? DesnivelNegM { get; set; }
    public short? FcMedia { get; set; }
    public decimal? Kcal { get; set; }
}

public sealed class FilaActividadLista
{
    public long ActividadId { get; set; }
    public string Tipo { get; set; } = "";
    public string Origen { get; set; } = "";
    public DateTime FechaInicio { get; set; }
    public decimal? DistanciaM { get; set; }
    public int? DuracionMovSeg { get; set; }
    public string? DuracionMovTxt { get; set; }
    public int? RitmoMedioSegKm { get; set; }
    public string? RitmoMedioTxt { get; set; }
    public int? Kcal { get; set; }
    public string? FuenteKcal { get; set; }
}

public sealed class FilaFisiologia
{
    public decimal? PesoCorporalKg { get; set; }
    public DateTime? FechaNacimiento { get; set; }
    public string? SexoCalculo { get; set; }
    public decimal? Vo2MaxMlKgMin { get; set; }
    public short? FcMaxLpm { get; set; }
}

public sealed class FilaConsentimiento
{
    public string Tipo { get; set; } = "";
    public bool Otorgado { get; set; }
    public string VersionTexto { get; set; } = "";
    public DateTime Fecha { get; set; }
}

public sealed class FilaZonaPrivada
{
    public int ZonaPrivadaId { get; set; }
    public string Nombre { get; set; } = "";
    public double Lat { get; set; }
    public double Lon { get; set; }
    public short RadioM { get; set; }
}

/// <summary>Primer conjunto de usp_EstadoPlan: fuentes de acceso vigentes.</summary>
public sealed class FilaFuentePlan
{
    public string Fuente { get; set; } = "";
    public string Plan { get; set; } = "";
    public string? Plataforma { get; set; }
    public string? Estado { get; set; }
    public DateTime? FechaFin { get; set; }
    public bool? RenovacionAutomatica { get; set; }
    public string? Organizacion { get; set; }
}

/// <summary>Segundo conjunto de usp_EstadoPlan: funciones incluidas (Limite null = sin límite).</summary>
public sealed class FilaFuncionPlan
{
    public string Funcion { get; set; } = "";
    public string Nombre { get; set; } = "";
    public int? Limite { get; set; }
}

public sealed class FilaMiembro
{
    public int UsuarioId { get; set; }
    public string Nombre { get; set; } = "";
    public string Email { get; set; } = "";
    public string Rol { get; set; } = "";
    public DateTime FechaAlta { get; set; }
}

/* =====================================================================
   Peticiones
   ===================================================================== */

public sealed record IniciarActividadDto(byte TipoActividadId, string? Origen);

/// <summary>
/// Punto GPS. Se reenvía tal cual a usp_RegistrarPuntos con nombres cortos
/// (s, t, lat, lon, alt, acc, fc). T incluye zona horaria (ISO 8601).
/// </summary>
public sealed record PuntoDto(int S, DateTimeOffset T, double Lat, double Lon, decimal? Alt, decimal? Acc, short? Fc);

public sealed record FinalizarActividadDto(int? KcalDispositivo);

public sealed record FisiologiaDto(
    decimal? PesoCorporalKg, DateTime? FechaNacimiento, string? SexoCalculo,
    decimal? Vo2MaxMlKgMin, short? FcMaxLpm);

public sealed record ConsentimientoDto(string Tipo, bool Otorgado, string VersionTexto);

public sealed record ZonaNuevaDto(string Nombre, double Lat, double Lon, short RadioM = 200);

public sealed record MiembroNuevoDto(string Email, string? Rol);

/* =====================================================================
   Respuestas
   ===================================================================== */

/// <summary>Ruta y RutaPublica en formato GeoJSON (MultiLineString, coordenadas [lon, lat]).</summary>
public sealed record ActividadDetalleDto(
    FilaActividad Resumen, IReadOnlyList<FilaParcial> Parciales, object? Ruta, object? RutaPublica);

public static partial class Geo
{
    // Contenido de cada paréntesis interior: "lon lat, lon lat, ..."
    [GeneratedRegex(@"\(([^()]+)\)")]
    private static partial Regex Tramo();

    /// <summary>
    /// Convierte el WKT de SQL Server (LINESTRING, MULTILINESTRING o
    /// GEOMETRYCOLLECTION) en un GeoJSON MultiLineString. Cada tramo se
    /// mantiene separado para no unir con una recta los cortes de las
    /// zonas privadas. Devuelve null si no hay ruta.
    /// </summary>
    public static object? AGeoJson(string? wkt)
    {
        if (string.IsNullOrWhiteSpace(wkt) || wkt.Contains("EMPTY", StringComparison.OrdinalIgnoreCase))
            return null;

        var tramos = Tramo().Matches(wkt)
            .Select(m => m.Groups[1].Value
                .Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
                .Select(par => par.Split(' ', StringSplitOptions.RemoveEmptyEntries))
                .Select(v => new[]
                {
                    double.Parse(v[0], CultureInfo.InvariantCulture),
                    double.Parse(v[1], CultureInfo.InvariantCulture)
                })
                .ToArray())
            .Where(t => t.Length >= 2)  // descarta puntos sueltos
            .ToArray();

        return tramos.Length == 0 ? null : new { type = "MultiLineString", coordinates = tramos };
    }
}
