import 'package:flutter/material.dart';

import '../api/api_cliente.dart';
import '../modelos/rutina.dart';
import '../tema.dart';
import 'resumen_pantalla.dart';

/// Pantalla 3 del prototipo: registro de series con repeticiones o tiempo, peso y RPE.
class SesionPantalla extends StatefulWidget {
  const SesionPantalla({super.key, required this.api, required this.dia});

  final ApiCliente api;
  final DiaRutina dia;

  @override
  State<SesionPantalla> createState() => _SesionPantallaState();
}

class _SesionPantallaState extends State<SesionPantalla> {
  // Escala RPE basada en repeticiones en reserva
  static const _descripcionRpe = {
    6: 'Te quedaban 4 o más repeticiones',
    7: 'Te quedaban 3 repeticiones',
    8: 'Te quedaban 2 repeticiones',
    9: 'Te quedaba 1 repetición',
    10: 'No podías hacer ni una repetición más',
  };

  int? _sesionId;
  String? _error;
  bool _ocupado = false;

  int _indice = 0;
  int _serie = 1;
  int _reps = 10;
  int _duracion = 30;
  int _peso = 0; // 0 = sin carga (se envía null para no alterar la progresión por repeticiones)
  int _rpe = 8;
  final List<String> _registradas = [];

  List<EjercicioRutina> get _ejercicios => widget.dia.ejercicios;
  bool get _terminado => _indice >= _ejercicios.length;

  @override
  void initState() {
    super.initState();
    _cargarValores();
    _iniciar();
  }

  void _cargarValores() {
    _serie = 1;
    _registradas.clear();
    if (_terminado) return;
    final e = _ejercicios[_indice];
    _reps = e.repsMin ?? 10;
    _duracion = e.duracionSegMin ?? 30;
    _peso = e.pesoObjetivoKg?.round() ?? 0;
  }

  Future<void> _iniciar() async {
    try {
      final id = await widget.api.iniciarSesion(widget.dia.rutinaDiaId);
      if (mounted) setState(() => _sesionId = id);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo conectar con el servidor.');
    }
  }

  Future<void> _guardarSerie() async {
    final id = _sesionId;
    if (id == null || _terminado) return;
    final e = _ejercicios[_indice];

    setState(() => _ocupado = true);
    try {
      await widget.api.registrarSerie(
        sesionId: id,
        ejercicioId: e.ejercicioId,
        reps: e.porTiempo ? null : _reps,
        duracionSeg: e.porTiempo ? _duracion : null,
        pesoKg: _peso > 0 ? _peso.toDouble() : null,
        rpe: _rpe.toDouble(),
      );
      if (!mounted) return;
      setState(() {
        final medida = e.porTiempo ? '$_duracion s' : '$_reps reps';
        final carga = _peso > 0 ? ' · $_peso kg' : '';
        _registradas.add('Serie $_serie: $medida$carga · RPE $_rpe');
        if (_serie >= e.series) {
          _indice++;
          _cargarValores();
        } else {
          _serie++;
        }
      });
    } on ApiExcepcion catch (err) {
      _aviso(err.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _saltar() => setState(() {
        _indice++;
        _cargarValores();
      });

  Future<void> _finalizar() async {
    final id = _sesionId;
    if (id == null) return;
    setState(() => _ocupado = true);
    try {
      final ajustes = await widget.api.finalizarSesion(id);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ResumenPantalla(dia: widget.dia, ajustes: ajustes)),
      );
    } on ApiExcepcion catch (err) {
      _aviso(err.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _aviso(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.dia.nombre)),
      body: SafeArea(child: _cuerpo(context)),
    );
  }

  Widget _cuerpo(BuildContext context) {
    final error = _error;
    if (error != null) return Center(child: Text(error, textAlign: TextAlign.center));
    if (_sesionId == null) return const Center(child: CircularProgressIndicator());

    if (_terminado) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Tema.acento, size: 48),
            const SizedBox(height: 12),
            const Text('Has completado todos los ejercicios', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            FilledButton(onPressed: _ocupado ? null : _finalizar, child: const Text('Finalizar sesión')),
          ],
        ),
      );
    }

    final e = _ejercicios[_indice];
    final textos = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Ejercicio ${_indice + 1} de ${_ejercicios.length}', style: const TextStyle(color: Tema.secundario)),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: _indice / _ejercicios.length, color: Tema.acento),
        const SizedBox(height: 16),
        Text(e.nombre, style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        Text('Objetivo: ${e.objetivoTexto}', style: const TextStyle(color: Tema.secundario)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Serie $_serie de ${e.series}', style: textos.titleLarge),
                const SizedBox(height: 8),
                if (e.porTiempo)
                  _Paso(
                    etiqueta: 'Duración',
                    valor: '$_duracion s',
                    alRestar: () => setState(() => _duracion = (_duracion - 5).clamp(5, 3600).toInt()),
                    alSumar: () => setState(() => _duracion = (_duracion + 5).clamp(5, 3600).toInt()),
                  )
                else
                  _Paso(
                    etiqueta: 'Repeticiones',
                    valor: '$_reps',
                    alRestar: () => setState(() => _reps = (_reps - 1).clamp(1, 100).toInt()),
                    alSumar: () => setState(() => _reps = (_reps + 1).clamp(1, 100).toInt()),
                  ),
                _Paso(
                  etiqueta: 'Peso',
                  valor: _peso == 0 ? 'Sin carga' : '$_peso kg',
                  alRestar: () => setState(() => _peso = (_peso - 1).clamp(0, 1000).toInt()),
                  alSumar: () => setState(() => _peso = (_peso + 1).clamp(0, 1000).toInt()),
                ),
                const SizedBox(height: 12),
                const Text('¿Cuánto esfuerzo te ha costado? (RPE)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final valor in _descripcionRpe.keys)
                      ChoiceChip(
                        label: Text('$valor'),
                        selected: valor == _rpe,
                        onSelected: (_) => setState(() => _rpe = valor),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('RPE $_rpe: ${_descripcionRpe[_rpe]}', style: const TextStyle(color: Tema.secundario)),
                const SizedBox(height: 16),
                FilledButton(onPressed: _ocupado ? null : _guardarSerie, child: const Text('Guardar serie')),
              ],
            ),
          ),
        ),
        if (_registradas.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Series registradas', style: textos.titleMedium),
          for (final r in _registradas) ListTile(dense: true, leading: const Icon(Icons.check), title: Text(r)),
        ],
        const SizedBox(height: 8),
        TextButton(onPressed: _ocupado ? null : _saltar, child: const Text('Saltar ejercicio')),
        OutlinedButton(onPressed: _ocupado ? null : _finalizar, child: const Text('Finalizar sesión')),
      ],
    );
  }
}

/// Control de +/- con botones de 48 px y descripción accesible.
class _Paso extends StatelessWidget {
  const _Paso({required this.etiqueta, required this.valor, required this.alRestar, required this.alSumar});

  final String etiqueta;
  final String valor;
  final VoidCallback alRestar;
  final VoidCallback alSumar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: const TextStyle(fontSize: 16))),
          IconButton.outlined(onPressed: alRestar, icon: const Icon(Icons.remove), tooltip: 'Restar $etiqueta'),
          SizedBox(
            width: 96,
            child: Text(
              valor,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton.outlined(onPressed: alSumar, icon: const Icon(Icons.add), tooltip: 'Sumar $etiqueta'),
        ],
      ),
    );
  }
}
