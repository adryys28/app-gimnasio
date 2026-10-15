USE App_Gym;
GO

/* =========================================================
   09 - Cardio exterior: rutas GPS, parciales por km, kcal y RGPD
   Ejecutar después de 01 a 08.
   Requisitos: SQL Server 2017+ o Azure SQL (STRING_AGG) y
   nivel de compatibilidad >= 130 (OPENJSON).

   Flujo:
     usp_IniciarActividad  -> usp_RegistrarPuntos (por lotes)
                           -> usp_FinalizarActividad -> resumen + parciales
   ========================================================= */

/* ---------- 1. Perfil y consentimientos ---------- */

-- Necesario para estimar kcal cuando el reloj no las aporta
ALTER TABLE gym.Usuario ADD
    PesoCorporalKg DECIMAL(5,2) NULL
        CONSTRAINT CK_Usuario_PesoCorporal CHECK (PesoCorporalKg BETWEEN 20 AND 400);

-- Historial de consentimientos (solo inserciones): permite demostrar
-- qué aceptó cada persona, cuándo y con qué versión del texto (RGPD art. 7.1)
CREATE TABLE gym.Consentimiento (
    ConsentimientoId BIGINT       IDENTITY(1,1) PRIMARY KEY,
    UsuarioId        INT          NOT NULL REFERENCES gym.Usuario(UsuarioId),
    Tipo             VARCHAR(20)  NOT NULL CHECK (Tipo IN ('UBICACION','SALUD')),
    Otorgado         BIT          NOT NULL,
    VersionTexto     VARCHAR(20)  NOT NULL,
    Fecha            DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
CREATE INDEX IX_Consentimiento_Usuario ON gym.Consentimiento(UsuarioId, Tipo, Fecha DESC);

/* ---------- 2. Actividades ---------- */

-- Ecuacion: C = carrera ACSM, A = andar ACSM, M = MET fijo
-- VelMinMovMs: por debajo, el tramo cuenta como parado (pausa automática)
-- VelMaxMs: por encima, un punto aislado se considera salto de GPS
CREATE TABLE gym.TipoActividad (
    TipoActividadId TINYINT      NOT NULL PRIMARY KEY,
    Nombre          NVARCHAR(50) NOT NULL UNIQUE,
    Exterior        BIT          NOT NULL,
    Ecuacion        CHAR(1)      NOT NULL CHECK (Ecuacion IN ('C','A','M')),
    MetReferencia   DECIMAL(4,1) NULL,
    VelMinMovMs     DECIMAL(4,2) NOT NULL,
    VelMaxMs        DECIMAL(5,2) NOT NULL,
    CONSTRAINT CK_TipoActividad_Met CHECK (Ecuacion <> 'M' OR MetReferencia IS NOT NULL)
);

CREATE TABLE gym.Actividad (
    ActividadId       BIGINT        IDENTITY(1,1) PRIMARY KEY,
    UsuarioId         INT           NOT NULL REFERENCES gym.Usuario(UsuarioId),
    TipoActividadId   TINYINT       NOT NULL REFERENCES gym.TipoActividad(TipoActividadId),
    Origen            VARCHAR(15)   NOT NULL CHECK (Origen IN ('MOVIL','APPLE_WATCH','WEAR_OS','GARMIN','IMPORTADA')),
    Estado            CHAR(1)       NOT NULL DEFAULT 'C' CHECK (Estado IN ('C','F')), -- C = en curso, F = finalizada
    FechaInicio       DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
    FechaFin          DATETIME2(0)  NULL,
    DistanciaM        DECIMAL(9,1)  NULL,
    DuracionTotalSeg  INT           NULL,
    DuracionMovSeg    INT           NULL,
    RitmoMedioSegKm   INT           NULL,
    VelocidadMediaKmh DECIMAL(5,2)  NULL,
    DesnivelPosM      DECIMAL(7,1)  NULL,
    DesnivelNegM      DECIMAL(7,1)  NULL,
    FcMedia           SMALLINT      NULL,
    FcMax             SMALLINT      NULL,
    Kcal              INT           NULL,
    FuenteKcal        VARCHAR(12)   NULL CHECK (FuenteKcal IN ('DISPOSITIVO','ACSM','MET')),
    Ruta              geography     NULL,  -- ruta completa: solo la ve su titular
    RutaPublica       geography     NULL,  -- sin los tramos dentro de zonas privadas
    PuntosPurgados    BIT           NOT NULL DEFAULT 0
);
CREATE INDEX IX_Actividad_Usuario ON gym.Actividad(UsuarioId, FechaInicio DESC);

CREATE TABLE gym.ActividadPunto (
    ActividadId BIGINT       NOT NULL REFERENCES gym.Actividad(ActividadId) ON DELETE CASCADE,
    Secuencia   INT          NOT NULL,
    Instante    DATETIME2(3) NOT NULL,  -- UTC
    Lat         FLOAT        NOT NULL CHECK (Lat BETWEEN -90 AND 90),
    Lon         FLOAT        NOT NULL CHECK (Lon BETWEEN -180 AND 180),
    AltitudM    DECIMAL(7,1) NULL,
    PrecisionM  DECIMAL(6,1) NULL,
    FcLpm       SMALLINT     NULL CHECK (FcLpm BETWEEN 25 AND 250),
    PRIMARY KEY (ActividadId, Secuencia)
);

CREATE TABLE gym.ActividadParcial (
    ActividadId  BIGINT       NOT NULL REFERENCES gym.Actividad(ActividadId) ON DELETE CASCADE,
    Km           SMALLINT     NOT NULL,
    DistanciaM   DECIMAL(7,1) NOT NULL,  -- 1000 salvo el último tramo
    DuracionSeg  DECIMAL(8,1) NOT NULL,  -- tiempo exacto entre km y km (en movimiento)
    RitmoSegKm   INT          NULL,
    DesnivelPosM DECIMAL(7,1) NULL,
    DesnivelNegM DECIMAL(7,1) NULL,
    FcMedia      SMALLINT     NULL,
    Kcal         DECIMAL(7,1) NULL,
    PRIMARY KEY (ActividadId, Km)
);

-- Zonas cuyo trazado se oculta en la ruta pública (p. ej. alrededor de casa)
CREATE TABLE gym.ZonaPrivada (
    ZonaPrivadaId INT          IDENTITY(1,1) PRIMARY KEY,
    UsuarioId     INT          NOT NULL REFERENCES gym.Usuario(UsuarioId),
    Nombre        NVARCHAR(50) NOT NULL,
    Centro        geography    NOT NULL,
    RadioM        SMALLINT     NOT NULL CHECK (RadioM BETWEEN 100 AND 1000)
);
CREATE INDEX IX_ZonaPrivada_Usuario ON gym.ZonaPrivada(UsuarioId);

/* ---------- 3. Catálogo de actividades ----------
   MET de referencia: Compendium of Physical Activities (Ainsworth et al., 2011):
   ciclismo general 7,5; senderismo campo a través 6,0. Conviene contrastarlos
   con la actualización de 2024 del Compendium antes de producción.
   Umbrales de velocidad: valores de diseño, ajustables.
*/
INSERT INTO gym.TipoActividad (TipoActividadId, Nombre, Exterior, Ecuacion, MetReferencia, VelMinMovMs, VelMaxMs) VALUES
(1, N'Carrera',    1, 'C', NULL, 1.00,  8.00),
(2, N'Caminata',   1, 'A', NULL, 0.40,  3.00),
(3, N'Ciclismo',   1, 'M', 7.5,  1.00, 25.00),
(4, N'Senderismo', 1, 'M', 6.0,  0.30,  3.00);
GO

/* ---------- 4. Funciones auxiliares ---------- */

CREATE OR ALTER FUNCTION gym.fn_ConsentimientoVigente (@UsuarioId INT, @Tipo VARCHAR(20))
RETURNS TABLE
AS
RETURN
    SELECT TOP (1) Otorgado
    FROM gym.Consentimiento
    WHERE UsuarioId = @UsuarioId AND Tipo = @Tipo
    ORDER BY Fecha DESC, ConsentimientoId DESC;
GO

-- Segundos -> "m:ss" o "h:mm:ss"
CREATE OR ALTER FUNCTION gym.fn_TiempoTxt (@Seg INT)
RETURNS VARCHAR(12)
WITH SCHEMABINDING
AS
BEGIN
    RETURN CASE
        WHEN @Seg IS NULL THEN NULL
        WHEN @Seg >= 3600 THEN CONCAT(@Seg / 3600, ':', RIGHT(CONCAT('0', (@Seg / 60) % 60), 2), ':', RIGHT(CONCAT('0', @Seg % 60), 2))
        ELSE CONCAT(@Seg / 60, ':', RIGHT(CONCAT('0', @Seg % 60), 2))
    END;
END;
GO

/* ---------- 5. Consentimientos ----------
   Al retirar un consentimiento se borran los datos que dependían de él
   (RGPD art. 17.1.b). Decisión de diseño a validar con la persona DPD:
     UBICACION -> se borran puntos y rutas; se conservan distancia y tiempos.
     SALUD     -> se borra la frecuencia cardiaca.
*/
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
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ---------- 6. Zonas privadas ---------- */

CREATE OR ALTER PROCEDURE gym.usp_RecalcularRutasPublicas
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Zonas geography = (
        SELECT geography::UnionAggregate(Centro.STBuffer(RadioM))
        FROM gym.ZonaPrivada
        WHERE UsuarioId = @UsuarioId);

    UPDATE gym.Actividad
    SET RutaPublica = CASE WHEN @Zonas IS NULL THEN Ruta ELSE Ruta.STDifference(@Zonas) END
    WHERE UsuarioId = @UsuarioId AND Ruta IS NOT NULL;
END;
GO

CREATE OR ALTER PROCEDURE gym.usp_GuardarZonaPrivada
    @UsuarioId     INT,
    @Nombre        NVARCHAR(100),
    @Lat           FLOAT,
    @Lon           FLOAT,
    @RadioM        SMALLINT = 200,
    @ZonaPrivadaId INT      = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), N'');

    IF NOT EXISTS (SELECT 1 FROM gym.Usuario WHERE UsuarioId = @UsuarioId)
        THROW 50001, N'El usuario no existe.', 1;
    IF @Nombre IS NULL OR LEN(@Nombre) > 50
        THROW 50067, N'Indica un nombre de 1 a 50 caracteres.', 1;
    IF @Lat IS NULL OR @Lon IS NULL OR @Lat NOT BETWEEN -90 AND 90 OR @Lon NOT BETWEEN -180 AND 180
        THROW 50068, N'Coordenadas no válidas.', 1;
    IF @RadioM NOT BETWEEN 100 AND 1000
        THROW 50069, N'El radio debe estar entre 100 y 1000 m.', 1;
    IF (SELECT COUNT(*) FROM gym.ZonaPrivada WHERE UsuarioId = @UsuarioId) >= 5
        THROW 50070, N'Se admite un máximo de 5 zonas privadas.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO gym.ZonaPrivada (UsuarioId, Nombre, Centro, RadioM)
        VALUES (@UsuarioId, @Nombre, geography::Point(@Lat, @Lon, 4326), @RadioM);

        SET @ZonaPrivadaId = SCOPE_IDENTITY();

        -- Se aplica también a las actividades ya registradas
        EXEC gym.usp_RecalcularRutasPublicas @UsuarioId = @UsuarioId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE gym.usp_QuitarZonaPrivada
    @UsuarioId     INT,
    @ZonaPrivadaId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM gym.ZonaPrivada WHERE ZonaPrivadaId = @ZonaPrivadaId AND UsuarioId = @UsuarioId;
        IF @@ROWCOUNT = 0
            THROW 50071, N'La zona no existe o no pertenece al usuario.', 1;

        EXEC gym.usp_RecalcularRutasPublicas @UsuarioId = @UsuarioId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ---------- 7. Iniciar actividad ---------- */

