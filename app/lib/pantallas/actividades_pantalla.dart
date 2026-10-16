import 'package:flutter/material.dart';

import '../api/api_cliente.dart';
import '../modelos/actividad.dart';
import '../modelos/formato.dart';
import '../tema.dart';
import 'actividad_pantalla.dart';

/// Historial de actividades de cardio.
class ActividadesPantalla extends StatefulWidget {
  const ActividadesPantalla({super.key, required this.api});

  final ApiCliente api;

  @override
  State<ActividadesPantalla> createState() => _ActividadesPantallaState();
}

class _ActividadesPantallaState extends State<ActividadesPantalla> {
  late Future<Historial> _historial;

  @override
  void initState() {
    super.initState();
    _historial = widget.api.actividades();
  }

  Future<void> _recargar() async {
    final nuevo = widget.api.actividades();
    setState(() {
      _historial = nuevo;
    });
    await nuevo;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cardio')),
      body: FutureBuilder<Historial>(
        future: _historial,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('No se pudo cargar el historial: ${snap.error}'));
          }
          final historial = snap.data!;
          return RefreshIndicator(
            onRefresh: _recargar,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (historial.actividades.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: Text('Todavía no hay actividades registradas.')),
                  ),
                for (final a in historial.actividades) _Fila(api: widget.api, actividad: a),
                if (historial.ocultasPorPlan > 0) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Tema.subeFondo,
                    child: ListTile(
                      leading: const Icon(Icons.lock_outline, color: Tema.sube),
                      title: Text(
                        historial.ocultasPorPlan == 1
                            ? 'Tienes 1 actividad anterior visible con Premium.'
                            : 'Tienes ${historial.ocultasPorPlan} actividades anteriores visibles con Premium.',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.api, required this.actividad});

  final ApiCliente api;
  final ActividadResumen actividad;

  @override
  Widget build(BuildContext context) {
    final a = actividad;
    final distancia = a.distanciaM == null ? '' : ' · ${formatearDistancia(a.distanciaM!)}';
    final detalles = [
      if (a.fechaInicio != null) formatearFechaHora(a.fechaInicio!),
      if (a.duracionMovTxt != null) a.duracionMovTxt!,
      if (a.ritmoMedioTxt != null) '${a.ritmoMedioTxt} /km',
    ].join(' · ');

    return Card(
      child: ListTile(
        leading: const Icon(Icons.directions_run, color: Tema.acento),
        title: Text('${a.tipo}$distancia', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(detalles),
        trailing: a.kcal == null ? null : Text('${a.kcal} kcal'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ActividadPantalla(api: api, actividadId: a.actividadId)),
        ),
      ),
    );
  }
}
