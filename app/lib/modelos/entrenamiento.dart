import 'formato.dart';
import 'rutina.dart';

/// Opciones del cuestionario inicial. Los Id coinciden con gym.Nivel y gym.Objetivo.
class OpcionCuestionario {
  const OpcionCuestionario(this.id, this.titulo, this.descripcion);

  final int id;
  final String titulo;
  final String descripcion;
}

const nivelesCuestionario = [
  OpcionCuestionario(1, 'Principiante', 'Empiezas o llevas menos de 6 meses entrenando con regularidad.'),
  OpcionCuestionario(2, 'Intermedio', 'Entrenas con constancia y dominas los ejercicios básicos.'),
  OpcionCuestionario(3, 'Avanzado', 'Llevas años entrenando y controlas cargas altas con buena técnica.'),
];

const objetivosCuestionario = [
  OpcionCuestionario(3, 'Perder grasa', 'Mantener la fuerza y el músculo mientras reduces grasa.'),
  OpcionCuestionario(1, 'Ganar fuerza', 'Mover más peso en los ejercicios básicos.'),
  OpcionCuestionario(2, 'Ganar músculo', 'Aumentar la masa muscular (hipertrofia).'),
];

/// Respuesta de GET /entrenamiento/recomendacion-dias.
class RecomendacionDias {
  const RecomendacionDias({
    required this.recomendado,
    required this.minimo,
    required this.maximo,
    required this.motivo,
    required this.fuente,
  });

  final int recomendado;
  final int minimo;
  final int maximo;
  final String motivo;
  final String fuente;

  factory RecomendacionDias.fromJson(Map<String, dynamic> j) => RecomendacionDias(
        recomendado: aEntero(j['recomendado'])!,
        minimo: aEntero(j['minimo'])!,
        maximo: aEntero(j['maximo'])!,
        motivo: j['motivo'] as String,
        fuente: j['fuente'] as String,
      );
}

/// Respuesta de POST /rutinas/ia.
class ResultadoRutina {
  const ResultadoRutina({required this.rutina, required this.generadaConIa});

  final Rutina rutina;
  final bool generadaConIa;

  factory ResultadoRutina.fromJson(Map<String, dynamic> j) => ResultadoRutina(
        rutina: Rutina.fromJson(j['rutina'] as Map<String, dynamic>),
        generadaConIa: j['generadaConIa'] == true,
      );
}

/// Tipos de serie (gym.SesionSerie.TipoSerie).
class TipoSerie {
  const TipoSerie(this.codigo, this.nombre, this.descripcion);

  final String codigo;
  final String nombre;
  final String descripcion;

  static const todos = [
    TipoSerie('N', 'Normal', 'Serie de trabajo habitual.'),
    TipoSerie('C', 'Calentamiento', 'Con poco peso para preparar el movimiento. No cuenta para la progresión ni el volumen.'),
    TipoSerie('F', 'Al fallo', 'Hasta no poder completar otra repetición con buena técnica (RPE 10).'),
    TipoSerie('D', 'Dropset', 'Al terminar, bajas el peso y continúas sin descanso.'),
    TipoSerie('R', 'Rest-pause', 'Descansas unos 10-20 segundos y continúas con el mismo peso.'),
  ];

  static TipoSerie porCodigo(String codigo) => todos.firstWhere((t) => t.codigo == codigo, orElse: () => todos.first);
}
