import 'package:flutter/material.dart';

import '../api/api_cliente.dart';
import '../modelos/actividad.dart';
import '../modelos/formato.dart';
import '../tema.dart';
import '../widgets/mapa_ruta.dart';

/// Resultado de una actividad: ruta, datos generales y tiempos exactos entre km.
class ActividadPantalla extends StatefulWidget {
  const ActividadPantalla({super.key, required this.api, required this.actividadId});

  final ApiCliente api;
  final int actividadId;

  @override
  State<ActividadPantalla> createState() => _ActividadPantallaState();
}

class _ActividadPantallaState extends State<ActividadPantalla> {
  late final Future<ActividadDetalle> _detalle = widget.api.actividad(widget.actividadId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Actividad')),
      body: FutureBuilder<ActividadDetalle>(
        future: _detalle,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('No se pudo cargar la actividad: ${snap.error}'));
          return _Contenido(a: snap.data!);
        },
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.a});

  final ActividadDetalle a;

  String _metros(double? m) => m == null ? '–' : '${m.round()} m';

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final velocidad = a.velocidadMediaKmh;
    final kcal = a.kcal;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(a.tipo, style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        if (a.fechaInicio != null)
          Text(formatearFechaHora(a.fechaInicio!), style: const TextStyle(color: Tema.secundario)),
        const SizedBox(height: 12),
        if (a.ruta.isNotEmpty) ...[
          MapaRuta(tramos: a.ruta),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Dato('Distancia', a.distanciaM == null ? '–' : formatearDistancia(a.distanciaM!)),
            _Dato('En movimiento', a.duracionMovTxt ?? '–'),
            _Dato('Tiempo total', a.duracionTotalTxt ?? '–'),
            _Dato('Ritmo medio', a.ritmoMedioTxt == null ? '–' : '${a.ritmoMedioTxt} /km'),
            _Dato('Velocidad media', velocidad == null ? '–' : '${formatearNumero(velocidad)} km/h'),
            _Dato('Desnivel', '+${_metros(a.desnivelPosM)} / −${_metros(a.desnivelNegM)}'),
            if (a.fcMedia != null) _Dato('Pulsaciones', '${a.fcMedia} media · ${a.fcMax} máx.'),
            if (kcal != null) _Dato('Calorías (aprox.)', '$kcal kcal', nota: a.fuenteKcalTexto),
          ],
        ),
        if (a.parciales.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Parciales', style: textos.titleMedium),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Km')),
                DataColumn(label: Text('Tiempo')),
                DataColumn(label: Text('Ritmo')),
                DataColumn(label: Text('Desnivel')),
                DataColumn(label: Text('FC')),
              ],
              rows: [
                for (final p in a.parciales)
                  DataRow(cells: [
                    DataCell(Text(p.etiqueta)),
                    DataCell(Text(p.duracionTxt ?? '–')),
                    DataCell(Text(p.ritmoTxt == null ? '–' : '${p.ritmoTxt} /km')),
                    DataCell(Text('+${_metros(p.desnivelPosM)}')),
                    DataCell(Text(p.fcMedia?.toString() ?? '–')),
                  ]),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor, {this.nota});

  final String etiqueta;
  final String valor;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 165,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Tema.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(fontSize: 12, color: Tema.secundario)),
          const SizedBox(height: 2),
          Text(valor, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          if ((nota ?? '').isNotEmpty) Text(nota!, style: const TextStyle(fontSize: 11, color: Tema.secundario)),
        ],
      ),
    );
  }
}
