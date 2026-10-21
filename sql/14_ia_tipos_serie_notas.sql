USE App_Gym;
GO

/* =========================================================
   14 - Rutinas generadas con IA, tipos de serie y notas
   Ejecutar después de 01 a 13. Se puede volver a ejecutar.

   - Rutina.Origen admite 'I' (generada con IA) y guarda una
     explicación en Rutina.Descripcion.
   - usp_CrearRutinaDesdeJson valida el plan que propone la IA
     contra el catálogo y lo guarda en una transacción.
   - SesionSerie guarda el tipo de serie y notas:
       N normal · C calentamiento · F al fallo · D dropset · R rest-pause
     Las series de calentamiento no cuentan para la adaptación por
     RPE, el volumen ni los récords.
   ========================================================= */

/* ---------- 1. Estructura ---------- */

IF COL_LENGTH(N'gym.Rutina', N'Descripcion') IS NULL
    ALTER TABLE gym.Rutina ADD Descripcion NVARCHAR(1000) NULL;

IF COL_LENGTH(N'gym.SesionSerie', N'TipoSerie') IS NULL
    ALTER TABLE gym.SesionSerie ADD
        TipoSerie CHAR(1) NOT NULL
            CONSTRAINT DF_SesionSerie_TipoSerie DEFAULT 'N'
            CONSTRAINT CK_SesionSerie_TipoSerie CHECK (TipoSerie IN ('N','C','F','D','R'));

IF COL_LENGTH(N'gym.SesionSerie', N'Notas') IS NULL
    ALTER TABLE gym.SesionSerie ADD Notas NVARCHAR(500) NULL;
GO

-- El CHECK original de Rutina.Origen no tenía nombre: se sustituye por uno que admite 'I'
DECLARE @ck SYSNAME = (
    SELECT TOP (1) cc.name
    FROM sys.check_constraints cc
    JOIN sys.columns c ON c.object_id = cc.parent_object_id AND c.column_id = cc.parent_column_id
    WHERE cc.parent_object_id = OBJECT_ID(N'gym.Rutina') AND c.name = N'Origen'
      AND cc.name <> N'CK_Rutina_Origen');
IF @ck IS NOT NULL
BEGIN
    DECLARE @Sql NVARCHAR(400) = N'ALTER TABLE gym.Rutina DROP CONSTRAINT ' + QUOTENAME(@ck) + N';';
    EXEC sys.sp_executesql @Sql;
END
IF OBJECT_ID(N'gym.CK_Rutina_Origen', N'C') IS NULL
    ALTER TABLE gym.Rutina ADD CONSTRAINT CK_Rutina_Origen CHECK (Origen IN ('S','M','I'));  -- S sugerida, M manual, I IA
GO

/* ---------- 2. Vista de detalle con la explicación de la rutina ---------- */
CREATE OR ALTER VIEW gym.vw_RutinaDetalle
AS
SELECT r.RutinaId, r.UsuarioId, r.Nombre AS Rutina, r.Origen, r.Activa, r.Descripcion,
       d.RutinaDiaId, d.Orden AS Dia, d.Nombre AS NombreDia,
       rde.RutinaDiaEjercicioId, rde.Orden,
       e.EjercicioId, e.Nombre AS Ejercicio, e.VideoUrl, e.MiniaturaUrl,
       rde.Series, rde.TipoMedida,
       rde.RepsMin, rde.RepsMax, rde.DuracionSegMin, rde.DuracionSegMax,
       rde.PesoObjetivoKg, rde.DescansoSeg, rde.RpeObjetivo
FROM gym.Rutina r
JOIN gym.RutinaDia d                 ON d.RutinaId = r.RutinaId
LEFT JOIN gym.RutinaDiaEjercicio rde ON rde.RutinaDiaId = d.RutinaDiaId
LEFT JOIN gym.Ejercicio e            ON e.EjercicioId = rde.EjercicioId;
GO

/* ---------- 3. Perfil de entrenamiento (respuestas del cuestionario inicial) ---------- */
CREATE OR ALTER PROCEDURE gym.usp_ActualizarPerfilEntrenamiento
    @UsuarioId  INT,
    @NivelId    TINYINT,
    @ObjetivoId TINYINT,
    @DiasSemana TINYINT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM gym.Nivel WHERE NivelId = @NivelId)
        THROW 50055, N'El nivel indicado no existe.', 1;
    IF NOT EXISTS (SELECT 1 FROM gym.Objetivo WHERE ObjetivoId = @ObjetivoId)
        THROW 50056, N'El objetivo indicado no existe.', 1;
    IF @DiasSemana NOT BETWEEN 1 AND 7
        THROW 50024, N'El número de días debe estar entre 1 y 7.', 1;

    UPDATE gym.Usuario
    SET NivelId = @NivelId, ObjetivoId = @ObjetivoId, DiasSemana = @DiasSemana
    WHERE UsuarioId = @UsuarioId;

    IF @@ROWCOUNT = 0
        THROW 50001, N'El usuario no existe.', 1;
