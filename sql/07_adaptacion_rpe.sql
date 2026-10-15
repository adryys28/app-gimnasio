USE App_Gym;
GO

/* =========================================================
   07 - Registro de sesiones y adaptación automática por RPE
   Ejecutar después de 01 a 06.

   Reglas de adaptación (por ejercicio, al finalizar la sesión):
     CALIBRAR  Primer registro con carga -> fija PesoObjetivoKg.
     BAJAR     RPE medio >= objetivo + 1,5, o alguna serie por
               debajo del mínimo (reps o segundos).
     SUBIR     Series previstas completadas, peor serie >= máximo
               del rango, RPE medio <= objetivo + 0,5 y carga
               usada >= carga objetivo.
     MANTENER  Resto de casos.

   Qué se ajusta:
     Con carga       -> peso (+2,5 kg si >= 20 kg; +1 kg si < 20 kg;
                        bajada: 5 % redondeado, mínimo un incremento)
     Sin carga       -> rango de repeticiones (±2)
     Por tiempo      -> rango de duración (±5 s)
   RPE objetivo por defecto: 7 (si el ejercicio no tiene uno fijado).
   ========================================================= */

/* ---------- 1. Estructura ---------- */

ALTER TABLE gym.RutinaDiaEjercicio ADD
    PesoObjetivoKg DECIMAL(6,2) NULL
        CONSTRAINT CK_RDE_Peso CHECK (PesoObjetivoKg BETWEEN 0 AND 1000);

ALTER TABLE gym.Sesion ADD
    Adaptada BIT NOT NULL CONSTRAINT DF_Sesion_Adaptada DEFAULT 0;

ALTER TABLE gym.SesionSerie ADD
    CONSTRAINT CK_SesionSerie_Peso CHECK (PesoKg BETWEEN 0 AND 1000);

-- Historial de ajustes: permite mostrar en la app por qué cambió la rutina
CREATE TABLE gym.AjusteRutina (
    AjusteId             BIGINT        IDENTITY(1,1) PRIMARY KEY,
    RutinaDiaEjercicioId INT           NOT NULL REFERENCES gym.RutinaDiaEjercicio(RutinaDiaEjercicioId) ON DELETE CASCADE,
    SesionId             BIGINT        NULL REFERENCES gym.Sesion(SesionId),
    Fecha                DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
    Accion               VARCHAR(10)   NOT NULL CHECK (Accion IN ('CALIBRAR','SUBIR','BAJAR')),
    Motivo               NVARCHAR(200) NOT NULL,
    PesoAntes            DECIMAL(6,2)  NULL,
    PesoDespues          DECIMAL(6,2)  NULL,
    RepsMinAntes         TINYINT       NULL,
    RepsMaxAntes         TINYINT       NULL,
    RepsMinDespues       TINYINT       NULL,
    RepsMaxDespues       TINYINT       NULL,
    DurMinAntes          SMALLINT      NULL,
    DurMaxAntes          SMALLINT      NULL,
    DurMinDespues        SMALLINT      NULL,
    DurMaxDespues        SMALLINT      NULL
);

CREATE INDEX IX_AjusteRutina_RDE     ON gym.AjusteRutina(RutinaDiaEjercicioId, Fecha DESC);
CREATE INDEX IX_SesionSerie_Sesion   ON gym.SesionSerie(SesionId, EjercicioId);
GO

/* ---------- 2. Vista de detalle con peso objetivo ---------- */

CREATE OR ALTER VIEW gym.vw_RutinaDetalle
AS
SELECT r.RutinaId, r.UsuarioId, r.Nombre AS Rutina, r.Origen, r.Activa,
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

/* ---------- 3. Fijar peso objetivo manualmente (NULL = recalibrar) ---------- */

CREATE OR ALTER PROCEDURE gym.usp_FijarPesoObjetivo
    @UsuarioId            INT,
    @RutinaDiaEjercicioId INT,
    @PesoKg               DECIMAL(6,2)
AS
BEGIN
    SET NOCOUNT ON;

    IF @PesoKg IS NOT NULL AND @PesoKg NOT BETWEEN 0 AND 1000
        THROW 50043, N'Peso fuera de rango (0-1000 kg).', 1;

    UPDATE rde
    SET PesoObjetivoKg = @PesoKg
    FROM gym.RutinaDiaEjercicio rde
    JOIN gym.RutinaDia d ON d.RutinaDiaId = rde.RutinaDiaId
    JOIN gym.Rutina r    ON r.RutinaId = d.RutinaId
    WHERE rde.RutinaDiaEjercicioId = @RutinaDiaEjercicioId
      AND r.UsuarioId = @UsuarioId
      AND r.EsPlantilla = 0;

    IF @@ROWCOUNT = 0
        THROW 50010, N'El ejercicio no existe o no pertenece a una rutina del usuario.', 1;
