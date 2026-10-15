USE App_Gym;
GO

/* =========================================================
   11 - Planes, suscripciones y licencias para gimnasios
   Ejecutar después de 01 a 10.

   Fuentes de acceso Premium:
     - Suscripción individual: Apple, Google Play o web (Stripe).
     - Licencia de gimnasio (B2B): sus miembros obtienen el plan contratado.
   Las funciones de cada plan se consultan con gym.fn_FuncionesUsuario.

   IMPORTANTE: la base de datos no verifica la autenticidad de las
   notificaciones de las tiendas. La API debe validar la firma antes de
   llamar a usp_ProcesarEventoSuscripcion:
     Apple  -> App Store Server Notifications V2 (JWS firmado)
     Google -> Real-time developer notifications + Play Developer API
     Stripe -> cabecera Stripe-Signature del webhook
   ========================================================= */

/* ---------- 1. Planes y funciones ---------- */

CREATE TABLE gym.[Plan] (
    PlanId TINYINT      NOT NULL PRIMARY KEY,
    Codigo VARCHAR(20)  NOT NULL UNIQUE,
    Nombre NVARCHAR(50) NOT NULL
);

CREATE TABLE gym.Funcion (
    Codigo VARCHAR(30)   NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(100) NOT NULL
);

-- Limite NULL = sin límite. Si un plan no tiene la fila, no incluye la función.
CREATE TABLE gym.PlanFuncion (
    PlanId        TINYINT     NOT NULL REFERENCES gym.[Plan](PlanId),
    FuncionCodigo VARCHAR(30) NOT NULL REFERENCES gym.Funcion(Codigo),
    Limite        INT         NULL CHECK (Limite >= 0),
    PRIMARY KEY (PlanId, FuncionCodigo)
);

-- Productos configurados en cada tienda. El precio lo gestiona la tienda
-- (localizado e IVA incluido), por eso no se guarda aquí.
CREATE TABLE gym.ProductoTienda (
    ProductoId        INT           IDENTITY(1,1) PRIMARY KEY,
    PlanId            TINYINT       NOT NULL REFERENCES gym.[Plan](PlanId),
    Plataforma        VARCHAR(10)   NOT NULL CHECK (Plataforma IN ('APPLE','GOOGLE','WEB')),
    IdProductoExterno NVARCHAR(100) NOT NULL,  -- productId (Apple/Google) o price id (Stripe)
    IdPlanBase        NVARCHAR(100) NULL,      -- basePlanId de Google Play
    Periodo           VARCHAR(5)    NOT NULL CHECK (Periodo IN ('P1M','P1Y')),
    Activo            BIT           NOT NULL DEFAULT 1
);
CREATE UNIQUE INDEX UX_ProductoTienda ON gym.ProductoTienda(Plataforma, IdProductoExterno, IdPlanBase);

/* ---------- 2. Suscripciones individuales ----------
   Estados:
     PRUEBA          periodo de prueba gratuita (con acceso)
     ACTIVA          pagada; si RenovacionAutomatica = 0 está cancelada
                     pero conserva el acceso hasta FechaFinPeriodo
     PERIODO_GRACIA  fallo de cobro con acceso mantenido
     REINTENTO       fallo de cobro sin acceso
     EXPIRADA, REEMBOLSADA, REVOCADA   sin acceso
*/
CREATE TABLE gym.Suscripcion (
    SuscripcionId         BIGINT        IDENTITY(1,1) PRIMARY KEY,
    UsuarioId             INT           NOT NULL REFERENCES gym.Usuario(UsuarioId),
    ProductoId            INT           NOT NULL REFERENCES gym.ProductoTienda(ProductoId),
    Plataforma            VARCHAR(10)   NOT NULL,
    IdTransaccionOriginal NVARCHAR(200) NOT NULL,  -- originalTransactionId / purchaseToken / subscription id
    Estado                VARCHAR(15)   NOT NULL CHECK (Estado IN
                              ('PRUEBA','ACTIVA','PERIODO_GRACIA','REINTENTO','EXPIRADA','REEMBOLSADA','REVOCADA')),
    FechaInicio           DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
    FechaFinPeriodo       DATETIME2(0)  NOT NULL,
    RenovacionAutomatica  BIT           NOT NULL,
    FechaUltimoEvento     DATETIME2(3)  NOT NULL,  -- evita aplicar eventos que llegan desordenados
    CONSTRAINT UQ_Suscripcion_Transaccion UNIQUE (Plataforma, IdTransaccionOriginal)
);
CREATE INDEX IX_Suscripcion_Usuario ON gym.Suscripcion(UsuarioId, FechaFinPeriodo DESC);

