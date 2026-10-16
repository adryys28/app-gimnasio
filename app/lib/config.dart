/// Configuración por entorno, con --dart-define al compilar o ejecutar:
///   flutter run -d chrome --dart-define=API_URL=http://localhost:5080
class Config {
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:5080');

  /// Solo desarrollo: identidad simulada con la cabecera X-Dev-Sub.
  /// En producción se sustituirá por el token de Microsoft Entra External ID.
  static const devSub = String.fromEnvironment('DEV_SUB', defaultValue: 'dev-prueba');

  /// Servidor de mapas. Los servidores públicos de OpenStreetMap solo valen para
  /// desarrollo; en producción hay que usar un proveedor contratado (MapTiler, Stadia…).
  static const urlTeselas =
      String.fromEnvironment('TILE_URL', defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');

  /// Identificador de la app que se envía al servidor de mapas (lo exige su política de uso).
  static const identificadorApp = 'io.github.adryys28.app_gimnasio';

  /// Versión del texto informativo de consentimientos que acepta la persona.
  static const versionConsentimiento = 'v1';
}
