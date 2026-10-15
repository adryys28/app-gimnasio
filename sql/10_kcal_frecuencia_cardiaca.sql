USE App_Gym;
GO

/* =========================================================
   10 - Kcal a partir de la frecuencia cardiaca
   Ejecutar después de 01 a 09.

   Ecuaciones de Keytel et al. (2005), J Sports Sci 23(3):289-297.
   Resultado en kJ/min (se divide entre 4,184 para kcal/min).
     Sin VO2máx:
       Hombre: -55,0969 + 0,6309·FC + 0,1988·peso + 0,2017·edad
       Mujer:  -20,4022 + 0,4472·FC - 0,1263·peso + 0,0740·edad
     Con VO2máx (más precisa):
       Hombre: -95,7735 + 0,634·FC + 0,404·VO2máx + 0,394·peso + 0,271·edad
       Mujer:  -59,3954 + 0,450·FC + 0,380·VO2máx + 0,103·peso + 0,274·edad

   Límites de validez (se aplican en el cálculo):
     - Se desarrollaron con personas de 18-45 años y 47-120 kg, en ejercicio
       aeróbico estable entre el 57 % y el 90 % de la FC máxima. Solo se usan
       los tramos en movimiento con FC en ese rango; el resto del tiempo se
       estima con ACSM/MET.
     - FC máxima: la indicada por la persona o, si no, 208 - 0,7·edad
       (Tanaka et al., 2001).
     - Las ecuaciones requieren sexo. Si no se indica, no se aplican y se
       usa ACSM/MET.
     - No son válidas para entrenamiento de fuerza: la relación FC-consumo
       de oxígeno es distinta. Solo se aplican a actividades de cardio.
   ========================================================= */

/* ---------- 1. Datos fisiológicos del perfil ---------- */

ALTER TABLE gym.Usuario ADD
    SexoCalculo   CHAR(1)      NULL CONSTRAINT CK_Usuario_SexoCalculo CHECK (SexoCalculo IN ('H','M')), -- H = hombre, M = mujer
    Vo2MaxMlKgMin DECIMAL(4,1) NULL CONSTRAINT CK_Usuario_Vo2Max      CHECK (Vo2MaxMlKgMin BETWEEN 10 AND 90),
    FcMaxLpm      SMALLINT     NULL CONSTRAINT CK_Usuario_FcMax       CHECK (FcMaxLpm BETWEEN 100 AND 230);

ALTER TABLE gym.Actividad ADD
    CoberturaFcPct DECIMAL(5,1) NULL;  -- % del tiempo en movimiento estimado por FC
GO

-- El CHECK original de FuenteKcal no tenía nombre: se localiza y se sustituye
DECLARE @ck SYSNAME = (
    SELECT cc.name
    FROM sys.check_constraints cc
    JOIN sys.columns c ON c.object_id = cc.parent_object_id AND c.column_id = cc.parent_column_id
    WHERE cc.parent_object_id = OBJECT_ID(N'gym.Actividad') AND c.name = N'FuenteKcal');

-- EXEC (...) no admite llamadas a funciones como QUOTENAME: se usa sp_executesql
IF @ck IS NOT NULL
BEGIN
    DECLARE @Sql NVARCHAR(400) = N'ALTER TABLE gym.Actividad DROP CONSTRAINT ' + QUOTENAME(@ck) + N';';
    EXEC sys.sp_executesql @Sql;
END

ALTER TABLE gym.Actividad ADD CONSTRAINT CK_Actividad_FuenteKcal
    CHECK (FuenteKcal IN ('DISPOSITIVO','FC','ACSM','MET'));
GO

