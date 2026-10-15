USE App_Gym;
GO

/* =========================================================
   08 - Soporte para la API: identidad externa y registro
   Ejecutar después de 01 a 07.
   ========================================================= */

-- Identificador del proveedor de identidad (claim "sub" del token)
ALTER TABLE gym.Usuario ADD IdExterno NVARCHAR(128) NULL;
GO

-- Único solo cuando tiene valor (un índice UNIQUE normal admite un único NULL)
CREATE UNIQUE INDEX UX_Usuario_IdExterno ON gym.Usuario(IdExterno) WHERE IdExterno IS NOT NULL;

-- Usuario de prueba accesible desde la API en desarrollo (cabecera X-Dev-Sub: dev-prueba)
UPDATE gym.Usuario SET IdExterno = N'dev-prueba' WHERE Email = N'prueba@ejemplo.com';
GO

CREATE OR ALTER PROCEDURE gym.usp_RegistrarUsuario
    @IdExterno       NVARCHAR(128),
    @Nombre          NVARCHAR(200),
    @Email           NVARCHAR(300),
    @FechaNacimiento DATE    = NULL,
    @NivelId         TINYINT,
    @ObjetivoId      TINYINT = NULL,
    @DiasSemana      TINYINT = NULL,
    @UsuarioId       INT     = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @IdExterno = NULLIF(LTRIM(RTRIM(@IdExterno)), N''),
           @Nombre    = NULLIF(LTRIM(RTRIM(@Nombre)), N''),
           @Email     = NULLIF(LOWER(LTRIM(RTRIM(@Email))), N'');

    IF @IdExterno IS NULL
        THROW 50050, N'Falta el identificador de la cuenta.', 1;
    IF @Nombre IS NULL OR LEN(@Nombre) > 100
        THROW 50051, N'Indica un nombre de 1 a 100 caracteres.', 1;
    IF @Email IS NULL OR LEN(@Email) > 256 OR @Email NOT LIKE N'_%@_%._%'
        THROW 50052, N'El correo electrónico no es válido.', 1;
    IF NOT EXISTS (SELECT 1 FROM gym.Nivel WHERE NivelId = @NivelId)
        THROW 50055, N'El nivel indicado no existe.', 1;
    IF @ObjetivoId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM gym.Objetivo WHERE ObjetivoId = @ObjetivoId)
        THROW 50056, N'El objetivo indicado no existe.', 1;
    IF @DiasSemana IS NOT NULL AND @DiasSemana NOT BETWEEN 1 AND 7
        THROW 50024, N'El número de días debe estar entre 1 y 7.', 1;
    -- 14 años: edad mínima de consentimiento para el tratamiento de datos en España (LOPDGDD, art. 7)
    IF @FechaNacimiento IS NOT NULL
       AND DATEADD(YEAR, 14, @FechaNacimiento) > CAST(SYSUTCDATETIME() AS DATE)
        THROW 50057, N'La edad mínima para registrarse es de 14 años.', 1;
    IF EXISTS (SELECT 1 FROM gym.Usuario WHERE IdExterno = @IdExterno)
        THROW 50053, N'La cuenta ya está registrada.', 1;
    IF EXISTS (SELECT 1 FROM gym.Usuario WHERE Email = @Email)
        THROW 50054, N'Ya existe una cuenta con ese correo electrónico.', 1;

    -- Si dos peticiones simultáneas pasan las comprobaciones, los índices
    -- únicos rechazan la segunda (error 2601, la API lo devuelve como 409)
    INSERT INTO gym.Usuario (IdExterno, Nombre, Email, FechaNacimiento, NivelId, ObjetivoId, DiasSemana)
    VALUES (@IdExterno, @Nombre, @Email, @FechaNacimiento, @NivelId, @ObjetivoId, @DiasSemana);

    SET @UsuarioId = SCOPE_IDENTITY();
END;
GO