END;
GO

/* ---------- 4. Crear rutina a partir de un plan en JSON (generado por IA) ----------
   Formato:
   { "nombre": "...", "explicacion": "...",
     "dias": [ { "nombre": "Torso A",
                 "ejercicios": [ { "ejercicioId": 12, "series": 3, "tipoMedida": "R",
                                   "repsMin": 8, "repsMax": 12,
                                   "duracionSegMin": null, "duracionSegMax": null,
                                   "descansoSeg": 90, "rpeObjetivo": 7.5 } ] } ] }
   Todo se valida aquí: la IA no puede introducir ejercicios inexistentes,
   de un nivel superior al de la persona ni valores fuera de rango.
*/
CREATE OR ALTER PROCEDURE gym.usp_CrearRutinaDesdeJson
    @UsuarioId INT,
    @PlanJson  NVARCHAR(MAX),
    @Origen    CHAR(1) = 'I',
    @RutinaId  INT     = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NivelId TINYINT, @ObjetivoId TINYINT;
    SELECT @NivelId = NivelId, @ObjetivoId = ObjetivoId FROM gym.Usuario WHERE UsuarioId = @UsuarioId;

    IF @NivelId IS NULL
        THROW 50001, N'El usuario no existe.', 1;
    IF ISJSON(@PlanJson) <> 1
        THROW 50130, N'El plan de rutina no es un JSON válido.', 1;
    IF @Origen NOT IN ('S','M','I')
        THROW 50131, N'Origen de rutina no válido.', 1;

    DECLARE @Nombre NVARCHAR(100) = LEFT(NULLIF(LTRIM(RTRIM(JSON_VALUE(@PlanJson, '$.nombre'))), N''), 100);
    DECLARE @Descripcion NVARCHAR(1000) = LEFT(JSON_VALUE(@PlanJson, '$.explicacion'), 1000);

    -- Días
    SELECT CAST(d.[key] AS INT) + 1 AS Orden,
           LEFT(COALESCE(NULLIF(LTRIM(RTRIM(JSON_VALUE(d.value, '$.nombre'))), N''), CONCAT(N'Día ', CAST(d.[key] AS INT) + 1)), 50) AS Nombre,
           JSON_QUERY(d.value, '$.ejercicios') AS Ejercicios
    INTO #Dia
    FROM OPENJSON(@PlanJson, '$.dias') d;

    -- Ejercicios de cada día
    SELECT d.Orden AS Dia,
           CAST(e.[key] AS INT) + 1 AS Orden,
           TRY_CAST(JSON_VALUE(e.value, '$.ejercicioId')    AS INT)          AS EjercicioId,
           TRY_CAST(JSON_VALUE(e.value, '$.series')         AS TINYINT)      AS Series,
           UPPER(JSON_VALUE(e.value, '$.tipoMedida'))                        AS TipoMedida,
           TRY_CAST(JSON_VALUE(e.value, '$.repsMin')        AS TINYINT)      AS RepsMin,
           TRY_CAST(JSON_VALUE(e.value, '$.repsMax')        AS TINYINT)      AS RepsMax,
           TRY_CAST(JSON_VALUE(e.value, '$.duracionSegMin') AS SMALLINT)     AS DuracionSegMin,
           TRY_CAST(JSON_VALUE(e.value, '$.duracionSegMax') AS SMALLINT)     AS DuracionSegMax,
           COALESCE(TRY_CAST(JSON_VALUE(e.value, '$.descansoSeg') AS SMALLINT), 90) AS DescansoSeg,
           TRY_CAST(JSON_VALUE(e.value, '$.rpeObjetivo')    AS DECIMAL(3,1)) AS RpeObjetivo
    INTO #Ej
    FROM #Dia d
    CROSS APPLY OPENJSON(d.Ejercicios) e;

    -- Validaciones con mensajes claros (las restricciones de las tablas son la última barrera)
    IF @Nombre IS NULL
        THROW 50132, N'El plan no tiene nombre.', 1;
    IF (SELECT COUNT(*) FROM #Dia) NOT BETWEEN 1 AND 7
        THROW 50133, N'El plan debe tener entre 1 y 7 días.', 1;
    IF EXISTS (SELECT 1 FROM #Dia d WHERE (SELECT COUNT(*) FROM #Ej e WHERE e.Dia = d.Orden) NOT BETWEEN 1 AND 15)
        THROW 50134, N'Cada día debe tener entre 1 y 15 ejercicios.', 1;
    IF EXISTS (SELECT 1 FROM #Ej e
               LEFT JOIN gym.Ejercicio x ON x.EjercicioId = e.EjercicioId AND x.Activo = 1 AND x.NivelMinimoId <= @NivelId
               WHERE x.EjercicioId IS NULL)
        THROW 50135, N'El plan incluye ejercicios inexistentes o de un nivel superior al de la persona.', 1;
    IF EXISTS (SELECT 1 FROM #Ej WHERE Series IS NULL OR Series NOT BETWEEN 1 AND 10
                                    OR DescansoSeg NOT BETWEEN 0 AND 600
                                    OR (RpeObjetivo IS NOT NULL AND RpeObjetivo NOT BETWEEN 5 AND 10))
        THROW 50136, N'El plan tiene series, descansos o RPE fuera de rango.', 1;
    -- CASE en lugar de NOT (...): con valores NULL la condición sería UNKNOWN y no se detectaría
    IF EXISTS (SELECT 1 FROM #Ej
               WHERE CASE WHEN TipoMedida = 'R' AND RepsMin BETWEEN 1 AND 100 AND RepsMax BETWEEN RepsMin AND 100 THEN 1
                          WHEN TipoMedida = 'T' AND DuracionSegMin BETWEEN 5 AND 3600
                                                AND DuracionSegMax BETWEEN DuracionSegMin AND 3600 THEN 1
                          ELSE 0 END = 0)
        THROW 50137, N'El plan tiene repeticiones o duraciones no válidas.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE gym.Rutina SET Activa = 0 WHERE UsuarioId = @UsuarioId AND Activa = 1;

        INSERT INTO gym.Rutina (Nombre, UsuarioId, NivelId, ObjetivoId, EsPlantilla, Origen, Activa, Descripcion)
        VALUES (@Nombre, @UsuarioId, @NivelId, @ObjetivoId, 0, @Origen, 1, @Descripcion);
        SET @RutinaId = SCOPE_IDENTITY();

        INSERT INTO gym.RutinaDia (RutinaId, Orden, Nombre)
        SELECT @RutinaId, Orden, Nombre FROM #Dia;

        INSERT INTO gym.RutinaDiaEjercicio
            (RutinaDiaId, EjercicioId, Orden, Series, TipoMedida, RepsMin, RepsMax,
             DuracionSegMin, DuracionSegMax, DescansoSeg, RpeObjetivo)
        SELECT rd.RutinaDiaId, e.EjercicioId, e.Orden, e.Series, e.TipoMedida,
               CASE WHEN e.TipoMedida = 'R' THEN e.RepsMin END,
               CASE WHEN e.TipoMedida = 'R' THEN e.RepsMax END,
               CASE WHEN e.TipoMedida = 'T' THEN e.DuracionSegMin END,
               CASE WHEN e.TipoMedida = 'T' THEN e.DuracionSegMax END,
               e.DescansoSeg, e.RpeObjetivo
        FROM #Ej e
        JOIN gym.RutinaDia rd ON rd.RutinaId = @RutinaId AND rd.Orden = e.Dia;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ---------- 5. Registrar serie con tipo y notas ---------- */
CREATE OR ALTER PROCEDURE gym.usp_RegistrarSerie
    @UsuarioId     INT,
    @SesionId      BIGINT,
    @EjercicioId   INT,
    @Reps          TINYINT      = NULL,
    @DuracionSeg   SMALLINT     = NULL,
    @PesoKg        DECIMAL(6,2) = NULL,
    @Rpe           DECIMAL(3,1) = NULL,
    @TipoSerie     CHAR(1)      = 'N',
    @Notas         NVARCHAR(600) = NULL,
    @SesionSerieId BIGINT       = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM gym.Sesion
                   WHERE SesionId = @SesionId AND UsuarioId = @UsuarioId AND FechaFin IS NULL)
        THROW 50040, N'La sesión no existe, no pertenece al usuario o ya está finalizada.', 1;
    IF NOT EXISTS (SELECT 1 FROM gym.Ejercicio WHERE EjercicioId = @EjercicioId)
        THROW 50021, N'El ejercicio no existe o está inactivo.', 1;
    IF @Reps IS NULL AND @DuracionSeg IS NULL
        THROW 50041, N'Indica repeticiones o duración.', 1;
    IF @Reps IS NOT NULL AND @Reps < 1
        THROW 50045, N'Las repeticiones deben ser al menos 1.', 1;
    IF @DuracionSeg IS NOT NULL AND @DuracionSeg NOT BETWEEN 1 AND 36000
        THROW 50044, N'Duración fuera de rango (1-36000 s).', 1;
    IF @PesoKg IS NOT NULL AND @PesoKg NOT BETWEEN 0 AND 1000
        THROW 50043, N'Peso fuera de rango (0-1000 kg).', 1;
    IF @Rpe IS NOT NULL AND @Rpe NOT BETWEEN 1 AND 10
        THROW 50018, N'RPE fuera de rango (1-10).', 1;
    IF COALESCE(@TipoSerie, 'N') NOT IN ('N','C','F','D','R')
        THROW 50140, N'Tipo de serie no válido (N, C, F, D o R).', 1;

    SET @TipoSerie = COALESCE(@TipoSerie, 'N');
    SET @Notas = NULLIF(LTRIM(RTRIM(@Notas)), N'');
    IF LEN(@Notas) > 500
        THROW 50141, N'Las notas admiten un máximo de 500 caracteres.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @NumSerie TINYINT = (SELECT COUNT(*) + 1
                                     FROM gym.SesionSerie WITH (UPDLOCK, HOLDLOCK)
                                     WHERE SesionId = @SesionId AND EjercicioId = @EjercicioId);

        INSERT INTO gym.SesionSerie (SesionId, EjercicioId, NumSerie, Reps, DuracionSeg, PesoKg, Rpe, TipoSerie, Notas)
        VALUES (@SesionId, @EjercicioId, @NumSerie, @Reps, @DuracionSeg, @PesoKg, @Rpe, @TipoSerie, @Notas);

        SET @SesionSerieId = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ---------- 6. Adaptación por RPE sin series de calentamiento ---------- */
