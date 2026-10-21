using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using GymApi.Modelos;

namespace GymApi.Infraestructura;

/// <summary>
/// Genera un plan de rutina con la API de mensajes de Anthropic (Claude).
/// La respuesta se fuerza a un JSON estructurado mediante una herramienta
/// (tool use) y después se valida en SQL con usp_CrearRutinaDesdeJson.
///
/// Protección de datos: solo se envían nivel, objetivo, días y el catálogo
/// de ejercicios. Nunca nombre, correo, peso ni datos de salud.
/// </summary>
public sealed class GeneradorRutinaIa(HttpClient http, IConfiguration config, Db db, ILogger<GeneradorRutinaIa> log)
{
    private const string UrlMensajes = "https://api.anthropic.com/v1/messages";

    /// <summary>Sin clave configurada, la API usa las plantillas como alternativa.</summary>
    public bool Disponible => !string.IsNullOrWhiteSpace(config["Ia:ClaveApi"]);

    private static readonly string[] Niveles = ["", "principiante", "intermedio", "avanzado"];
    private static readonly Dictionary<int, string> Objetivos = new()
    {
        [1] = "ganar fuerza", [2] = "ganar músculo (hipertrofia)", [3] = "perder grasa",
    };

    public async Task<string> GenerarPlanJsonAsync(int nivelId, int objetivoId, int dias, CancellationToken ct)
    {
        var catalogo = await db.QueryAsync<FilaCatalogoIa>("""
            SELECT e.EjercicioId, e.Nombre, e.TipoMedida,
                   (SELECT STRING_AGG(g.Nombre, ', ') FROM gym.EjercicioMusculo em
                    JOIN gym.GrupoMuscular g ON g.GrupoMuscularId = em.GrupoMuscularId
                    WHERE em.EjercicioId = e.EjercicioId AND em.EsPrincipal = 1) AS Musculos,
                   (SELECT STRING_AGG(m.Nombre, ', ') FROM gym.EjercicioMaterial x
                    JOIN gym.Material m ON m.MaterialId = x.MaterialId
                    WHERE x.EjercicioId = e.EjercicioId) AS Materiales
            FROM gym.Ejercicio e
            WHERE e.Activo = 1 AND e.NivelMinimoId <= @nivelId
            ORDER BY e.EjercicioId
            """, new { nivelId }, ct);

        var lineas = string.Join('\n', catalogo.Select(e =>
            $"{e.EjercicioId}|{e.Nombre}|{e.Musculos}|{e.Materiales}|{(e.TipoMedida == "T" ? "tiempo" : "repeticiones")}"));

        var mensaje = $"""
            Perfil: nivel {Niveles[nivelId]}, objetivo {Objetivos[objetivoId]}, {dias} días de entrenamiento por semana.

            Catálogo disponible (id|nombre|músculos principales|material|medida):
            {lineas}
            """;

        var cuerpo = new JsonObject
        {
            ["model"] = config["Ia:Modelo"] ?? "claude-sonnet-5-5",
            ["max_tokens"] = 4096,
            ["system"] = InstruccionesSistema(dias),
            ["tools"] = new JsonArray(new JsonObject
            {
                ["name"] = "crear_rutina",
                ["description"] = "Guarda la rutina semanal propuesta para la persona.",
                ["input_schema"] = Esquema(dias),
            }),
            ["tool_choice"] = new JsonObject { ["type"] = "tool", ["name"] = "crear_rutina" },
            ["messages"] = new JsonArray(new JsonObject { ["role"] = "user", ["content"] = mensaje }),
        };

        using var peticion = new HttpRequestMessage(HttpMethod.Post, UrlMensajes)
        {
            Content = new StringContent(cuerpo.ToJsonString(), Encoding.UTF8, "application/json"),
        };
        peticion.Headers.Add("x-api-key", config["Ia:ClaveApi"]);
        peticion.Headers.Add("anthropic-version", "2023-06-01");
        peticion.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        using var respuesta = await http.SendAsync(peticion, ct);
        var texto = await respuesta.Content.ReadAsStringAsync(ct);
        if (!respuesta.IsSuccessStatusCode)
        {
            log.LogWarning("La API de IA respondió {Estado}: {Cuerpo}", (int)respuesta.StatusCode, texto);
            throw new HttpRequestException($"La API de IA respondió {(int)respuesta.StatusCode}.");
        }

        var raiz = JsonNode.Parse(texto)?["content"]?.AsArray()
                   ?? throw new JsonException("Respuesta de IA sin contenido.");
        var herramienta = raiz.FirstOrDefault(n => n?["type"]?.GetValue<string>() == "tool_use")
                          ?? throw new JsonException("La IA no devolvió el plan estructurado.");
        return herramienta["input"]?.ToJsonString() ?? throw new JsonException("Plan vacío.");
    }

