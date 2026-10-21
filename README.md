# App de gimnasio

## Estructura

| Carpeta      | Contenido |
|--------------|-----------|
| `sql/`       | Modelo de datos y procedimientos (SQL Server 2017+ / Azure SQL) |
| `api/GymApi` | API REST en .NET 10 (Dapper + Microsoft.Data.SqlClient) |
| `prototipo/` | Fuentes de las 7 pantallas del prototipo |
| `app/`       | App Flutter (iOS, Android, web y escritorio) |
| `herramientas/imagenes` | Generador de las ilustraciones de ejercicios (Python) |

## Base de datos

Ejecutar los scripts en orden, de `00` a `17`. El `00` crea la base de datos `App_Gym` y el resto empieza con `USE App_Gym`, así que se crean siempre en ella. Cada script incluye al final una prueba con datos sintéticos.

| Script | Contenido |
|--------|-----------|
| 00 | Creación de la base de datos `App_Gym` |
| 01 | Modelo base: catálogos, ejercicios, usuarios, rutinas y sesiones |
| 02 | Generación de rutina sugerida |
| 03 | Datos de prueba |
| 04 | Series, repeticiones o tiempo por ejercicio |
| 05 | Rutina personalizada: añadir, quitar y reordenar ejercicios |
| 06 | Gestión de días |
| 07 | Registro de sesiones y adaptación automática por RPE |
| 08 | Identidad externa y registro de usuarios (API) |
| 09 | Cardio exterior: GPS, parciales por km, kcal, zonas privadas y RGPD |
| 10 | Kcal por frecuencia cardiaca (Keytel et al., 2005) |
| 11 | Planes, suscripciones (Apple, Google, web) y licencias para gimnasios |
| 12 | Catálogo completo de ejercicios por grupo muscular (reejecutable) |
| 13 | Estadísticas para el diseño V2: semana, racha, volumen, récords y progresión |
| 14 | Rutinas generadas con IA, tipos de serie (calentamiento, fallo, dropset, rest-pause) y notas por serie |
| 15 | Datos para recomendar calentamiento y tipo de serie durante la sesión |
| 16 | Músculos principales y secundarios de cada ejercicio en la vista de rutina |
| 17 | Ilustraciones de los ejercicios (archivo, autoría y licencia) |

Requisitos: SQL Server 2017 o posterior (o Azure SQL) y nivel de compatibilidad >= 130.

Los scripts deben ejecutarse con `QUOTED_IDENTIFIER ON` (valor por defecto en SSMS; con `sqlcmd` hay que añadir `-I`), necesario para los índices filtrados.

## API

```
cd api/GymApi
dotnet run
```

- En desarrollo, la autenticación usa la cabecera `X-Dev-Sub` (usuario de prueba: `dev-prueba`).
- Las peticiones de ejemplo están en `GymApi.http`.
- En `appsettings.json` hay que sustituir el servidor, el inquilino y el client ID de Microsoft Entra External ID.
- Documento OpenAPI en desarrollo: `/openapi/v1.json`.

## Rutina personalizada (cuestionario inicial)

`POST /rutinas/cuestionario` guarda nivel, objetivo y días, y crea la rutina con el **generador de reglas** (`GeneradorRutinaReglas`): determinista, sin coste y basado en el catálogo. Estructura por días (2-3 cuerpo completo, 4 torso/pierna, 5 torso/pierna + empuje/tirón, 6 empuje/tirón/pierna), 5-7 ejercicios según nivel, compuestos primero y series, repeticiones, RPE y descansos según objetivo. El plan se valida en SQL (`usp_CrearRutinaDesdeJson`).

La generación con IA (Anthropic) queda disponible pero **desactivada**. Para activarla: `Ia:Habilitada = true` y la clave en secretos (`dotnet user-secrets set "Ia:ClaveApi" "..."`) o en `Ia__ClaveApi`. Si falla, se usa el generador de reglas. A la IA solo se enviarían nivel, objetivo, días y el catálogo; al activarla, el proveedor debe figurar como encargado del tratamiento en la EIPD.

