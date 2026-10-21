using System.Text.Json.Nodes;
using GymApi.Modelos;

namespace GymApi.Infraestructura;

/// <summary>
/// Genera una rutina a partir del catálogo con reglas fijas, sin IA.
/// Es determinista: las mismas respuestas producen siempre la misma rutina.
///
/// Reglas (decisiones de diseño basadas en pautas habituales: ACSM 2009 para
/// rangos por objetivo y frecuencia de 2 veces por semana por grupo muscular):
///   - Estructura por días: 2-3 cuerpo completo · 4 torso/pierna ·
///     5 torso/pierna + empuje/tirón/pierna · 6 empuje/tirón/pierna × 2.
///   - Ejercicios por día: principiante 5, intermedio 6, avanzado 7.
///   - Compuestos primero y aislamiento y core al final, eligiendo cada
///     ejercicio de una lista de prioridad por grupo muscular.
///   - Series, repeticiones, RPE y descanso según objetivo y nivel.
/// El plan resultante pasa la misma validación SQL que cualquier otro
/// (usp_CrearRutinaDesdeJson).
/// </summary>
public static class GeneradorRutinaReglas
{
    private enum Tipo { Compuesto, Aislamiento, Core }

    private sealed record Hueco(Tipo Tipo, string[] Grupos);

    private static readonly Hueco[] CuerpoCompleto =
    [
        new(Tipo.Compuesto, ["Cuádriceps"]), new(Tipo.Compuesto, ["Pecho"]), new(Tipo.Compuesto, ["Espalda"]),
        new(Tipo.Compuesto, ["Isquiotibiales", "Glúteos"]), new(Tipo.Compuesto, ["Hombros"]),
        new(Tipo.Core, ["Core", "Oblicuos"]), new(Tipo.Aislamiento, ["Bíceps", "Tríceps"]),
    ];
    private static readonly Hueco[] Torso =
    [
        new(Tipo.Compuesto, ["Pecho"]), new(Tipo.Compuesto, ["Espalda"]), new(Tipo.Compuesto, ["Hombros"]),
        new(Tipo.Compuesto, ["Espalda"]), new(Tipo.Aislamiento, ["Pecho"]), new(Tipo.Aislamiento, ["Bíceps"]),
        new(Tipo.Aislamiento, ["Tríceps"]),
    ];
    private static readonly Hueco[] Pierna =
    [
        new(Tipo.Compuesto, ["Cuádriceps"]), new(Tipo.Compuesto, ["Isquiotibiales"]), new(Tipo.Compuesto, ["Glúteos"]),
        new(Tipo.Compuesto, ["Cuádriceps", "Aductores"]), new(Tipo.Core, ["Core", "Oblicuos"]),
        new(Tipo.Aislamiento, ["Gemelos"]), new(Tipo.Aislamiento, ["Isquiotibiales"]),
    ];
    private static readonly Hueco[] Empuje =
    [
        new(Tipo.Compuesto, ["Pecho"]), new(Tipo.Compuesto, ["Hombros"]), new(Tipo.Compuesto, ["Pecho"]),
        new(Tipo.Aislamiento, ["Hombros"]), new(Tipo.Aislamiento, ["Tríceps"]), new(Tipo.Core, ["Core", "Oblicuos"]),
        new(Tipo.Aislamiento, ["Tríceps"]),
    ];
    private static readonly Hueco[] Tiron =
    [
        new(Tipo.Compuesto, ["Espalda"]), new(Tipo.Compuesto, ["Espalda"]), new(Tipo.Aislamiento, ["HombrosPosterior"]),
        new(Tipo.Aislamiento, ["Bíceps"]), new(Tipo.Core, ["Core", "Lumbares"]), new(Tipo.Aislamiento, ["Bíceps", "Antebrazos"]),
        new(Tipo.Aislamiento, ["Trapecio"]),
    ];