END;
GO

/* ---------- 4. Iniciar sesión (@RutinaDiaId NULL = sesión libre) ---------- */

CREATE OR ALTER PROCEDURE gym.usp_IniciarSesion
    @UsuarioId   INT,
    @RutinaDiaId INT    = NULL,
    @SesionId    BIGINT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM gym.Usuario WHERE UsuarioId = @UsuarioId)
        THROW 50001, N'El usuario no existe.', 1;

    IF @RutinaDiaId IS NOT NULL
       AND NOT EXISTS (SELECT 1
                       FROM gym.RutinaDia d
                       JOIN gym.Rutina r ON r.RutinaId = d.RutinaId
                       WHERE d.RutinaDiaId = @RutinaDiaId
                         AND r.UsuarioId = @UsuarioId
                         AND r.EsPlantilla = 0)
        THROW 50020, N'El día no existe o no pertenece a una rutina del usuario.', 1;

    INSERT INTO gym.Sesion (UsuarioId, RutinaDiaId) VALUES (@UsuarioId, @RutinaDiaId);
    SET @SesionId = SCOPE_IDENTITY();

    -- Plan del día para mostrarlo en la app
    IF @RutinaDiaId IS NOT NULL
        SELECT * FROM gym.vw_RutinaDetalle WHERE RutinaDiaId = @RutinaDiaId ORDER BY Orden;
END;
GO

/* ---------- 5. Registrar una serie ---------- */

CREATE OR ALTER PROCEDURE gym.usp_RegistrarSerie
    @UsuarioId     INT,
    @SesionId      BIGINT,
    @EjercicioId   INT,
    @Reps          TINYINT      = NULL,
    @DuracionSeg   SMALLINT     = NULL,
    @PesoKg        DECIMAL(6,2) = NULL,
    @Rpe           DECIMAL(3,1) = NULL,
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

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @NumSerie TINYINT = (SELECT COUNT(*) + 1
                                     FROM gym.SesionSerie WITH (UPDLOCK, HOLDLOCK)
                                     WHERE SesionId = @SesionId AND EjercicioId = @EjercicioId);

        INSERT INTO gym.SesionSerie (SesionId, EjercicioId, NumSerie, Reps, DuracionSeg, PesoKg, Rpe)
        VALUES (@SesionId, @EjercicioId, @NumSerie, @Reps, @DuracionSeg, @PesoKg, @Rpe);

        SET @SesionSerieId = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ---------- 6. Adaptación de la rutina a partir de una sesión ----------
   Solo actúa sobre sesiones finalizadas, no adaptadas y vinculadas a
   un día de una rutina propia. Es idempotente (marca Adaptada = 1).
*/

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
                WHEN 'BAJAR_RPE' THEN CONCAT(N'Esfuerzo medio (RPE ', FORMAT(m.RpeMedio, '0.0', 'es-ES'),
                                             N') muy por encima del objetivo (', FORMAT(p.RpeObj, '0.0', 'es-ES'), N').')
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

/* ---------- 7. Finalizar sesión ----------
   La adaptación va fuera de la transacción de cierre: si fallara,
   la sesión queda finalizada con Adaptada = 0 y se puede reintentar
   con usp_AdaptarRutinaPorSesion.
*/

CREATE OR ALTER PROCEDURE gym.usp_FinalizarSesion
    @UsuarioId INT,
    @SesionId  BIGINT,
    @Notas     NVARCHAR(500) = NULL,
    @Adaptar   BIT           = 1
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE gym.Sesion
    SET FechaFin = SYSUTCDATETIME(),
        Notas    = COALESCE(@Notas, Notas)
    WHERE SesionId = @SesionId
      AND UsuarioId = @UsuarioId
      AND FechaFin IS NULL;

    IF @@ROWCOUNT = 0
        THROW 50040, N'La sesión no existe, no pertenece al usuario o ya está finalizada.', 1;

    IF @Adaptar = 1
        EXEC gym.usp_AdaptarRutinaPorSesion @SesionId = @SesionId;
END;
GO

/* ---------- 8. Prueba (día "Torso" de la rutina manual de 05-06) ---------- */

DECLARE @U INT = (SELECT UsuarioId FROM gym.Usuario WHERE Email = N'prueba@ejemplo.com');

DECLARE @Rutina INT = (SELECT TOP (1) RutinaId FROM gym.Rutina
                       WHERE UsuarioId = @U AND Nombre = N'Mi rutina torso-pierna'
                       ORDER BY RutinaId DESC);

