using GymApi.Endpoints;
using GymApi.Infraestructura;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<ManejadorErroresSql>();
builder.Services.AddMemoryCache();
builder.Services.AddSingleton<Db>();
builder.Services.AddScoped<UsuarioActual>();

// Generación de rutinas con IA. La clave va en secretos de usuario (desarrollo) o en Key Vault / variable
// de entorno Ia__ClaveApi (producción), nunca en appsettings.json.
builder.Services.AddHttpClient<GeneradorRutinaIa>(c => c.Timeout = TimeSpan.FromSeconds(90));

if (builder.Environment.IsDevelopment())
{
    // Solo desarrollo: la identidad se toma de la cabecera X-Dev-Sub
    builder.Services.AddAuthentication(DevAuthHandler.Esquema)
        .AddScheme<AuthenticationSchemeOptions, DevAuthHandler>(DevAuthHandler.Esquema, null);

    // Solo desarrollo: permite llamadas desde la app Flutter ejecutada en Chrome (http://localhost:<puerto>)
    builder.Services.AddCors(o => o.AddDefaultPolicy(p => p
        .SetIsOriginAllowed(origen => Uri.TryCreate(origen, UriKind.Absolute, out var uri) && uri.IsLoopback)
        .AllowAnyHeader()
        .AllowAnyMethod()));
}
else
{
    builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(o =>
        {
            o.Authority = builder.Configuration["Auth:Authority"];
            o.Audience = builder.Configuration["Auth:Audience"];
            o.MapInboundClaims = false; // conserva el claim "sub" sin renombrar
        });
}

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseExceptionHandler();

if (app.Environment.IsDevelopment())
    app.UseCors();

app.UseAuthentication();
app.UseAuthorization();

if (app.Environment.IsDevelopment())
    app.MapOpenApi(); // /openapi/v1.json

app.MapCatalogoEndpoints();
app.MapUsuarioEndpoints();
app.MapRutinaEndpoints();
app.MapSesionEndpoints();
app.MapActividadEndpoints();
app.MapPerfilEndpoints();
app.MapPlanEndpoints();
app.MapEstadisticaEndpoints();
app.MapEntrenamientoEndpoints();

app.Run();
