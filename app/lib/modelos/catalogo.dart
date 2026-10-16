import 'formato.dart';

class ItemCatalogo {
  const ItemCatalogo({required this.id, required this.nombre});

  final int id;
  final String nombre;

  factory ItemCatalogo.fromJson(Map<String, dynamic> j) =>
      ItemCatalogo(id: aEntero(j['id'])!, nombre: j['nombre'] as String);
}

/// Respuesta de GET /catalogos.
class Catalogo {
  const Catalogo({
    required this.niveles,
    required this.objetivos,
    required this.gruposMusculares,
    required this.materiales,
  });

  final List<ItemCatalogo> niveles;
  final List<ItemCatalogo> objetivos;
  final List<ItemCatalogo> gruposMusculares;
  final List<ItemCatalogo> materiales;

  String nombreNivel(int id) => niveles.where((n) => n.id == id).map((n) => n.nombre).firstOrNull ?? '';

  static List<ItemCatalogo> _lista(dynamic v) =>
      (v as List).map((e) => ItemCatalogo.fromJson(e as Map<String, dynamic>)).toList();

  factory Catalogo.fromJson(Map<String, dynamic> j) => Catalogo(
        niveles: _lista(j['niveles']),
        objetivos: _lista(j['objetivos']),
        gruposMusculares: _lista(j['gruposMusculares']),
        materiales: _lista(j['materiales']),
      );
}

/// Elemento de GET /ejercicios.
class EjercicioResumen {
  const EjercicioResumen({
    required this.ejercicioId,
    required this.nombre,
    required this.nivelMinimoId,
    required this.tipoMedida,
    this.descripcion,
    this.erroresComunes,
    this.videoUrl,
  });

  final int ejercicioId;
  final String nombre;
  final int nivelMinimoId;
  final String tipoMedida;
  final String? descripcion;
  final String? erroresComunes;
  final String? videoUrl;

  String get medidaTexto => tipoMedida == 'T' ? 'Por tiempo' : 'Por repeticiones';

  factory EjercicioResumen.fromJson(Map<String, dynamic> j) => EjercicioResumen(
        ejercicioId: aEntero(j['ejercicioId'])!,
        nombre: j['nombre'] as String,
        nivelMinimoId: aEntero(j['nivelMinimoId'])!,
        tipoMedida: j['tipoMedida'] as String,
        descripcion: j['descripcion'] as String?,
        erroresComunes: j['erroresComunes'] as String?,
        videoUrl: j['videoUrl'] as String?,
      );
}

class MusculoEjercicio {
  const MusculoEjercicio({required this.nombre, required this.esPrincipal});

  final String nombre;
  final bool esPrincipal;

  factory MusculoEjercicio.fromJson(Map<String, dynamic> j) =>
      MusculoEjercicio(nombre: j['nombre'] as String, esPrincipal: j['esPrincipal'] == true);
}

/// Respuesta de GET /ejercicios/{id}.
class EjercicioDetalle {
  const EjercicioDetalle({required this.ejercicio, required this.musculos, required this.materiales});

  final EjercicioResumen ejercicio;
  final List<MusculoEjercicio> musculos;
  final List<String> materiales;

  factory EjercicioDetalle.fromJson(Map<String, dynamic> j) => EjercicioDetalle(
        ejercicio: EjercicioResumen.fromJson(j['ejercicio'] as Map<String, dynamic>),
        musculos: (j['musculos'] as List).map((m) => MusculoEjercicio.fromJson(m as Map<String, dynamic>)).toList(),
        materiales: (j['materiales'] as List).cast<String>(),
      );
}