CREATE OR ALTER PROCEDURE gym.usp_IniciarActividad
    @UsuarioId       INT,
    @TipoActividadId TINYINT,
    @Origen          VARCHAR(15) = 'MOVIL',
    @ActividadId     BIGINT      = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Exterior BIT = (SELECT Exterior FROM gym.TipoActividad WHERE TipoActividadId = @TipoActividadId);

    IF NOT EXISTS (SELECT 1 FROM gym.Usuario WHERE UsuarioId = @UsuarioId)
        THROW 50001, N'El usuario no existe.', 1;
    IF @Exterior IS NULL
        THROW 50072, N'El tipo de actividad no existe.', 1;
    IF @Origen NOT IN ('MOVIL','APPLE_WATCH','WEAR_OS','GARMIN','IMPORTADA')
        THROW 50073, N'Origen no válido.', 1;
    IF @Exterior = 1 AND NOT EXISTS (SELECT 1 FROM gym.fn_ConsentimientoVigente(@UsuarioId, 'UBICACION') WHERE Otorgado = 1)
        THROW 50074, N'Para registrar rutas al aire libre necesitas dar tu consentimiento para usar la ubicación.', 1;
    IF EXISTS (SELECT 1 FROM gym.Actividad WHERE UsuarioId = @UsuarioId AND Estado = 'C')
        THROW 50075, N'Ya tienes una actividad en curso.', 1;

    INSERT INTO gym.Actividad (UsuarioId, TipoActividadId, Origen)
    VALUES (@UsuarioId, @TipoActividadId, @Origen);

    SET @ActividadId = SCOPE_IDENTITY();
