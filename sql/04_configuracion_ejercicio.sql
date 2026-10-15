USE App_Gym;
GO

/* =========================================================
   04 - Configuración por ejercicio: series, repeticiones o tiempo
   Ejecutar después de 01, 02 y 03.

   TipoMedida:
     'R' = repeticiones  -> RepsMin / RepsMax
     'T' = tiempo        -> DuracionSegMin / DuracionSegMax
   ========================================================= */

/* ---------- 1. Cambios de estructura ----------
   Se puede volver a ejecutar sin errores: cada cambio comprueba antes
   si ya está aplicado (útil si una ejecución anterior se quedó a medias).
*/

-- Medida por defecto del ejercicio (se usará al añadirlo a una rutina)
IF COL_LENGTH(N'gym.Ejercicio', N'TipoMedida') IS NULL
    ALTER TABLE gym.Ejercicio ADD
        TipoMedida CHAR(1) NOT NULL
            CONSTRAINT DF_Ejercicio_TipoMedida DEFAULT 'R'
            CONSTRAINT CK_Ejercicio_TipoMedida CHECK (TipoMedida IN ('R','T'));

-- Configuración concreta dentro de la rutina (puede diferir de la del ejercicio)
IF OBJECT_ID(N'gym.CK_Reps', N'C') IS NOT NULL
    ALTER TABLE gym.RutinaDiaEjercicio DROP CONSTRAINT CK_Reps;

ALTER TABLE gym.RutinaDiaEjercicio ALTER COLUMN RepsMin TINYINT NULL;
ALTER TABLE gym.RutinaDiaEjercicio ALTER COLUMN RepsMax TINYINT NULL;

IF COL_LENGTH(N'gym.RutinaDiaEjercicio', N'TipoMedida') IS NULL
    ALTER TABLE gym.RutinaDiaEjercicio ADD
        TipoMedida     CHAR(1)  NOT NULL CONSTRAINT DF_RDE_TipoMedida DEFAULT 'R',
        DuracionSegMin SMALLINT NULL,
        DuracionSegMax SMALLINT NULL;

-- Registro real: una serie puede medirse en repeticiones o en segundos.
-- SQL Server no permite cambiar la nulabilidad de una columna incluida en
-- un índice (error 5074): se borra IX_SesionSerie_Ejercicio y se recrea.
IF EXISTS (SELECT 1 FROM sys.indexes
           WHERE object_id = OBJECT_ID(N'gym.SesionSerie') AND name = N'IX_SesionSerie_Ejercicio')
    DROP INDEX IX_SesionSerie_Ejercicio ON gym.SesionSerie;

ALTER TABLE gym.SesionSerie ALTER COLUMN Reps TINYINT NULL;

CREATE INDEX IX_SesionSerie_Ejercicio ON gym.SesionSerie(EjercicioId) INCLUDE (Reps, PesoKg, Rpe);

IF COL_LENGTH(N'gym.SesionSerie', N'DuracionSeg') IS NULL
    ALTER TABLE gym.SesionSerie ADD DuracionSeg SMALLINT NULL;
GO

/* ---------- 2. Migración de datos (la plancha pasa a tiempo) ---------- */

UPDATE gym.Ejercicio SET TipoMedida = 'T' WHERE Nombre = N'Plancha frontal';

UPDATE rde
SET TipoMedida     = 'T',
    DuracionSegMin = rde.RepsMin,
    DuracionSegMax = rde.RepsMax,
    RepsMin        = NULL,
    RepsMax        = NULL
FROM gym.RutinaDiaEjercicio rde
JOIN gym.Ejercicio e ON e.EjercicioId = rde.EjercicioId
WHERE e.TipoMedida = 'T' AND rde.TipoMedida = 'R';
GO

/* ---------- 3. Restricciones de coherencia ----------
   Los IS NOT NULL explícitos son necesarios: un CHECK que evalúa
   a UNKNOWN (por un NULL) se considera superado en SQL Server.
*/

