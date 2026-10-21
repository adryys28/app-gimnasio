import 'rutina.dart';

/// Recomendaciones orientativas durante la sesión. La persona puede seguirlas o no.
///
/// Pautas de diseño (habituales en entrenamiento de fuerza):
///  - Calentamiento específico solo en ejercicios compuestos con repeticiones:
///    2 series de aproximación (≈50 % × 10 y ≈75 % × 5) en el primer compuesto de la
///    sesión y 1 (≈60 % × 6) en los siguientes, porque los músculos ya están activos.
///  - El fallo y las técnicas de intensidad (dropset, rest-pause) se reservan para la
///    última serie de ejercicios de aislamiento en personas con experiencia; en fuerza,
///    en compuestos y en principiantes se recomiendan series normales.
class SerieCalentamiento {
  const SerieCalentamiento({required this.reps, this.pesoKg});

  final int reps;
  final int? pesoKg; // null = sin carga o carga muy ligera

  String get texto => pesoKg == null ? '$reps reps ligeras' : '$pesoKg kg × $reps';
}

class PlanCalentamiento {
  const PlanCalentamiento({required this.series, required this.motivo});

  final List<SerieCalentamiento> series;
  final String motivo;

  String get texto => series.map((s) => s.texto).join(' · ');
}

/// Null si el ejercicio no necesita calentamiento específico.
PlanCalentamiento? calentamientoRecomendado(EjercicioRutina e, {required bool hayCompuestoAnterior}) {
  if (e.porTiempo || !e.compuesto) return null;
  final peso = e.pesoObjetivoKg;
  int? carga(double pct) {
    if (peso == null) return null;
    final kg = (peso * pct).round();
    return kg >= 1 ? kg : null;
  }

  if (hayCompuestoAnterior) {
    return PlanCalentamiento(
      series: [SerieCalentamiento(reps: 6, pesoKg: carga(0.6))],
      motivo: 'Los músculos ya están activos: basta con una serie de aproximación.',
    );
  }
  return PlanCalentamiento(
    series: [SerieCalentamiento(reps: 10, pesoKg: carga(0.5)), SerieCalentamiento(reps: 5, pesoKg: carga(0.75))],
    motivo: 'Primer ejercicio compuesto de la sesión: dos series de aproximación con carga creciente.',
  );
}

/// Consejo cuando el ejercicio no necesita calentamiento específico.
String consejoSinCalentamiento({required bool primerEjercicio}) => primerEjercicio
    ? 'Antes de empezar, haz 5-10 minutos de calentamiento general: cardio suave y movilidad.'
    : 'No necesita calentamiento específico: vienes de los ejercicios anteriores.';

/// Tipo de serie recomendado para una serie de trabajo: (código, motivo).
(String, String) recomendarTipoSerie({
  required int nivel,
  required int objetivo, // 1 fuerza, 2 músculo, 3 perder grasa
  required bool compuesto,
  required bool porTiempo,
  required int serie,
  required int totalSeries,
}) {
  if (porTiempo) return ('N', 'Ejercicio por tiempo: mantén la postura durante todo el intervalo.');
  if (nivel <= 1) return ('N', 'Al empezar, prioriza la técnica con series normales y deja repeticiones en reserva.');
  if (objetivo == 1) return ('N', 'Para ganar fuerza, evita el fallo: cuida la calidad de cada repetición.');
  if (compuesto) return ('N', 'En ejercicios compuestos, mejor dejar 1-3 repeticiones en reserva.');

  final ultima = serie >= totalSeries;
  if (!ultima) return ('N', 'Serie de trabajo: guarda las técnicas de intensidad para la última.');

  if (objetivo == 3) {
    return ('R', 'Última serie: el rest-pause acumula trabajo en menos tiempo.');
  }
  return nivel >= 3
      ? ('D', 'Última serie de aislamiento: un dropset añade estímulo con poco riesgo.')
      : ('F', 'Última serie de aislamiento: puedes llevarla al fallo con buena técnica.');
}
