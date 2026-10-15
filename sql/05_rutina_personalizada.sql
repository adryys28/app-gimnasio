USE App_Gym;
GO

/* =========================================================
   05 - Rutina personalizada: crear, añadir, quitar y reordenar
   Ejecutar después de 01 a 04.
   ========================================================= */

/* ---------- Vista de detalle (reutilizada por la app y los procedimientos) ----------
   LEFT JOIN para que aparezcan también los días sin ejercicios.
*/
CREATE OR ALTER VIEW gym.vw_RutinaDetalle
AS
SELECT r.RutinaId, r.UsuarioId, r.Nombre AS Rutina, r.Origen, r.Activa,
       d.RutinaDiaId, d.Orden AS Dia, d.Nombre AS NombreDia,
       rde.RutinaDiaEjercicioId, rde.Orden,
       e.EjercicioId, e.Nombre AS Ejercicio, e.VideoUrl, e.MiniaturaUrl,
       rde.Series, rde.TipoMedida,
       rde.RepsMin, rde.RepsMax, rde.DuracionSegMin, rde.DuracionSegMax,
       rde.DescansoSeg, rde.RpeObjetivo
FROM gym.Rutina r
JOIN gym.RutinaDia d                 ON d.RutinaId = r.RutinaId
LEFT JOIN gym.RutinaDiaEjercicio rde ON rde.RutinaDiaId = d.RutinaDiaId
LEFT JOIN gym.Ejercicio e            ON e.EjercicioId = rde.EjercicioId;
GO

/* ---------- Uso interno: renumera el orden de un día como 1..N ----------
   Necesario porque la copia de plantillas puede dejar huecos
   (ejercicios inactivos o por encima del nivel).
   Un único UPDATE no provoca conflictos transitorios con la
   restricción UNIQUE (RutinaDiaId, Orden): SQL Server la valida
   al final de la instrucción.
*/
CREATE OR ALTER PROCEDURE gym.usp_CompactarOrdenDia
    @RutinaDiaId INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH x AS (
        SELECT Orden, ROW_NUMBER() OVER (ORDER BY Orden) AS rn
        FROM gym.RutinaDiaEjercicio
        WHERE RutinaDiaId = @RutinaDiaId
    )
    UPDATE x SET Orden = rn WHERE Orden <> rn;
END;
GO

/* ---------- Crear rutina manual vacía ---------- */
CREATE OR ALTER PROCEDURE gym.usp_CrearRutinaManual
    @UsuarioId INT,
    @Nombre    NVARCHAR(100),
    @NumDias   TINYINT = 3,
    @Activar   BIT     = 1,
    @RutinaId  INT     = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NivelId TINYINT, @ObjetivoId TINYINT;

    SELECT @NivelId = NivelId, @ObjetivoId = ObjetivoId
    FROM gym.Usuario
    WHERE UsuarioId = @UsuarioId;

    IF @NivelId IS NULL
        THROW 50001, N'El usuario no existe.', 1;
    IF NULLIF(LTRIM(RTRIM(@Nombre)), N'') IS NULL
        THROW 50023, N'Indica un nombre para la rutina.', 1;
    IF @NumDias NOT BETWEEN 1 AND 7
        THROW 50024, N'El número de días debe estar entre 1 y 7.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Activar = 1
            UPDATE gym.Rutina SET Activa = 0
            WHERE UsuarioId = @UsuarioId AND Activa = 1;

        INSERT INTO gym.Rutina (Nombre, UsuarioId, NivelId, ObjetivoId, EsPlantilla, Origen, Activa)
        VALUES (LTRIM(RTRIM(@Nombre)), @UsuarioId, @NivelId, @ObjetivoId, 0, 'M', @Activar);

        SET @RutinaId = SCOPE_IDENTITY();

        INSERT INTO gym.RutinaDia (RutinaId, Orden, Nombre)
        SELECT @RutinaId, v.n, N'Día ' + CAST(v.n AS NVARCHAR(1))
        FROM (VALUES (1),(2),(3),(4),(5),(6),(7)) v(n)
        WHERE v.n <= @NumDias;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT * FROM gym.vw_RutinaDetalle WHERE RutinaId = @RutinaId ORDER BY Dia, Orden;
END;
GO

