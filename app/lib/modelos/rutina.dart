import 'formato.dart';

/// Respuesta de GET /rutinas/activa y de las operaciones sobre rutinas.
class Rutina {
  const Rutina({
    required this.rutinaId,
    required this.nombre,
    required this.origen,
    required this.dias,
    this.descripcion,
    this.nivelId,
    this.objetivoId,
  });

  final int rutinaId;
  final String nombre;
  final String origen; // S = sugerida, M = manual, I = generada con IA
  final List<DiaRutina> dias;

  /// Explicación de la IA sobre la estructura de la rutina.
  final String? descripcion;

  bool get generadaConIa => origen == 'I';

  /// Nivel (1-3) y objetivo (1 fuerza, 2 músculo, 3 perder grasa) con los que se creó la rutina.
  final int? nivelId;
  final int? objetivoId;

  factory Rutina.fromJson(Map<String, dynamic> j) => Rutina(
        rutinaId: aEntero(j['rutinaId'])!,
        nombre: j['nombre'] as String,
        origen: j['origen'] as String,
        dias: (j['dias'] as List).map((d) => DiaRutina.fromJson(d as Map<String, dynamic>)).toList(),
        descripcion: j['descripcion'] as String?,
        nivelId: aEntero(j['nivelId']),
        objetivoId: aEntero(j['objetivoId']),
      );
}

class DiaRutina {
  const DiaRutina({
    required this.rutinaDiaId,
    required this.orden,
    required this.nombre,
    required this.ejercicios,
    this.musculos = const [],
  });

  final int rutinaDiaId;
  final int orden;
  final String nombre;
  final List<EjercicioRutina> ejercicios;

  /// Grupos musculares principales que trabaja el día.
  final List<String> musculos;

  /// Estimación: 40 s por serie más el descanso indicado.
  int get minutosEstimados =>
      (ejercicios.fold<int>(0, (s, e) => s + e.series * (40 + e.descansoSeg)) / 60).round();

  int get totalSeries => ejercicios.fold(0, (suma, e) => suma + e.series);

  factory DiaRutina.fromJson(Map<String, dynamic> j) => DiaRutina(
        rutinaDiaId: aEntero(j['rutinaDiaId'])!,
        orden: aEntero(j['orden'])!,
        nombre: j['nombre'] as String,
        ejercicios: (j['ejercicios'] as List)
            .map((e) => EjercicioRutina.fromJson(e as Map<String, dynamic>))
            .toList(),
        musculos: ((j['musculos'] as List?) ?? const []).cast<String>(),
      );
}

class EjercicioRutina {
  const EjercicioRutina({
    required this.rutinaDiaEjercicioId,
    required this.orden,
    required this.ejercicioId,
    required this.nombre,
    required this.series,
    required this.tipoMedida,
    required this.descansoSeg,
    this.videoUrl,
    this.repsMin,
    this.repsMax,
    this.duracionSegMin,
    this.duracionSegMax,
    this.pesoObjetivoKg,
    this.rpeObjetivo,
    this.compuesto = false,
    this.principales = const [],
    this.secundarios = const [],
  });

  final int rutinaDiaEjercicioId;
  final int orden;
  final int ejercicioId;
  final String nombre;
  final String? videoUrl;
  final int series;
  final String tipoMedida; // R = repeticiones, T = tiempo
  final int? repsMin;
  final int? repsMax;
  final int? duracionSegMin;
  final int? duracionSegMax;
  final double? pesoObjetivoKg;
  final int descansoSeg;
  final double? rpeObjetivo;

  /// Implica varios músculos (sentadilla, press, remo…): se recomienda calentar antes.
  final bool compuesto;

  /// Grupos musculares que trabaja (principales y secundarios).
  final List<String> principales;
  final List<String> secundarios;

  bool get porTiempo => tipoMedida == 'T';

  /// "3 × 8–10 reps · 17 kg" o "3 × 30–45 s"
  String get objetivoTexto {
    final medida = porTiempo ? '${rango(duracionSegMin, duracionSegMax)} s' : '${rango(repsMin, repsMax)} reps';
    final peso = pesoObjetivoKg;
    final carga = peso == null ? '' : ' · ${formatearNumero(peso)} kg';
    return '$series × $medida$carga';
  }

  factory EjercicioRutina.fromJson(Map<String, dynamic> j) => EjercicioRutina(
        rutinaDiaEjercicioId: aEntero(j['rutinaDiaEjercicioId'])!,
        orden: aEntero(j['orden'])!,
        ejercicioId: aEntero(j['ejercicioId'])!,
        nombre: j['nombre'] as String,
        videoUrl: j['videoUrl'] as String?,
        series: aEntero(j['series'])!,
        tipoMedida: j['tipoMedida'] as String,
        repsMin: aEntero(j['repsMin']),
        repsMax: aEntero(j['repsMax']),
        duracionSegMin: aEntero(j['duracionSegMin']),
        duracionSegMax: aEntero(j['duracionSegMax']),
        pesoObjetivoKg: aDecimal(j['pesoObjetivoKg']),
        descansoSeg: aEntero(j['descansoSeg']) ?? 90,
        rpeObjetivo: aDecimal(j['rpeObjetivo']),
        compuesto: j['compuesto'] == true,
        principales: ((j['musculosPrincipales'] as List?) ?? const []).cast<String>(),
        secundarios: ((j['musculosSecundarios'] as List?) ?? const []).cast<String>(),
      );
}
