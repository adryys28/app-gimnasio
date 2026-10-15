USE App_Gym;
GO

/* =========================================================
   App Gimnasio - Modelo de datos v1 (SQL Server / Azure SQL)
   ========================================================= */

CREATE SCHEMA gym;
GO

/* ---------- CATÁLOGOS ---------- */

CREATE TABLE gym.Nivel (
    NivelId     TINYINT       NOT NULL PRIMARY KEY,
    Nombre      NVARCHAR(30)  NOT NULL UNIQUE
);

CREATE TABLE gym.Objetivo (
    ObjetivoId  TINYINT       NOT NULL PRIMARY KEY,
    Nombre      NVARCHAR(50)  NOT NULL UNIQUE
);

CREATE TABLE gym.GrupoMuscular (
    GrupoMuscularId SMALLINT  IDENTITY(1,1) PRIMARY KEY,
    Nombre          NVARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE gym.Material (
    MaterialId  SMALLINT      IDENTITY(1,1) PRIMARY KEY,
    Nombre      NVARCHAR(50)  NOT NULL UNIQUE
);

/* ---------- EJERCICIOS ---------- */

CREATE TABLE gym.Ejercicio (
    EjercicioId     INT            IDENTITY(1,1) PRIMARY KEY,
    Nombre          NVARCHAR(100)  NOT NULL UNIQUE,
    Descripcion     NVARCHAR(MAX)  NULL,
    ErroresComunes  NVARCHAR(MAX)  NULL,
    VideoUrl        NVARCHAR(500)  NULL,
    MiniaturaUrl    NVARCHAR(500)  NULL,
    NivelMinimoId   TINYINT        NOT NULL REFERENCES gym.Nivel(NivelId),
    Activo          BIT            NOT NULL DEFAULT 1,
    FechaAlta       DATETIME2(0)   NOT NULL DEFAULT SYSUTCDATETIME()
);

-- Un ejercicio trabaja varios músculos (principal / secundario)
CREATE TABLE gym.EjercicioMusculo (
    EjercicioId     INT      NOT NULL REFERENCES gym.Ejercicio(EjercicioId) ON DELETE CASCADE,
    GrupoMuscularId SMALLINT NOT NULL REFERENCES gym.GrupoMuscular(GrupoMuscularId),
    EsPrincipal     BIT      NOT NULL DEFAULT 1,
    PRIMARY KEY (EjercicioId, GrupoMuscularId)
);

-- Un ejercicio puede requerir varios materiales
CREATE TABLE gym.EjercicioMaterial (
    EjercicioId INT      NOT NULL REFERENCES gym.Ejercicio(EjercicioId) ON DELETE CASCADE,
    MaterialId  SMALLINT NOT NULL REFERENCES gym.Material(MaterialId),
    PRIMARY KEY (EjercicioId, MaterialId)
);

/* ---------- USUARIOS ---------- */

CREATE TABLE gym.Usuario (
    UsuarioId       INT            IDENTITY(1,1) PRIMARY KEY,
    Nombre          NVARCHAR(100)  NOT NULL,
    Email           NVARCHAR(256)  NOT NULL UNIQUE,
    FechaNacimiento DATE           NULL,
    NivelId         TINYINT        NOT NULL REFERENCES gym.Nivel(NivelId),
    ObjetivoId      TINYINT        NULL REFERENCES gym.Objetivo(ObjetivoId),
    DiasSemana      TINYINT        NULL CHECK (DiasSemana BETWEEN 1 AND 7),
    FechaAlta       DATETIME2(0)   NOT NULL DEFAULT SYSUTCDATETIME()
);

/* ---------- RUTINAS ----------
   EsPlantilla = 1 y UsuarioId NULL  -> rutina sugerida del sistema
   EsPlantilla = 0 y UsuarioId       -> rutina propia o copia asignada
*/

CREATE TABLE gym.Rutina (
    RutinaId      INT            IDENTITY(1,1) PRIMARY KEY,
    Nombre        NVARCHAR(100)  NOT NULL,
    UsuarioId     INT            NULL REFERENCES gym.Usuario(UsuarioId),
    NivelId       TINYINT        NOT NULL REFERENCES gym.Nivel(NivelId),
    ObjetivoId    TINYINT        NULL REFERENCES gym.Objetivo(ObjetivoId),
    EsPlantilla   BIT            NOT NULL DEFAULT 0,
    Origen        CHAR(1)        NOT NULL DEFAULT 'M' CHECK (Origen IN ('S','M')), -- S=Sugerida, M=Manual
    Activa        BIT            NOT NULL DEFAULT 1,
    FechaAlta     DATETIME2(0)   NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT CK_Rutina_Plantilla CHECK (
        (EsPlantilla = 1 AND UsuarioId IS NULL) OR (EsPlantilla = 0 AND UsuarioId IS NOT NULL)
    )
);

CREATE TABLE gym.RutinaDia (
    RutinaDiaId INT           IDENTITY(1,1) PRIMARY KEY,
    RutinaId    INT           NOT NULL REFERENCES gym.Rutina(RutinaId) ON DELETE CASCADE,
    Orden       TINYINT       NOT NULL,
    Nombre      NVARCHAR(50)  NOT NULL, -- p. ej. "Día A - Tren superior"
    CONSTRAINT UQ_RutinaDia UNIQUE (RutinaId, Orden)
);

CREATE TABLE gym.RutinaDiaEjercicio (
    RutinaDiaEjercicioId INT     IDENTITY(1,1) PRIMARY KEY,
    RutinaDiaId          INT     NOT NULL REFERENCES gym.RutinaDia(RutinaDiaId) ON DELETE CASCADE,
    EjercicioId          INT     NOT NULL REFERENCES gym.Ejercicio(EjercicioId),
    Orden                TINYINT NOT NULL,
    Series               TINYINT NOT NULL CHECK (Series BETWEEN 1 AND 20),
    RepsMin              TINYINT NOT NULL,
    RepsMax              TINYINT NOT NULL,
    DescansoSeg          SMALLINT NOT NULL DEFAULT 90,
    RpeObjetivo          DECIMAL(3,1) NULL CHECK (RpeObjetivo BETWEEN 1 AND 10),
    CONSTRAINT CK_Reps CHECK (RepsMax >= RepsMin),
    CONSTRAINT UQ_RutinaDiaEjercicio UNIQUE (RutinaDiaId, Orden)
);

/* ---------- REGISTRO DE ENTRENAMIENTOS ---------- */

CREATE TABLE gym.Sesion (
    SesionId     BIGINT        IDENTITY(1,1) PRIMARY KEY,
    UsuarioId    INT           NOT NULL REFERENCES gym.Usuario(UsuarioId),
    RutinaDiaId  INT           NULL REFERENCES gym.RutinaDia(RutinaDiaId), -- NULL = sesión libre
    FechaInicio  DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
    FechaFin     DATETIME2(0)  NULL,
    Notas        NVARCHAR(500) NULL
);

-- Cada serie realizada: base para la adaptación automática por RPE
CREATE TABLE gym.SesionSerie (
    SesionSerieId BIGINT       IDENTITY(1,1) PRIMARY KEY,
    SesionId      BIGINT       NOT NULL REFERENCES gym.Sesion(SesionId) ON DELETE CASCADE,
    EjercicioId   INT          NOT NULL REFERENCES gym.Ejercicio(EjercicioId),
    NumSerie      TINYINT      NOT NULL,
    Reps          TINYINT      NOT NULL,
    PesoKg        DECIMAL(6,2) NULL,
    Rpe           DECIMAL(3,1) NULL CHECK (Rpe BETWEEN 1 AND 10)
);

/* ---------- ÍNDICES ---------- */

CREATE INDEX IX_Rutina_Usuario        ON gym.Rutina(UsuarioId) WHERE UsuarioId IS NOT NULL;
CREATE INDEX IX_Rutina_Plantilla      ON gym.Rutina(NivelId, ObjetivoId) WHERE EsPlantilla = 1;
CREATE INDEX IX_Sesion_UsuarioFecha   ON gym.Sesion(UsuarioId, FechaInicio DESC);
CREATE INDEX IX_SesionSerie_Ejercicio ON gym.SesionSerie(EjercicioId) INCLUDE (Reps, PesoKg, Rpe);
CREATE INDEX IX_Ejercicio_Nivel       ON gym.Ejercicio(NivelMinimoId) WHERE Activo = 1;

/* ---------- DATOS INICIALES ---------- */

INSERT INTO gym.Nivel (NivelId, Nombre) VALUES
(1, N'Principiante'), (2, N'Intermedio'), (3, N'Avanzado');

INSERT INTO gym.Objetivo (ObjetivoId, Nombre) VALUES
(1, N'Fuerza'), (2, N'Hipertrofia'), (3, N'Pérdida de grasa'),
(4, N'Resistencia'), (5, N'Movilidad y salud');

INSERT INTO gym.GrupoMuscular (Nombre) VALUES
(N'Pecho'), (N'Espalda'), (N'Hombros'), (N'Bíceps'), (N'Tríceps'),
(N'Cuádriceps'), (N'Isquiotibiales'), (N'Glúteos'), (N'Gemelos'), (N'Core');

INSERT INTO gym.Material (Nombre) VALUES
(N'Peso corporal'), (N'Barra'), (N'Mancuernas'), (N'Kettlebell'),
(N'Máquina'), (N'Polea'), (N'Banda elástica'), (N'Banco');
GO