-- Registro de notificaciones recibidas: idempotencia y auditoría
CREATE TABLE gym.EventoSuscripcion (
    EventoId        BIGINT        IDENTITY(1,1) PRIMARY KEY,
    Plataforma      VARCHAR(10)   NOT NULL,
    IdEventoExterno NVARCHAR(200) NOT NULL,  -- notificationUUID / messageId / event id
    SuscripcionId   BIGINT        NULL REFERENCES gym.Suscripcion(SuscripcionId),
    TipoEvento      NVARCHAR(60)  NOT NULL,
    FechaEvento     DATETIME2(3)  NOT NULL,
    FechaRecepcion  DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
    Aplicado        BIT           NOT NULL,  -- 0 = evento anterior al último aplicado
    Payload         NVARCHAR(MAX) NULL,
    CONSTRAINT UQ_EventoSuscripcion UNIQUE (Plataforma, IdEventoExterno)
);

/* ---------- 3. Licencias para gimnasios (B2B) ---------- */

CREATE TABLE gym.Organizacion (
    OrganizacionId   INT           IDENTITY(1,1) PRIMARY KEY,
    Nombre           NVARCHAR(100) NOT NULL,
    PlanId           TINYINT       NOT NULL REFERENCES gym.[Plan](PlanId),
    Plazas           INT           NOT NULL CHECK (Plazas > 0),
    FechaFinLicencia DATE          NOT NULL,
    Activa           BIT           NOT NULL DEFAULT 1
);

CREATE TABLE gym.OrganizacionMiembro (
    OrganizacionId INT          NOT NULL REFERENCES gym.Organizacion(OrganizacionId),
    UsuarioId      INT          NOT NULL REFERENCES gym.Usuario(UsuarioId),
    Rol            VARCHAR(12)  NOT NULL CHECK (Rol IN ('SOCIO','ENTRENADOR','ADMIN')),
    FechaAlta      DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    PRIMARY KEY (OrganizacionId, UsuarioId)
);
CREATE INDEX IX_OrganizacionMiembro_Usuario ON gym.OrganizacionMiembro(UsuarioId);

/* ---------- 4. Datos iniciales ----------
   Reparto de funciones propuesto (decisión de producto, ajustable sin
   tocar código):
     Gratis : 4 actividades de cardio al mes, historial visible de 90 días
     Premium: cardio ilimitado, adaptación por RPE, relojes, historial completo
*/
INSERT INTO gym.[Plan] (PlanId, Codigo, Nombre) VALUES
(1, 'GRATIS',  N'Gratis'),
(2, 'PREMIUM', N'Premium');

INSERT INTO gym.Funcion (Codigo, Nombre) VALUES
('ADAPTACION_RPE', N'Adaptación automática de la rutina por RPE'),
('CARDIO_GPS',     N'Actividades de cardio con GPS (límite mensual)'),
('RELOJES',        N'Conexión con relojes inteligentes'),
('HISTORIAL_DIAS', N'Historial visible (días)');

INSERT INTO gym.PlanFuncion (PlanId, FuncionCodigo, Limite) VALUES
(1, 'CARDIO_GPS',     4),
(1, 'HISTORIAL_DIAS', 90),
(2, 'CARDIO_GPS',     NULL),
(2, 'HISTORIAL_DIAS', NULL),
(2, 'ADAPTACION_RPE', NULL),
(2, 'RELOJES',        NULL);

