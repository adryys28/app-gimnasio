import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../tema.dart';

/// Mapa con la ruta de una actividad, encuadrado automáticamente.
class MapaRuta extends StatelessWidget {
  const MapaRuta({super.key, required this.tramos, this.alto = 260});

  final List<List<LatLng>> tramos;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final puntos = [for (final t in tramos) ...t];
    if (puntos.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: alto,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(puntos),
              padding: const EdgeInsets.all(32),
              maxZoom: 17, // evita un zoom extremo si la ruta es muy corta
            ),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(urlTemplate: Config.urlTeselas, userAgentPackageName: Config.identificadorApp),
            PolylineLayer(
              polylines: [
                for (final t in tramos) Polyline(points: t, strokeWidth: 4, color: Tema.acento),
              ],
            ),
            RichAttributionWidget(
              attributions: [TextSourceAttribution('OpenStreetMap contributors')],
            ),
          ],
        ),
      ),
    );
  }
}