    /// <summary>
    /// Orden de preferencia por grupo muscular y tipo de hueco (nombres del catálogo).
    /// Se descartan los que superan el nivel de la persona; la variante A/B/C rota
    /// sobre esta lista. Revisable por una persona profesional del entrenamiento.
    /// </summary>
    private static readonly Dictionary<(Tipo, string), string[]> Prioridad = new()
    {
        [(Tipo.Compuesto, "Cuádriceps")] = ["Sentadilla con barra", "Sentadilla goblet", "Prensa de piernas", "Sentadilla frontal con barra", "Sentadilla hack", "Sentadilla búlgara", "Zancadas", "Zancadas hacia atrás", "Zancadas caminando", "Sentadilla en multipower"],
        [(Tipo.Compuesto, "Pecho")] = ["Press de banca con barra", "Press de banca con mancuernas", "Press inclinado con mancuernas", "Press inclinado con barra", "Press de pecho en máquina", "Flexiones", "Fondos en paralelas", "Press declinado con barra"],
        [(Tipo.Compuesto, "Espalda")] = ["Remo con barra", "Jalón al pecho", "Dominadas", "Remo con mancuerna", "Remo sentado en polea", "Dominadas supinas", "Remo en máquina", "Remo en punta con barra", "Jalón con agarre estrecho", "Remo Pendlay"],
        [(Tipo.Compuesto, "Isquiotibiales")] = ["Peso muerto rumano con barra", "Peso muerto rumano con mancuernas", "Peso muerto con barra", "Buenos días con barra", "Peso muerto a una pierna con mancuerna"],
        [(Tipo.Compuesto, "Glúteos")] = ["Hip thrust", "Peso muerto sumo con barra", "Hip thrust en máquina", "Puente de glúteos", "Subidas al banco", "Swing con kettlebell"],
        [(Tipo.Compuesto, "Hombros")] = ["Press militar con barra", "Press militar con mancuernas", "Press de hombro en máquina", "Press Arnold"],
        [(Tipo.Compuesto, "Aductores")] = ["Sentadilla sumo con mancuerna", "Zancada lateral"],
        [(Tipo.Aislamiento, "Pecho")] = ["Aperturas con mancuernas", "Cruce de poleas", "Aperturas en máquina", "Aperturas inclinadas con mancuernas"],
        [(Tipo.Aislamiento, "Bíceps")] = ["Curl de bíceps con barra", "Curl de bíceps con mancuernas", "Curl martillo", "Curl de bíceps en polea baja", "Curl inclinado con mancuernas", "Curl predicador con barra Z", "Curl con barra Z"],
        [(Tipo.Aislamiento, "Tríceps")] = ["Extensión de tríceps en polea alta", "Extensión de tríceps con cuerda en polea", "Press francés con barra", "Extensión de tríceps por encima de la cabeza", "Fondos en banco"],
        [(Tipo.Aislamiento, "Hombros")] = ["Elevaciones laterales con mancuernas", "Elevaciones laterales en polea", "Elevaciones frontales con mancuernas"],
        [(Tipo.Aislamiento, "HombrosPosterior")] = ["Face pull en polea", "Pájaros con mancuernas", "Pájaros en máquina"],
        [(Tipo.Aislamiento, "Trapecio")] = ["Encogimientos con mancuernas", "Encogimientos con barra"],
        [(Tipo.Aislamiento, "Gemelos")] = ["Elevación de talones de pie", "Elevación de talones sentado en máquina", "Elevación de talones en prensa", "Elevación de talones de pie en máquina"],
        [(Tipo.Aislamiento, "Isquiotibiales")] = ["Curl femoral tumbado en máquina", "Curl femoral sentado en máquina", "Curl femoral con fitball", "Curl nórdico"],
        [(Tipo.Aislamiento, "Antebrazos")] = ["Curl invertido con barra Z", "Curl de muñeca con barra"],
        [(Tipo.Core, "Core")] = ["Plancha frontal", "Dead bug", "Crunch abdominal", "Pallof press", "Elevación de piernas colgado", "Rueda abdominal", "Crunch en polea alta", "Bird dog"],
        [(Tipo.Core, "Oblicuos")] = ["Plancha lateral", "Leñador en polea", "Rotación rusa"],
        [(Tipo.Core, "Lumbares")] = ["Hiperextensiones", "Superman"],
    };

