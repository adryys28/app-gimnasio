import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../modelos/actividad.dart';
import '../modelos/catalogo.dart';
import '../modelos/cuenta.dart';
import '../modelos/rutina.dart';
import '../modelos/sesion.dart';

/// Error devuelto por la API (formato ProblemDetails).
class ApiExcepcion implements Exception {
  const ApiExcepcion(this.estado, this.mensaje, {this.requierePremium = false});

  final int estado;
  final String mensaje;

  /// La función pedida está en el plan Premium: la app puede mostrar la oferta.
  final bool requierePremium;

  @override
  String toString() => mensaje;
}

class ApiCliente {
  ApiCliente({http.Client? cliente, String? baseUrl, String? devSub})
      : _cliente = cliente ?? http.Client(),
        _baseUrl = baseUrl ?? Config.apiUrl,
        _devSub = devSub ?? Config.devSub;

  final http.Client _cliente;
  final String _baseUrl;
  final String _devSub;

  Map<String, String> get _cabeceras => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_devSub.isNotEmpty) 'X-Dev-Sub': _devSub,
      };

  /// Los parámetros vacíos o null no se envían.
  Future<dynamic> _get(String ruta, [Map<String, String?> consulta = const {}]) async {
    final parametros = {
      for (final p in consulta.entries)
        if (p.value != null && p.value!.isNotEmpty) p.key: p.value!,
    };
    final uri = Uri.parse('$_baseUrl$ruta');
    return _procesar(await _cliente.get(
      parametros.isEmpty ? uri : uri.replace(queryParameters: parametros),
      headers: _cabeceras,
    ));
  }

  Future<dynamic> _post(String ruta, [Object? cuerpo]) async => _procesar(
      await _cliente.post(Uri.parse('$_baseUrl$ruta'), headers: _cabeceras, body: jsonEncode(cuerpo ?? {})));

  dynamic _procesar(http.Response r) {
    final texto = utf8.decode(r.bodyBytes);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return texto.isEmpty ? null : jsonDecode(texto);
    }

    var mensaje = 'Error ${r.statusCode}';
    var premium = false;
    try {
      final j = jsonDecode(texto);
      if (j is Map<String, dynamic>) {
        mensaje = (j['title'] as String?) ?? mensaje;
        premium = j['requierePremium'] == true;
      }
    } on FormatException {
      // Respuesta sin JSON: se mantiene el mensaje genérico
    }
    throw ApiExcepcion(r.statusCode, mensaje, requierePremium: premium);
  }

  /* ---------- Rutinas ---------- */

  /// Devuelve null si la persona todavía no tiene rutina activa (404).
  Future<Rutina?> rutinaActiva() async {
    try {
      return Rutina.fromJson(await _get('/rutinas/activa') as Map<String, dynamic>);
    } on ApiExcepcion catch (e) {
      if (e.estado == 404) return null;
      rethrow;
    }
  }

  /// Usa el nivel, objetivo y días guardados en el perfil.
  Future<Rutina> generarRutinaSugerida() async =>
      Rutina.fromJson(await _post('/rutinas/sugerida') as Map<String, dynamic>);

  /* ---------- Sesiones de fuerza ---------- */

  Future<int> iniciarSesion(int rutinaDiaId) async {
    final j = await _post('/sesiones', {'rutinaDiaId': rutinaDiaId}) as Map<String, dynamic>;
    return (j['sesionId'] as num).toInt();
  }

  Future<void> registrarSerie({
    required int sesionId,
    required int ejercicioId,
    int? reps,
    int? duracionSeg,
    double? pesoKg,
    double? rpe,
  }) async {
    await _post('/sesiones/$sesionId/series', {
      'ejercicioId': ejercicioId,
      'reps': reps,
      'duracionSeg': duracionSeg,
      'pesoKg': pesoKg,
      'rpe': rpe,
    });
  }

  /// Devuelve los ajustes para la próxima sesión. Lista vacía si no hay
  /// ajustes o si el plan no incluye la adaptación automática.
  Future<List<AjusteSesion>> finalizarSesion(int sesionId) async {
    final j = await _post('/sesiones/$sesionId/finalizar', {'adaptar': true}) as Map<String, dynamic>;
    return (j['adaptacion'] as List).map((a) => AjusteSesion.fromJson(a as Map<String, dynamic>)).toList();
  }

  /* ---------- Catálogo de ejercicios ---------- */

  Future<Catalogo> catalogos() async => Catalogo.fromJson(await _get('/catalogos') as Map<String, dynamic>);

  Future<List<EjercicioResumen>> buscarEjercicios({String? texto, int? grupoMuscularId, int? materialId}) async {
    final lista = await _get('/ejercicios', {
      'texto': texto,
      'grupoMuscularId': grupoMuscularId?.toString(),
      'materialId': materialId?.toString(),
    }) as List;
    return lista.map((e) => EjercicioResumen.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<EjercicioDetalle> ejercicio(int ejercicioId) async =>
      EjercicioDetalle.fromJson(await _get('/ejercicios/$ejercicioId') as Map<String, dynamic>);

  /* ---------- Cardio ---------- */

  Future<Historial> actividades({int pagina = 1}) async =>
      Historial.fromJson(await _get('/actividades', {'pagina': '$pagina'}) as Map<String, dynamic>);

  Future<ActividadDetalle> actividad(int actividadId) async =>
      ActividadDetalle.fromJson(await _get('/actividades/$actividadId') as Map<String, dynamic>);

  /* ---------- Cuenta ---------- */

  Future<EstadoPlan> estadoPlan() async =>
      EstadoPlan.fromJson(await _get('/planes/estado') as Map<String, dynamic>);

  Future<List<Consentimiento>> consentimientos() async {
    final lista = await _get('/consentimientos') as List;
    return lista.map((c) => Consentimiento.fromJson(c as Map<String, dynamic>)).toList();
  }

  /// Al retirar un consentimiento, la API borra los datos que dependían de él.
  Future<void> registrarConsentimiento(String tipo, {required bool otorgado}) async {
    await _post('/consentimientos', {
      'tipo': tipo,
      'otorgado': otorgado,
      'versionTexto': Config.versionConsentimiento,
    });
  }
}