/* ---------- 2. Actualizar datos fisiológicos ----------
   Parámetros NULL = sin cambios.
   VO2máx y FC máxima son datos de salud: requieren consentimiento SALUD.
*/
CREATE OR ALTER PROCEDURE gym.usp_ActualizarDatosFisiologicos
    @UsuarioId       INT,
    @PesoCorporalKg  DECIMAL(5,2) = NULL,
    @FechaNacimiento DATE         = NULL,
    @SexoCalculo     CHAR(1)      = NULL,
    @Vo2MaxMlKgMin   DECIMAL(4,1) = NULL,
    @FcMaxLpm        SMALLINT     = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM gym.Usuario WHERE UsuarioId = @UsuarioId)
        THROW 50001, N'El usuario no existe.', 1;
    IF @PesoCorporalKg IS NOT NULL AND @PesoCorporalKg NOT BETWEEN 20 AND 400
        THROW 50080, N'Peso fuera de rango (20-400 kg).', 1;
    IF @FechaNacimiento IS NOT NULL AND DATEADD(YEAR, 14, @FechaNacimiento) > CAST(SYSUTCDATETIME() AS DATE)
        THROW 50057, N'La edad mínima para registrarse es de 14 años.', 1;
    IF @SexoCalculo IS NOT NULL AND @SexoCalculo NOT IN ('H','M')
        THROW 50081, N'SexoCalculo debe ser H (hombre) o M (mujer).', 1;
    IF @Vo2MaxMlKgMin IS NOT NULL AND @Vo2MaxMlKgMin NOT BETWEEN 10 AND 90
        THROW 50082, N'VO2máx fuera de rango (10-90 ml/kg/min).', 1;
    IF @FcMaxLpm IS NOT NULL AND @FcMaxLpm NOT BETWEEN 100 AND 230
        THROW 50083, N'FC máxima fuera de rango (100-230 lpm).', 1;
    IF (@Vo2MaxMlKgMin IS NOT NULL OR @FcMaxLpm IS NOT NULL)
       AND NOT EXISTS (SELECT 1 FROM gym.fn_ConsentimientoVigente(@UsuarioId, 'SALUD') WHERE Otorgado = 1)
        THROW 50084, N'Para guardar VO2máx o FC máxima necesitas dar tu consentimiento para datos de salud.', 1;

    UPDATE gym.Usuario
    SET PesoCorporalKg  = COALESCE(@PesoCorporalKg,  PesoCorporalKg),
        FechaNacimiento = COALESCE(@FechaNacimiento, FechaNacimiento),
        SexoCalculo     = COALESCE(@SexoCalculo,     SexoCalculo),
        Vo2MaxMlKgMin   = COALESCE(@Vo2MaxMlKgMin,   Vo2MaxMlKgMin),
        FcMaxLpm        = COALESCE(@FcMaxLpm,        FcMaxLpm)
    WHERE UsuarioId = @UsuarioId;
END;
GO

/* ---------- 3. Consentimientos: al retirar SALUD también se borran VO2máx y FC máxima ---------- */
CREATE OR ALTER PROCEDURE gym.usp_RegistrarConsentimiento
    @UsuarioId    INT,
    @Tipo         VARCHAR(20),
    @Otorgado     BIT,
    @VersionTexto VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM gym.Usuario WHERE UsuarioId = @UsuarioId)
        THROW 50001, N'El usuario no existe.', 1;
    IF @Tipo NOT IN ('UBICACION','SALUD')
        THROW 50060, N'Tipo de consentimiento no válido.', 1;
    IF NULLIF(LTRIM(RTRIM(@VersionTexto)), '') IS NULL OR @Otorgado IS NULL
        THROW 50061, N'Indica la decisión y la versión del texto informativo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO gym.Consentimiento (UsuarioId, Tipo, Otorgado, VersionTexto)
        VALUES (@UsuarioId, @Tipo, @Otorgado, @VersionTexto);

        IF @Otorgado = 0 AND @Tipo = 'UBICACION'
        BEGIN
            DELETE p FROM gym.ActividadPunto p
            JOIN gym.Actividad a ON a.ActividadId = p.ActividadId
            WHERE a.UsuarioId = @UsuarioId;

            UPDATE gym.Actividad
            SET Ruta = NULL, RutaPublica = NULL, PuntosPurgados = 1
            WHERE UsuarioId = @UsuarioId;

            DELETE FROM gym.ZonaPrivada WHERE UsuarioId = @UsuarioId;
        END

        IF @Otorgado = 0 AND @Tipo = 'SALUD'
        BEGIN
            UPDATE p SET FcLpm = NULL
            FROM gym.ActividadPunto p
            JOIN gym.Actividad a ON a.ActividadId = p.ActividadId
            WHERE a.UsuarioId = @UsuarioId AND p.FcLpm IS NOT NULL;

            UPDATE gym.Actividad SET FcMedia = NULL, FcMax = NULL WHERE UsuarioId = @UsuarioId;

            UPDATE ap SET FcMedia = NULL
            FROM gym.ActividadParcial ap
            JOIN gym.Actividad a ON a.ActividadId = ap.ActividadId
            WHERE a.UsuarioId = @UsuarioId;

            UPDATE gym.Usuario SET Vo2MaxMlKgMin = NULL, FcMaxLpm = NULL WHERE UsuarioId = @UsuarioId;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ---------- 4. Consulta de actividad con cobertura de FC ---------- */