/* ---------- Añadir ejercicio a un día ----------
   @Posicion NULL = al final. Si no se indica configuración, se aplica
   un valor por defecto según el TipoMedida del ejercicio:
     R -> 3 x 10-12 reps, 90 s descanso
     T -> 3 x 30-45 s,    60 s descanso
   La validación se delega en usp_ConfigurarEjercicioRutina.
*/
CREATE OR ALTER PROCEDURE gym.usp_AgregarEjercicioRutina
    @UsuarioId            INT,
    @RutinaDiaId          INT,
    @EjercicioId          INT,
    @Posicion             TINYINT      = NULL,
    @Series               TINYINT      = NULL,
    @TipoMedida           CHAR(1)      = NULL,
    @RepsMin              TINYINT      = NULL,
    @RepsMax              TINYINT      = NULL,
    @DuracionSegMin       SMALLINT     = NULL,
    @DuracionSegMax       SMALLINT     = NULL,
    @DescansoSeg          SMALLINT     = NULL,
    @RpeObjetivo          DECIMAL(3,1) = NULL,
    @RutinaDiaEjercicioId INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1
                   FROM gym.RutinaDia d
                   JOIN gym.Rutina r ON r.RutinaId = d.RutinaId
                   WHERE d.RutinaDiaId = @RutinaDiaId
                     AND r.UsuarioId = @UsuarioId
                     AND r.EsPlantilla = 0)
        THROW 50020, N'El día no existe o no pertenece a una rutina del usuario.', 1;

    DECLARE @TipoDef CHAR(1);

    SELECT @TipoDef = TipoMedida
    FROM gym.Ejercicio
    WHERE EjercicioId = @EjercicioId AND Activo = 1;

    IF @TipoDef IS NULL
        THROW 50021, N'El ejercicio no existe o está inactivo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC gym.usp_CompactarOrdenDia @RutinaDiaId = @RutinaDiaId;

        -- Bloqueo del día para evitar colisiones de orden con otra petición simultánea
        DECLARE @Total INT = (SELECT COUNT(*)
                              FROM gym.RutinaDiaEjercicio WITH (UPDLOCK, HOLDLOCK)
                              WHERE RutinaDiaId = @RutinaDiaId);

        IF @Total >= 30
            THROW 50022, N'Se admite un máximo de 30 ejercicios por día.', 1;

        SET @Posicion = CASE WHEN @Posicion IS NULL OR @Posicion > @Total THEN @Total + 1
                             WHEN @Posicion < 1 THEN 1
                             ELSE @Posicion END;

        UPDATE gym.RutinaDiaEjercicio
        SET Orden = Orden + 1
        WHERE RutinaDiaId = @RutinaDiaId AND Orden >= @Posicion;

        INSERT INTO gym.RutinaDiaEjercicio
            (RutinaDiaId, EjercicioId, Orden, Series, TipoMedida,
             RepsMin, RepsMax, DuracionSegMin, DuracionSegMax, DescansoSeg)
        VALUES
            (@RutinaDiaId, @EjercicioId, @Posicion, 3, @TipoDef,
             CASE WHEN @TipoDef = 'R' THEN 10 END,
             CASE WHEN @TipoDef = 'R' THEN 12 END,
             CASE WHEN @TipoDef = 'T' THEN 30 END,
             CASE WHEN @TipoDef = 'T' THEN 45 END,
             CASE WHEN @TipoDef = 'T' THEN 60 ELSE 90 END);

        SET @RutinaDiaEjercicioId = SCOPE_IDENTITY();

        -- Aplica y valida la configuración indicada (NULL = mantiene el valor por defecto)
        EXEC gym.usp_ConfigurarEjercicioRutina
             @UsuarioId            = @UsuarioId,
             @RutinaDiaEjercicioId = @RutinaDiaEjercicioId,
             @Series               = @Series,
             @TipoMedida           = @TipoMedida,
             @RepsMin              = @RepsMin,
             @RepsMax              = @RepsMax,
             @DuracionSegMin       = @DuracionSegMin,
             @DuracionSegMax       = @DuracionSegMax,
             @DescansoSeg          = @DescansoSeg,
             @RpeObjetivo          = @RpeObjetivo;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ---------- Quitar ejercicio ----------
   El histórico no se pierde: SesionSerie referencia a Ejercicio,
   no a RutinaDiaEjercicio.
*/
CREATE OR ALTER PROCEDURE gym.usp_QuitarEjercicioRutina
    @UsuarioId            INT,
    @RutinaDiaEjercicioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RutinaDiaId INT;

    SELECT @RutinaDiaId = rde.RutinaDiaId
    FROM gym.RutinaDiaEjercicio rde
    JOIN gym.RutinaDia d ON d.RutinaDiaId = rde.RutinaDiaId
    JOIN gym.Rutina r    ON r.RutinaId = d.RutinaId
    WHERE rde.RutinaDiaEjercicioId = @RutinaDiaEjercicioId
      AND r.UsuarioId = @UsuarioId
      AND r.EsPlantilla = 0;

    IF @RutinaDiaId IS NULL
        THROW 50010, N'El ejercicio no existe o no pertenece a una rutina del usuario.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM gym.RutinaDiaEjercicio
        WHERE RutinaDiaEjercicioId = @RutinaDiaEjercicioId;

        EXEC gym.usp_CompactarOrdenDia @RutinaDiaId = @RutinaDiaId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT * FROM gym.vw_RutinaDetalle WHERE RutinaDiaId = @RutinaDiaId ORDER BY Orden;
END;
GO