-- Identificadores de ejemplo: sustituir por los reales de cada tienda
INSERT INTO gym.ProductoTienda (PlanId, Plataforma, IdProductoExterno, IdPlanBase, Periodo) VALUES
(2, 'APPLE',  N'premium_mensual',     NULL,       'P1M'),
(2, 'APPLE',  N'premium_anual',       NULL,       'P1Y'),
(2, 'GOOGLE', N'premium',             N'mensual', 'P1M'),
(2, 'GOOGLE', N'premium',             N'anual',   'P1Y'),
(2, 'WEB',    N'price_[ID_MENSUAL]',  NULL,       'P1M'),
(2, 'WEB',    N'price_[ID_ANUAL]',    NULL,       'P1Y');
GO

/* ---------- 5. Funciones disponibles para un usuario ----------
   Combina el plan gratuito, las suscripciones con acceso y las licencias
   de gimnasio vigentes. Para cada función se queda el límite más
   favorable (NULL = sin límite).
*/
CREATE OR ALTER FUNCTION gym.fn_FuncionesUsuario (@UsuarioId INT)
RETURNS TABLE
AS
RETURN
    WITH Planes AS (
        SELECT p.PlanId
        FROM gym.[Plan] p
        WHERE p.Codigo = 'GRATIS'

        UNION ALL

        SELECT pt.PlanId
        FROM gym.Suscripcion s
        JOIN gym.ProductoTienda pt ON pt.ProductoId = s.ProductoId
        WHERE s.UsuarioId = @UsuarioId
          AND s.Estado IN ('PRUEBA','ACTIVA','PERIODO_GRACIA')
          AND s.FechaFinPeriodo > SYSUTCDATETIME()

        UNION ALL

        SELECT o.PlanId
        FROM gym.OrganizacionMiembro m
        JOIN gym.Organizacion o ON o.OrganizacionId = m.OrganizacionId
        WHERE m.UsuarioId = @UsuarioId
          AND o.Activa = 1
          AND o.FechaFinLicencia >= CAST(SYSUTCDATETIME() AS DATE)
    )
    SELECT pf.FuncionCodigo AS Funcion,
           CASE WHEN COUNT(*) > COUNT(pf.Limite) THEN NULL ELSE MAX(pf.Limite) END AS Limite
    FROM Planes pl
    JOIN gym.PlanFuncion pf ON pf.PlanId = pl.PlanId
    GROUP BY pf.FuncionCodigo;
GO

/* ---------- 6. Estado del plan (para la pantalla de cuenta) ---------- */
CREATE OR ALTER PROCEDURE gym.usp_EstadoPlan
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM gym.Usuario WHERE UsuarioId = @UsuarioId)
        THROW 50001, N'El usuario no existe.', 1;

    -- Fuentes de acceso vigentes
    WITH Fuentes AS (
        SELECT 'SUSCRIPCION' AS Fuente, p.Codigo AS [Plan], s.Plataforma, s.Estado,
               s.FechaFinPeriodo AS FechaFin, s.RenovacionAutomatica, CAST(NULL AS NVARCHAR(100)) AS Organizacion
        FROM gym.Suscripcion s
        JOIN gym.ProductoTienda pt ON pt.ProductoId = s.ProductoId
        JOIN gym.[Plan] p          ON p.PlanId = pt.PlanId
        WHERE s.UsuarioId = @UsuarioId
          AND s.Estado IN ('PRUEBA','ACTIVA','PERIODO_GRACIA')
          AND s.FechaFinPeriodo > SYSUTCDATETIME()

        UNION ALL

        SELECT 'GIMNASIO', p.Codigo, NULL, NULL,
               CAST(o.FechaFinLicencia AS DATETIME2(0)), NULL, o.Nombre
        FROM gym.OrganizacionMiembro m
        JOIN gym.Organizacion o ON o.OrganizacionId = m.OrganizacionId
        JOIN gym.[Plan] p       ON p.PlanId = o.PlanId
        WHERE m.UsuarioId = @UsuarioId
          AND o.Activa = 1
          AND o.FechaFinLicencia >= CAST(SYSUTCDATETIME() AS DATE)
    )
    SELECT Fuente, [Plan], Plataforma, Estado, FechaFin, RenovacionAutomatica, Organizacion FROM Fuentes
    UNION ALL
    SELECT 'BASE', 'GRATIS', NULL, NULL, NULL, NULL, NULL
    WHERE NOT EXISTS (SELECT 1 FROM Fuentes);

    -- Funciones incluidas
    SELECT f.Funcion, fu.Nombre, f.Limite
    FROM gym.fn_FuncionesUsuario(@UsuarioId) f
    JOIN gym.Funcion fu ON fu.Codigo = f.Funcion
    ORDER BY f.Funcion;