IF OBJECT_ID(N'gym.CK_RDE_Medida', N'C') IS NULL
    ALTER TABLE gym.RutinaDiaEjercicio ADD CONSTRAINT CK_RDE_Medida CHECK (
        (TipoMedida = 'R'
            AND RepsMin IS NOT NULL AND RepsMax IS NOT NULL
            AND RepsMin BETWEEN 1 AND 100 AND RepsMax BETWEEN RepsMin AND 100
            AND DuracionSegMin IS NULL AND DuracionSegMax IS NULL)
     OR (TipoMedida = 'T'
            AND DuracionSegMin IS NOT NULL AND DuracionSegMax IS NOT NULL
            AND DuracionSegMin BETWEEN 5 AND 3600 AND DuracionSegMax BETWEEN DuracionSegMin AND 3600
            AND RepsMin IS NULL AND RepsMax IS NULL)
    );

IF OBJECT_ID(N'gym.CK_SesionSerie_Medida', N'C') IS NULL
    ALTER TABLE gym.SesionSerie ADD
        CONSTRAINT CK_SesionSerie_Medida   CHECK (Reps IS NOT NULL OR DuracionSeg IS NOT NULL),
        CONSTRAINT CK_SesionSerie_Duracion CHECK (DuracionSeg BETWEEN 1 AND 36000);
GO

/* ---------- 4. Generador de rutina actualizado ---------- */

CREATE OR ALTER PROCEDURE gym.usp_GenerarRutinaSugerida
    @UsuarioId            INT,
    @NivelId              TINYINT = NULL,
    @ObjetivoId           TINYINT = NULL,
    @DiasSemana           TINYINT = NULL,
    @DesactivarAnteriores BIT     = 1,
    @RutinaId             INT     = NULL OUTPUT,
    @PlantillaId          INT     = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SELECT
        @NivelId    = COALESCE(@NivelId,    u.NivelId),
        @ObjetivoId = COALESCE(@ObjetivoId, u.ObjetivoId),
        @DiasSemana = COALESCE(@DiasSemana, u.DiasSemana, 3)
    FROM gym.Usuario u
    WHERE u.UsuarioId = @UsuarioId;

    IF @@ROWCOUNT = 0
        THROW 50001, N'El usuario no existe.', 1;

    SELECT TOP (1) @PlantillaId = r.RutinaId
    FROM gym.Rutina r
    CROSS APPLY (SELECT COUNT(*) AS Dias
                 FROM gym.RutinaDia d
                 WHERE d.RutinaId = r.RutinaId) d
    WHERE r.EsPlantilla = 1
      AND r.Activa = 1
      AND r.NivelId <= @NivelId
      AND (@ObjetivoId IS NULL OR r.ObjetivoId = @ObjetivoId OR r.ObjetivoId IS NULL)
      AND d.Dias > 0
    ORDER BY
        r.NivelId DESC,
        CASE WHEN r.ObjetivoId = @ObjetivoId THEN 0 ELSE 1 END,
        CASE WHEN d.Dias = @DiasSemana THEN 0
             WHEN d.Dias < @DiasSemana THEN 1
             ELSE 2 END,
        ABS(d.Dias - @DiasSemana),
        r.RutinaId;

    IF @PlantillaId IS NULL
        THROW 50002, N'No hay ninguna plantilla compatible con el nivel y objetivo indicados.', 1;

    DECLARE @MapaDias TABLE (DiaOrigen INT PRIMARY KEY, DiaNuevo INT NOT NULL);

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @DesactivarAnteriores = 1
            UPDATE gym.Rutina
            SET Activa = 0
            WHERE UsuarioId = @UsuarioId AND Activa = 1;

        INSERT INTO gym.Rutina (Nombre, UsuarioId, NivelId, ObjetivoId, EsPlantilla, Origen)
        SELECT Nombre, @UsuarioId, NivelId, ObjetivoId, 0, 'S'
        FROM gym.Rutina
        WHERE RutinaId = @PlantillaId;

        SET @RutinaId = SCOPE_IDENTITY();

        MERGE gym.RutinaDia AS t
        USING (SELECT RutinaDiaId, Orden, Nombre
               FROM gym.RutinaDia
               WHERE RutinaId = @PlantillaId) AS s
        ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT (RutinaId, Orden, Nombre)
            VALUES (@RutinaId, s.Orden, s.Nombre)
        OUTPUT s.RutinaDiaId, inserted.RutinaDiaId INTO @MapaDias (DiaOrigen, DiaNuevo);

        INSERT INTO gym.RutinaDiaEjercicio
            (RutinaDiaId, EjercicioId, Orden, Series, TipoMedida,
             RepsMin, RepsMax, DuracionSegMin, DuracionSegMax, DescansoSeg, RpeObjetivo)
        SELECT m.DiaNuevo, rde.EjercicioId, rde.Orden, rde.Series, rde.TipoMedida,
               rde.RepsMin, rde.RepsMax, rde.DuracionSegMin, rde.DuracionSegMax,
               rde.DescansoSeg, rde.RpeObjetivo
        FROM gym.RutinaDiaEjercicio rde
        JOIN @MapaDias m     ON m.DiaOrigen = rde.RutinaDiaId
        JOIN gym.Ejercicio e ON e.EjercicioId = rde.EjercicioId
        WHERE e.Activo = 1
          AND e.NivelMinimoId <= @NivelId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT r.RutinaId, r.Nombre AS Rutina,
           d.Orden AS Dia, d.Nombre AS NombreDia,
           rde.RutinaDiaEjercicioId, rde.Orden,
           e.EjercicioId, e.Nombre AS Ejercicio, e.VideoUrl, e.MiniaturaUrl,
           rde.Series, rde.TipoMedida,
           rde.RepsMin, rde.RepsMax, rde.DuracionSegMin, rde.DuracionSegMax,
           rde.DescansoSeg, rde.RpeObjetivo
    FROM gym.Rutina r
    JOIN gym.RutinaDia d            ON d.RutinaId = r.RutinaId
    JOIN gym.RutinaDiaEjercicio rde ON rde.RutinaDiaId = d.RutinaDiaId
    JOIN gym.Ejercicio e            ON e.EjercicioId = rde.EjercicioId
    WHERE r.RutinaId = @RutinaId
    ORDER BY d.Orden, rde.Orden;
