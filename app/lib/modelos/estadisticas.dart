import 'formato.dart';

/// Ajuste automático reciente (pantalla Hoy).
class AjusteReciente {
  const AjusteReciente({
    required this.ejercicio,
    required this.accion,
    this.pesoAntes,
    this.pesoDespues,
    this.repsAntes,
    this.repsDespues,
    this.durAntes,
    this.durDespues,
  });

  final String ejercicio;
  final String accion; // SUBIR o BAJAR
  final double? pesoAntes;
  final double? pesoDespues;
  final int? repsAntes;
  final int? repsDespues;
  final int? durAntes;
  final int? durDespues;

  bool get sube => accion == 'SUBIR';

  /// "+1 kg", "+2 reps", "−5 s"
  String get valor {
    final pa = pesoAntes, pd = pesoDespues, ra = repsAntes, rd = repsDespues, da = durAntes, dd = durDespues;
    if (pa != null && pd != null && pa != pd) return conSigno(pd - pa, 'kg');
    if (ra != null && rd != null && ra != rd) return conSigno((rd - ra).toDouble(), 'reps');
    if (da != null && dd != null && da != dd) return conSigno((dd - da).toDouble(), 's');
    return sube ? 'Sube' : 'Baja';
  }

  factory AjusteReciente.fromJson(Map<String, dynamic> j) => AjusteReciente(
        ejercicio: j['ejercicio'] as String,
        accion: j['accion'] as String,
        pesoAntes: aDecimal(j['pesoAntes']),
        pesoDespues: aDecimal(j['pesoDespues']),
        repsAntes: aEntero(j['repsMinAntes']),
        repsDespues: aEntero(j['repsMinDespues']),
        durAntes: aEntero(j['durMinAntes']),
        durDespues: aEntero(j['durMinDespues']),
      );
}

/// Respuesta de GET /inicio/resumen.
class ResumenInicio {
  const ResumenInicio({
    required this.nombre,
    required this.objetivoSemana,
    required this.sesionesSemana,
    required this.volumenSemanaKg,
    required this.volumenAnteriorKg,
    required this.rachaDias,
    required this.volumenDias,
    required this.ajustes,
  });

  final String nombre;
  final int objetivoSemana;
  final int sesionesSemana;
  final double volumenSemanaKg;
  final double volumenAnteriorKg;
  final int rachaDias;
  final List<double> volumenDias; // lunes a domingo
  final List<AjusteReciente> ajustes;

  /// Variación del volumen frente a la semana anterior, en %. Null si no hay referencia.
  int? get variacionVolumenPct =>
      volumenAnteriorKg > 0 ? ((volumenSemanaKg - volumenAnteriorKg) / volumenAnteriorKg * 100).round() : null;

  String get nombreCorto => nombre.trim().split(' ').first;

  factory ResumenInicio.fromJson(Map<String, dynamic> j) {
    final r = j['resumen'] as Map<String, dynamic>;
    return ResumenInicio(
      nombre: r['nombre'] as String,
      objetivoSemana: aEntero(r['objetivoSemana']) ?? 3,
      sesionesSemana: aEntero(r['sesionesSemana']) ?? 0,
      volumenSemanaKg: aDecimal(r['volumenSemanaKg']) ?? 0,
      volumenAnteriorKg: aDecimal(r['volumenSemanaAnteriorKg']) ?? 0,
      rachaDias: aEntero(r['rachaDias']) ?? 0,
      volumenDias: (j['volumenSemana'] as List).map((d) => aDecimal((d as Map<String, dynamic>)['volumenKg']) ?? 0).toList(),
      ajustes: (j['ajustes'] as List).map((a) => AjusteReciente.fromJson(a as Map<String, dynamic>)).toList(),
    );
  }
}

class RecordPersonal {
  const RecordPersonal({required this.ejercicio, required this.pesoKg, required this.pesoAnteriorKg, this.reps});

  final String ejercicio;
  final double pesoKg;
  final double pesoAnteriorKg;
  final int? reps;

  factory RecordPersonal.fromJson(Map<String, dynamic> j) => RecordPersonal(
        ejercicio: j['ejercicio'] as String,
        pesoKg: aDecimal(j['pesoKg'])!,
        pesoAnteriorKg: aDecimal(j['pesoAnteriorKg'])!,
        reps: aEntero(j['reps']),
      );
}

/// Respuesta de GET /sesiones/{id}/resumen.
class ResumenSesion {
  const ResumenSesion({
    required this.nombreDia,
    required this.series,
    required this.volumenKg,
    required this.records,
    required this.progresion,
    this.fecha,
    this.duracionSeg,
    this.rpeMedio,
    this.ejercicioProgresion,
  });

  final String nombreDia;
  final DateTime? fecha;
  final int? duracionSeg;
  final int series;
  final double volumenKg;
  final double? rpeMedio;
  final List<RecordPersonal> records;
  final List<double> progresion;
  final String? ejercicioProgresion;

  factory ResumenSesion.fromJson(Map<String, dynamic> j) {
    final r = j['resumen'] as Map<String, dynamic>;
    final prog = (j['progresion'] as List).cast<Map<String, dynamic>>();
    return ResumenSesion(
      nombreDia: r['nombreDia'] as String,
      fecha: aFechaLocal(r['fechaInicio']),
      duracionSeg: aEntero(r['duracionSeg']),
      series: aEntero(r['series']) ?? 0,
      volumenKg: aDecimal(r['volumenKg']) ?? 0,
      rpeMedio: aDecimal(r['rpeMedio']),
      records: (j['records'] as List).map((x) => RecordPersonal.fromJson(x as Map<String, dynamic>)).toList(),
      progresion: prog.map((p) => aDecimal(p['pesoKg']) ?? 0).toList(),
      ejercicioProgresion: prog.isEmpty ? null : prog.first['ejercicio'] as String,
    );
  }
}