    private static (string Nombre, Hueco[] Huecos)[] Estructura(int dias) => dias switch
    {
        <= 2 => [("Cuerpo completo A", CuerpoCompleto), ("Cuerpo completo B", CuerpoCompleto)],
        3 => [("Cuerpo completo A", CuerpoCompleto), ("Cuerpo completo B", CuerpoCompleto), ("Cuerpo completo C", CuerpoCompleto)],
        4 => [("Torso A", Torso), ("Pierna A", Pierna), ("Torso B", Torso), ("Pierna B", Pierna)],
        5 => [("Torso", Torso), ("Pierna A", Pierna), ("Empuje", Empuje), ("Tirón", Tiron), ("Pierna B", Pierna)],
        _ => [("Empuje A", Empuje), ("Tirón A", Tiron), ("Pierna A", Pierna), ("Empuje B", Empuje), ("Tirón B", Tiron), ("Pierna B", Pierna)],
    };

    private static string NombreEstructura(int dias) => dias switch
    {
        <= 3 => "Cuerpo completo",
        4 => "Torso/Pierna",
        5 => "Torso/Pierna + Empuje/Tirón",
        _ => "Empuje/Tirón/Pierna",
    };

    private static readonly string[] Objetivos = ["", "Ganar fuerza", "Ganar músculo", "Perder grasa"];

    /// <summary>Series, repeticiones, RPE y descanso por objetivo, nivel y tipo de ejercicio.</summary>
    private static (int Series, int RepsMin, int RepsMax, decimal Rpe, int Descanso) Parametros(int objetivo, int nivel, Tipo tipo)
    {
        var principiante = nivel == 1;
        var avanzado = nivel == 3;
        return (objetivo, tipo) switch
        {
            (1, Tipo.Compuesto) => (principiante ? 3 : 4, principiante ? 6 : 4, principiante ? 8 : 6, principiante ? 7m : 8m, 150),
            (1, _) => (principiante ? 2 : 3, 8, 12, 7.5m, 90),
            (2, Tipo.Compuesto) => (avanzado ? 4 : 3, 6, 10, principiante ? 7m : 8m, 120),
            (2, _) => (principiante ? 2 : 3, 10, 15, principiante ? 7m : 8m, 75),
            (_, Tipo.Compuesto) => (3, 8, 12, principiante ? 7m : 7.5m, 75),
            _ => (principiante ? 2 : 3, 12, 15, 7.5m, 45),
        };
    }

    public static JsonObject Generar(int nivel, int objetivo, int dias, IReadOnlyList<FilaCatalogoReglas> catalogo)
    {
        var porDia = nivel switch { 1 => 5, 2 => 6, _ => 7 };
        var disponibles = catalogo.Where(e => e.NivelMinimoId <= nivel).ToList();
        var vecesTipo = new Dictionary<Hueco[], int>();
        var diasJson = new JsonArray();

        foreach (var (nombreDia, huecos) in Estructura(dias))
        {
            // Variante A/B/C del mismo tipo de día: rota la elección de ejercicios
            var variante = vecesTipo.GetValueOrDefault(huecos);
            vecesTipo[huecos] = variante + 1;

            var usados = new HashSet<int>();
            var ejercicios = new JsonArray();

            foreach (var hueco in huecos.Take(porDia))
            {
                var candidatos = Candidatos(disponibles, hueco, nivel);
                if (candidatos.Count == 0) continue;

                var elegido = Enumerable.Range(0, candidatos.Count)
                    .Select(i => candidatos[(variante + i) % candidatos.Count])
                    .FirstOrDefault(c => !usados.Contains(c.EjercicioId));
                if (elegido is null) continue;
                usados.Add(elegido.EjercicioId);

                var e = new JsonObject { ["ejercicioId"] = elegido.EjercicioId };
                if (elegido.TipoMedida == "T")
                {
                    var (min, max) = nivel == 1 ? (20, 30) : nivel == 2 ? (30, 45) : (40, 60);
                    e["series"] = 3; e["tipoMedida"] = "T";
                    e["duracionSegMin"] = min; e["duracionSegMax"] = max; e["descansoSeg"] = 45;
                }
                else
                {
                    var p = Parametros(objetivo, nivel, hueco.Tipo == Tipo.Core ? Tipo.Aislamiento : hueco.Tipo);
                    e["series"] = p.Series; e["tipoMedida"] = "R";
                    e["repsMin"] = p.RepsMin; e["repsMax"] = p.RepsMax;
                    e["descansoSeg"] = p.Descanso; e["rpeObjetivo"] = p.Rpe;
                }
                ejercicios.Add(e);
            }

            diasJson.Add(new JsonObject { ["nombre"] = nombreDia, ["ejercicios"] = ejercicios });
        }

        return new JsonObject
        {
            ["nombre"] = $"{NombreEstructura(dias)} · {Objetivos[objetivo]}",
            ["explicacion"] = Explicacion(nivel, objetivo, dias),
            ["dias"] = diasJson,
        };
    }