CREATE OR ALTER PROCEDURE gym.usp_ObtenerActividad
    @UsuarioId   INT,
    @ActividadId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM gym.Actividad WHERE ActividadId = @ActividadId AND UsuarioId = @UsuarioId)
        THROW 50065, N'La actividad no existe o no pertenece al usuario.', 1;

    SELECT a.ActividadId, t.Nombre AS Tipo, a.Origen, a.Estado, a.FechaInicio, a.FechaFin,
           a.DistanciaM,
           a.DuracionTotalSeg, gym.fn_TiempoTxt(a.DuracionTotalSeg) AS DuracionTotalTxt,
           a.DuracionMovSeg,   gym.fn_TiempoTxt(a.DuracionMovSeg)   AS DuracionMovTxt,
           a.RitmoMedioSegKm,  gym.fn_TiempoTxt(a.RitmoMedioSegKm)  AS RitmoMedioTxt,
           a.VelocidadMediaKmh, a.DesnivelPosM, a.DesnivelNegM,
           a.FcMedia, a.FcMax, a.Kcal, a.FuenteKcal, a.CoberturaFcPct,
           a.Ruta.STAsText()        AS RutaWkt,
           a.RutaPublica.STAsText() AS RutaPublicaWkt
    FROM gym.Actividad a
    JOIN gym.TipoActividad t ON t.TipoActividadId = a.TipoActividadId
    WHERE a.ActividadId = @ActividadId;

    SELECT Km, DistanciaM,
           DuracionSeg, gym.fn_TiempoTxt(CAST(ROUND(DuracionSeg, 0) AS INT)) AS DuracionTxt,
           RitmoSegKm,  gym.fn_TiempoTxt(RitmoSegKm) AS RitmoTxt,
           DesnivelPosM, DesnivelNegM, FcMedia, Kcal
    FROM gym.ActividadParcial
    WHERE ActividadId = @ActividadId
    ORDER BY Km;
END;
GO