CREATE OR ALTER PROCEDURE gym.usp_AdaptarRutinaPorSesion
    @SesionId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RutinaDiaId INT;

    SELECT @RutinaDiaId = s.RutinaDiaId
    FROM gym.Sesion s
    JOIN gym.RutinaDia d ON d.RutinaDiaId = s.RutinaDiaId
    JOIN gym.Rutina r    ON r.RutinaId = d.RutinaId
    WHERE s.SesionId = @SesionId
      AND s.FechaFin IS NOT NULL
      AND s.Adaptada = 0
      AND r.EsPlantilla = 0
      AND r.UsuarioId = s.UsuarioId;

    IF @RutinaDiaId IS NULL
        RETURN;  -- sesión libre, abierta o ya procesada

    SELECT rde.RutinaDiaEjercicioId, rde.Orden, e.Nombre AS Ejercicio,
           c.Codigo, a.Accion,
           CAST(CASE c.Codigo
                WHEN 'CALIBRAR'  THEN N'Primer registro con carga: se fija el peso de referencia.'
                -- Sin FORMAT: depende de CLR y falla si SQL Server no puede crear el AppDomain (error 6517)
                WHEN 'BAJAR_RPE' THEN CONCAT(N'Esfuerzo medio (RPE ',
                                             REPLACE(CONVERT(VARCHAR(5), CAST(m.RpeMedio AS DECIMAL(3,1))), '.', ','),
                                             N') muy por encima del objetivo (',
                                             REPLACE(CONVERT(VARCHAR(5), CAST(p.RpeObj AS DECIMAL(3,1))), '.', ','),
                                             N').')
                WHEN 'BAJAR_MIN' THEN N'Alguna serie no alcanzó el mínimo objetivo.'
                WHEN 'SUBIR'     THEN N'Máximo del rango alcanzado en todas las series con esfuerzo asumible.'
                ELSE CASE WHEN m.SeriesHechas < rde.Series
                          THEN N'No se completaron todas las series previstas.'
                          ELSE N'Progresando dentro del rango objetivo.' END
           END AS NVARCHAR(200)) AS Motivo,
           m.SeriesHechas, m.RpeMedio,
           rde.PesoObjetivoKg AS PesoAntes,      n.PesoNuevo,
           rde.RepsMin        AS RepsMinAntes,   n.RepsMinNuevo,
           rde.RepsMax        AS RepsMaxAntes,   n.RepsMaxNuevo,
           rde.DuracionSegMin AS DurMinAntes,    n.DurMinNueva,
           rde.DuracionSegMax AS DurMaxAntes,    n.DurMaxNueva
    INTO #Eval
    FROM gym.RutinaDiaEjercicio rde
    JOIN gym.Ejercicio e ON e.EjercicioId = rde.EjercicioId
    -- Métricas de la sesión para el ejercicio
    CROSS APPLY (
        SELECT COUNT(*)          AS SeriesHechas,
               MIN(ss.Reps)        AS RepsPeor,
               MIN(ss.DuracionSeg) AS DurPeor,
               MIN(ss.PesoKg)      AS PesoMin,
               MAX(ss.PesoKg)      AS PesoMax,
               AVG(ss.Rpe)         AS RpeMedio
        FROM gym.SesionSerie ss
        WHERE ss.SesionId = @SesionId AND ss.EjercicioId = rde.EjercicioId
          AND ss.TipoSerie <> 'C'  -- el calentamiento no cuenta para la adaptación
    ) m
    -- Parámetros
    CROSS APPLY (
        SELECT COALESCE(rde.RpeObjetivo, 7.0) AS RpeObj,
               CAST(CASE WHEN rde.PesoObjetivoKg >= 20 THEN 2.5 ELSE 1.0 END AS DECIMAL(6,2)) AS Inc
    ) p
    CROSS APPLY (
        SELECT CASE WHEN ROUND(rde.PesoObjetivoKg * 0.05 / p.Inc, 0) * p.Inc > p.Inc
                    THEN CAST(ROUND(rde.PesoObjetivoKg * 0.05 / p.Inc, 0) * p.Inc AS DECIMAL(6,2))
                    ELSE p.Inc END AS Bajada
    ) b
    -- Decisión (el orden de las condiciones es la prioridad)
    CROSS APPLY (
        SELECT CASE
            WHEN rde.TipoMedida = 'R' AND rde.PesoObjetivoKg IS NULL AND m.PesoMax IS NOT NULL THEN 'CALIBRAR'
            WHEN m.RpeMedio >= p.RpeObj + 1.5 THEN 'BAJAR_RPE'
            WHEN rde.TipoMedida = 'R' AND m.RepsPeor < rde.RepsMin THEN 'BAJAR_MIN'
            WHEN rde.TipoMedida = 'T' AND m.DurPeor < rde.DuracionSegMin THEN 'BAJAR_MIN'
            WHEN m.SeriesHechas >= rde.Series
             AND COALESCE(m.RpeMedio, p.RpeObj) <= p.RpeObj + 0.5
             AND (   (rde.TipoMedida = 'R' AND m.RepsPeor >= rde.RepsMax
                      AND (rde.PesoObjetivoKg IS NULL OR m.PesoMin >= rde.PesoObjetivoKg))
                  OR (rde.TipoMedida = 'T' AND m.DurPeor >= rde.DuracionSegMax))
                THEN 'SUBIR'
            ELSE 'MANTENER' END AS Codigo
    ) c
    CROSS APPLY (
        SELECT CASE WHEN c.Codigo LIKE 'BAJAR%' THEN 'BAJAR' ELSE c.Codigo END AS Accion
    ) a
    -- Nuevos valores
    CROSS APPLY (
        SELECT
            CAST(CASE
                WHEN a.Accion = 'CALIBRAR'       THEN m.PesoMax
                WHEN rde.PesoObjetivoKg IS NULL  THEN NULL
                WHEN a.Accion = 'SUBIR'          THEN CASE WHEN rde.PesoObjetivoKg + p.Inc > 1000 THEN 1000
                                                           ELSE rde.PesoObjetivoKg + p.Inc END
                WHEN a.Accion = 'BAJAR'          THEN CASE WHEN rde.PesoObjetivoKg > b.Bajada
                                                           THEN rde.PesoObjetivoKg - b.Bajada ELSE 0 END
                ELSE rde.PesoObjetivoKg END AS DECIMAL(6,2)) AS PesoNuevo,

            -- Repeticiones: solo cambian si es por repeticiones y sin carga
            CASE WHEN rde.TipoMedida = 'R' AND rde.PesoObjetivoKg IS NULL AND a.Accion = 'SUBIR'
                     THEN CASE WHEN rde.RepsMin + 2 > 100 THEN 100 ELSE rde.RepsMin + 2 END
                 WHEN rde.TipoMedida = 'R' AND rde.PesoObjetivoKg IS NULL AND a.Accion = 'BAJAR'
                     THEN CASE WHEN rde.RepsMin > 2 THEN rde.RepsMin - 2 ELSE 1 END
                 ELSE rde.RepsMin END AS RepsMinNuevo,
            CASE WHEN rde.TipoMedida = 'R' AND rde.PesoObjetivoKg IS NULL AND a.Accion = 'SUBIR'
                     THEN CASE WHEN rde.RepsMax + 2 > 100 THEN 100 ELSE rde.RepsMax + 2 END
                 WHEN rde.TipoMedida = 'R' AND rde.PesoObjetivoKg IS NULL AND a.Accion = 'BAJAR'
                     THEN CASE WHEN rde.RepsMax > 2 THEN rde.RepsMax - 2 ELSE 1 END
                 ELSE rde.RepsMax END AS RepsMaxNuevo,

            -- Duración: ±5 s dentro de 5-3600 s
            CASE WHEN rde.TipoMedida = 'T' AND a.Accion = 'SUBIR'
                     THEN CASE WHEN rde.DuracionSegMin + 5 > 3600 THEN 3600 ELSE rde.DuracionSegMin + 5 END
                 WHEN rde.TipoMedida = 'T' AND a.Accion = 'BAJAR'
                     THEN CASE WHEN rde.DuracionSegMin - 5 < 5 THEN 5 ELSE rde.DuracionSegMin - 5 END
                 ELSE rde.DuracionSegMin END AS DurMinNueva,
            CASE WHEN rde.TipoMedida = 'T' AND a.Accion = 'SUBIR'
                     THEN CASE WHEN rde.DuracionSegMax + 5 > 3600 THEN 3600 ELSE rde.DuracionSegMax + 5 END
                 WHEN rde.TipoMedida = 'T' AND a.Accion = 'BAJAR'
                     THEN CASE WHEN rde.DuracionSegMax - 5 < 5 THEN 5 ELSE rde.DuracionSegMax - 5 END
                 ELSE rde.DuracionSegMax END AS DurMaxNueva
    ) n
    WHERE rde.RutinaDiaId = @RutinaDiaId
      AND m.SeriesHechas > 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE rde
        SET PesoObjetivoKg = e.PesoNuevo,
            RepsMin        = e.RepsMinNuevo,
            RepsMax        = e.RepsMaxNuevo,
            DuracionSegMin = e.DurMinNueva,
            DuracionSegMax = e.DurMaxNueva
        FROM gym.RutinaDiaEjercicio rde
        JOIN #Eval e ON e.RutinaDiaEjercicioId = rde.RutinaDiaEjercicioId
        WHERE e.Accion <> 'MANTENER';

        INSERT INTO gym.AjusteRutina
            (RutinaDiaEjercicioId, SesionId, Accion, Motivo,
             PesoAntes, PesoDespues,
             RepsMinAntes, RepsMaxAntes, RepsMinDespues, RepsMaxDespues,
             DurMinAntes, DurMaxAntes, DurMinDespues, DurMaxDespues)
        SELECT RutinaDiaEjercicioId, @SesionId, Accion, Motivo,
               PesoAntes, PesoNuevo,
               RepsMinAntes, RepsMaxAntes, RepsMinNuevo, RepsMaxNuevo,
               DurMinAntes, DurMaxAntes, DurMinNueva, DurMaxNueva
        FROM #Eval
        WHERE Accion <> 'MANTENER';

        UPDATE gym.Sesion SET Adaptada = 1 WHERE SesionId = @SesionId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    -- Resumen para la app (todos los ejercicios realizados, también los que se mantienen)
    SELECT Ejercicio, Accion, Motivo, SeriesHechas, RpeMedio,
           PesoAntes, PesoNuevo,
           RepsMinAntes, RepsMaxAntes, RepsMinNuevo, RepsMaxNuevo,
           DurMinAntes, DurMaxAntes, DurMinNueva, DurMaxNueva
    FROM #Eval
    ORDER BY Orden;