DECLARE @Torso     INT = (SELECT RutinaDiaId FROM gym.RutinaDia WHERE RutinaId = @Rutina AND Orden = 1),
        @EjFlex    INT = (SELECT EjercicioId FROM gym.Ejercicio WHERE Nombre = N'Flexiones'),
        @EjPlancha INT = (SELECT EjercicioId FROM gym.Ejercicio WHERE Nombre = N'Plancha frontal'),
        @EjRemo    INT = (SELECT EjercicioId FROM gym.Ejercicio WHERE Nombre = N'Remo con mancuerna'),
        @IdRemo INT, @S1 BIGINT, @S2 BIGINT;

-- Remo 3 x 8-10 con carga (aún sin peso objetivo)
EXEC gym.usp_AgregarEjercicioRutina @UsuarioId = @U, @RutinaDiaId = @Torso,
     @EjercicioId = @EjRemo, @Series = 3, @RepsMin = 8, @RepsMax = 10,
     @RutinaDiaEjercicioId = @IdRemo OUTPUT;

/* Sesión 1 */
EXEC gym.usp_IniciarSesion @UsuarioId = @U, @RutinaDiaId = @Torso, @SesionId = @S1 OUTPUT;

-- Plancha 3 x 30-45 s: muy dura (RPE medio 9,2) -> BAJAR a 25-40 s
EXEC gym.usp_RegistrarSerie @U, @S1, @EjPlancha, @DuracionSeg = 45, @Rpe = 9.0;
EXEC gym.usp_RegistrarSerie @U, @S1, @EjPlancha, @DuracionSeg = 40, @Rpe = 9.0;
EXEC gym.usp_RegistrarSerie @U, @S1, @EjPlancha, @DuracionSeg = 35, @Rpe = 9.5;

-- Flexiones 3 x 10-12: 12 en todas, RPE medio 7,2 -> SUBIR a 12-14
EXEC gym.usp_RegistrarSerie @U, @S1, @EjFlex, @Reps = 12, @Rpe = 7.0;
EXEC gym.usp_RegistrarSerie @U, @S1, @EjFlex, @Reps = 12, @Rpe = 7.0;
EXEC gym.usp_RegistrarSerie @U, @S1, @EjFlex, @Reps = 12, @Rpe = 7.5;

-- Remo con 16 kg -> CALIBRAR a 16 kg
EXEC gym.usp_RegistrarSerie @U, @S1, @EjRemo, @Reps = 10, @PesoKg = 16, @Rpe = 8.0;
EXEC gym.usp_RegistrarSerie @U, @S1, @EjRemo, @Reps = 10, @PesoKg = 16, @Rpe = 8.0;
EXEC gym.usp_RegistrarSerie @U, @S1, @EjRemo, @Reps = 9,  @PesoKg = 16, @Rpe = 8.5;

EXEC gym.usp_FinalizarSesion @UsuarioId = @U, @SesionId = @S1;

/* Sesión 2: remo 3 x 10 con 16 kg, RPE 7 -> SUBIR a 17 kg (+1 kg por ser < 20 kg) */
EXEC gym.usp_IniciarSesion @UsuarioId = @U, @RutinaDiaId = @Torso, @SesionId = @S2 OUTPUT;

EXEC gym.usp_RegistrarSerie @U, @S2, @EjRemo, @Reps = 10, @PesoKg = 16, @Rpe = 7.0;
EXEC gym.usp_RegistrarSerie @U, @S2, @EjRemo, @Reps = 10, @PesoKg = 16, @Rpe = 7.0;
EXEC gym.usp_RegistrarSerie @U, @S2, @EjRemo, @Reps = 10, @PesoKg = 16, @Rpe = 7.0;

EXEC gym.usp_FinalizarSesion @UsuarioId = @U, @SesionId = @S2;

-- Historial de ajustes
SELECT e.Nombre AS Ejercicio, a.Fecha, a.Accion, a.Motivo, a.PesoAntes, a.PesoDespues,
       a.RepsMinAntes, a.RepsMaxAntes, a.RepsMinDespues, a.RepsMaxDespues,
       a.DurMinAntes, a.DurMaxAntes, a.DurMinDespues, a.DurMaxDespues
FROM gym.AjusteRutina a
JOIN gym.RutinaDiaEjercicio rde ON rde.RutinaDiaEjercicioId = a.RutinaDiaEjercicioId
JOIN gym.Ejercicio e            ON e.EjercicioId = rde.EjercicioId
ORDER BY a.AjusteId;
GO