/* ---------- Mover ejercicio a otra posición del mismo día ----------
   Pensado para arrastrar y soltar en la app.
   Posiciones fuera de rango se ajustan al primer o último lugar.
*/
CREATE OR ALTER PROCEDURE gym.usp_MoverEjercicioRutina
    @UsuarioId            INT,
    @RutinaDiaEjercicioId INT,
    @NuevaPosicion        TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RutinaDiaId INT;

    SELECT @RutinaDiaId = rde.RutinaDiaId
    FROM gym.RutinaDiaEjercicio rde
    JOIN gym.RutinaDia d ON d.RutinaDiaId = rde.RutinaDiaId
    JOIN gym.Rutina r    ON r.RutinaId = d.RutinaId
    WHERE rde.RutinaDiaEjercicioId = @RutinaDiaEjercicioId
      AND r.UsuarioId = @UsuarioId
      AND r.EsPlantilla = 0;

    IF @RutinaDiaId IS NULL
        THROW 50010, N'El ejercicio no existe o no pertenece a una rutina del usuario.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Total INT = (SELECT COUNT(*)
                              FROM gym.RutinaDiaEjercicio WITH (UPDLOCK, HOLDLOCK)
                              WHERE RutinaDiaId = @RutinaDiaId);

        SET @NuevaPosicion = CASE WHEN @NuevaPosicion < 1 THEN 1
                                  WHEN @NuevaPosicion > @Total THEN @Total
                                  ELSE @NuevaPosicion END;

        -- Los demás ejercicios se numeran sin el que se mueve y se
        -- desplazan una posición a partir del hueco de destino
        WITH Otros AS (
            SELECT RutinaDiaEjercicioId,
                   ROW_NUMBER() OVER (ORDER BY Orden) AS rn
            FROM gym.RutinaDiaEjercicio
            WHERE RutinaDiaId = @RutinaDiaId
              AND RutinaDiaEjercicioId <> @RutinaDiaEjercicioId
        ),
        Nuevo AS (
            SELECT RutinaDiaEjercicioId,
                   CASE WHEN rn >= @NuevaPosicion THEN rn + 1 ELSE rn END AS NuevoOrden
            FROM Otros
            UNION ALL
            SELECT @RutinaDiaEjercicioId, @NuevaPosicion
        )
        UPDATE rde
        SET Orden = n.NuevoOrden
        FROM gym.RutinaDiaEjercicio rde
        JOIN Nuevo n ON n.RutinaDiaEjercicioId = rde.RutinaDiaEjercicioId
        WHERE rde.Orden <> n.NuevoOrden;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT * FROM gym.vw_RutinaDetalle WHERE RutinaDiaId = @RutinaDiaId ORDER BY Orden;
END;
GO

/* ---------- Prueba ---------- */

DECLARE @U INT = (SELECT UsuarioId FROM gym.Usuario WHERE Email = N'prueba@ejemplo.com'),
        @Rutina INT, @Dia1 INT, @IdFlex INT, @IdRemo INT, @IdPlancha INT;

EXEC gym.usp_CrearRutinaManual
     @UsuarioId = @U, @Nombre = N'Mi rutina torso-pierna', @NumDias = 2,
     @RutinaId = @Rutina OUTPUT;

SELECT @Dia1 = RutinaDiaId FROM gym.RutinaDia WHERE RutinaId = @Rutina AND Orden = 1;

DECLARE @EjFlex    INT = (SELECT EjercicioId FROM gym.Ejercicio WHERE Nombre = N'Flexiones'),
        @EjRemo    INT = (SELECT EjercicioId FROM gym.Ejercicio WHERE Nombre = N'Remo con mancuerna'),
        @EjPlancha INT = (SELECT EjercicioId FROM gym.Ejercicio WHERE Nombre = N'Plancha frontal');

-- Configuración por defecto (3 x 10-12)
EXEC gym.usp_AgregarEjercicioRutina @UsuarioId = @U, @RutinaDiaId = @Dia1,
     @EjercicioId = @EjFlex, @RutinaDiaEjercicioId = @IdFlex OUTPUT;

-- Configuración personalizada (4 x 8-10)
EXEC gym.usp_AgregarEjercicioRutina @UsuarioId = @U, @RutinaDiaId = @Dia1,
     @EjercicioId = @EjRemo, @Series = 4, @RepsMin = 8, @RepsMax = 10,
     @RutinaDiaEjercicioId = @IdRemo OUTPUT;

-- Por tiempo (defecto del ejercicio: 3 x 30-45 s)
EXEC gym.usp_AgregarEjercicioRutina @UsuarioId = @U, @RutinaDiaId = @Dia1,
     @EjercicioId = @EjPlancha, @RutinaDiaEjercicioId = @IdPlancha OUTPUT;

-- La plancha pasa a primera posición
EXEC gym.usp_MoverEjercicioRutina @UsuarioId = @U,
     @RutinaDiaEjercicioId = @IdPlancha, @NuevaPosicion = 1;

-- Se quita el remo
EXEC gym.usp_QuitarEjercicioRutina @UsuarioId = @U, @RutinaDiaEjercicioId = @IdRemo;

-- Resultado esperado día 1: 1 Plancha frontal, 2 Flexiones
SELECT * FROM gym.vw_RutinaDetalle WHERE RutinaId = @Rutina ORDER BY Dia, Orden;
GO