/* ---------- 5. Finalizar actividad con kcal por FC ----------
   Prioridad de kcal:
     1. Dato del reloj (@KcalDispositivo).
     2. Mixto por parcial: tramos con FC válida -> Keytel;
        resto del tiempo en movimiento -> ACSM (carrera/caminata) o MET.
        FuenteKcal = 'FC' si la FC cubre al menos el 50 % del tiempo
        en movimiento (ver CoberturaFcPct); si no, 'ACSM' o 'MET'.
   El resto del procesamiento es igual que en el script 09.
*/
CREATE OR ALTER PROCEDURE gym.usp_FinalizarActividad
    @UsuarioId       INT,
    @ActividadId     BIGINT,
    @KcalDispositivo INT          = NULL,
    @PrecisionMaxM   DECIMAL(6,1) = 30
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Ecuacion CHAR(1), @Met DECIMAL(4,1), @VelMin DECIMAL(4,2), @VelMax DECIMAL(5,2),
            @Peso DECIMAL(5,2), @Sexo CHAR(1), @Vo2Max DECIMAL(4,1), @FcMaxUsuario SMALLINT, @FechaNac DATE;

    SELECT @Ecuacion = t.Ecuacion, @Met = t.MetReferencia,
           @VelMin = t.VelMinMovMs, @VelMax = t.VelMaxMs,
           @Peso = u.PesoCorporalKg, @Sexo = u.SexoCalculo, @Vo2Max = u.Vo2MaxMlKgMin,
           @FcMaxUsuario = u.FcMaxLpm, @FechaNac = u.FechaNacimiento
    FROM gym.Actividad a
    JOIN gym.TipoActividad t ON t.TipoActividadId = a.TipoActividadId
    JOIN gym.Usuario u       ON u.UsuarioId = a.UsuarioId
    WHERE a.ActividadId = @ActividadId AND a.UsuarioId = @UsuarioId AND a.Estado = 'C';

    IF @Ecuacion IS NULL
        THROW 50063, N'La actividad no existe, no pertenece al usuario o ya está finalizada.', 1;
    IF @KcalDispositivo IS NOT NULL AND @KcalDispositivo NOT BETWEEN 0 AND 20000
        THROW 50066, N'Kcal del dispositivo fuera de rango (0-20000).', 1;

    /* Parámetros para la FC */
    DECLARE @Hoy DATE = CAST(SYSUTCDATETIME() AS DATE);
    DECLARE @Edad INT = CASE WHEN @FechaNac IS NULL THEN NULL
                             ELSE DATEDIFF(YEAR, @FechaNac, @Hoy)
                                  - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, @FechaNac, @Hoy), @FechaNac) > @Hoy THEN 1 ELSE 0 END
                        END;
    DECLARE @FcMaxEst FLOAT = COALESCE(@FcMaxUsuario, 208 - 0.7 * @Edad);  -- Tanaka et al. (2001)
    DECLARE @UsaFc BIT = CASE
        WHEN @Peso IS NOT NULL AND @Sexo IS NOT NULL AND @Edad IS NOT NULL AND @FcMaxEst IS NOT NULL
         AND EXISTS (SELECT 1 FROM gym.fn_ConsentimientoVigente(@UsuarioId, 'SALUD') WHERE Otorgado = 1)
        THEN 1 ELSE 0 END;

    /* 1. Puntos con precisión suficiente */
    SELECT Secuencia, Instante, Lat, Lon, AltitudM, FcLpm
    INTO #P
    FROM gym.ActividadPunto
    WHERE ActividadId = @ActividadId
      AND (PrecisionM IS NULL OR PrecisionM <= @PrecisionMaxM);

    /* 2. Saltos aislados
       COALESCE en los puntos vecinos: SQL Server no garantiza el orden de
       evaluación de las condiciones del WHERE, y geography::Point no admite
       NULL (error 6569). Con el propio punto, la distancia es 0 y no se borra. */
    WITH v AS (
        SELECT Secuencia, Lat, Lon, Instante,
               LAG(Lat)       OVER (ORDER BY Secuencia) AS LatAnt,
               LAG(Lon)       OVER (ORDER BY Secuencia) AS LonAnt,
               LAG(Instante)  OVER (ORDER BY Secuencia) AS InstAnt,
               LEAD(Lat)      OVER (ORDER BY Secuencia) AS LatSig,
               LEAD(Lon)      OVER (ORDER BY Secuencia) AS LonSig,
               LEAD(Instante) OVER (ORDER BY Secuencia) AS InstSig
        FROM #P
    )
    DELETE p
    FROM #P p
    JOIN v ON v.Secuencia = p.Secuencia
    WHERE v.LatAnt IS NOT NULL AND v.LatSig IS NOT NULL
      AND geography::Point(v.Lat, v.Lon, 4326).STDistance(geography::Point(COALESCE(v.LatAnt, v.Lat), COALESCE(v.LonAnt, v.Lon), 4326)) * 1000.0
          / NULLIF(DATEDIFF_BIG(MILLISECOND, v.InstAnt, v.Instante), 0) > @VelMax
      AND geography::Point(v.Lat, v.Lon, 4326).STDistance(geography::Point(COALESCE(v.LatSig, v.Lat), COALESCE(v.LonSig, v.Lon), 4326)) * 1000.0
          / NULLIF(DATEDIFF_BIG(MILLISECOND, v.Instante, v.InstSig), 0) > @VelMax;

    /* 3. Tramos con acumulados y kcal por FC */
    SELECT s.Secuencia, s.Instante, s.FcLpm, s.DAlt, m.DistMov, m.DtMov,
           CASE WHEN k.KcalMin > 0 THEN k.KcalMin * m.DtMov / 60.0 ELSE 0 END AS KcalFc,
           CASE WHEN f.FcValida = 1 THEN m.DtMov ELSE 0 END AS DtFc,
           SUM(m.DistMov) OVER (ORDER BY s.Secuencia ROWS UNBOUNDED PRECEDING) AS DistAcum,
           SUM(m.DtMov)   OVER (ORDER BY s.Secuencia ROWS UNBOUNDED PRECEDING) AS TAcum
    INTO #S
    FROM (
        SELECT y.Secuencia, y.Instante, y.FcLpm,
               y.AltSuav - LAG(y.AltSuav) OVER (ORDER BY y.Secuencia) AS DAlt,
               CASE WHEN y.LatAnt IS NULL THEN 0
                    ELSE geography::Point(y.Lat, y.Lon, 4326).STDistance(geography::Point(COALESCE(y.LatAnt, y.Lat), COALESCE(y.LonAnt, y.Lon), 4326)) END AS Dist,
               DATEDIFF_BIG(MILLISECOND, y.InstAnt, y.Instante) / 1000.0 AS Dt
        FROM (
            SELECT p.*,
                   LAG(p.Lat)      OVER (ORDER BY p.Secuencia) AS LatAnt,
                   LAG(p.Lon)      OVER (ORDER BY p.Secuencia) AS LonAnt,
                   LAG(p.Instante) OVER (ORDER BY p.Secuencia) AS InstAnt,
                   AVG(p.AltitudM) OVER (ORDER BY p.Secuencia ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) AS AltSuav
            FROM #P p
        ) y
    ) s
    CROSS APPLY (
        SELECT CASE WHEN s.Dt > 0 AND s.Dist / s.Dt >= @VelMin THEN s.Dist ELSE 0 END AS DistMov,
               CASE WHEN s.Dt > 0 AND s.Dist / s.Dt >= @VelMin THEN s.Dt   ELSE 0 END AS DtMov
    ) m
    CROSS APPLY (
        -- FC válida: en movimiento y entre el 57 % y el 90 % de la FC máxima
        SELECT CASE WHEN @UsaFc = 1 AND m.DtMov > 0
                     AND s.FcLpm BETWEEN 0.57 * @FcMaxEst AND 0.90 * @FcMaxEst
                    THEN 1 ELSE 0 END AS FcValida
    ) f
    CROSS APPLY (
        SELECT CASE WHEN f.FcValida = 0 THEN NULL
                    WHEN @Vo2Max IS NOT NULL AND @Sexo = 'H'
                        THEN -95.7735 + 0.634 * s.FcLpm + 0.404 * @Vo2Max + 0.394 * @Peso + 0.271 * @Edad
                    WHEN @Vo2Max IS NOT NULL AND @Sexo = 'M'
                        THEN -59.3954 + 0.450 * s.FcLpm + 0.380 * @Vo2Max + 0.103 * @Peso + 0.274 * @Edad
                    WHEN @Sexo = 'H'
                        THEN -55.0969 + 0.6309 * s.FcLpm + 0.1988 * @Peso + 0.2017 * @Edad
                    ELSE     -20.4022 + 0.4472 * s.FcLpm - 0.1263 * @Peso + 0.0740 * @Edad
               END / 4.184 AS KcalMin  -- kJ/min -> kcal/min
    ) k;

    /* 4. Totales */
    DECLARE @DistTotal FLOAT, @TMov FLOAT, @TFc FLOAT, @DesPos FLOAT, @DesNeg FLOAT,
            @DurTotal INT, @FcMedia INT, @FcMax INT;

    SELECT @DistTotal = COALESCE(MAX(DistAcum), 0),
           @TMov      = COALESCE(MAX(TAcum), 0),
           @TFc       = COALESCE(SUM(DtFc), 0),
           @DesPos    = SUM(CASE WHEN DistMov > 0 AND DAlt > 0 THEN DAlt ELSE 0 END),
           @DesNeg    = SUM(CASE WHEN DistMov > 0 AND DAlt < 0 THEN -DAlt ELSE 0 END)
    FROM #S;

    SELECT @DurTotal = DATEDIFF(SECOND, MIN(Instante), MAX(Instante)),
           @FcMedia  = AVG(CAST(FcLpm AS INT)),
           @FcMax    = MAX(FcLpm)
    FROM #P;

    DECLARE @CobFc FLOAT = CASE WHEN @TMov > 0 THEN 100.0 * @TFc / @TMov END;

    /* 5. Cortes por km */
    DECLARE @Km INT = FLOOR(@DistTotal / 1000.0);

    CREATE TABLE #Corte (Km INT PRIMARY KEY, T FLOAT NOT NULL);
    INSERT INTO #Corte (Km, T) VALUES (0, 0);

    INSERT INTO #Corte (Km, T)
    SELECT n.k, c.TCruce
    FROM (SELECT TOP (@Km) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS k
          FROM sys.all_objects a CROSS JOIN sys.all_objects b) n
    CROSS APPLY (
        SELECT TOP (1)
               (s.TAcum - s.DtMov) + (n.k * 1000.0 - (s.DistAcum - s.DistMov)) / s.DistMov * s.DtMov AS TCruce
        FROM #S s
        WHERE s.DistMov > 0 AND s.DistAcum >= n.k * 1000.0
        ORDER BY s.Secuencia
    ) c;

    IF @DistTotal - @Km * 1000.0 >= 10
        INSERT INTO #Corte (Km, T) VALUES (@Km + 1, @TMov);

    /* 6. Parciales */
    SELECT CASE WHEN DistAcum <= 0 THEN 1 ELSE CAST(CEILING(DistAcum / 1000.0) AS INT) END AS Km,
           SUM(CASE WHEN DistMov > 0 AND DAlt > 0 THEN DAlt ELSE 0 END)  AS DesPos,
           SUM(CASE WHEN DistMov > 0 AND DAlt < 0 THEN -DAlt ELSE 0 END) AS DesNeg,
           AVG(CAST(FcLpm AS INT)) AS FcMedia,
           SUM(KcalFc) AS KcalFc,
           SUM(DtFc)   AS TFc
    INTO #PorKm
    FROM #S
    GROUP BY CASE WHEN DistAcum <= 0 THEN 1 ELSE CAST(CEILING(DistAcum / 1000.0) AS INT) END;

    SELECT p.Km, p.DistanciaM, p.DuracionSeg,
           CAST(ROUND(p.DuracionSeg / (p.DistanciaM / 1000.0), 0) AS INT) AS RitmoSegKm,
           k.DesPos, k.DesNeg, k.FcMedia,
           CASE WHEN @Peso IS NULL THEN NULL
                ELSE COALESCE(k.KcalFc, 0)
                     + CASE WHEN p.DuracionSeg - COALESCE(k.TFc, 0) > 0
                            THEN (p.DuracionSeg - COALESCE(k.TFc, 0)) * r.KcalSeg
                            ELSE 0 END
           END AS Kcal
    INTO #Parcial
    FROM (
        SELECT c.Km,
               CASE WHEN c.Km <= @Km THEN 1000.0 ELSE @DistTotal - @Km * 1000.0 END AS DistanciaM,
               c.T - LAG(c.T) OVER (ORDER BY c.Km) AS DuracionSeg
        FROM #Corte c
    ) p
    LEFT JOIN #PorKm k ON k.Km = p.Km
    CROSS APPLY (
        SELECT p.DistanciaM / NULLIF(p.DuracionSeg / 60.0, 0) AS V,  -- m/min
               (COALESCE(k.DesPos, 0) - COALESCE(k.DesNeg, 0)) / p.DistanciaM AS PendRaw
    ) a
    CROSS APPLY (
        SELECT CASE WHEN a.PendRaw < 0 THEN 0 WHEN a.PendRaw > 0.15 THEN 0.15 ELSE a.PendRaw END AS Pend
    ) g
    CROSS APPLY (
        SELECT CASE @Ecuacion
                   WHEN 'C' THEN 0.2 * a.V + 0.9 * a.V * g.Pend + 3.5
                   WHEN 'A' THEN 0.1 * a.V + 1.8 * a.V * g.Pend + 3.5
               END AS Vo2Acsm
    ) e
    CROSS APPLY (
        -- Respaldo (kcal por segundo en movimiento) para el tiempo sin FC válida
        SELECT CASE WHEN @Ecuacion = 'M' THEN @Met * @Peso / 3600.0
                    ELSE e.Vo2Acsm * @Peso / 1000.0 * 5.0 / 60.0 END AS KcalSeg
    ) r
    WHERE p.Km > 0 AND p.DuracionSeg > 0;

    DECLARE @Kcal INT, @FuenteKcal VARCHAR(12);

    IF @KcalDispositivo IS NOT NULL
        SELECT @Kcal = @KcalDispositivo, @FuenteKcal = 'DISPOSITIVO';
    ELSE IF @Peso IS NOT NULL AND EXISTS (SELECT 1 FROM #Parcial)
        SELECT @Kcal = CAST(ROUND(SUM(Kcal), 0) AS INT),
               @FuenteKcal = CASE WHEN @CobFc >= 50 THEN 'FC'
                                  WHEN @Ecuacion = 'M' THEN 'MET'
                                  ELSE 'ACSM' END
        FROM #Parcial;

    /* 7. Ruta y ruta pública */
    DECLARE @Wkt NVARCHAR(MAX), @NPuntos INT, @Ruta geography, @RutaPublica geography;

    SELECT @Wkt = STRING_AGG(CAST(LTRIM(STR(Lon, 12, 7)) + ' ' + LTRIM(STR(Lat, 12, 7)) AS NVARCHAR(MAX)), N',')
                  WITHIN GROUP (ORDER BY Secuencia),
           @NPuntos = COUNT(*)
    FROM (
        SELECT Secuencia, Lat, Lon,
               LAG(Lat) OVER (ORDER BY Secuencia) AS LatAnt,
               LAG(Lon) OVER (ORDER BY Secuencia) AS LonAnt
        FROM #P
    ) x
    WHERE LatAnt IS NULL OR Lat <> LatAnt OR Lon <> LonAnt;

    IF @NPuntos >= 2
    BEGIN
        SET @Ruta = geography::STGeomFromText(N'LINESTRING(' + @Wkt + N')', 4326).MakeValid();

        DECLARE @Zonas geography = (
            SELECT geography::UnionAggregate(Centro.STBuffer(RadioM))
            FROM gym.ZonaPrivada WHERE UsuarioId = @UsuarioId);

        SET @RutaPublica = CASE WHEN @Zonas IS NULL THEN @Ruta ELSE @Ruta.STDifference(@Zonas) END;
    END

    /* 8. Guardar */
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE gym.Actividad
        SET Estado            = 'F',
            FechaFin          = SYSUTCDATETIME(),
            DistanciaM        = ROUND(@DistTotal, 1),
            DuracionTotalSeg  = @DurTotal,
            DuracionMovSeg    = CAST(ROUND(@TMov, 0) AS INT),
            RitmoMedioSegKm   = CASE WHEN @DistTotal >= 10 THEN CAST(ROUND(@TMov / (@DistTotal / 1000.0), 0) AS INT) END,
            VelocidadMediaKmh = CASE WHEN @TMov > 0 THEN ROUND((@DistTotal / 1000.0) / (@TMov / 3600.0), 2) END,
            DesnivelPosM      = ROUND(@DesPos, 1),
            DesnivelNegM      = ROUND(@DesNeg, 1),
            FcMedia           = @FcMedia,
            FcMax             = @FcMax,
            Kcal              = @Kcal,
            FuenteKcal        = @FuenteKcal,
            CoberturaFcPct    = ROUND(@CobFc, 1),
            Ruta              = @Ruta,
            RutaPublica       = @RutaPublica
        WHERE ActividadId = @ActividadId;

        INSERT INTO gym.ActividadParcial
            (ActividadId, Km, DistanciaM, DuracionSeg, RitmoSegKm, DesnivelPosM, DesnivelNegM, FcMedia, Kcal)
        SELECT @ActividadId, Km, ROUND(DistanciaM, 1), ROUND(DuracionSeg, 1), RitmoSegKm,
               ROUND(DesPos, 1), ROUND(DesNeg, 1), FcMedia, ROUND(Kcal, 1)
        FROM #Parcial;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    EXEC gym.usp_ObtenerActividad @UsuarioId = @UsuarioId, @ActividadId = @ActividadId;
END;
GO

/* ---------- 6. Prueba ----------
   Misma carrera sintética que en 09 (FC 150-159 lpm), con perfil:
   70 kg, 36 años, hombre, sin VO2máx -> FC máx. estimada ≈ 183 lpm;
   rango válido ≈ 104-164 lpm, así que toda la FC en movimiento es válida.
   Resultado esperado: FuenteKcal = 'FC', CoberturaFcPct = 100,
   kcal ≈ 175 (unos 15 kcal/min durante ~11,5 min en movimiento).
   Con sexo = mujer, el mismo registro daría ≈ 115-120 kcal.
*/
DECLARE @U INT = (SELECT UsuarioId FROM gym.Usuario WHERE Email = N'prueba@ejemplo.com'),
        @Act BIGINT,
        @T0 DATETIME2(0) = '2026-09-28T08:00:00',
        @Lat0 FLOAT = 40.4153, @Lon0 FLOAT = -3.6845;

EXEC gym.usp_ActualizarDatosFisiologicos
     @UsuarioId = @U, @PesoCorporalKg = 70, @FechaNacimiento = '1990-05-10', @SexoCalculo = 'H';

EXEC gym.usp_IniciarActividad @UsuarioId = @U, @TipoActividadId = 1, @ActividadId = @Act OUTPUT;

WITH n AS (
    SELECT TOP (720) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS i
    FROM sys.all_objects
),
d AS (
    SELECT i,
           CASE WHEN i <= 300 THEN 3.3 * i
                WHEN i < 330  THEN 990.0
                ELSE 990.0 + 3.3 * (i - 329) END AS m
    FROM n
)
SELECT i + 1 AS s,
       CONVERT(VARCHAR(19), DATEADD(SECOND, i, @T0), 126) + 'Z' AS t,
       @Lat0 + m / 111035.0 AS lat,
       @Lon0 AS lon,
       CAST(650 + 10 * SIN(i / 100.0) AS DECIMAL(7,1)) AS alt,
       5.0 AS acc,
       150 + i % 10 AS fc
INTO #Gen
FROM d;

DECLARE @Lote NVARCHAR(MAX) = (SELECT s, t, lat, lon, alt, acc, fc FROM #Gen ORDER BY s FOR JSON PATH);

EXEC gym.usp_RegistrarPuntos @UsuarioId = @U, @ActividadId = @Act, @PuntosJson = @Lote;
EXEC gym.usp_FinalizarActividad @UsuarioId = @U, @ActividadId = @Act;

DROP TABLE #Gen;
GO