END;
GO

/* ---------- 7. Estadísticas sin series de calentamiento ---------- */
CREATE OR ALTER PROCEDURE gym.usp_ResumenInicio
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM gym.Usuario WHERE UsuarioId = @UsuarioId)
        THROW 50001, N'El usuario no existe.', 1;

    DECLARE @Hoy DATE = CAST(SYSUTCDATETIME() AS DATE);
    -- Lunes de la semana actual, independiente de @@DATEFIRST
    DECLARE @Lunes DATE = DATEADD(DAY, -((DATEPART(WEEKDAY, @Hoy) + @@DATEFIRST - 2) % 7), @Hoy);
    DECLARE @LunesAnterior DATE = DATEADD(DAY, -7, @Lunes);

    -- Volumen (kg × repeticiones) por día de las dos últimas semanas
    SELECT CAST(s.FechaInicio AS DATE) AS Dia,
           SUM(CAST(ss.Reps AS DECIMAL(12,2)) * ss.PesoKg) AS VolumenKg
    INTO #Volumen
    FROM gym.Sesion s
    JOIN gym.SesionSerie ss ON ss.SesionId = s.SesionId
    WHERE s.UsuarioId = @UsuarioId
      AND s.FechaFin IS NOT NULL
      AND s.FechaInicio >= @LunesAnterior
      AND ss.Reps IS NOT NULL AND ss.PesoKg IS NOT NULL
      AND ss.TipoSerie <> 'C'
    GROUP BY CAST(s.FechaInicio AS DATE);

    -- Días con alguna sesión de fuerza o actividad de cardio finalizada
    SELECT DISTINCT CAST(FechaInicio AS DATE) AS Dia
    INTO #Dias
    FROM (
        SELECT FechaInicio FROM gym.Sesion WHERE UsuarioId = @UsuarioId AND FechaFin IS NOT NULL
        UNION ALL
        SELECT FechaInicio FROM gym.Actividad WHERE UsuarioId = @UsuarioId AND Estado = 'F'
    ) x;

    -- Racha: días consecutivos hasta hoy (o hasta ayer, si hoy aún no se ha entrenado)
    DECLARE @Ultimo DATE = (SELECT MAX(Dia) FROM #Dias), @Racha INT = 0;
    IF @Ultimo >= DATEADD(DAY, -1, @Hoy)
    BEGIN
        ;WITH g AS (
            SELECT Dia, DATEADD(DAY, -ROW_NUMBER() OVER (ORDER BY Dia), Dia) AS Grupo FROM #Dias
        )
        SELECT @Racha = COUNT(*) FROM g WHERE Grupo = (SELECT Grupo FROM g WHERE Dia = @Ultimo);
    END

    -- 1. Resumen
    SELECT u.Nombre,
           CAST(COALESCE(u.DiasSemana, 3) AS INT) AS ObjetivoSemana,
           (SELECT COUNT(*) FROM gym.Sesion s
            WHERE s.UsuarioId = @UsuarioId AND s.FechaFin IS NOT NULL AND s.FechaInicio >= @Lunes) AS SesionesSemana,
           CAST(COALESCE((SELECT SUM(VolumenKg) FROM #Volumen WHERE Dia >= @Lunes), 0) AS DECIMAL(12,1)) AS VolumenSemanaKg,
           CAST(COALESCE((SELECT SUM(VolumenKg) FROM #Volumen WHERE Dia < @Lunes), 0) AS DECIMAL(12,1)) AS VolumenSemanaAnteriorKg,
           @Racha AS RachaDias
    FROM gym.Usuario u
    WHERE u.UsuarioId = @UsuarioId;

    -- 2. Volumen por día de la semana actual (0 = lunes ... 6 = domingo)
    SELECT n.i AS DiaSemana,
           DATEADD(DAY, n.i, @Lunes) AS Fecha,
           CAST(COALESCE(v.VolumenKg, 0) AS DECIMAL(12,1)) AS VolumenKg
    FROM (VALUES (0),(1),(2),(3),(4),(5),(6)) n(i)
    LEFT JOIN #Volumen v ON v.Dia = DATEADD(DAY, n.i, @Lunes)
    ORDER BY n.i;

    -- 3. Últimos ajustes automáticos
    SELECT TOP (3) e.Nombre AS Ejercicio, a.Accion, a.Fecha,
           a.PesoAntes, a.PesoDespues,
           a.RepsMinAntes, a.RepsMinDespues,
           a.DurMinAntes, a.DurMinDespues
    FROM gym.AjusteRutina a
    JOIN gym.RutinaDiaEjercicio rde ON rde.RutinaDiaEjercicioId = a.RutinaDiaEjercicioId
    JOIN gym.RutinaDia d            ON d.RutinaDiaId = rde.RutinaDiaId
    JOIN gym.Rutina r               ON r.RutinaId = d.RutinaId
    JOIN gym.Ejercicio e            ON e.EjercicioId = rde.EjercicioId
    WHERE r.UsuarioId = @UsuarioId AND r.Activa = 1 AND a.Accion IN ('SUBIR', 'BAJAR')
    ORDER BY a.Fecha DESC, a.AjusteId DESC;
END;
GO

CREATE OR ALTER PROCEDURE gym.usp_ResumenSesion
    @UsuarioId INT,
    @SesionId  BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Inicio DATETIME2(0), @Fin DATETIME2(0), @NombreDia NVARCHAR(50);

    SELECT @Inicio = s.FechaInicio, @Fin = s.FechaFin, @NombreDia = d.Nombre
    FROM gym.Sesion s
    LEFT JOIN gym.RutinaDia d ON d.RutinaDiaId = s.RutinaDiaId
    WHERE s.SesionId = @SesionId AND s.UsuarioId = @UsuarioId;

    IF @Inicio IS NULL
        THROW 50120, N'La sesión no existe o no pertenece al usuario.', 1;

    -- Máximo peso por ejercicio en esta sesión y en las anteriores
    SELECT ss.EjercicioId,
           MAX(ss.PesoKg) AS PesoMax,
           MAX(ss.Reps)   AS RepsMax
    INTO #Actual
    FROM gym.SesionSerie ss
    WHERE ss.SesionId = @SesionId AND ss.PesoKg IS NOT NULL AND ss.TipoSerie <> 'C'
    GROUP BY ss.EjercicioId;

    SELECT ss.EjercicioId, MAX(ss.PesoKg) AS PesoMax
    INTO #Anterior
    FROM gym.SesionSerie ss
    JOIN gym.Sesion s ON s.SesionId = ss.SesionId
    WHERE s.UsuarioId = @UsuarioId AND s.SesionId <> @SesionId AND s.FechaInicio < @Inicio
      AND ss.PesoKg IS NOT NULL AND ss.TipoSerie <> 'C'
    GROUP BY ss.EjercicioId;

    -- 1. Resumen
    SELECT COALESCE(@NombreDia, N'Sesión libre') AS NombreDia,
           @Inicio AS FechaInicio,
           CASE WHEN @Fin IS NULL THEN NULL ELSE DATEDIFF(SECOND, @Inicio, @Fin) END AS DuracionSeg,
           COUNT(*) AS Series,
           CAST(COALESCE(SUM(CAST(Reps AS DECIMAL(12,2)) * PesoKg), 0) AS DECIMAL(12,1)) AS VolumenKg,
           CAST(AVG(Rpe) AS DECIMAL(3,1)) AS RpeMedio
    FROM gym.SesionSerie
    WHERE SesionId = @SesionId AND TipoSerie <> 'C';

    -- 2. Récords personales: peso máximo superior al de cualquier sesión anterior
    SELECT e.Nombre AS Ejercicio, a.PesoMax AS PesoKg, a.RepsMax AS Reps, p.PesoMax AS PesoAnteriorKg
    FROM #Actual a
    JOIN #Anterior p     ON p.EjercicioId = a.EjercicioId
    JOIN gym.Ejercicio e ON e.EjercicioId = a.EjercicioId
    WHERE a.PesoMax > p.PesoMax
    ORDER BY a.PesoMax - p.PesoMax DESC;

    -- 3. Progresión del ejercicio destacado (el del primer récord o, si no hay, el de más peso)
    DECLARE @Destacado INT = (
        SELECT TOP (1) a.EjercicioId
        FROM #Actual a
        LEFT JOIN #Anterior p ON p.EjercicioId = a.EjercicioId
        ORDER BY CASE WHEN a.PesoMax > p.PesoMax THEN 0 ELSE 1 END, a.PesoMax DESC);

    SELECT e.Nombre AS Ejercicio, x.Fecha, x.PesoMax AS PesoKg
    FROM (
        SELECT TOP (6) CAST(s.FechaInicio AS DATE) AS Fecha, MAX(ss.PesoKg) AS PesoMax, MAX(s.FechaInicio) AS Orden
        FROM gym.SesionSerie ss
        JOIN gym.Sesion s ON s.SesionId = ss.SesionId
        WHERE s.UsuarioId = @UsuarioId AND ss.EjercicioId = @Destacado
          AND ss.PesoKg IS NOT NULL AND ss.TipoSerie <> 'C' AND s.FechaInicio <= @Inicio
        GROUP BY CAST(s.FechaInicio AS DATE)
        ORDER BY MAX(s.FechaInicio) DESC
    ) x
    JOIN gym.Ejercicio e ON e.EjercicioId = @Destacado
    ORDER BY x.Orden;
END;
GO

/* ---------- 8. Prueba: plan como el que devolvería la IA ---------- */
DECLARE @U INT = (SELECT UsuarioId FROM gym.Usuario WHERE Email = N'prueba@ejemplo.com');
DECLARE @E1 INT = (SELECT EjercicioId FROM gym.Ejercicio WHERE Nombre = N'Sentadilla goblet'),
        @E2 INT = (SELECT EjercicioId FROM gym.Ejercicio WHERE Nombre = N'Press de banca con mancuernas'),
        @E3 INT = (SELECT EjercicioId FROM gym.Ejercicio WHERE Nombre = N'Jalón al pecho'),
        @E4 INT = (SELECT EjercicioId FROM gym.Ejercicio WHERE Nombre = N'Plancha frontal');
DECLARE @Plan NVARCHAR(MAX) = CONCAT(N'{"nombre":"Full body IA (prueba)","explicacion":"Plan de prueba de 1 día.",',
    N'"dias":[{"nombre":"Cuerpo completo","ejercicios":[',
    N'{"ejercicioId":', @E1, N',"series":3,"tipoMedida":"R","repsMin":8,"repsMax":12,"descansoSeg":90,"rpeObjetivo":7.5},',
    N'{"ejercicioId":', @E2, N',"series":3,"tipoMedida":"R","repsMin":8,"repsMax":12,"descansoSeg":90,"rpeObjetivo":7.5},',
    N'{"ejercicioId":', @E3, N',"series":3,"tipoMedida":"R","repsMin":10,"repsMax":12,"descansoSeg":90},',
    N'{"ejercicioId":', @E4, N',"series":3,"tipoMedida":"T","duracionSegMin":30,"duracionSegMax":45,"descansoSeg":60}]}]}');
DECLARE @R INT;

-- Se guarda la rutina activa actual para restaurarla después de la prueba
DECLARE @Anterior INT = (SELECT TOP (1) RutinaId FROM gym.Rutina WHERE UsuarioId = @U AND Activa = 1);

EXEC gym.usp_CrearRutinaDesdeJson @UsuarioId = @U, @PlanJson = @Plan, @RutinaId = @R OUTPUT;
SELECT * FROM gym.vw_RutinaDetalle WHERE RutinaId = @R ORDER BY Dia, Orden;

-- Restaurar: la rutina de prueba queda inactiva y vuelve la anterior
UPDATE gym.Rutina SET Activa = 0 WHERE RutinaId = @R;
UPDATE gym.Rutina SET Activa = 1 WHERE RutinaId = @Anterior;
GO