END;
GO

/* ---------- 5. Configurar un ejercicio de la rutina del usuario ----------
   Parámetros NULL = se mantiene el valor actual.
   Al cambiar de tipo de medida, los valores del tipo anterior se borran.
*/

CREATE OR ALTER PROCEDURE gym.usp_ConfigurarEjercicioRutina
    @UsuarioId            INT,
    @RutinaDiaEjercicioId INT,
    @Series               TINYINT      = NULL,
    @TipoMedida           CHAR(1)      = NULL,
    @RepsMin              TINYINT      = NULL,
    @RepsMax              TINYINT      = NULL,
    @DuracionSegMin       SMALLINT     = NULL,
    @DuracionSegMax       SMALLINT     = NULL,
    @DescansoSeg          SMALLINT     = NULL,
    @RpeObjetivo          DECIMAL(3,1) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TipoAct CHAR(1),
            @RepsMinAct TINYINT, @RepsMaxAct TINYINT,
            @DurMinAct SMALLINT, @DurMaxAct SMALLINT;

    -- Solo rutinas propias del usuario; las plantillas no se editan
    SELECT @TipoAct    = rde.TipoMedida,
           @RepsMinAct = rde.RepsMin,        @RepsMaxAct = rde.RepsMax,
           @DurMinAct  = rde.DuracionSegMin, @DurMaxAct  = rde.DuracionSegMax
    FROM gym.RutinaDiaEjercicio rde
    JOIN gym.RutinaDia d ON d.RutinaDiaId = rde.RutinaDiaId
    JOIN gym.Rutina r    ON r.RutinaId = d.RutinaId
    WHERE rde.RutinaDiaEjercicioId = @RutinaDiaEjercicioId
      AND r.UsuarioId = @UsuarioId
      AND r.EsPlantilla = 0;

    IF @@ROWCOUNT = 0
        THROW 50010, N'El ejercicio no existe o no pertenece a una rutina del usuario.', 1;

    SET @TipoMedida = COALESCE(@TipoMedida, @TipoAct);

    IF @TipoMedida NOT IN ('R','T')
        THROW 50011, N'TipoMedida debe ser R (repeticiones) o T (tiempo).', 1;

    IF @TipoMedida = 'R'
    BEGIN
        SET @RepsMin = COALESCE(@RepsMin, CASE WHEN @TipoAct = 'R' THEN @RepsMinAct END);
        SET @RepsMax = COALESCE(@RepsMax, CASE WHEN @TipoAct = 'R' THEN @RepsMaxAct END, @RepsMin);

        IF @RepsMin IS NULL
            THROW 50012, N'Indica el número de repeticiones.', 1;
        IF @RepsMin NOT BETWEEN 1 AND 100 OR @RepsMax NOT BETWEEN @RepsMin AND 100
            THROW 50013, N'Repeticiones fuera de rango (1-100, máximo >= mínimo).', 1;

        SELECT @DuracionSegMin = NULL, @DuracionSegMax = NULL;
    END
    ELSE
    BEGIN
        SET @DuracionSegMin = COALESCE(@DuracionSegMin, CASE WHEN @TipoAct = 'T' THEN @DurMinAct END);
        SET @DuracionSegMax = COALESCE(@DuracionSegMax, CASE WHEN @TipoAct = 'T' THEN @DurMaxAct END, @DuracionSegMin);

        IF @DuracionSegMin IS NULL
            THROW 50014, N'Indica la duración en segundos.', 1;
        IF @DuracionSegMin NOT BETWEEN 5 AND 3600 OR @DuracionSegMax NOT BETWEEN @DuracionSegMin AND 3600
            THROW 50015, N'Duración fuera de rango (5-3600 s, máximo >= mínimo).', 1;

        SELECT @RepsMin = NULL, @RepsMax = NULL;
    END

    IF @Series IS NOT NULL AND @Series NOT BETWEEN 1 AND 20
        THROW 50016, N'Series fuera de rango (1-20).', 1;
    IF @DescansoSeg IS NOT NULL AND @DescansoSeg NOT BETWEEN 0 AND 600
        THROW 50017, N'Descanso fuera de rango (0-600 s).', 1;
    IF @RpeObjetivo IS NOT NULL AND @RpeObjetivo NOT BETWEEN 1 AND 10
        THROW 50018, N'RPE fuera de rango (1-10).', 1;

    UPDATE gym.RutinaDiaEjercicio
    SET Series         = COALESCE(@Series, Series),
        TipoMedida     = @TipoMedida,
        RepsMin        = @RepsMin,
        RepsMax        = @RepsMax,
        DuracionSegMin = @DuracionSegMin,
        DuracionSegMax = @DuracionSegMax,
        DescansoSeg    = COALESCE(@DescansoSeg, DescansoSeg),
        RpeObjetivo    = COALESCE(@RpeObjetivo, RpeObjetivo)
    WHERE RutinaDiaEjercicioId = @RutinaDiaEjercicioId;

    SELECT RutinaDiaEjercicioId, Series, TipoMedida, RepsMin, RepsMax,
           DuracionSegMin, DuracionSegMax, DescansoSeg, RpeObjetivo
    FROM gym.RutinaDiaEjercicio
    WHERE RutinaDiaEjercicioId = @RutinaDiaEjercicioId;
