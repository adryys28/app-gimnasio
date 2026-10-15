import 'formato.dart';

/// Un ajuste de la rutina calculado al finalizar la sesión (usp_AdaptarRutinaPorSesion).
class AjusteSesion {
  const AjusteSesion({
    required this.ejercicio,
    required this.accion,
    required this.motivo,
    this.pesoAntes,
    this.pesoNuevo,
    this.repsMinAntes,
    this.repsMaxAntes,
    this.repsMinNuevo,
    this.repsMaxNuevo,
    this.durMinAntes,
    this.durMaxAntes,
    this.durMinNueva,
    this.durMaxNueva,
  });

  final String ejercicio;
  final String accion; // SUBIR, BAJAR, CALIBRAR, MANTENER
  final String motivo;
  final double? pesoAntes;
  final double? pesoNuevo;
  final int? repsMinAntes;
  final int? repsMaxAntes;
  final int? repsMinNuevo;
  final int? repsMaxNuevo;
  final int? durMinAntes;
  final int? durMaxAntes;
  final int? durMinNueva;
  final int? durMaxNueva;

  /// Cambio legible: "16 → 17 kg", "10–12 → 12–14 reps", "30–45 → 25–40 s". Vacío si no cambia nada.
  String get cambioTexto {
    final antes = pesoAntes;
    final nuevo = pesoNuevo;
    if (accion == 'CALIBRAR' && nuevo != null) return 'Peso de referencia: ${formatearNumero(nuevo)} kg';
    if (antes != null && nuevo != null && antes != nuevo) {
      return '${formatearNumero(antes)} → ${formatearNumero(nuevo)} kg';
    }
    if (repsMinAntes != null && (repsMinAntes != repsMinNuevo || repsMaxAntes != repsMaxNuevo)) {
      return '${rango(repsMinAntes, repsMaxAntes)} → ${rango(repsMinNuevo, repsMaxNuevo)} reps';
    }
    if (durMinAntes != null && (durMinAntes != durMinNueva || durMaxAntes != durMaxNueva)) {
      return '${rango(durMinAntes, durMaxAntes)} → ${rango(durMinNueva, durMaxNueva)} s';
    }
    return '';
  }

  factory AjusteSesion.fromJson(Map<String, dynamic> j) => AjusteSesion(
        ejercicio: j['ejercicio'] as String,
        accion: j['accion'] as String,
        motivo: j['motivo'] as String,
        pesoAntes: aDecimal(j['pesoAntes']),
        pesoNuevo: aDecimal(j['pesoNuevo']),
        repsMinAntes: aEntero(j['repsMinAntes']),
        repsMaxAntes: aEntero(j['repsMaxAntes']),
        repsMinNuevo: aEntero(j['repsMinNuevo']),
        repsMaxNuevo: aEntero(j['repsMaxNuevo']),
        durMinAntes: aEntero(j['durMinAntes']),
        durMaxAntes: aEntero(j['durMaxAntes']),
        durMinNueva: aEntero(j['durMinNueva']),
        durMaxNueva: aEntero(j['durMaxNueva']),
      );
}
