import 'formato.dart';

class FuentePlan {
  const FuentePlan({
    required this.fuente,
    required this.plan,
    this.plataforma,
    this.fechaFin,
    this.renovacionAutomatica,
    this.organizacion,
  });

  final String fuente; // SUSCRIPCION, GIMNASIO o BASE
  final String plan;
  final String? plataforma;
  final DateTime? fechaFin;
  final bool? renovacionAutomatica;
  final String? organizacion;

  String get descripcion {
    final hasta = fechaFin == null ? '' : ' hasta el ${formatearFecha(fechaFin!)}';
    switch (fuente) {
      case 'SUSCRIPCION':
        final renueva = renovacionAutomatica == true ? ' (se renueva automáticamente)' : '';
        return 'Suscripción en ${_plataforma(plataforma)}$hasta$renueva';
      case 'GIMNASIO':
        return 'Licencia de ${organizacion ?? 'tu gimnasio'}$hasta';
      default:
        return 'Plan gratuito';
    }
  }

  static String _plataforma(String? p) => switch (p) {
        'APPLE' => 'App Store',
        'GOOGLE' => 'Google Play',
        'WEB' => 'la web',
        _ => 'la tienda',
      };

  factory FuentePlan.fromJson(Map<String, dynamic> j) => FuentePlan(
        fuente: j['fuente'] as String,
        plan: j['plan'] as String,
        plataforma: j['plataforma'] as String?,
        fechaFin: aFechaLocal(j['fechaFin']),
        renovacionAutomatica: j['renovacionAutomatica'] as bool?,
        organizacion: j['organizacion'] as String?,
      );
}

class FuncionPlan {
  const FuncionPlan({required this.funcion, required this.nombre, this.limite});

  final String funcion;
  final String nombre;
  final int? limite; // null = sin límite

  factory FuncionPlan.fromJson(Map<String, dynamic> j) =>
      FuncionPlan(funcion: j['funcion'] as String, nombre: j['nombre'] as String, limite: aEntero(j['limite']));
}

/// Respuesta de GET /planes/estado.
class EstadoPlan {
  const EstadoPlan({required this.premium, required this.fuentes, required this.funciones});

  final bool premium;
  final List<FuentePlan> fuentes;
  final List<FuncionPlan> funciones;

  factory EstadoPlan.fromJson(Map<String, dynamic> j) => EstadoPlan(
        premium: j['premium'] == true,
        fuentes: (j['fuentes'] as List).map((f) => FuentePlan.fromJson(f as Map<String, dynamic>)).toList(),
        funciones: (j['funciones'] as List).map((f) => FuncionPlan.fromJson(f as Map<String, dynamic>)).toList(),
      );
}

/// Estado vigente de un consentimiento (GET /consentimientos).
class Consentimiento {
  const Consentimiento({required this.tipo, required this.otorgado, this.fecha});

  final String tipo; // UBICACION o SALUD
  final bool otorgado;
  final DateTime? fecha;

  factory Consentimiento.fromJson(Map<String, dynamic> j) => Consentimiento(
        tipo: j['tipo'] as String,
        otorgado: j['otorgado'] == true,
        fecha: aFechaLocal(j['fecha']),
      );
}
