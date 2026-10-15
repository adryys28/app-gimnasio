/// Configuración por entorno, con --dart-define al compilar o ejecutar:
///   flutter run -d chrome --dart-define=API_URL=http://localhost:5080
class Config {
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:5080');

  /// Solo desarrollo: identidad simulada con la cabecera X-Dev-Sub.
  /// En producción se sustituirá por el token de Microsoft Entra External ID.
  static const devSub = String.fromEnvironment('DEV_SUB', defaultValue: 'dev-prueba');
}