    private static string InstruccionesSistema(int dias) => $"""
        Eres una persona entrenadora titulada que diseña rutinas de gimnasio seguras y basadas en la evidencia.
        Devuelve la rutina SIEMPRE con la herramienta crear_rutina.

        Reglas obligatorias:
        - Usa solo ejercicioId del catálogo que te doy. No inventes ejercicios.
        - La rutina tiene exactamente {dias} días, de 4 a 7 ejercicios cada uno.
        - Estructura: con 2-3 días, cuerpo completo; con 4 días, torso/pierna; con 5 o más, combina torso/pierna con empuje/tirón/pierna.
        - Equilibra empuje y tirón, incluye piernas en la semana y un ejercicio de core en la mayoría de los días.
        - Empieza cada día por ejercicios compuestos y deja los de aislamiento y core para el final.
        - Por objetivo:
          · Ganar fuerza: compuestos de 3 a 6 repeticiones, RPE 7-9, descansos de 120-180 s.
          · Ganar músculo: 6-12 repeticiones (hasta 15 en aislamiento), RPE 7-9, descansos de 60-120 s,
            cada grupo muscular al menos 2 veces por semana y unas 10-20 series semanales por grupo.
          · Perder grasa: 8-15 repeticiones, RPE 7-8, descansos de 45-90 s, priorizando ejercicios compuestos.
        - Principiantes: 2-3 series por ejercicio y RPE 6-8, con ejercicios sencillos de aprender.
        - Ejercicios medidos por tiempo (tipoMedida "T"): usa duracionSegMin/duracionSegMax y no repeticiones.
        - "explicacion": 2-3 frases en español de España, con lenguaje inclusivo, explicando la estructura elegida.
          Si el objetivo es perder grasa, recuerda que el déficit calórico y la actividad cardiovascular son determinantes.
          No prometas resultados concretos.
        """;

    private static JsonObject Esquema(int dias) => new()
    {
        ["type"] = "object",
        ["required"] = new JsonArray("nombre", "explicacion", "dias"),
        ["properties"] = new JsonObject
        {
            ["nombre"] = new JsonObject { ["type"] = "string", ["description"] = "Nombre corto de la rutina" },
            ["explicacion"] = new JsonObject { ["type"] = "string" },
            ["dias"] = new JsonObject
            {
                ["type"] = "array",
                ["minItems"] = dias,
                ["maxItems"] = dias,
                ["items"] = new JsonObject
                {
                    ["type"] = "object",
                    ["required"] = new JsonArray("nombre", "ejercicios"),
                    ["properties"] = new JsonObject
                    {
                        ["nombre"] = new JsonObject { ["type"] = "string" },
                        ["ejercicios"] = new JsonObject
                        {
                            ["type"] = "array",
                            ["items"] = new JsonObject
                            {
                                ["type"] = "object",
                                ["required"] = new JsonArray("ejercicioId", "series", "tipoMedida", "descansoSeg"),
                                ["properties"] = new JsonObject
                                {
                                    ["ejercicioId"] = new JsonObject { ["type"] = "integer" },
                                    ["series"] = new JsonObject { ["type"] = "integer", ["minimum"] = 1, ["maximum"] = 6 },
                                    ["tipoMedida"] = new JsonObject { ["type"] = "string", ["enum"] = new JsonArray("R", "T") },
                                    ["repsMin"] = new JsonObject { ["type"] = "integer" },
                                    ["repsMax"] = new JsonObject { ["type"] = "integer" },
                                    ["duracionSegMin"] = new JsonObject { ["type"] = "integer" },
                                    ["duracionSegMax"] = new JsonObject { ["type"] = "integer" },
                                    ["descansoSeg"] = new JsonObject { ["type"] = "integer" },
                                    ["rpeObjetivo"] = new JsonObject { ["type"] = "number" },
                                },
                            },
                        },
                    },
                },
            },
        },
    };
}
