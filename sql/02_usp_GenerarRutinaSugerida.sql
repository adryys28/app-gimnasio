USE App_Gym;
GO

/* =========================================================
   gym.usp_GenerarRutinaSugerida
   Copia la plantilla más adecuada al usuario según nivel,
   objetivo y días por semana.

   Criterios de selección (por prioridad):
     1. Nivel: el del usuario; si no hay plantilla, el inferior
        más cercano (nunca uno superior).
     2. Objetivo: coincidencia exacta > plantilla genérica (NULL).
     3. Días: exactos > menos días (el más cercano) > más días.
   ========================================================= */

CREATE OR ALTER PROCEDURE gym.usp_GenerarRutinaSugerida
    @UsuarioId            INT,
    @NivelId              TINYINT = NULL,  -- NULL = nivel guardado del usuario
    @ObjetivoId           TINYINT = NULL,  -- NULL = objetivo guardado del usuario
    @DiasSemana           TINYINT = NULL,  -- NULL = días guardados del usuario
    @DesactivarAnteriores BIT     = 1,
    @RutinaId             INT     = NULL OUTPUT,
    @PlantillaId          INT     = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* --- 1. Parámetros efectivos --- */
    SELECT
        @NivelId    = COALESCE(@NivelId,    u.NivelId),
        @ObjetivoId = COALESCE(@ObjetivoId, u.ObjetivoId),
        @DiasSemana = COALESCE(@DiasSemana, u.DiasSemana, 3)
    FROM gym.Usuario u
    WHERE u.UsuarioId = @UsuarioId;

    IF @@ROWCOUNT = 0
        THROW 50001, N'El usuario no existe.', 1;

    /* --- 2. Selección de plantilla --- */
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

    /* --- 3. Copia de la plantilla al usuario --- */
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

        -- MERGE permite devolver en OUTPUT el Id de origen y el nuevo
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
            (RutinaDiaId, EjercicioId, Orden, Series, RepsMin, RepsMax, DescansoSeg, RpeObjetivo)
        SELECT m.DiaNuevo, rde.EjercicioId, rde.Orden, rde.Series,
               rde.RepsMin, rde.RepsMax, rde.DescansoSeg, rde.RpeObjetivo
        FROM gym.RutinaDiaEjercicio rde
        JOIN @MapaDias m      ON m.DiaOrigen = rde.RutinaDiaId
        JOIN gym.Ejercicio e  ON e.EjercicioId = rde.EjercicioId
        WHERE e.Activo = 1
          AND e.NivelMinimoId <= @NivelId;  -- descarta ejercicios por encima del nivel

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    /* --- 4. Resultado para la app --- */
    SELECT r.RutinaId, r.Nombre AS Rutina,
           d.Orden AS Dia, d.Nombre AS NombreDia,
           rde.Orden, e.EjercicioId, e.Nombre AS Ejercicio, e.VideoUrl, e.MiniaturaUrl,
           rde.Series, rde.RepsMin, rde.RepsMax, rde.DescansoSeg, rde.RpeObjetivo
    FROM gym.Rutina r
    JOIN gym.RutinaDia d            ON d.RutinaId = r.RutinaId
    JOIN gym.RutinaDiaEjercicio rde ON rde.RutinaDiaId = d.RutinaDiaId
    JOIN gym.Ejercicio e            ON e.EjercicioId = rde.EjercicioId
    WHERE r.RutinaId = @RutinaId
    ORDER BY d.Orden, rde.Orden;
END;
GO