END;
GO

/* ---------- 7. Procesar notificación de tienda (ya verificada por la API) ----------
   - Idempotente: un evento repetido no se vuelve a aplicar.
   - Orden: un evento con fecha anterior al último aplicado se registra
     pero no modifica la suscripción (las tiendas no garantizan el orden).
   - @UsuarioId solo es obligatorio en el primer evento. La API lo obtiene
     del identificador de cuenta que la app envía al comprar
     (appAccountToken en Apple, obfuscatedAccountId en Google, metadata en Stripe).
*/
CREATE OR ALTER PROCEDURE gym.usp_ProcesarEventoSuscripcion
    @Plataforma            VARCHAR(10),
    @IdEventoExterno       NVARCHAR(200),
    @TipoEvento            NVARCHAR(60),
    @FechaEvento           DATETIME2(3),
    @IdTransaccionOriginal NVARCHAR(200),
    @IdProductoExterno     NVARCHAR(100),
    @IdPlanBase            NVARCHAR(100) = NULL,
    @UsuarioId             INT           = NULL,
    @Estado                VARCHAR(15),
    @FechaFinPeriodo       DATETIME2(0),
    @RenovacionAutomatica  BIT,
    @Payload               NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Plataforma NOT IN ('APPLE','GOOGLE','WEB')
        THROW 50090, N'Plataforma no válida.', 1;
    IF @Estado NOT IN ('PRUEBA','ACTIVA','PERIODO_GRACIA','REINTENTO','EXPIRADA','REEMBOLSADA','REVOCADA')
        THROW 50091, N'Estado de suscripción no válido.', 1;
    IF NULLIF(@IdEventoExterno, N'') IS NULL OR NULLIF(@IdTransaccionOriginal, N'') IS NULL
       OR @FechaEvento IS NULL OR @FechaFinPeriodo IS NULL OR @RenovacionAutomatica IS NULL
        THROW 50092, N'Faltan datos obligatorios del evento.', 1;

    IF EXISTS (SELECT 1 FROM gym.EventoSuscripcion
               WHERE Plataforma = @Plataforma AND IdEventoExterno = @IdEventoExterno)
    BEGIN
        SELECT 'DUPLICADO' AS Resultado;
        RETURN;
    END

    DECLARE @ProductoId INT = (
        SELECT ProductoId FROM gym.ProductoTienda
        WHERE Plataforma = @Plataforma
          AND IdProductoExterno = @IdProductoExterno
          AND (IdPlanBase = @IdPlanBase OR (IdPlanBase IS NULL AND @IdPlanBase IS NULL)));

    IF @ProductoId IS NULL
        THROW 50093, N'El producto de la tienda no está configurado.', 1;

    DECLARE @SuscripcionId BIGINT, @UsuarioActual INT, @UltimoEvento DATETIME2(3), @Aplicado BIT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @SuscripcionId = SuscripcionId, @UsuarioActual = UsuarioId, @UltimoEvento = FechaUltimoEvento
        FROM gym.Suscripcion WITH (UPDLOCK, HOLDLOCK)
        WHERE Plataforma = @Plataforma AND IdTransaccionOriginal = @IdTransaccionOriginal;

        IF @SuscripcionId IS NULL
        BEGIN
            IF @UsuarioId IS NULL OR NOT EXISTS (SELECT 1 FROM gym.Usuario WHERE UsuarioId = @UsuarioId)
                THROW 50094, N'No se puede asociar la suscripción a ninguna cuenta.', 1;

            INSERT INTO gym.Suscripcion
                (UsuarioId, ProductoId, Plataforma, IdTransaccionOriginal, Estado,
                 FechaFinPeriodo, RenovacionAutomatica, FechaUltimoEvento)
            VALUES
                (@UsuarioId, @ProductoId, @Plataforma, @IdTransaccionOriginal, @Estado,
                 @FechaFinPeriodo, @RenovacionAutomatica, @FechaEvento);

            SELECT @SuscripcionId = SCOPE_IDENTITY(), @Aplicado = 1;
        END
        ELSE
        BEGIN
            -- Una compra no puede pasar de una cuenta a otra
            IF @UsuarioId IS NOT NULL AND @UsuarioId <> @UsuarioActual
                THROW 50095, N'La suscripción pertenece a otra cuenta.', 1;

            IF @FechaEvento >= @UltimoEvento
            BEGIN
                UPDATE gym.Suscripcion
                SET ProductoId           = @ProductoId,  -- cambio de mensual a anual, etc.
                    Estado               = @Estado,
                    FechaFinPeriodo      = @FechaFinPeriodo,
                    RenovacionAutomatica = @RenovacionAutomatica,
                    FechaUltimoEvento    = @FechaEvento
                WHERE SuscripcionId = @SuscripcionId;

                SET @Aplicado = 1;
            END
        END

        INSERT INTO gym.EventoSuscripcion
            (Plataforma, IdEventoExterno, SuscripcionId, TipoEvento, FechaEvento, Aplicado, Payload)
        VALUES
            (@Plataforma, @IdEventoExterno, @SuscripcionId, @TipoEvento, @FechaEvento, @Aplicado, @Payload);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT CASE WHEN @Aplicado = 1 THEN 'APLICADO' ELSE 'IGNORADO_ANTIGUO' END AS Resultado,
           @SuscripcionId AS SuscripcionId;
