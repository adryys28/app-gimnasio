USE App_Gym;
GO

/* =========================================================
   13 - Estadísticas para el diseño V2
   Ejecutar después de 01 a 12. Se puede volver a ejecutar.

   usp_ResumenInicio : sesiones de la semana, volumen por día,
                       racha de días activos y últimos ajustes.
   usp_ResumenSesion : duración, volumen, series y RPE medio de una
                       sesión, récords personales y progresión.

   Las fechas se agrupan por día UTC. Para España (UTC+1/UTC+2) una
   sesión entre medianoche y las 2:00 puede contar en el día anterior.
   ========================================================= */

/* ---------- Pantalla Hoy ---------- */
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

/* ---------- Pantalla Resumen de sesión ---------- */
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
    WHERE ss.SesionId = @SesionId AND ss.PesoKg IS NOT NULL
    GROUP BY ss.EjercicioId;

    SELECT ss.EjercicioId, MAX(ss.PesoKg) AS PesoMax
    INTO #Anterior
    FROM gym.SesionSerie ss
    JOIN gym.Sesion s ON s.SesionId = ss.SesionId
    WHERE s.UsuarioId = @UsuarioId AND s.SesionId <> @SesionId AND s.FechaInicio < @Inicio
      AND ss.PesoKg IS NOT NULL
    GROUP BY ss.EjercicioId;

    -- 1. Resumen
    SELECT COALESCE(@NombreDia, N'Sesión libre') AS NombreDia,
           @Inicio AS FechaInicio,
           CASE WHEN @Fin IS NULL THEN NULL ELSE DATEDIFF(SECOND, @Inicio, @Fin) END AS DuracionSeg,
           COUNT(*) AS Series,
           CAST(COALESCE(SUM(CAST(Reps AS DECIMAL(12,2)) * PesoKg), 0) AS DECIMAL(12,1)) AS VolumenKg,
           CAST(AVG(Rpe) AS DECIMAL(3,1)) AS RpeMedio
    FROM gym.SesionSerie
    WHERE SesionId = @SesionId;

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
          AND ss.PesoKg IS NOT NULL AND s.FechaInicio <= @Inicio
        GROUP BY CAST(s.FechaInicio AS DATE)
        ORDER BY MAX(s.FechaInicio) DESC
    ) x
    JOIN gym.Ejercicio e ON e.EjercicioId = @Destacado
    ORDER BY x.Orden;
END;
GO

/* ---------- Prueba con el usuario de prueba ---------- */
DECLARE @U INT = (SELECT UsuarioId FROM gym.Usuario WHERE Email = N'prueba@ejemplo.com');
DECLARE @S BIGINT = (SELECT MAX(SesionId) FROM gym.Sesion WHERE UsuarioId = @U AND FechaFin IS NOT NULL);

EXEC gym.usp_ResumenInicio @UsuarioId = @U;
IF @S IS NOT NULL EXEC gym.usp_ResumenSesion @UsuarioId = @U, @SesionId = @S;
GO
