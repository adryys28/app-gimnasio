USE App_Gym;
GO

/* =========================================================
   Datos de prueba: ejercicios, plantilla y usuario de prueba
   ========================================================= */

INSERT INTO gym.Ejercicio (Nombre, Descripcion, NivelMinimoId) VALUES
(N'Sentadilla goblet',                 N'Sentadilla sujetando una mancuerna o kettlebell a la altura del pecho.', 1),
(N'Flexiones',                         N'Empuje horizontal con peso corporal.', 1),
(N'Remo con mancuerna',                N'Remo unilateral apoyado en banco.', 1),
(N'Press militar con mancuernas',      N'Empuje vertical sentado o de pie.', 1),
(N'Peso muerto rumano con mancuernas', N'Bisagra de cadera con rodillas semiflexionadas.', 1),
(N'Plancha frontal',                   N'Isométrico de core apoyado en antebrazos.', 1),
(N'Jalón al pecho',                    N'Tracción vertical en polea alta.', 1),
(N'Zancadas',                          N'Paso adelante alterno con descenso controlado.', 1),
(N'Hip thrust',                        N'Extensión de cadera con espalda apoyada en banco.', 1);

INSERT INTO gym.EjercicioMusculo (EjercicioId, GrupoMuscularId, EsPrincipal)
SELECT e.EjercicioId, g.GrupoMuscularId, v.Principal
FROM (VALUES
    (N'Sentadilla goblet', N'Cuádriceps', 1), (N'Sentadilla goblet', N'Glúteos', 0),
    (N'Flexiones', N'Pecho', 1), (N'Flexiones', N'Tríceps', 0),
    (N'Remo con mancuerna', N'Espalda', 1), (N'Remo con mancuerna', N'Bíceps', 0),
    (N'Press militar con mancuernas', N'Hombros', 1), (N'Press militar con mancuernas', N'Tríceps', 0),
    (N'Peso muerto rumano con mancuernas', N'Isquiotibiales', 1), (N'Peso muerto rumano con mancuernas', N'Glúteos', 0),
    (N'Plancha frontal', N'Core', 1),
    (N'Jalón al pecho', N'Espalda', 1), (N'Jalón al pecho', N'Bíceps', 0),
    (N'Zancadas', N'Cuádriceps', 1), (N'Zancadas', N'Glúteos', 0),
    (N'Hip thrust', N'Glúteos', 1), (N'Hip thrust', N'Isquiotibiales', 0)
) v(Ejercicio, Grupo, Principal)
JOIN gym.Ejercicio e     ON e.Nombre = v.Ejercicio
JOIN gym.GrupoMuscular g ON g.Nombre = v.Grupo;

INSERT INTO gym.EjercicioMaterial (EjercicioId, MaterialId)
SELECT e.EjercicioId, m.MaterialId
FROM (VALUES
    (N'Sentadilla goblet', N'Mancuernas'),
    (N'Flexiones', N'Peso corporal'),
    (N'Remo con mancuerna', N'Mancuernas'), (N'Remo con mancuerna', N'Banco'),
    (N'Press militar con mancuernas', N'Mancuernas'),
    (N'Peso muerto rumano con mancuernas', N'Mancuernas'),
    (N'Plancha frontal', N'Peso corporal'),
    (N'Jalón al pecho', N'Polea'),
    (N'Zancadas', N'Peso corporal'),
    (N'Hip thrust', N'Banco'), (N'Hip thrust', N'Barra')
) v(Ejercicio, Material)
JOIN gym.Ejercicio e ON e.Nombre = v.Ejercicio
JOIN gym.Material m  ON m.Nombre = v.Material;

/* --- Plantilla: Full body 3 días, principiante, hipertrofia --- */
INSERT INTO gym.Rutina (Nombre, NivelId, ObjetivoId, EsPlantilla, Origen)
VALUES (N'Full body 3 días - Principiante', 1, 2, 1, 'S');

DECLARE @Plantilla INT = SCOPE_IDENTITY();

INSERT INTO gym.RutinaDia (RutinaId, Orden, Nombre) VALUES
(@Plantilla, 1, N'Día A'), (@Plantilla, 2, N'Día B'), (@Plantilla, 3, N'Día C');

INSERT INTO gym.RutinaDiaEjercicio
    (RutinaDiaId, EjercicioId, Orden, Series, RepsMin, RepsMax, DescansoSeg, RpeObjetivo)
SELECT d.RutinaDiaId, e.EjercicioId, v.Orden, v.Series, v.RepsMin, v.RepsMax, v.Descanso, v.Rpe
FROM (VALUES
    (1, N'Sentadilla goblet',                 1, 3, 10, 12, 90, 7.0),
    (1, N'Flexiones',                         2, 3,  8, 12, 90, 7.0),
    (1, N'Remo con mancuerna',                3, 3, 10, 12, 90, 7.0),
    (1, N'Plancha frontal',                   4, 3, 20, 30, 60, 6.0),  -- reps = segundos
    (2, N'Peso muerto rumano con mancuernas', 1, 3, 10, 12, 90, 7.0),
    (2, N'Press militar con mancuernas',      2, 3, 10, 12, 90, 7.0),
    (2, N'Jalón al pecho',                    3, 3, 10, 12, 90, 7.0),
    (3, N'Zancadas',                          1, 3, 10, 12, 90, 7.0),
    (3, N'Flexiones',                         2, 3,  8, 12, 90, 7.0),
    (3, N'Hip thrust',                        3, 3, 10, 12, 90, 7.0),
    (3, N'Remo con mancuerna',                4, 3, 10, 12, 90, 7.0)
) v(Dia, Ejercicio, Orden, Series, RepsMin, RepsMax, Descanso, Rpe)
JOIN gym.RutinaDia d ON d.RutinaId = @Plantilla AND d.Orden = v.Dia
JOIN gym.Ejercicio e ON e.Nombre = v.Ejercicio;

/* --- Usuario de prueba y ejecución --- */
INSERT INTO gym.Usuario (Nombre, Email, NivelId, ObjetivoId, DiasSemana)
VALUES (N'Usuario de prueba', N'prueba@ejemplo.com', 1, 2, 3);

DECLARE @Usuario INT = SCOPE_IDENTITY(), @NuevaRutina INT, @Origen INT;

EXEC gym.usp_GenerarRutinaSugerida
     @UsuarioId   = @Usuario,
     @RutinaId    = @NuevaRutina OUTPUT,
     @PlantillaId = @Origen OUTPUT;

SELECT @NuevaRutina AS RutinaCreada, @Origen AS PlantillaUsada;
GO