END;
GO

/* ---------- 8. Miembros de un gimnasio ---------- */
CREATE OR ALTER PROCEDURE gym.usp_AgregarMiembroOrganizacion
    @AdminUsuarioId INT,
    @OrganizacionId INT,
    @UsuarioId      INT,
    @Rol            VARCHAR(12) = 'SOCIO'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM gym.OrganizacionMiembro
                   WHERE OrganizacionId = @OrganizacionId AND UsuarioId = @AdminUsuarioId AND Rol = 'ADMIN')
        THROW 50096, N'Solo la administración del gimnasio puede añadir miembros.', 1;
    IF @Rol NOT IN ('SOCIO','ENTRENADOR','ADMIN')
        THROW 50097, N'Rol no válido.', 1;
    IF NOT EXISTS (SELECT 1 FROM gym.Usuario WHERE UsuarioId = @UsuarioId)
        THROW 50001, N'El usuario no existe.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Plazas INT = (SELECT Plazas FROM gym.Organizacion WITH (UPDLOCK, HOLDLOCK)
                               WHERE OrganizacionId = @OrganizacionId AND Activa = 1);
        IF @Plazas IS NULL
            THROW 50098, N'El gimnasio no existe o no tiene licencia activa.', 1;
        IF EXISTS (SELECT 1 FROM gym.OrganizacionMiembro WHERE OrganizacionId = @OrganizacionId AND UsuarioId = @UsuarioId)
            THROW 50099, N'La persona ya es miembro del gimnasio.', 1;
        IF (SELECT COUNT(*) FROM gym.OrganizacionMiembro WHERE OrganizacionId = @OrganizacionId) >= @Plazas
            THROW 50100, N'No quedan plazas disponibles en la licencia.', 1;

        INSERT INTO gym.OrganizacionMiembro (OrganizacionId, UsuarioId, Rol)
        VALUES (@OrganizacionId, @UsuarioId, @Rol);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- La administración puede dar de baja a cualquier miembro; cada persona, a sí misma
CREATE OR ALTER PROCEDURE gym.usp_QuitarMiembroOrganizacion
    @SolicitanteId  INT,
    @OrganizacionId INT,
    @UsuarioId      INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @SolicitanteId <> @UsuarioId
       AND NOT EXISTS (SELECT 1 FROM gym.OrganizacionMiembro
                       WHERE OrganizacionId = @OrganizacionId AND UsuarioId = @SolicitanteId AND Rol = 'ADMIN')
        THROW 50096, N'Solo la administración del gimnasio puede dar de baja a otros miembros.', 1;

    DELETE FROM gym.OrganizacionMiembro WHERE OrganizacionId = @OrganizacionId AND UsuarioId = @UsuarioId;

    IF @@ROWCOUNT = 0
        THROW 50101, N'La persona no es miembro del gimnasio.', 1;
