import 'package:latlong2/latlong.dart';

import 'formato.dart';

/// Elemento del historial (GET /actividades).
class ActividadResumen {
  const ActividadResumen({
    required this.actividadId,
    required this.tipo,
    this.fechaInicio,
    this.distanciaM,
    this.duracionMovTxt,
    this.ritmoMedioTxt,
    this.kcal,
  });

  final int actividadId;
  final String tipo;
  final DateTime? fechaInicio;
  final double? distanciaM;
  final String? duracionMovTxt;
  final String? ritmoMedioTxt;
  final int? kcal;

  factory ActividadResumen.fromJson(Map<String, dynamic> j) => ActividadResumen(
        actividadId: aEntero(j['actividadId'])!,
        tipo: j['tipo'] as String,
        fechaInicio: aFechaLocal(j['fechaInicio']),
        distanciaM: aDecimal(j['distanciaM']),
        duracionMovTxt: j['duracionMovTxt'] as String?,
        ritmoMedioTxt: j['ritmoMedioTxt'] as String?,
        kcal: aEntero(j['kcal']),
      );
}

class Historial {
  const Historial({required this.actividades, required this.ocultasPorPlan});

  final List<ActividadResumen> actividades;

  /// Actividades más antiguas que el límite del plan gratuito (se ven en Premium).
  final int ocultasPorPlan;

  factory Historial.fromJson(Map<String, dynamic> j) => Historial(
        actividades:
            (j['actividades'] as List).map((a) => ActividadResumen.fromJson(a as Map<String, dynamic>)).toList(),
        ocultasPorPlan: aEntero(j['ocultasPorPlan']) ?? 0,
      );
}

/// Un parcial por kilómetro (el último puede ser incompleto).
class Parcial {
  const Parcial({
    required this.km,
    required this.distanciaM,
    required this.duracionSeg,
    this.duracionTxt,
    this.ritmoTxt,
    this.desnivelPosM,
    this.desnivelNegM,
    this.fcMedia,
    this.kcal,
  });

  final int km;
  final double distanciaM;
  final double duracionSeg;
  final String? duracionTxt;
  final String? ritmoTxt;
  final double? desnivelPosM;
  final double? desnivelNegM;
  final int? fcMedia;
  final double? kcal;

  String get etiqueta => distanciaM >= 999.5 ? '$km' : '$km (${distanciaM.round()} m)';

  factory Parcial.fromJson(Map<String, dynamic> j) => Parcial(
        km: aEntero(j['km'])!,
        distanciaM: aDecimal(j['distanciaM'])!,
        duracionSeg: aDecimal(j['duracionSeg'])!,
        duracionTxt: j['duracionTxt'] as String?,
        ritmoTxt: j['ritmoTxt'] as String?,
        desnivelPosM: aDecimal(j['desnivelPosM']),
        desnivelNegM: aDecimal(j['desnivelNegM']),
        fcMedia: aEntero(j['fcMedia']),
        kcal: aDecimal(j['kcal']),
      );
}

/// Respuesta de GET /actividades/{id}: resumen, parciales y ruta.
class ActividadDetalle {
  const ActividadDetalle({
    required this.actividadId,
    required this.tipo,
    required this.parciales,
    required this.ruta,
    this.fechaInicio,
    this.distanciaM,
    this.duracionTotalTxt,
    this.duracionMovTxt,
    this.ritmoMedioTxt,
    this.velocidadMediaKmh,
    this.desnivelPosM,
    this.desnivelNegM,
    this.fcMedia,
    this.fcMax,
    this.kcal,
    this.fuenteKcal,
    this.coberturaFcPct,
  });

  final int actividadId;
  final String tipo;
  final DateTime? fechaInicio;
  final double? distanciaM;
  final String? duracionTotalTxt;
  final String? duracionMovTxt;
  final String? ritmoMedioTxt;
  final double? velocidadMediaKmh;
  final double? desnivelPosM;
  final double? desnivelNegM;
  final int? fcMedia;
  final int? fcMax;
  final int? kcal;
  final String? fuenteKcal;
  final double? coberturaFcPct;
  final List<Parcial> parciales;

  /// Tramos de la ruta. Van separados para no unir con una recta los cortes de las zonas privadas.
  final List<List<LatLng>> ruta;

  /// Cómo se han calculado las kcal: siempre es una estimación.
  String get fuenteKcalTexto {
    switch (fuenteKcal) {
      case 'DISPOSITIVO':
        return 'según tu reloj';
      case 'FC':
        final cobertura = coberturaFcPct;
        return cobertura == null ? 'por pulsaciones' : 'por pulsaciones (${cobertura.round()} % del tiempo)';
      case 'ACSM':
        return 'por velocidad y pendiente';
      case 'MET':
        return 'por tipo de actividad';
      default:
        return '';
    }
  }

  /// GeoJSON MultiLineString: coordenadas [longitud, latitud].
  static List<List<LatLng>> _ruta(dynamic geo) {
    if (geo is! Map<String, dynamic> || geo['coordinates'] is! List) return const [];
    return (geo['coordinates'] as List)
        .map((tramo) => (tramo as List).map((p) {
              final c = p as List;
              return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
            }).toList())
        .where((t) => t.length >= 2)
        .toList();
  }

  factory ActividadDetalle.fromJson(Map<String, dynamic> j) {
    final r = j['resumen'] as Map<String, dynamic>;
    return ActividadDetalle(
      actividadId: aEntero(r['actividadId'])!,
      tipo: r['tipo'] as String,
      fechaInicio: aFechaLocal(r['fechaInicio']),
      distanciaM: aDecimal(r['distanciaM']),
      duracionTotalTxt: r['duracionTotalTxt'] as String?,
      duracionMovTxt: r['duracionMovTxt'] as String?,
      ritmoMedioTxt: r['ritmoMedioTxt'] as String?,
      velocidadMediaKmh: aDecimal(r['velocidadMediaKmh']),
      desnivelPosM: aDecimal(r['desnivelPosM']),
      desnivelNegM: aDecimal(r['desnivelNegM']),
      fcMedia: aEntero(r['fcMedia']),
      fcMax: aEntero(r['fcMax']),
      kcal: aEntero(r['kcal']),
      fuenteKcal: r['fuenteKcal'] as String?,
      coberturaFcPct: aDecimal(r['coberturaFcPct']),
      parciales: (j['parciales'] as List).map((p) => Parcial.fromJson(p as Map<String, dynamic>)).toList(),
      ruta: _ruta(j['ruta']),
    );
  }
}