END;
GO

/* ---------- 6. Prueba ---------- */

DECLARE @U INT = (SELECT UsuarioId FROM gym.Usuario WHERE Email = N'prueba@ejemplo.com');

DECLARE @Flexiones INT = (
    SELECT TOP (1) rde.RutinaDiaEjercicioId
    FROM gym.RutinaDiaEjercicio rde
    JOIN gym.RutinaDia d ON d.RutinaDiaId = rde.RutinaDiaId
    JOIN gym.Rutina r    ON r.RutinaId = d.RutinaId
    JOIN gym.Ejercicio e ON e.EjercicioId = rde.EjercicioId
    WHERE r.UsuarioId = @U AND r.Activa = 1 AND e.Nombre = N'Flexiones'
    ORDER BY d.Orden);

-- 4 series de 10-15 repeticiones
EXEC gym.usp_ConfigurarEjercicioRutina
     @UsuarioId = @U, @RutinaDiaEjercicioId = @Flexiones,
     @Series = 4, @RepsMin = 10, @RepsMax = 15;

-- Cambio a tiempo: 3 series de 30-45 s
EXEC gym.usp_ConfigurarEjercicioRutina
     @UsuarioId = @U, @RutinaDiaEjercicioId = @Flexiones,
     @Series = 3, @TipoMedida = 'T', @DuracionSegMin = 30, @DuracionSegMax = 45;
GO
