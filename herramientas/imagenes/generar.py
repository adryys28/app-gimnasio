"""Genera las ilustraciones de ejercicios de la app y el script SQL que las asigna.

Fuente: proyecto de datos abierto Everkinetic (https://github.com/everkinetic/data),
licencia CC BY-SA 4.0. Las imágenes solo se redimensionan y se convierten a WebP
(modificación técnica permitida por la sección 2(a)(4) de la licencia); no se alteran.

Uso:  python generar.py            (descarga el repositorio de GitHub)
      python generar.py RUTA_LOCAL (usa una copia ya descargada de everkinetic/data)
Requiere Pillow.
"""
import io
import json
import sys
import zipfile
import urllib.request
from pathlib import Path

from PIL import Image

from mapeo import M

RAIZ = Path(__file__).resolve().parents[2]
DESTINO = RAIZ / "app" / "assets" / "ejercicios"
SQL = RAIZ / "sql" / "17_imagenes_ejercicios.sql"
ZIP = "https://codeload.github.com/everkinetic/data/zip/refs/heads/master"
ANCHO = 600
AUTOR = "Everkinetic"
LICENCIA = "CC BY-SA 4.0"
LICENCIA_URL = "https://creativecommons.org/licenses/by-sa/4.0/"
FUENTE_URL = "https://github.com/everkinetic/data"


def leer_origen():
    if len(sys.argv) > 1:
        base = Path(sys.argv[1])
        return json.loads((base / "exercises.json").read_text()), lambda n: (base / "src" / "images-web" / n).read_bytes()
    z = zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(ZIP).read()))
    raiz = z.namelist()[0].split("/")[0]
    return json.loads(z.read(f"{raiz}/exercises.json")), lambda n: z.read(f"{raiz}/src/images-web/{n}")


def main():
    datos, leer = leer_origen()
    por_nombre = {e["name"]: e for e in datos}
    DESTINO.mkdir(parents=True, exist_ok=True)
    for viejo in DESTINO.glob("*.webp"):
        viejo.unlink()
    filas = []
    for ejercicio, origen in sorted(M.items()):
        for orden, ruta in enumerate(por_nombre[origen]["img"][:2], start=1):
            nombre = ruta.split("/")[-1]
            im = Image.open(io.BytesIO(leer(nombre))).convert("RGB")
            im = im.resize((ANCHO, round(im.height * ANCHO / im.width)), Image.LANCZOS)
            archivo = nombre.rsplit(".", 1)[0] + ".webp"
            im.save(DESTINO / archivo, "WEBP", quality=80, method=6)
            filas.append(f"    (N'{ejercicio}', {orden}, '{archivo}')")
    (DESTINO / "LICENCIA.txt").write_text(
        f"Ilustraciones de ejercicios: {AUTOR} ({FUENTE_URL}).\n"
        f"Licencia {LICENCIA}: {LICENCIA_URL}\n"
        "Cambios: redimensionadas a 600 px de ancho y convertidas a WebP; sin otras modificaciones.\n",
        encoding="utf-8")
    SQL.write_text(PLANTILLA.format(filas=",\n".join(filas), autor=AUTOR, licencia=LICENCIA,
                                    licencia_url=LICENCIA_URL, fuente=FUENTE_URL), encoding="utf-8")
    print(len(M), "ejercicios;", len(filas), "imágenes")


PLANTILLA = """USE App_Gym;
GO

/* =========================================================
   17 - Ilustraciones de los ejercicios
   Ejecutar después de 01 a 16. Se puede volver a ejecutar.
   Generado por herramientas/imagenes/generar.py: no editar a mano.

   Las imágenes van incluidas en la app (app/assets/ejercicios) y
   aquí se guarda qué archivo corresponde a cada ejercicio, con su
   autoría y licencia, que la app muestra bajo la imagen.
   Origen: {fuente}, licencia {licencia}.
   Los ejercicios sin fila aquí no muestran imagen.
   ========================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'gym.EjercicioImagen', N'U') IS NULL
    CREATE TABLE gym.EjercicioImagen (
        EjercicioId  INT            NOT NULL REFERENCES gym.Ejercicio(EjercicioId) ON DELETE CASCADE,
        Orden        TINYINT        NOT NULL CONSTRAINT CK_EjercicioImagen_Orden CHECK (Orden BETWEEN 1 AND 2),
        Archivo      VARCHAR(120)   NOT NULL,
        Autor        NVARCHAR(100)  NOT NULL,
        Licencia     VARCHAR(20)    NOT NULL,
        LicenciaUrl  VARCHAR(200)   NOT NULL,
        FuenteUrl    VARCHAR(200)   NOT NULL,
        CONSTRAINT PK_EjercicioImagen PRIMARY KEY (EjercicioId, Orden)
    );
GO

DECLARE @Imagen TABLE (Ejercicio NVARCHAR(100) NOT NULL, Orden TINYINT NOT NULL, Archivo VARCHAR(120) NOT NULL,
                       PRIMARY KEY (Ejercicio, Orden));

INSERT INTO @Imagen (Ejercicio, Orden, Archivo) VALUES
{filas};

IF EXISTS (SELECT 1 FROM @Imagen i WHERE NOT EXISTS (SELECT 1 FROM gym.Ejercicio e WHERE e.Nombre = i.Ejercicio))
BEGIN
    DECLARE @Falta NVARCHAR(100) = (SELECT TOP (1) i.Ejercicio FROM @Imagen i
                                    WHERE NOT EXISTS (SELECT 1 FROM gym.Ejercicio e WHERE e.Nombre = i.Ejercicio));
    DECLARE @Msg NVARCHAR(200) = CONCAT(N'Ejercicio no encontrado en el catálogo: ', @Falta);
    THROW 50170, @Msg, 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    -- La asignación se sustituye por la de este script
    DELETE FROM gym.EjercicioImagen;

    INSERT INTO gym.EjercicioImagen (EjercicioId, Orden, Archivo, Autor, Licencia, LicenciaUrl, FuenteUrl)
    SELECT e.EjercicioId, i.Orden, i.Archivo, N'{autor}', '{licencia}', '{licencia_url}', '{fuente}'
    FROM @Imagen i
    JOIN gym.Ejercicio e ON e.Nombre = i.Ejercicio;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

/* ---------- Comprobación ---------- */
SELECT COUNT(DISTINCT EjercicioId) AS EjerciciosConImagen,
       COUNT(*) AS Imagenes,
       (SELECT COUNT(*) FROM gym.Ejercicio WHERE Activo = 1) AS EjerciciosActivos
FROM gym.EjercicioImagen;

SELECT TOP (5) e.Nombre, ei.Orden, ei.Archivo, ei.Autor, ei.Licencia
FROM gym.EjercicioImagen ei
JOIN gym.Ejercicio e ON e.EjercicioId = ei.EjercicioId
ORDER BY e.Nombre, ei.Orden;
GO
"""

if __name__ == "__main__":
    main()
