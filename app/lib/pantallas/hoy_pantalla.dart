import 'package:flutter/material.dart';

import '../api/api_cliente.dart';
import '../modelos/rutina.dart';
import '../tema.dart';
import 'sesion_pantalla.dart';

/// Pantalla 2 del prototipo: rutina activa y día a entrenar.
class HoyPantalla extends StatefulWidget {
  const HoyPantalla({super.key, required this.api});

  final ApiCliente api;

  @override
  State<HoyPantalla> createState() => _HoyPantallaState();
}

class _HoyPantallaState extends State<HoyPantalla> {
  late Future<Rutina?> _rutina;
  int _diaSeleccionado = 0;
  bool _generando = false;

  @override
  void initState() {
    super.initState();
    _rutina = widget.api.rutinaActiva();
  }

  void _recargar() {
    setState(() {
      _rutina = widget.api.rutinaActiva();
    });
  }

  Future<void> _generar() async {
    setState(() => _generando = true);
    try {
      await widget.api.generarRutinaSugerida();
      if (!mounted) return;
      _recargar();
    } on ApiExcepcion catch (e) {
      _aviso(e.mensaje);
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _empezar(DiaRutina dia) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SesionPantalla(api: widget.api, dia: dia)),
    );
    if (mounted) _recargar(); // la rutina puede haberse ajustado tras la sesión
  }

  void _aviso(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Rutina?>(
          future: _rutina,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _Mensaje(
                texto: 'No se pudo cargar la rutina: ${snap.error}',
                boton: 'Reintentar',
                alPulsar: _recargar,
              );
            }
            final rutina = snap.data;
            if (rutina == null || rutina.dias.isEmpty) {
              return _Mensaje(
                texto: 'Todavía no tienes una rutina activa.',
                boton: _generando ? 'Generando…' : 'Generar rutina sugerida',
                alPulsar: _generando ? null : _generar,
              );
            }
            return _contenido(context, rutina);
          },
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context, Rutina rutina) {
    final indice = _diaSeleccionado < rutina.dias.length ? _diaSeleccionado : 0;
    final dia = rutina.dias[indice];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        const Text(
          'HOY TOCA',
          style: TextStyle(color: Tema.acento, fontWeight: FontWeight.w600, letterSpacing: 1.2, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          dia.nombre,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${rutina.nombre} · ${dia.ejercicios.length} ejercicios · ${dia.totalSeries} series',
          style: const TextStyle(color: Tema.secundario),
        ),
        if (rutina.dias.length > 1) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < rutina.dias.length; i++)
                ChoiceChip(
                  label: Text(rutina.dias[i].nombre),
                  selected: i == indice,
                  onSelected: (_) => setState(() => _diaSeleccionado = i),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        for (final e in dia.ejercicios)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Tema.fondo,
                foregroundColor: Tema.tinta,
                child: Text('${e.orden}'),
              ),
              title: Text(e.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(e.objetivoTexto),
            ),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: dia.ejercicios.isEmpty ? null : () => _empezar(dia),
          child: const Text('Empezar sesión'),
        ),
      ],
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.texto, required this.boton, required this.alPulsar});

  final String texto;
  final String boton;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            FilledButton(onPressed: alPulsar, child: Text(boton)),
          ],
        ),
      ),
    );
  }
}
