import 'package:flutter/material.dart';

import '../tema.dart';

/// Silueta corporal (frontal o posterior) con los grupos musculares resaltados.
/// Geometría en un lienzo de 120 × 240, igual que en el diseño de Figma.
class Silueta extends StatelessWidget {
  const Silueta({super.key, required this.musculos, this.secundarios = const [], this.posterior, this.ancho = 76});

  /// Nombres de grupos musculares del catálogo (Pecho, Espalda, Cuádriceps…).
  final List<String> musculos;

  /// Grupos secundarios: se resaltan con menos intensidad.
  final List<String> secundarios;

  /// null = elige la vista donde se ven más músculos resaltados.
  final bool? posterior;
  final double ancho;

  static const _frontal = {
    'Pecho': 'pecho', 'Hombros': 'hombros', 'Bíceps': 'biceps', 'Antebrazos': 'antebrazos', 'Core': 'abdomen',
    'Oblicuos': 'oblicuos', 'Cuádriceps': 'cuadriceps', 'Aductores': 'cuadriceps', 'Gemelos': 'gemelos',
  };
  static const _posterior = {
    'Trapecio': 'trapecio', 'Hombros': 'hombros', 'Espalda': 'espalda', 'Tríceps': 'triceps', 'Antebrazos': 'antebrazos',
    'Lumbares': 'lumbares', 'Glúteos': 'gluteos', 'Isquiotibiales': 'isquios', 'Gemelos': 'gemelos',
  };

  bool get _vistaPosterior {
    if (posterior != null) return posterior!;
    const compartidos = {'Hombros', 'Antebrazos', 'Gemelos'};
    final delante = musculos.where((m) => _frontal.containsKey(m) && !compartidos.contains(m)).length;
    final detras = musculos.where((m) => _posterior.containsKey(m) && !compartidos.contains(m)).length;
    return detras > delante;
  }

  @override
  Widget build(BuildContext context) {
    final atras = _vistaPosterior;
    final mapa = atras ? _posterior : _frontal;
    final zonas = {for (final m in musculos) if (mapa[m] != null) mapa[m]!};
    final zonasSec = {for (final m in secundarios) if (mapa[m] != null) mapa[m]!}..removeAll(zonas);
    return Semantics(
      label: 'Músculos trabajados: ${musculos.join(', ')}'
          '${secundarios.isEmpty ? '' : '; secundarios: ${secundarios.join(', ')}'}',
      child: SizedBox(
        width: ancho,
        height: ancho * 2,
        child: CustomPaint(painter: _PintorSilueta(zonas, zonasSec, atras)),
      ),
    );
  }
}

class _PintorSilueta extends CustomPainter {
  _PintorSilueta(this.zonas, this.secundarias, this.posterior);

  final Set<String> zonas;
  final Set<String> secundarias;
  final bool posterior;

  static const _apagado = Color(0xFF2A2E36);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120, size.height / 240);
    Paint p(String? zona) => Paint()
      ..color = zona == null
          ? _apagado
          : zonas.contains(zona)
              ? Tema.acento
              : secundarias.contains(zona)
                  ? Tema.acento.withValues(alpha: 0.4)
                  : _apagado;
    void ovalo(double cx, double cy, double rx, double ry, String? z) =>
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2), p(z));
    void bloque(double x, double y, double w, double h, double r, String? z) =>
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)), p(z));
    void forma(List<Offset> puntos, String? z) => canvas.drawPath(Path()..addPolygon(puntos, true), p(z));

    canvas.drawCircle(const Offset(60, 18), 12, p(null));
    ovalo(36, 50, 11, 9, 'hombros');
    ovalo(84, 50, 11, 9, 'hombros');
    ovalo(25, 111, 6, 17, 'antebrazos');
    ovalo(95, 111, 6, 17, 'antebrazos');
    bloque(45, 192, 12, 40, 6, 'gemelos');
    bloque(63, 192, 12, 40, 6, 'gemelos');

    if (!posterior) {
      bloque(54, 30, 12, 8, 3, null);
      forma(const [Offset(47, 44), Offset(59, 44), Offset(59, 68), Offset(46, 66)], 'pecho');
      forma(const [Offset(61, 44), Offset(73, 44), Offset(74, 66), Offset(61, 68)], 'pecho');
      ovalo(30, 77, 7, 15, 'biceps');
      ovalo(90, 77, 7, 15, 'biceps');
      bloque(50, 72, 20, 44, 6, 'abdomen');
      forma(const [Offset(44, 74), Offset(48, 74), Offset(48, 114), Offset(42, 108)], 'oblicuos');
      forma(const [Offset(76, 74), Offset(72, 74), Offset(72, 114), Offset(78, 108)], 'oblicuos');
      forma(const [Offset(44, 118), Offset(76, 118), Offset(74, 132), Offset(46, 132)], null);
      bloque(44, 134, 14, 52, 7, 'cuadriceps');
      bloque(62, 134, 14, 52, 7, 'cuadriceps');
    } else {
      final trapecio = Path()
        ..moveTo(46, 38)
        ..quadraticBezierTo(60, 30, 74, 38)
        ..lineTo(70, 56)
        ..lineTo(60, 62)
        ..lineTo(50, 56)
        ..close();
      canvas.drawPath(trapecio, p('trapecio'));
      forma(const [Offset(46, 58), Offset(60, 64), Offset(74, 58), Offset(76, 92), Offset(64, 104), Offset(56, 104), Offset(44, 92)], 'espalda');
      ovalo(30, 77, 7, 15, 'triceps');
      ovalo(90, 77, 7, 15, 'triceps');
      bloque(52, 104, 16, 13, 4, 'lumbares');
      final gluteos = Path()
        ..moveTo(44, 120)
        ..lineTo(76, 120)
        ..lineTo(76, 136)
        ..quadraticBezierTo(60, 146, 44, 136)
        ..close();
      canvas.drawPath(gluteos, p('gluteos'));
      bloque(44, 142, 14, 46, 7, 'isquios');
      bloque(62, 142, 14, 46, 7, 'isquios');
    }
  }

  @override
  bool shouldRepaint(_PintorSilueta old) =>
      old.zonas != zonas || old.secundarias != secundarias || old.posterior != posterior;
}
