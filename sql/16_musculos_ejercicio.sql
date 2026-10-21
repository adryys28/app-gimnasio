USE App_Gym;
GO

/* =========================================================
   16 - Músculos de cada ejercicio en la vista de rutina
   Ejecutar después de 01 a 15. Se puede volver a ejecutar.

   Añade los grupos musculares principales y secundarios de cada
   ejercicio, que la app muestra junto al ejercicio (silueta y texto).
   ========================================================= */

CREATE OR ALTER VIEW gym.vw_RutinaDetalle
AS
SELECT r.RutinaId, r.UsuarioId, r.Nombre AS Rutina, r.Origen, r.Activa, r.Descripcion,
       r.NivelId, r.ObjetivoId,
       d.RutinaDiaId, d.Orden AS Dia, d.Nombre AS NombreDia,
       rde.RutinaDiaEjercicioId, rde.Orden,
       e.EjercicioId, e.Nombre AS Ejercicio, e.VideoUrl, e.MiniaturaUrl,
       rde.Series, rde.TipoMedida,
       rde.RepsMin, rde.RepsMax, rde.DuracionSegMin, rde.DuracionSegMax,
       rde.PesoObjetivoKg, rde.DescansoSeg, rde.RpeObjetivo,
       -- Músculos implicados (principales + secundarios): 2 o más = ejercicio compuesto
       (SELECT COUNT(*) FROM gym.EjercicioMusculo em WHERE em.EjercicioId = e.EjercicioId) AS NumMusculos,
       -- Grupos musculares separados por '|' (para mostrarlos junto al ejercicio)
       (SELECT STRING_AGG(g.Nombre, '|') FROM gym.EjercicioMusculo em
        JOIN gym.GrupoMuscular g ON g.GrupoMuscularId = em.GrupoMuscularId
        WHERE em.EjercicioId = e.EjercicioId AND em.EsPrincipal = 1) AS Principales,
       (SELECT STRING_AGG(g.Nombre, '|') FROM gym.EjercicioMusculo em
        JOIN gym.GrupoMuscular g ON g.GrupoMuscularId = em.GrupoMuscularId
        WHERE em.EjercicioId = e.EjercicioId AND em.EsPrincipal = 0) AS Secundarios
FROM gym.Rutina r
JOIN gym.RutinaDia d                 ON d.RutinaId = r.RutinaId
LEFT JOIN gym.RutinaDiaEjercicio rde ON rde.RutinaDiaId = d.RutinaDiaId
LEFT JOIN gym.Ejercicio e            ON e.EjercicioId = rde.EjercicioId;
GO

SELECT TOP (5) Ejercicio, Principales, Secundarios
FROM gym.vw_RutinaDetalle
WHERE Ejercicio IS NOT NULL
ORDER BY RutinaId DESC, Dia, Orden;
GO
