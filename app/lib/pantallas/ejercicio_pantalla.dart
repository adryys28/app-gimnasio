import 'package:flutter/material.dart';

import '../api/api_cliente.dart';
import '../modelos/catalogo.dart';
import '../tema.dart';

/// Pantalla 7 del prototipo: detalle de un ejercicio.
class EjercicioPantalla extends StatelessWidget {
  const EjercicioPantalla({super.key, required this.api, required this.ejercicioId});

  final ApiCliente api;
  final int ejercicioId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<EjercicioDetalle>(
        future: api.ejercicio(ejercicioId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('No se pudo cargar el ejercicio: ${snap.error}'));
          return _Contenido(detalle: snap.data!);
        },
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.detalle});

  final EjercicioDetalle detalle;

  @override
  Widget build(BuildContext context) {
    final e = detalle.ejercicio;
    final textos = Theme.of(context).textTheme;
    final errores = (e.erroresComunes ?? '')
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // La reproducción de vídeo se añadirá cuando estén grabados los vídeos
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(color: Tema.tinta, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
                const SizedBox(height: 8),
                Text(
                  e.videoUrl == null ? 'Vídeo de técnica pendiente' : 'Vídeo de técnica',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(e.nombre, style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Chip(label: Text(e.medidaTexto)),
            for (final m in detalle.materiales) Chip(label: Text(m)),
          ],
        ),
        if (detalle.musculos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Músculos', style: textos.titleMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in detalle.musculos)
                Chip(
                  avatar: Icon(m.esPrincipal ? Icons.star : Icons.star_border, size: 16),
                  label: Text('${m.nombre} · ${m.esPrincipal ? 'principal' : 'secundario'}'),
                ),
            ],
          ),
        ],
        if ((e.descripcion ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Cómo se hace', style: textos.titleMedium),
          const SizedBox(height: 6),
          Text(e.descripcion!),
        ],
        if (errores.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Errores comunes', style: textos.titleMedium),
          for (final err in errores)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warning_amber, color: Tema.sube),
              title: Text(err),
            ),
        ],
      ],
    );
  }
}