## Ilustraciones de los ejercicios

Al pulsar un ejercicio en Hoy, o «Cómo se hace» durante la sesión, se abre su detalle. Si el ejercicio tiene ilustración, aparece arriba (dos dibujos de la ejecución); si no, no se muestra nada.

- **Origen**: proyecto de datos abierto [Everkinetic](https://github.com/everkinetic/data), licencia CC BY-SA 4.0. La licencia exige atribución, que se muestra en pequeño bajo cada imagen. Las imágenes no se alteran: solo se redimensionan y se pasan a WebP.
- **Cobertura**: 71 de 145 ejercicios, solo los que coinciden en técnica y material, revisados uno a uno.
- **Almacenamiento**: los archivos van incluidos en la app (`app/assets/ejercicios`, unos 3 MB). La asignación por ejercicio está en `gym.EjercicioImagen`.
- **API**: `GET /ejercicios/{id}` devuelve `imagenes` con `archivo`, `autor` y `licencia`.
- **Mantenimiento**: para cambiar la asignación, ver `herramientas/imagenes/README.md`.

## App Flutter

Primera vez (genera las carpetas de cada plataforma sin tocar `lib/` ni `test/`):

```
cd app
flutter create . --project-name app_gimnasio --org com.TU-EMPRESA --platforms=android,ios,web,windows
flutter pub get
```

Ejecutar contra la API local (arrancada con `dotnet run`):

```
flutter run -d chrome --dart-define=API_URL=http://localhost:5080
```

La API permite peticiones desde `localhost` solo en el entorno Development (CORS). Las compilaciones de iOS requieren un Mac con Xcode.

Los mapas usan por defecto los servidores públicos de OpenStreetMap, válidos solo para desarrollo. En producción hay que indicar un proveedor contratado con `--dart-define=TILE_URL=...`.

## Diseño

El diseño vigente (V2, oscuro y deportivo) está en Figma: https://www.figma.com/design/xdUCCiGnMb077VBbHSSXy4

Fuentes incluidas en `app/fonts`: Barlow Condensed e Inter, ambas con licencia SIL Open Font License 1.1.

## Prototipo

Los archivos `.dc.html` necesitan el entorno de diseño de Claude para mostrarse; abiertos directamente en el navegador no se ven. La versión navegable está en:
https://claude.ai/artifact/G5CgAEHJpm5cCSkEC1qFgg

`sql/utilidades/limpiar_master.sql` elimina el esquema `gym` si se creó por error en `master` (ejecutar primero en modo vista previa).

## Integración continua

El flujo `.github/workflows/ci.yml` se ejecuta en cada push a `main` y en cada pull request:

- **Compilar API:** `dotnet build` con .NET 10.
- **Analizar y probar app Flutter:** `flutter analyze` y `flutter test`.
- **Validar scripts SQL:** arranca SQL Server 2022 en un contenedor y ejecuta los scripts `00` a `17` en orden, incluidas sus pruebas. Falla ante el primer error.

Dependabot revisa cada semana las dependencias de NuGet y de GitHub Actions.

## Pendiente

- Notificaciones de compra de Apple, Google y Stripe en la API (verificación de firmas y llamada a usp_ProcesarEventoSuscripcion).
- App Flutter: grabación de cardio con GPS, inicio de sesión real, datos fisiológicos y compra de la suscripción (ya hechas: Hoy, Sesión, Resumen, Cardio con mapa, Ejercicios y Cuenta).
- Apps de reloj (watchOS, Wear OS, Garmin).
- Revisión profesional de los contenidos de ejercicios y de los umbrales de adaptación.
- Ilustraciones de los 74 ejercicios que aún no tienen.
- EIPD y registro de actividades de tratamiento (RGPD).

## Verificación

La primera ejecución del flujo de CI será la primera validación real de los scripts y de la API; puede requerir ajustes.