    /// <summary>
    /// Candidatos de un hueco: primero la lista de prioridad de cada grupo; si no hay
    /// ninguno disponible, cualquier ejercicio del grupo (compuestos con más músculos primero).
    /// </summary>
    private static List<FilaCatalogoReglas> Candidatos(List<FilaCatalogoReglas> catalogo, Hueco hueco, int nivel)
    {
        bool Valido(FilaCatalogoReglas e) => hueco.Tipo == Tipo.Core || e.TipoMedida == "R";

        var porNombre = catalogo.GroupBy(e => e.Nombre).ToDictionary(g => g.Key, g => g.First());
        var preferidos = hueco.Grupos
            .SelectMany(g => Prioridad.GetValueOrDefault((hueco.Tipo, g)) ?? Array.Empty<string>())
            .Select(n => porNombre.GetValueOrDefault(n))
            .OfType<FilaCatalogoReglas>()
            .Where(Valido)
            .Distinct()
            .ToList();
        if (preferidos.Count > 0) return preferidos;

        var delGrupo = catalogo.Where(e => hueco.Grupos.Any(g => e.GruposPrincipales.Contains(g)) && Valido(e));
        return hueco.Tipo == Tipo.Compuesto
            ? [.. delGrupo.OrderByDescending(e => e.NumMusculos).ThenBy(e => Math.Abs(e.NivelMinimoId - nivel)).ThenBy(e => e.EjercicioId)]
            : [.. delGrupo.OrderBy(e => e.NumMusculos).ThenBy(e => Math.Abs(e.NivelMinimoId - nivel)).ThenBy(e => e.EjercicioId)];
    }

    private static string Explicacion(int nivel, int objetivo, int dias)
    {
        var estructura = dias switch
        {
            <= 3 => $"{dias} días de cuerpo completo para trabajar cada grupo muscular varias veces por semana",
            4 => "4 días alternando torso y pierna, de modo que cada grupo muscular se entrena dos veces por semana",
            5 => "5 días que combinan torso/pierna con empuje/tirón para repartir más volumen",
            _ => "6 días de empuje, tirón y pierna, repitiendo cada bloque dos veces por semana",
        };
        var enfoque = objetivo switch
        {
            1 => "Los ejercicios básicos van primero, con pocas repeticiones y descansos largos para priorizar la fuerza.",
            2 => "Se combinan básicos de 6-10 repeticiones con ejercicios de aislamiento de 10-15 para estimular el crecimiento muscular.",
            _ => "Se usan repeticiones moderadas y descansos cortos; recuerda que el déficit calórico y el cardio son determinantes para perder grasa.",
        };
        var nivelTxt = nivel == 1 ? " Al ser principiante, el volumen y la intensidad son moderados para que aprendas la técnica." : "";
        return $"Rutina de {estructura}. {enfoque}{nivelTxt}";
    }
}
