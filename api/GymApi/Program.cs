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

if (builder.Environment.IsDevelopment())
{
    // Solo desarrollo: la identidad se toma de la cabecera X-Dev-Sub
    builder.Services.AddAuthentication(DevAuthHandler.Esquema)
        .AddScheme<AuthenticationSchemeOptions, DevAuthHandler>(DevAuthHandler.Esquema, null);
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

app.Run();
