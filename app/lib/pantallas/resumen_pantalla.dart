import 'package:flutter/material.dart';

import '../modelos/rutina.dart';
import '../modelos/sesion.dart';
import '../tema.dart';

/// Pantalla 4 del prototipo: ajustes automáticos para la próxima sesión.
class ResumenPantalla extends StatelessWidget {
  const ResumenPantalla({super.key, required this.dia, required this.ajustes});

  final DiaRutina dia;
  final List<AjusteSesion> ajustes;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sesión completada'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(dia.nombre, style: const TextStyle(color: Tema.secundario)),
            const SizedBox(height: 16),
            if (ajustes.isEmpty)
              const Text('Sesión guardada. No hay ajustes automáticos para la próxima sesión.')
            else ...[
              Text('Así se ajusta tu próxima sesión', style: textos.titleLarge),
              const SizedBox(height: 8),
              for (final a in ajustes) _TarjetaAjuste(ajuste: a),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).popUntil((ruta) => ruta.isFirst),
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaAjuste extends StatelessWidget {
  const _TarjetaAjuste({required this.ajuste});

  final AjusteSesion ajuste;

  @override
  Widget build(BuildContext context) {
    final cambio = ajuste.cambioTexto;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(ajuste.ejercicio, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                _Insignia(accion: ajuste.accion),
              ],
            ),
            if (cambio.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(cambio, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 4),
            Text(ajuste.motivo, style: const TextStyle(color: Tema.secundario)),
          ],
        ),
      ),
    );
  }
}

/// El estado se indica con texto e icono, no solo con color.
class _Insignia extends StatelessWidget {
  const _Insignia({required this.accion});

  final String accion;

  @override
  Widget build(BuildContext context) {
    final (texto, icono, color, fondo) = switch (accion) {
      'SUBIR' => ('Sube', Icons.arrow_upward, Tema.sube, Tema.subeFondo),
      'BAJAR' => ('Baja', Icons.arrow_downward, Tema.baja, Tema.bajaFondo),
      'CALIBRAR' => ('Referencia', Icons.tune, Tema.mantiene, Tema.mantieneFondo),
      _ => ('Se mantiene', Icons.drag_handle, Tema.mantiene, Tema.mantieneFondo),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 4),
          Text(texto, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
