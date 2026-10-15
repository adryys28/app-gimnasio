USE App_Gym;
GO

/* =========================================================
   06 - Gestión de días: añadir, renombrar, mover y quitar
   Ejecutar después de 01 a 05.
   ========================================================= */

/* ---------- Uso interno: renumera los días de una rutina como 1..N ---------- */
CREATE OR ALTER PROCEDURE gym.usp_CompactarOrdenRutina
    @RutinaId INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH x AS (
        SELECT Orden, ROW_NUMBER() OVER (ORDER BY Orden) AS rn
        FROM gym.RutinaDia
        WHERE RutinaId = @RutinaId
    )
    UPDATE x SET Orden = rn WHERE Orden <> rn;
END;
GO

/* ---------- Añadir día ----------
   @Posicion NULL = al final. @Nombre NULL = "Día N".
*/
CREATE OR ALTER PROCEDURE gym.usp_AgregarDiaRutina
    @UsuarioId   INT,
    @RutinaId    INT,
    @Nombre      NVARCHAR(100) = NULL,
    @Posicion    TINYINT       = NULL,
    @RutinaDiaId INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM gym.Rutina
                   WHERE RutinaId = @RutinaId AND UsuarioId = @UsuarioId AND EsPlantilla = 0)
        THROW 50030, N'La rutina no existe o no pertenece al usuario.', 1;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), N'');

    IF LEN(@Nombre) > 50
        THROW 50031, N'El nombre del día admite un máximo de 50 caracteres.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC gym.usp_CompactarOrdenRutina @RutinaId = @RutinaId;

        DECLARE @Total INT = (SELECT COUNT(*)
                              FROM gym.RutinaDia WITH (UPDLOCK, HOLDLOCK)
                              WHERE RutinaId = @RutinaId);

        IF @Total >= 7
            THROW 50032, N'Una rutina admite un máximo de 7 días.', 1;

        SET @Posicion = CASE WHEN @Posicion IS NULL OR @Posicion > @Total THEN @Total + 1
                             WHEN @Posicion < 1 THEN 1
                             ELSE @Posicion END;

        UPDATE gym.RutinaDia
        SET Orden = Orden + 1
        WHERE RutinaId = @RutinaId AND Orden >= @Posicion;

        INSERT INTO gym.RutinaDia (RutinaId, Orden, Nombre)
        VALUES (@RutinaId, @Posicion, COALESCE(@Nombre, N'Día ' + CAST(@Total + 1 AS NVARCHAR(1))));

        SET @RutinaDiaId = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT * FROM gym.vw_RutinaDetalle WHERE RutinaId = @RutinaId ORDER BY Dia, Orden;
END;
GO

/* ---------- Renombrar día ---------- */
CREATE OR ALTER PROCEDURE gym.usp_RenombrarDiaRutina
    @UsuarioId   INT,
    @RutinaDiaId INT,
    @Nombre      NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), N'');

    IF @Nombre IS NULL
        THROW 50033, N'Indica un nombre para el día.', 1;
    IF LEN(@Nombre) > 50
        THROW 50031, N'El nombre del día admite un máximo de 50 caracteres.', 1;

    UPDATE d
    SET Nombre = @Nombre
    FROM gym.RutinaDia d
    JOIN gym.Rutina r ON r.RutinaId = d.RutinaId
    WHERE d.RutinaDiaId = @RutinaDiaId
      AND r.UsuarioId = @UsuarioId
      AND r.EsPlantilla = 0;

    IF @@ROWCOUNT = 0
        THROW 50020, N'El día no existe o no pertenece a una rutina del usuario.', 1;
END;
GO

