USE App_Gym;
GO

/* =========================================================
   17 - Ilustraciones de los ejercicios
   Ejecutar después de 01 a 16. Se puede volver a ejecutar.
   Generado por herramientas/imagenes/generar.py: no editar a mano.

   Las imágenes van incluidas en la app (app/assets/ejercicios) y
   aquí se guarda qué archivo corresponde a cada ejercicio, con su
   autoría y licencia, que la app muestra bajo la imagen.
   Origen: https://github.com/everkinetic/data, licencia CC BY-SA 4.0.
   Los ejercicios sin fila aquí no muestran imagen.
   ========================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'gym.EjercicioImagen', N'U') IS NULL
    CREATE TABLE gym.EjercicioImagen (
        EjercicioId  INT            NOT NULL REFERENCES gym.Ejercicio(EjercicioId) ON DELETE CASCADE,
        Orden        TINYINT        NOT NULL CONSTRAINT CK_EjercicioImagen_Orden CHECK (Orden BETWEEN 1 AND 2),
        Archivo      VARCHAR(120)   NOT NULL,
        Autor        NVARCHAR(100)  NOT NULL,
        Licencia     VARCHAR(20)    NOT NULL,
        LicenciaUrl  VARCHAR(200)   NOT NULL,
        FuenteUrl    VARCHAR(200)   NOT NULL,
        CONSTRAINT PK_EjercicioImagen PRIMARY KEY (EjercicioId, Orden)
    );
GO

DECLARE @Imagen TABLE (Ejercicio NVARCHAR(100) NOT NULL, Orden TINYINT NOT NULL, Archivo VARCHAR(120) NOT NULL,
                       PRIMARY KEY (Ejercicio, Orden));

INSERT INTO @Imagen (Ejercicio, Orden, Archivo) VALUES
    (N'Abducción de cadera en máquina', 1, 'thigh-abductor-1.webp'),
    (N'Abducción de cadera en máquina', 2, 'thigh-abductor-2.webp'),
    (N'Aducción de cadera en máquina', 1, 'thigh-adductor-1.webp'),
    (N'Aducción de cadera en máquina', 2, 'thigh-adductor-2.webp'),
    (N'Aperturas con mancuernas', 1, 'dumbbell-flys-1.webp'),
    (N'Aperturas con mancuernas', 2, 'dumbbell-flys-2.webp'),
    (N'Aperturas en máquina', 1, 'butterfly-machine-1.webp'),
    (N'Aperturas en máquina', 2, 'butterfly-machine-2.webp'),
    (N'Aperturas inclinadas con mancuernas', 1, 'incline-dumbbell-flys-1.webp'),
    (N'Aperturas inclinadas con mancuernas', 2, 'incline-dumbbell-flys-2.webp'),
    (N'Buenos días con barra', 1, 'barbell-good-mornings-1.webp'),
    (N'Buenos días con barra', 2, 'barbell-good-mornings-2.webp'),
    (N'Cruce de poleas', 1, 'cable-crossover-1.webp'),
    (N'Cruce de poleas', 2, 'cable-crossover-2.webp'),
    (N'Crunch abdominal', 1, 'crunches-1.webp'),
    (N'Crunch abdominal', 2, 'crunches-2.webp'),
    (N'Crunch inverso', 1, 'bent-knee-hip-raise-1.webp'),
    (N'Crunch inverso', 2, 'bent-knee-hip-raise-2.webp'),
    (N'Curl con barra Z', 1, 'ez-bar-curl-with-barbell-1.webp'),
    (N'Curl con barra Z', 2, 'ez-bar-curl-with-barbell-2.webp'),
    (N'Curl de bíceps con barra', 1, 'wide-grip-standing-biceps-curl-with-barbell-1.webp'),
    (N'Curl de bíceps con barra', 2, 'wide-grip-standing-biceps-curl-with-barbell-2.webp'),
    (N'Curl de bíceps con mancuernas', 1, 'biceps-curl-with-dumbbell-1.webp'),
    (N'Curl de bíceps con mancuernas', 2, 'biceps-curl-with-dumbbell-2.webp'),
    (N'Curl de bíceps en máquina', 1, 'preacher-curl-with-machine-1.webp'),
    (N'Curl de bíceps en máquina', 2, 'preacher-curl-with-machine-2.webp'),
    (N'Curl de bíceps en polea baja', 1, 'standing-biceps-curl-with-cable-1.webp'),
    (N'Curl de bíceps en polea baja', 2, 'standing-biceps-curl-with-cable-2.webp'),
    (N'Curl femoral sentado en máquina', 1, 'seated-leg-curl-1.webp'),
    (N'Curl femoral sentado en máquina', 2, 'seated-leg-curl-2.webp'),
    (N'Curl femoral tumbado en máquina', 1, 'lying-leg-curl-machine-1.webp'),
    (N'Curl femoral tumbado en máquina', 2, 'lying-leg-curl-machine-2.webp'),
    (N'Curl martillo', 1, 'bicep-hammer-curl-with-dumbbell-1.webp'),
    (N'Curl martillo', 2, 'bicep-hammer-curl-with-dumbbell-2.webp'),
    (N'Curl martillo con cuerda en polea', 1, 'hammer-curls-with-rope-and-cable-1.webp'),
    (N'Curl martillo con cuerda en polea', 2, 'hammer-curls-with-rope-and-cable-2.webp'),
    (N'Curl predicador con barra Z', 1, 'preacher-curl-with-barbell-1.webp'),
    (N'Curl predicador con barra Z', 2, 'preacher-curl-with-barbell-2.webp'),
    (N'Dominadas', 1, 'pull-ups-1.webp'),
    (N'Dominadas', 2, 'pull-ups-2.webp'),
    (N'Dominadas supinas', 1, 'chin-ups-1.webp'),
    (N'Dominadas supinas', 2, 'chin-ups-2.webp'),
    (N'Elevaciones frontales con mancuernas', 1, 'front-raises-1.webp'),
    (N'Elevaciones frontales con mancuernas', 2, 'front-raises-2.webp'),
    (N'Elevaciones laterales con mancuernas', 1, 'lateral-dumbbell-raises-1.webp'),
    (N'Elevaciones laterales con mancuernas', 2, 'lateral-dumbbell-raises-2.webp'),
    (N'Elevación de talones de pie en máquina', 1, 'standing-calf-raises-using-machine-1.webp'),
    (N'Elevación de talones de pie en máquina', 2, 'standing-calf-raises-using-machine-2.webp'),
    (N'Elevación de talones en prensa', 1, 'calves-press-on-leg-machine-1.webp'),
    (N'Elevación de talones en prensa', 2, 'calves-press-on-leg-machine-2.webp'),
    (N'Encogimientos con barra', 1, 'barbell-shrugs-1.webp'),
    (N'Encogimientos con barra', 2, 'barbell-shrugs-2.webp'),
    (N'Encogimientos con mancuernas', 1, 'shoulder-shrugs-1.webp'),
    (N'Encogimientos con mancuernas', 2, 'shoulder-shrugs-2.webp'),
    (N'Extensión de cuádriceps en máquina', 1, 'leg-extensions-1.webp'),
    (N'Extensión de cuádriceps en máquina', 2, 'leg-extensions-2.webp'),
    (N'Extensión de tríceps con cuerda en polea', 1, 'triceps-pushdown-with-rope-and-cable-1.webp'),
    (N'Extensión de tríceps con cuerda en polea', 2, 'triceps-pushdown-with-rope-and-cable-2.webp'),
    (N'Extensión de tríceps en polea alta', 1, 'triceps-pushdown-with-cable-1.webp'),
    (N'Extensión de tríceps en polea alta', 2, 'triceps-pushdown-with-cable-2.webp'),
    (N'Extensión de tríceps por encima de la cabeza', 1, 'seated-triceps-press-with-dumbbell-1.webp'),
    (N'Extensión de tríceps por encima de la cabeza', 2, 'seated-triceps-press-with-dumbbell-2.webp'),
    (N'Flexiones', 1, 'push-ups-1.webp'),
    (N'Flexiones', 2, 'push-ups-2.webp'),
    (N'Flexiones declinadas', 1, 'push-up-feet-elevated-1.webp'),
    (N'Flexiones declinadas', 2, 'push-up-feet-elevated-2.webp'),
    (N'Flexiones diamante', 1, 'close-triceps-pushup-1.webp'),
    (N'Flexiones diamante', 2, 'close-triceps-pushup-2.webp'),
    (N'Flexión lateral con mancuerna', 1, 'side-bend-with-dumbbell-1.webp'),
    (N'Flexión lateral con mancuerna', 2, 'side-bend-with-dumbbell-2.webp'),
    (N'Fondos en banco', 1, 'bench-dips-1.webp'),
    (N'Fondos en banco', 2, 'bench-dips-2.webp'),
    (N'Fondos en paralelas', 1, 'chest-dips-1.webp'),
    (N'Fondos en paralelas', 2, 'chest-dips-2.webp'),
    (N'Hiperextensiones', 1, 'hyperextensions-1.webp'),
    (N'Hiperextensiones', 2, 'hyperextensions-2.webp'),
    (N'Jalón al pecho', 1, 'wide-grip-lat-pull-down-1.webp'),
    (N'Jalón al pecho', 2, 'wide-grip-lat-pull-down-2.webp'),
    (N'Jalón con agarre estrecho', 1, 'v-bar-pull-down-1.webp'),
    (N'Jalón con agarre estrecho', 2, 'v-bar-pull-down-2.webp'),
    (N'Jalón con brazos rectos en polea', 1, 'straight-arm-push-down-1.webp'),
    (N'Jalón con brazos rectos en polea', 2, 'straight-arm-push-down-2.webp'),
    (N'Patada de glúteo en polea', 1, 'one-legged-cable-kickback-1.webp'),
    (N'Patada de glúteo en polea', 2, 'one-legged-cable-kickback-2.webp'),
    (N'Peso muerto con barra', 1, 'barbell-dead-lifts-1.webp'),
    (N'Peso muerto con barra', 2, 'barbell-dead-lifts-2.webp'),
    (N'Peso muerto rumano con barra', 1, 'romanian-dead-lift-1.webp'),
    (N'Peso muerto rumano con barra', 2, 'romanian-dead-lift-2.webp'),
    (N'Plancha lateral', 1, 'side-plank-1.webp'),
    (N'Plancha lateral', 2, 'side-plank-2.webp'),
    (N'Prensa de piernas', 1, 'leg-press-1.webp'),
    (N'Prensa de piernas', 2, 'leg-press-2.webp'),
    (N'Press Arnold', 1, 'arnold-press-1.webp'),
    (N'Press Arnold', 2, 'arnold-press-2.webp'),
    (N'Press de banca con agarre cerrado', 1, 'close-grip-barbell-bench-press-1.webp'),
    (N'Press de banca con agarre cerrado', 2, 'close-grip-barbell-bench-press-2.webp'),
    (N'Press de banca con barra', 1, 'bench-press-1.webp'),
    (N'Press de banca con barra', 2, 'bench-press-2.webp'),
    (N'Press de banca con mancuernas', 1, 'bench-press-dumbbell-1.webp'),
    (N'Press de banca con mancuernas', 2, 'bench-press-dumbbell-2.webp'),
    (N'Press de banca en multipower', 1, 'smith-machine-bench-press-1.webp'),
    (N'Press de banca en multipower', 2, 'smith-machine-bench-press-2.webp'),
    (N'Press de hombro en máquina', 1, 'seated-shoulder-press-machine-1.webp'),
    (N'Press de hombro en máquina', 2, 'seated-shoulder-press-machine-2.webp'),
    (N'Press de pecho en máquina', 1, 'machine-bench-press-1.webp'),
    (N'Press de pecho en máquina', 2, 'machine-bench-press-2.webp'),
    (N'Press declinado con barra', 1, 'decline-barbell-bench-press-1.webp'),
    (N'Press declinado con barra', 2, 'decline-barbell-bench-press-2.webp'),
    (N'Press francés con barra', 1, 'lying-triceps-press-with-barbell-1.webp'),
    (N'Press francés con barra', 2, 'lying-triceps-press-with-barbell-2.webp'),
    (N'Press inclinado con barra', 1, 'incline-bench-press-1.webp'),
    (N'Press inclinado con barra', 2, 'incline-bench-press-2.webp'),
    (N'Press inclinado con mancuernas', 1, 'dumbbell-incline-bench-press-1.webp'),
    (N'Press inclinado con mancuernas', 2, 'dumbbell-incline-bench-press-2.webp'),
    (N'Press militar con mancuernas', 1, 'dumbbell-shoulder-press-1.webp'),
    (N'Press militar con mancuernas', 2, 'dumbbell-shoulder-press-2.webp'),
    (N'Puente de glúteos', 1, 'bridging-1.webp'),
    (N'Puente de glúteos', 2, 'bridging-2.webp'),
    (N'Pullover con mancuerna', 1, 'straight-arm-dumbbell-pullover-1.webp'),
    (N'Pullover con mancuerna', 2, 'straight-arm-dumbbell-pullover-2.webp'),
    (N'Remo al mentón con barra', 1, 'upright-barbell-rows-1.webp'),
    (N'Remo al mentón con barra', 2, 'upright-barbell-rows-2.webp'),
    (N'Remo invertido en multipower', 1, 'body-row-1.webp'),
    (N'Remo invertido en multipower', 2, 'body-row-2.webp'),
    (N'Remo sentado en polea', 1, 'seated-cable-rows-1.webp'),
    (N'Remo sentado en polea', 2, 'seated-cable-rows-2.webp'),
    (N'Sentadilla con barra', 1, 'barbell-squat-1.webp'),
    (N'Sentadilla con barra', 2, 'barbell-squat-2.webp'),
    (N'Sentadilla en multipower', 1, 'smith-machine-squats-1.webp'),
    (N'Sentadilla en multipower', 2, 'smith-machine-squats-2.webp'),
    (N'Sentadilla frontal con barra', 1, 'front-squat-with-barbell-1.webp'),
    (N'Sentadilla frontal con barra', 2, 'front-squat-with-barbell-2.webp'),
    (N'Sentadilla sumo con mancuerna', 1, 'pile-squat-with-dumbbell-1.webp'),
    (N'Sentadilla sumo con mancuerna', 2, 'pile-squat-with-dumbbell-2.webp'),
    (N'Subidas al banco', 1, 'step-ups-with-dumbbells-1.webp'),
    (N'Subidas al banco', 2, 'step-ups-with-dumbbells-2.webp'),
    (N'Superman', 1, 'supermans-1.webp'),
    (N'Superman', 2, 'supermans-2.webp'),
    (N'Zancadas caminando', 1, 'walking-lunges-1.webp'),
    (N'Zancadas caminando', 2, 'walking-lunges-2.webp'),
    (N'Zancadas hacia atrás', 1, 'rear-lunges-with-dumbbell-1.webp'),
    (N'Zancadas hacia atrás', 2, 'rear-lunges-with-dumbbell-2.webp');

IF EXISTS (SELECT 1 FROM @Imagen i WHERE NOT EXISTS (SELECT 1 FROM gym.Ejercicio e WHERE e.Nombre = i.Ejercicio))
BEGIN
    DECLARE @Falta NVARCHAR(100) = (SELECT TOP (1) i.Ejercicio FROM @Imagen i
                                    WHERE NOT EXISTS (SELECT 1 FROM gym.Ejercicio e WHERE e.Nombre = i.Ejercicio));
    DECLARE @Msg NVARCHAR(200) = CONCAT(N'Ejercicio no encontrado en el catálogo: ', @Falta);
    THROW 50170, @Msg, 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    -- La asignación se sustituye por la de este script
    DELETE FROM gym.EjercicioImagen;

    INSERT INTO gym.EjercicioImagen (EjercicioId, Orden, Archivo, Autor, Licencia, LicenciaUrl, FuenteUrl)
    SELECT e.EjercicioId, i.Orden, i.Archivo, N'Everkinetic', 'CC BY-SA 4.0', 'https://creativecommons.org/licenses/by-sa/4.0/', 'https://github.com/everkinetic/data'
    FROM @Imagen i
    JOIN gym.Ejercicio e ON e.Nombre = i.Ejercicio;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

/* ---------- Comprobación ---------- */
SELECT COUNT(DISTINCT EjercicioId) AS EjerciciosConImagen,
       COUNT(*) AS Imagenes,
       (SELECT COUNT(*) FROM gym.Ejercicio WHERE Activo = 1) AS EjerciciosActivos
FROM gym.EjercicioImagen;

SELECT TOP (5) e.Nombre, ei.Orden, ei.Archivo, ei.Autor, ei.Licencia
FROM gym.EjercicioImagen ei
JOIN gym.Ejercicio e ON e.EjercicioId = ei.EjercicioId
ORDER BY e.Nombre, ei.Orden;
GO
