import 'package:flutter/material.dart';

import '../api/api_cliente.dart';
import '../modelos/rutina.dart';
import 'cuestionario_pantalla.dart';
import 'inicio_pantalla.dart';

/// Primera pantalla: si la persona no tiene rutina activa, empieza por el cuestionario.
class ArranquePantalla extends StatefulWidget {
  const ArranquePantalla({super.key, required this.api});

  final ApiCliente api;

  @override
  State<ArranquePantalla> createState() => _ArranquePantallaState();
}

class _ArranquePantallaState extends State<ArranquePantalla> {
  late final Future<Rutina?> _rutina = widget.api.rutinaActiva();
  bool _cuestionarioHecho = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Rutina?>(
      future: _rutina,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // Con error de conexión se entra igualmente: la pantalla Hoy permite reintentar
        final sinRutina = !snap.hasError && snap.data == null;
        if (sinRutina && !_cuestionarioHecho) {
          return CuestionarioPantalla(api: widget.api, alTerminar: () => setState(() => _cuestionarioHecho = true));
        }
        return InicioPantalla(api: widget.api);
      },
    );
  }
}