/* ---------- Mover día a otra posición ---------- */
CREATE OR ALTER PROCEDURE gym.usp_MoverDiaRutina
    @UsuarioId     INT,
    @RutinaDiaId   INT,
    @NuevaPosicion TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RutinaId INT;

    SELECT @RutinaId = d.RutinaId
    FROM gym.RutinaDia d
    JOIN gym.Rutina r ON r.RutinaId = d.RutinaId
    WHERE d.RutinaDiaId = @RutinaDiaId
      AND r.UsuarioId = @UsuarioId
      AND r.EsPlantilla = 0;

    IF @RutinaId IS NULL
        THROW 50020, N'El día no existe o no pertenece a una rutina del usuario.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Total INT = (SELECT COUNT(*)
                              FROM gym.RutinaDia WITH (UPDLOCK, HOLDLOCK)
                              WHERE RutinaId = @RutinaId);

        SET @NuevaPosicion = CASE WHEN @NuevaPosicion < 1 THEN 1
                                  WHEN @NuevaPosicion > @Total THEN @Total
                                  ELSE @NuevaPosicion END;

        WITH Otros AS (
            SELECT RutinaDiaId, ROW_NUMBER() OVER (ORDER BY Orden) AS rn
            FROM gym.RutinaDia
            WHERE RutinaId = @RutinaId AND RutinaDiaId <> @RutinaDiaId
        ),
        Nuevo AS (
            SELECT RutinaDiaId,
                   CASE WHEN rn >= @NuevaPosicion THEN rn + 1 ELSE rn END AS NuevoOrden
            FROM Otros
            UNION ALL
            SELECT @RutinaDiaId, @NuevaPosicion
        )
        UPDATE d
        SET Orden = n.NuevoOrden
        FROM gym.RutinaDia d
        JOIN Nuevo n ON n.RutinaDiaId = d.RutinaDiaId
        WHERE d.Orden <> n.NuevoOrden;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT * FROM gym.vw_RutinaDetalle WHERE RutinaId = @RutinaId ORDER BY Dia, Orden;
END;
GO

/* ---------- Quitar día ----------
   Borra sus ejercicios (ON DELETE CASCADE). Las sesiones ya
   registradas se conservan: solo se desvinculan del día
   (Sesion.RutinaDiaId = NULL), igual que una sesión libre.
*/
CREATE OR ALTER PROCEDURE gym.usp_QuitarDiaRutina
    @UsuarioId   INT,
    @RutinaDiaId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RutinaId INT;

    SELECT @RutinaId = d.RutinaId
    FROM gym.RutinaDia d
    JOIN gym.Rutina r ON r.RutinaId = d.RutinaId
    WHERE d.RutinaDiaId = @RutinaDiaId
      AND r.UsuarioId = @UsuarioId
      AND r.EsPlantilla = 0;

    IF @RutinaId IS NULL
        THROW 50020, N'El día no existe o no pertenece a una rutina del usuario.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF (SELECT COUNT(*) FROM gym.RutinaDia WITH (UPDLOCK, HOLDLOCK)
            WHERE RutinaId = @RutinaId) <= 1
            THROW 50034, N'La rutina debe tener al menos un día.', 1;

        UPDATE gym.Sesion SET RutinaDiaId = NULL WHERE RutinaDiaId = @RutinaDiaId;

        DELETE FROM gym.RutinaDia WHERE RutinaDiaId = @RutinaDiaId;

        EXEC gym.usp_CompactarOrdenRutina @RutinaId = @RutinaId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT * FROM gym.vw_RutinaDetalle WHERE RutinaId = @RutinaId ORDER BY Dia, Orden;
END;
GO

/* ---------- Prueba (sobre la rutina manual creada en 05) ---------- */

DECLARE @U INT = (SELECT UsuarioId FROM gym.Usuario WHERE Email = N'prueba@ejemplo.com');

DECLARE @Rutina INT = (SELECT TOP (1) RutinaId FROM gym.Rutina
                       WHERE UsuarioId = @U AND Nombre = N'Mi rutina torso-pierna'
                       ORDER BY RutinaId DESC);

DECLARE @Dia1 INT = (SELECT RutinaDiaId FROM gym.RutinaDia WHERE RutinaId = @Rutina AND Orden = 1),
        @Dia2 INT = (SELECT RutinaDiaId FROM gym.RutinaDia WHERE RutinaId = @Rutina AND Orden = 2),
        @DiaNuevo INT;

EXEC gym.usp_RenombrarDiaRutina @UsuarioId = @U, @RutinaDiaId = @Dia1, @Nombre = N'Torso';
EXEC gym.usp_RenombrarDiaRutina @UsuarioId = @U, @RutinaDiaId = @Dia2, @Nombre = N'Pierna';

-- Nuevo día en primera posición
EXEC gym.usp_AgregarDiaRutina @UsuarioId = @U, @RutinaId = @Rutina,
     @Nombre = N'Full body', @Posicion = 1, @RutinaDiaId = @DiaNuevo OUTPUT;

-- Se mueve al final
EXEC gym.usp_MoverDiaRutina @UsuarioId = @U, @RutinaDiaId = @DiaNuevo, @NuevaPosicion = 3;

-- Se elimina
EXEC gym.usp_QuitarDiaRutina @UsuarioId = @U, @RutinaDiaId = @DiaNuevo;

-- Resultado esperado: 1 Torso (Plancha, Flexiones), 2 Pierna (vacío)
SELECT * FROM gym.vw_RutinaDetalle WHERE RutinaId = @Rutina ORDER BY Dia, Orden;
GO
