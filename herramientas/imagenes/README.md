# Ilustraciones de ejercicios

Las imágenes que muestra la app en el detalle de cada ejercicio salen del proyecto de datos abierto [Everkinetic](https://github.com/everkinetic/data), con licencia [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

La licencia obliga a citar la autoría y la licencia junto a la imagen. La app lo hace con una línea pequeña bajo cada ilustración. No se modifican las imágenes: solo se redimensionan y se convierten a WebP, que es una modificación técnica permitida.

| Archivo | Contenido |
|---------|-----------|
| `mapeo.py` | Ejercicio del catálogo → ejercicio de Everkinetic. Solo entran los que coinciden en técnica y material, revisados uno a uno. |
| `generar.py` | Descarga el repositorio y genera `app/assets/ejercicios/*.webp`, `LICENCIA.txt` y `sql/17_imagenes_ejercicios.sql`. |

Uso: `python generar.py`. Requiere Python 3.10 o superior y Pillow. Para trabajar sin conexión: `python generar.py RUTA_A_everkinetic-data`.