END;
GO

/* ---------- 9. Aplicar el plan en los procedimientos existentes ---------- */

-- Iniciar actividad: relojes solo en Premium y límite mensual de cardio
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

    IF @Origen IN ('APPLE_WATCH','WEAR_OS','GARMIN')
       AND NOT EXISTS (SELECT 1 FROM gym.fn_FuncionesUsuario(@UsuarioId) WHERE Funcion = 'RELOJES')
        THROW 50076, N'La conexión con relojes está incluida en el plan Premium.', 1;

    DECLARE @TieneCardio BIT = 0, @Limite INT;
    SELECT @TieneCardio = 1, @Limite = Limite
    FROM gym.fn_FuncionesUsuario(@UsuarioId)
    WHERE Funcion = 'CARDIO_GPS';

    IF @TieneCardio = 0
        THROW 50077, N'Tu plan no incluye actividades de cardio.', 1;

    IF @Limite IS NOT NULL
    BEGIN
        DECLARE @Ahora DATETIME2(0) = SYSUTCDATETIME();
        DECLARE @InicioMes DATETIME2(0) = DATEFROMPARTS(YEAR(@Ahora), MONTH(@Ahora), 1);

        IF (SELECT COUNT(*) FROM gym.Actividad
            WHERE UsuarioId = @UsuarioId AND FechaInicio >= @InicioMes) >= @Limite
        BEGIN
            DECLARE @Msg NVARCHAR(2048) = CONCAT(
                N'Has alcanzado el límite de ', @Limite,
                N' actividades de cardio al mes del plan gratuito.');
            THROW 50078, @Msg, 1;
        END
    END

    INSERT INTO gym.Actividad (UsuarioId, TipoActividadId, Origen)
    VALUES (@UsuarioId, @TipoActividadId, @Origen);

    SET @ActividadId = SCOPE_IDENTITY();
END;
GO

-- Finalizar sesión de fuerza: la adaptación por RPE solo en Premium.
-- Las sesiones no adaptadas quedan con Adaptada = 0 por si la persona
-- se pasa a Premium más adelante.
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
       AND EXISTS (SELECT 1 FROM gym.fn_FuncionesUsuario(@UsuarioId) WHERE Funcion = 'ADAPTACION_RPE')
        EXEC gym.usp_AdaptarRutinaPorSesion @SesionId = @SesionId;
END;
GO

-- Historial de actividades con el límite de días del plan.
-- Las actividades antiguas no se borran, solo se ocultan: siguen
-- incluidas en el derecho de acceso y portabilidad (RGPD arts. 15 y 20).
CREATE OR ALTER PROCEDURE gym.usp_ListarActividades
    @UsuarioId INT,
    @Pagina    INT = 1,
    @TamPagina INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    IF @Pagina < 1 OR @TamPagina NOT BETWEEN 1 AND 100
        THROW 50102, N'Paginación no válida (página >= 1, tamaño 1-100).', 1;

    DECLARE @Tiene BIT = 0, @Dias INT;
    SELECT @Tiene = 1, @Dias = Limite
    FROM gym.fn_FuncionesUsuario(@UsuarioId)
    WHERE Funcion = 'HISTORIAL_DIAS';

    IF @Tiene = 0 SET @Dias = 0;

    DECLARE @Desde DATETIME2(0) = CASE WHEN @Dias IS NULL THEN NULL ELSE DATEADD(DAY, -@Dias, SYSUTCDATETIME()) END;

    SELECT a.ActividadId, t.Nombre AS Tipo, a.Origen, a.FechaInicio,
           a.DistanciaM, a.DuracionMovSeg, gym.fn_TiempoTxt(a.DuracionMovSeg) AS DuracionMovTxt,
           a.RitmoMedioSegKm, gym.fn_TiempoTxt(a.RitmoMedioSegKm) AS RitmoMedioTxt,
           a.Kcal, a.FuenteKcal
    FROM gym.Actividad a
    JOIN gym.TipoActividad t ON t.TipoActividadId = a.TipoActividadId
    WHERE a.UsuarioId = @UsuarioId
      AND a.Estado = 'F'
      AND (@Desde IS NULL OR a.FechaInicio >= @Desde)
    ORDER BY a.FechaInicio DESC
    OFFSET (@Pagina - 1) * @TamPagina ROWS FETCH NEXT @TamPagina ROWS ONLY;

    -- Para mostrar "Tienes N actividades más antiguas en Premium"
    SELECT COUNT(*) AS OcultasPorPlan
    FROM gym.Actividad
    WHERE UsuarioId = @UsuarioId AND Estado = 'F'
      AND @Desde IS NOT NULL AND FechaInicio < @Desde;