END;
GO

/* ---------- 8. Registrar puntos por lotes ----------
   JSON: [{"s":1,"t":"2026-09-27T08:00:00.000Z","lat":40.41,"lon":-3.68,"alt":650,"acc":5,"fc":142}, ...]
   s = secuencia (entero creciente), t = instante ISO 8601 con zona horaria.
   Idempotente: si la app reenvía un lote, los puntos ya guardados se ignoran.
   La frecuencia cardiaca solo se guarda con consentimiento SALUD vigente.
   Recomendado: lotes de hasta 500 puntos.
*/
CREATE OR ALTER PROCEDURE gym.usp_RegistrarPuntos
    @UsuarioId   INT,
    @ActividadId BIGINT,
    @PuntosJson  NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM gym.Actividad
                   WHERE ActividadId = @ActividadId AND UsuarioId = @UsuarioId AND Estado = 'C')
        THROW 50063, N'La actividad no existe, no pertenece al usuario o ya está finalizada.', 1;
    IF ISJSON(@PuntosJson) <> 1
        THROW 50064, N'El lote de puntos no es un JSON válido.', 1;

    DECLARE @Salud BIT = CASE WHEN EXISTS (SELECT 1 FROM gym.fn_ConsentimientoVigente(@UsuarioId, 'SALUD') WHERE Otorgado = 1)
                              THEN 1 ELSE 0 END;

    WITH j AS (
        SELECT s, t, lat, lon, alt, acc, fc,
               ROW_NUMBER() OVER (PARTITION BY s ORDER BY (SELECT NULL)) AS rn
        FROM OPENJSON(@PuntosJson) WITH (
            s   INT               '$.s',
            t   DATETIMEOFFSET(3) '$.t',
            lat FLOAT             '$.lat',
            lon FLOAT             '$.lon',
            alt DECIMAL(7,1)      '$.alt',
            acc DECIMAL(6,1)      '$.acc',
            fc  SMALLINT          '$.fc')
    )
    INSERT INTO gym.ActividadPunto (ActividadId, Secuencia, Instante, Lat, Lon, AltitudM, PrecisionM, FcLpm)
    SELECT @ActividadId, j.s,
           CONVERT(DATETIME2(3), SWITCHOFFSET(j.t, '+00:00')),
           j.lat, j.lon, j.alt,
           CASE WHEN j.acc >= 0 THEN j.acc END,
           CASE WHEN @Salud = 1 AND j.fc BETWEEN 25 AND 250 THEN j.fc END
    FROM j
    WHERE j.rn = 1
      AND j.s IS NOT NULL AND j.t IS NOT NULL
      AND j.lat BETWEEN -90 AND 90 AND j.lon BETWEEN -180 AND 180
      AND NOT EXISTS (SELECT 1 FROM gym.ActividadPunto p
                      WHERE p.ActividadId = @ActividadId AND p.Secuencia = j.s);

    SELECT @@ROWCOUNT AS PuntosGuardados;
