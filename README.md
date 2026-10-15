# App de gimnasio

## Estructura

| Carpeta      | Contenido |
|--------------|-----------|
| `sql/`       | Modelo de datos y procedimientos (SQL Server 2017+ / Azure SQL) |
| `api/GymApi` | API REST en .NET 10 (Dapper + Microsoft.Data.SqlClient) |
| `prototipo/` | Fuentes de las 7 pantallas del prototipo |

## Base de datos

Ejecutar los scripts en orden, de `00` a `11`. El `00` crea la base de datos `App_Gym` y el resto empieza con `USE App_Gym`, así que se crean siempre en ella. Cada script incluye al final una prueba con datos sintéticos.

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

## Prototipo

Los archivos `.dc.html` necesitan el entorno de diseño de Claude para mostrarse; abiertos directamente en el navegador no se ven. La versión navegable está en:
https://claude.ai/artifact/G5CgAEHJpm5cCSkEC1qFgg

`sql/utilidades/limpiar_master.sql` elimina el esquema `gym` si se creó por error en `master` (ejecutar primero en modo vista previa).

## Integración continua

El flujo `.github/workflows/ci.yml` se ejecuta en cada push a `main` y en cada pull request:

- **Compilar API:** `dotnet build` con .NET 10.
- **Validar scripts SQL:** arranca SQL Server 2022 en un contenedor y ejecuta los scripts `00` a `11` en orden, incluidas sus pruebas. Falla ante el primer error.

Dependabot revisa cada semana las dependencias de NuGet y de GitHub Actions.

## Pendiente

- Endpoints de la API para cardio, datos fisiológicos y suscripciones (scripts 09 a 11), incluida la verificación de firmas de las notificaciones de Apple, Google y Stripe.
- Pantallas de actividad de cardio con mapa y de catálogo de ejercicios.
- App Flutter (iOS, Android, web y escritorio) y apps de reloj (watchOS, Wear OS, Garmin).
- Revisión profesional de los contenidos de ejercicios y de los umbrales de adaptación.
- EIPD y registro de actividades de tratamiento (RGPD).

## Verificación

La primera ejecución del flujo de CI será la primera validación real de los scripts y de la API; puede requerir ajustes.