END;
GO

/* ---------- 10. Prueba ---------- */

DECLARE @U INT = (SELECT UsuarioId FROM gym.Usuario WHERE Email = N'prueba@ejemplo.com'),
        @Act BIGINT,
        @Fin DATETIME2(0) = DATEADD(MONTH, 1, SYSUTCDATETIME()),
        @FinAntiguo DATETIME2(0) = DATEADD(DAY, -1, SYSUTCDATETIME()),
        @Org INT;

-- 1. Plan gratuito: CARDIO_GPS (4/mes) e HISTORIAL_DIAS (90)
EXEC gym.usp_EstadoPlan @UsuarioId = @U;

-- 2. Reloj sin Premium -> error esperado 50076
BEGIN TRY
    EXEC gym.usp_IniciarActividad @UsuarioId = @U, @TipoActividadId = 1, @Origen = 'APPLE_WATCH', @ActividadId = @Act OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;

-- 3. Alta de suscripción en Apple -> APLICADO
EXEC gym.usp_ProcesarEventoSuscripcion
     @Plataforma = 'APPLE', @IdEventoExterno = N'evt-001', @TipoEvento = N'SUBSCRIBED',
     @FechaEvento = '2026-10-01T10:00:00', @IdTransaccionOriginal = N'2000000123456789',
     @IdProductoExterno = N'premium_mensual', @UsuarioId = @U,
     @Estado = 'ACTIVA', @FechaFinPeriodo = @Fin, @RenovacionAutomatica = 1;

-- 4. Mismo evento reenviado -> DUPLICADO
EXEC gym.usp_ProcesarEventoSuscripcion
     @Plataforma = 'APPLE', @IdEventoExterno = N'evt-001', @TipoEvento = N'SUBSCRIBED',
     @FechaEvento = '2026-10-01T10:00:00', @IdTransaccionOriginal = N'2000000123456789',
     @IdProductoExterno = N'premium_mensual', @UsuarioId = @U,
     @Estado = 'ACTIVA', @FechaFinPeriodo = @Fin, @RenovacionAutomatica = 1;

-- 5. Evento anterior que llega tarde -> IGNORADO_ANTIGUO (la suscripción sigue activa)
EXEC gym.usp_ProcesarEventoSuscripcion
     @Plataforma = 'APPLE', @IdEventoExterno = N'evt-000', @TipoEvento = N'EXPIRED',
     @FechaEvento = '2026-09-30T10:00:00', @IdTransaccionOriginal = N'2000000123456789',
     @IdProductoExterno = N'premium_mensual',
     @Estado = 'EXPIRADA', @FechaFinPeriodo = @FinAntiguo, @RenovacionAutomatica = 0;

-- 6. Ahora Premium: todas las funciones, sin límites
EXEC gym.usp_EstadoPlan @UsuarioId = @U;

-- 7. Licencia de gimnasio: la persona aparece con dos fuentes de acceso
INSERT INTO gym.Organizacion (Nombre, PlanId, Plazas, FechaFinLicencia)
VALUES (N'Gimnasio de prueba', 2, 50, DATEADD(YEAR, 1, CAST(SYSUTCDATETIME() AS DATE)));
SET @Org = SCOPE_IDENTITY();

INSERT INTO gym.OrganizacionMiembro (OrganizacionId, UsuarioId, Rol) VALUES (@Org, @U, 'ADMIN');

EXEC gym.usp_EstadoPlan @UsuarioId = @U;

-- 8. Historial
EXEC gym.usp_ListarActividades @UsuarioId = @U;
GO