END;
GO

/* ---------- 9. Consultar actividad (resumen + parciales) ---------- */

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
           a.FcMedia, a.FcMax, a.Kcal, a.FuenteKcal,
           a.Ruta.STAsText()        AS RutaWkt,        -- WKT: "LINESTRING(lon lat, ...)"
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

/* ---------- 10. Finalizar actividad ----------
   1. Descarta puntos con precisión peor que @PrecisionMaxM.
   2. Descarta saltos aislados de GPS (velocidad imposible hacia el punto
      anterior Y hacia el siguiente).
   3. Calcula tramos con distancia geodésica (STDistance sobre WGS84) y
      pausa automática: los tramos por debajo de VelMinMovMs no suman
      distancia ni tiempo en movimiento (evita la deriva del GPS parado).
   4. Parciales por km: el cruce de cada km se interpola dentro del tramo.
   5. Desnivel: altitud suavizada (media móvil de 5 puntos), solo en movimiento.
   6. Kcal (por orden de prioridad):
        - dato del reloj (@KcalDispositivo);
        - carrera y caminata: ecuaciones metabólicas del ACSM
            carrera: VO2 = 0,2·v + 0,9·v·pendiente + 3,5
            andar:   VO2 = 0,1·v + 1,8·v·pendiente + 3,5
          (v en m/min, pendiente 0-15 %; ~5 kcal por litro de O2);
        - resto: MET × kg × horas.
      Todas son estimaciones.
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

    DECLARE @Ecuacion CHAR(1), @Met DECIMAL(4,1), @VelMin DECIMAL(4,2), @VelMax DECIMAL(5,2), @Peso DECIMAL(5,2);

    SELECT @Ecuacion = t.Ecuacion, @Met = t.MetReferencia,
           @VelMin = t.VelMinMovMs, @VelMax = t.VelMaxMs,
           @Peso = u.PesoCorporalKg
    FROM gym.Actividad a
    JOIN gym.TipoActividad t ON t.TipoActividadId = a.TipoActividadId
    JOIN gym.Usuario u       ON u.UsuarioId = a.UsuarioId
    WHERE a.ActividadId = @ActividadId AND a.UsuarioId = @UsuarioId AND a.Estado = 'C';

    IF @Ecuacion IS NULL
        THROW 50063, N'La actividad no existe, no pertenece al usuario o ya está finalizada.', 1;
    IF @KcalDispositivo IS NOT NULL AND @KcalDispositivo NOT BETWEEN 0 AND 20000
        THROW 50066, N'Kcal del dispositivo fuera de rango (0-20000).', 1;

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

    /* 3. Tramos entre puntos consecutivos, con acumulados en movimiento */
    SELECT s.Secuencia, s.Instante, s.FcLpm, s.DAlt, m.DistMov, m.DtMov,
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
    ) m;

    /* 4. Totales */
    DECLARE @DistTotal FLOAT, @TMov FLOAT, @DesPos FLOAT, @DesNeg FLOAT,
            @DurTotal INT, @FcMedia INT, @FcMax INT;

    SELECT @DistTotal = COALESCE(MAX(DistAcum), 0),
           @TMov      = COALESCE(MAX(TAcum), 0),
           @DesPos    = SUM(CASE WHEN DistMov > 0 AND DAlt > 0 THEN DAlt ELSE 0 END),
           @DesNeg    = SUM(CASE WHEN DistMov > 0 AND DAlt < 0 THEN -DAlt ELSE 0 END)
    FROM #S;

    SELECT @DurTotal = DATEDIFF(SECOND, MIN(Instante), MAX(Instante)),
           @FcMedia  = AVG(CAST(FcLpm AS INT)),
           @FcMax    = MAX(FcLpm)
    FROM #P;

    /* 5. Cortes por km (tiempo en movimiento acumulado en cada km exacto) */
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

    -- Último tramo incompleto (si supera 10 m)
    IF @DistTotal - @Km * 1000.0 >= 10
        INSERT INTO #Corte (Km, T) VALUES (@Km + 1, @TMov);

    /* 6. Parciales con desnivel, FC y kcal */
    SELECT CASE WHEN DistAcum <= 0 THEN 1 ELSE CAST(CEILING(DistAcum / 1000.0) AS INT) END AS Km,
           SUM(CASE WHEN DistMov > 0 AND DAlt > 0 THEN DAlt ELSE 0 END)  AS DesPos,
           SUM(CASE WHEN DistMov > 0 AND DAlt < 0 THEN -DAlt ELSE 0 END) AS DesNeg,
           AVG(CAST(FcLpm AS INT)) AS FcMedia
    INTO #PorKm
    FROM #S
    GROUP BY CASE WHEN DistAcum <= 0 THEN 1 ELSE CAST(CEILING(DistAcum / 1000.0) AS INT) END;

    SELECT p.Km, p.DistanciaM, p.DuracionSeg,
           CAST(ROUND(p.DuracionSeg / (p.DistanciaM / 1000.0), 0) AS INT) AS RitmoSegKm,
           k.DesPos, k.DesNeg, k.FcMedia,
           CASE WHEN @Peso IS NULL      THEN NULL
                WHEN @Ecuacion = 'M'    THEN @Met * @Peso * p.DuracionSeg / 3600.0
                ELSE e.Vo2 * @Peso / 1000.0 * 5.0 * p.DuracionSeg / 60.0 END AS Kcal
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
               END AS Vo2
    ) e
    WHERE p.Km > 0 AND p.DuracionSeg > 0;

    DECLARE @Kcal INT, @FuenteKcal VARCHAR(12);

    IF @KcalDispositivo IS NOT NULL
        SELECT @Kcal = @KcalDispositivo, @FuenteKcal = 'DISPOSITIVO';
    ELSE IF @Peso IS NOT NULL AND EXISTS (SELECT 1 FROM #Parcial)
        SELECT @Kcal = CAST(ROUND(SUM(Kcal), 0) AS INT),
               @FuenteKcal = CASE WHEN @Ecuacion = 'M' THEN 'MET' ELSE 'ACSM' END
        FROM #Parcial;

    /* 7. Ruta (WKT: longitud latitud) y ruta pública */
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
    WHERE LatAnt IS NULL OR Lat <> LatAnt OR Lon <> LonAnt;  -- sin puntos repetidos (paradas)

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

/* ---------- 11. Supresión y minimización (RGPD arts. 5.1.c y 17) ---------- */

CREATE OR ALTER PROCEDURE gym.usp_EliminarActividad
    @UsuarioId   INT,
    @ActividadId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    -- Puntos y parciales se borran en cascada
    DELETE FROM gym.Actividad WHERE ActividadId = @ActividadId AND UsuarioId = @UsuarioId;

    IF @@ROWCOUNT = 0
        THROW 50065, N'La actividad no existe o no pertenece al usuario.', 1;
END;
GO

/* Borra los puntos GPS en bruto de actividades finalizadas hace más de
   @Dias días; se conservan la ruta, el resumen y los parciales.
   El plazo debe coincidir con el fijado en el registro de actividades
   de tratamiento. Pensado para un trabajo programado (Agente SQL /
   Elastic Jobs en Azure). Borra por lotes para no bloquear la tabla. */
CREATE OR ALTER PROCEDURE gym.usp_PurgarPuntosAntiguos
    @Dias INT = 30,
    @Lote INT = 50000
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Limite DATETIME2(0) = DATEADD(DAY, -@Dias, SYSUTCDATETIME()), @Filas INT = 1;

    WHILE @Filas > 0
    BEGIN
        DELETE TOP (@Lote) p
        FROM gym.ActividadPunto p
        JOIN gym.Actividad a ON a.ActividadId = p.ActividadId
        WHERE a.Estado = 'F' AND a.FechaFin < @Limite;

        SET @Filas = @@ROWCOUNT;
    END

    UPDATE gym.Actividad
    SET PuntosPurgados = 1
    WHERE Estado = 'F' AND FechaFin < @Limite AND PuntosPurgados = 0;
END;
GO

/* ---------- 12. Prueba: carrera sintética de ~2,28 km ----------
   3,3 m/s en línea recta hacia el norte, con:
     - una parada de 30 s a los 990 m (debe excluirse del tiempo en movimiento);
     - un punto erróneo con precisión de 80 m (debe descartarse);
     - una zona privada de 150 m en la salida (se recorta de la ruta pública).
   Resultado esperado (aprox.):
     distancia 2,28 km · en movimiento 11:30 · total 11:59 · ritmo 5:03/km
     parciales: km 1 ≈ 5:03 · km 2 ≈ 5:03 · último tramo ≈ 277 m en ≈ 1:24
     kcal (ACSM, 70 kg) ≈ 170-180
*/
DECLARE @U INT = (SELECT UsuarioId FROM gym.Usuario WHERE Email = N'prueba@ejemplo.com'),
        @Act BIGINT, @Zona INT,
        @T0 DATETIME2(0) = '2026-09-27T08:00:00',
        @Lat0 FLOAT = 40.4153, @Lon0 FLOAT = -3.6845;

UPDATE gym.Usuario SET PesoCorporalKg = 70 WHERE UsuarioId = @U;

EXEC gym.usp_RegistrarConsentimiento @UsuarioId = @U, @Tipo = 'UBICACION', @Otorgado = 1, @VersionTexto = 'v1';
EXEC gym.usp_RegistrarConsentimiento @UsuarioId = @U, @Tipo = 'SALUD',     @Otorgado = 1, @VersionTexto = 'v1';

EXEC gym.usp_GuardarZonaPrivada @UsuarioId = @U, @Nombre = N'Casa',
     @Lat = @Lat0, @Lon = @Lon0, @RadioM = 150, @ZonaPrivadaId = @Zona OUTPUT;

EXEC gym.usp_IniciarActividad @UsuarioId = @U, @TipoActividadId = 1, @ActividadId = @Act OUTPUT;

-- Generación de 720 puntos (1 por segundo). 111 035 m ≈ 1° de latitud a 40° N.
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
       CASE WHEN i = 150 THEN @Lat0 + 0.01 ELSE @Lat0 + m / 111035.0 END AS lat,
       @Lon0 AS lon,
       CAST(650 + 10 * SIN(i / 100.0) AS DECIMAL(7,1)) AS alt,
       CASE WHEN i = 150 THEN 80.0 ELSE 5.0 END AS acc,
       150 + i % 10 AS fc
INTO #Gen
FROM d;

DECLARE @Lote1 NVARCHAR(MAX) = (SELECT s, t, lat, lon, alt, acc, fc FROM #Gen WHERE s <= 360 ORDER BY s FOR JSON PATH),
        @Lote2 NVARCHAR(MAX) = (SELECT s, t, lat, lon, alt, acc, fc FROM #Gen WHERE s > 360  ORDER BY s FOR JSON PATH);

EXEC gym.usp_RegistrarPuntos @UsuarioId = @U, @ActividadId = @Act, @PuntosJson = @Lote1;
EXEC gym.usp_RegistrarPuntos @UsuarioId = @U, @ActividadId = @Act, @PuntosJson = @Lote2;
EXEC gym.usp_RegistrarPuntos @UsuarioId = @U, @ActividadId = @Act, @PuntosJson = @Lote2;  -- reenvío: 0 puntos nuevos

EXEC gym.usp_FinalizarActividad @UsuarioId = @U, @ActividadId = @Act;

DROP TABLE #Gen;
GO
