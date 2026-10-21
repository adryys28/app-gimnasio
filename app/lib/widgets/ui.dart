import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema.dart';

/// Tarjeta base: superficie oscura con borde sutil.
class Tarjeta extends StatelessWidget {
  const Tarjeta({super.key, required this.child, this.padding = 16, this.radio = 22, this.gradiente, this.colorBorde});

  final Widget child;
  final double padding;
  final double radio;
  final Gradient? gradiente;
  final Color? colorBorde;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: gradiente == null ? Tema.tarjeta : null,
        gradient: gradiente,
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: colorBorde ?? Tema.linea),
      ),
      child: child,
    );
  }
}

/// Texto de etiqueta en mayúsculas.
class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key, this.color = Tema.secundario});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(texto.toUpperCase(), style: Tema.etiqueta(color: color));
}

/// Botón principal con brillo del color de acento.
class BotonBrillo extends StatelessWidget {
  const BotonBrillo({super.key, required this.texto, required this.onPressed, this.icono = Icons.arrow_forward});

  final String texto;
  final VoidCallback? onPressed;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: activo
            ? [BoxShadow(color: Tema.acento.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 10))]
            : const [],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(texto.toUpperCase(), style: Tema.titular(22, color: activo ? Tema.sobreAcento : Tema.secundario)),
            const SizedBox(width: 10),
            Icon(icono, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Píldora de texto con fondo translúcido del mismo color.
class Pildora extends StatelessWidget {
  const Pildora(this.texto, {super.key, this.color = Tema.acento});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
      child: Text(texto, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

/// Insignia de ajuste: texto e icono, no solo color.
class Insignia extends StatelessWidget {
  const Insignia({super.key, required this.accion});

  final String accion;

  @override
  Widget build(BuildContext context) {
    final (texto, icono, color, fondo) = switch (accion) {
      'SUBIR' => ('Sube', Icons.arrow_upward, Tema.acento, Tema.subeFondo),
      'BAJAR' => ('Baja', Icons.arrow_downward, Tema.baja, Tema.bajaFondo),
      'CALIBRAR' => ('Referencia', Icons.my_location, Tema.texto, Tema.mantieneFondo),
      _ => ('Se mantiene', Icons.drag_handle, Tema.secundario, Tema.mantieneFondo),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 4),
          Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Halo de luz decorativo (no recibe toques).
class Brillo extends StatelessWidget {
  const Brillo({super.key, this.color = Tema.acento, this.tamano = 360});

  final Color color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// Anillo de progreso con degradado lima-cian.
class AnilloProgreso extends StatelessWidget {
  const AnilloProgreso({super.key, required this.valor, required this.centro, this.tamano = 96, this.grosor = 10});

  final double valor; // 0..1
  final Widget centro;
  final double tamano;
  final double grosor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: CustomPaint(
        painter: _PintorAnillo(valor.clamp(0.0, 1.0).toDouble(), grosor),
        child: Center(child: centro),
      ),
    );
  }
}

class _PintorAnillo extends CustomPainter {
  _PintorAnillo(this.valor, this.grosor);

  final double valor;
  final double grosor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arco = rect.deflate(grosor / 2);
    final fondo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..color = Tema.superficie2;
    canvas.drawArc(arco, 0, math.pi * 2, false, fondo);
    if (valor <= 0) return;
    final progreso = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [Tema.acento, Tema.baja, Tema.acento],
      ).createShader(rect);
    canvas.drawArc(arco, -math.pi / 2, math.pi * 2 * valor, false, progreso);
  }

  @override
  bool shouldRepaint(_PintorAnillo old) => old.valor != valor || old.grosor != grosor;
}

/// Barras de volumen por día (lunes a domingo); el día actual en color de acento.
class BarrasSemana extends StatelessWidget {
  const BarrasSemana({super.key, required this.valores, required this.hoy, this.alto = 48});

  final List<double> valores;
  final int hoy; // 0 = lunes
  final double alto;

  static const _dias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final maximo = valores.fold<double>(0, math.max);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: maximo == 0 || i >= valores.length || valores[i] == 0
                      ? 4
                      : math.max(6, alto * valores[i] / maximo),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i < valores.length && valores[i] > 0
                        ? (i == hoy ? Tema.acento : Tema.acento.withValues(alpha: 0.45))
                        : Tema.superficie2,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(_dias[i], style: TextStyle(fontSize: 10, color: i == hoy ? Tema.acento : Tema.secundario)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Gráfico de línea con área degradada (progresión de pesos).
class GraficoLinea extends StatelessWidget {
  const GraficoLinea({super.key, required this.valores, this.alto = 96});

  final List<double> valores;
  final double alto;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: alto, width: double.infinity, child: CustomPaint(painter: _PintorLinea(valores)));
}

class _PintorLinea extends CustomPainter {
  _PintorLinea(this.valores);

  final List<double> valores;

  @override
  void paint(Canvas canvas, Size size) {
    if (valores.length < 2) return;
    final minimo = valores.reduce(math.min), maximo = valores.reduce(math.max);
    final rango = maximo - minimo == 0 ? 1 : maximo - minimo;
    const margen = 8.0;
    final puntos = [
      for (var i = 0; i < valores.length; i++)
        Offset(
          margen + (size.width - margen * 2) * i / (valores.length - 1),
          margen + (size.height - margen * 2) * (1 - (valores[i] - minimo) / rango),
        ),
    ];
    final guia = Paint()..color = Tema.superficie2;
    for (final f in [0.25, 0.6, 0.95]) {
      canvas.drawLine(Offset(0, size.height * f), Offset(size.width, size.height * f), guia);
    }
    final linea = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (final p in puntos.skip(1)) {
      linea.lineTo(p.dx, p.dy);
    }
    final area = Path.from(linea)
      ..lineTo(puntos.last.dx, size.height)
      ..lineTo(puntos.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Tema.acento.withValues(alpha: 0.35), Tema.acento.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      linea,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = Tema.acento,
    );
    for (final p in puntos.take(puntos.length - 1)) {
      canvas.drawCircle(p, 4, Paint()..color = Tema.acento);
    }
    canvas.drawCircle(puntos.last, 6, Paint()..color = Tema.fondo);
    canvas.drawCircle(
      puntos.last,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Tema.acento,
    );
  }

  @override
  bool shouldRepaint(_PintorLinea old) => old.valores != valores;
}

/// Barra de navegación flotante con la pestaña activa resaltada.
class NavFlotante extends StatelessWidget {
  const NavFlotante({super.key, required this.indice, required this.alCambiar});

  final int indice;
  final ValueChanged<int> alCambiar;

  static const _items = [
    (Icons.home_rounded, 'Hoy'),
    (Icons.monitor_heart_outlined, 'Cardio'),
    (Icons.fitness_center, 'Ejercicios'),
    (Icons.person_outline, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Container(
        height: 64,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Tema.tarjeta,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Tema.linea),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 12))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < _items.length; i++)
              Semantics(
                button: true,
                selected: i == indice,
                label: _items[i].$2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => alCambiar(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(horizontal: i == indice ? 16 : 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: i == indice ? Tema.acento : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_items[i].$1, size: 22, color: i == indice ? Tema.sobreAcento : Tema.secundario),
                        if (i == indice) ...[
                          const SizedBox(width: 8),
                          Text(
                            _items[i].$2,
                            style: const TextStyle(color: Tema.sobreAcento, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
