USE App_Gym;
GO

/* =========================================================
   15 - Datos para recomendaciones durante la sesión
   Ejecutar después de 01 a 14. Se puede volver a ejecutar.

   La vista de rutina añade el nivel y el objetivo de la rutina y el
   número de músculos de cada ejercicio. La app los usa para recomendar
   series de calentamiento y el tipo de serie; la persona decide.
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
       (SELECT COUNT(*) FROM gym.EjercicioMusculo em WHERE em.EjercicioId = e.EjercicioId) AS NumMusculos
FROM gym.Rutina r
JOIN gym.RutinaDia d                 ON d.RutinaId = r.RutinaId
LEFT JOIN gym.RutinaDiaEjercicio rde ON rde.RutinaDiaId = d.RutinaDiaId
LEFT JOIN gym.Ejercicio e            ON e.EjercicioId = rde.EjercicioId;
GO

-- Comprobación
SELECT TOP (5) RutinaId, NivelId, ObjetivoId, Ejercicio, NumMusculos
FROM gym.vw_RutinaDetalle
WHERE Ejercicio IS NOT NULL
ORDER BY RutinaId DESC, Dia, Orden;
GO
