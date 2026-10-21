import 'package:flutter/material.dart';

import '../api/api_cliente.dart';
import '../modelos/entrenamiento.dart';
import '../modelos/formato.dart';
import '../modelos/recomendaciones.dart';
import '../modelos/rutina.dart';
import '../tema.dart';
import '../widgets/ui.dart';
import 'ejercicio_pantalla.dart';
import 'resumen_pantalla.dart';

/// Sesión en curso (diseño V2): cifras grandes, seguimiento por series y RPE en barra degradada.
class SesionPantalla extends StatefulWidget {
  const SesionPantalla({super.key, required this.api, required this.dia, this.nivelId = 1, this.objetivoId = 2});

  final ApiCliente api;
  final DiaRutina dia;

  /// Nivel (1-3) y objetivo (1 fuerza, 2 músculo, 3 perder grasa) para las recomendaciones.
  final int nivelId;
  final int objetivoId;

  @override
  State<SesionPantalla> createState() => _SesionPantallaState();
}

class _SesionPantallaState extends State<SesionPantalla> {
  // Escala RPE basada en repeticiones en reserva
  static const _descripcionRpe = {
    6: 'Te quedaban 4 o más repeticiones en reserva',
    7: 'Te quedaban 3 repeticiones en reserva',
    8: 'Te quedaban 2 repeticiones en reserva',
    9: 'Te quedaba 1 repetición en reserva',
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
  String _tipo = 'N';
  final _notas = TextEditingController();
  final List<_SerieHecha> _hechas = [];

  // Series de trabajo de este ejercicio en esta sesión (la persona puede añadir o quitar)
  int _total = 3;
  int _calentamientosHechos = 0;
  int _pesoTrabajo = 0;
  int _repsTrabajo = 10;
  final Map<int, int> _seriesGuardadas = {}; // RutinaDiaEjercicioId -> series guardadas en la rutina

  List<EjercicioRutina> get _ejercicios => widget.dia.ejercicios;
  bool get _terminado => _indice >= _ejercicios.length;

  @override
  void initState() {
    super.initState();
    _cargarValores();
    _iniciar();
  }

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  void _cargarValores() {
    _serie = 1;
    _tipo = 'N';
    _hechas.clear();
    if (_terminado) return;
    final e = _ejercicios[_indice];
    _reps = e.repsMin ?? 10;
    _duracion = e.duracionSegMin ?? 30;
    _peso = e.pesoObjetivoKg?.round() ?? 0;
    _total = _seriesGuardadas[e.rutinaDiaEjercicioId] ?? e.series;
    _calentamientosHechos = 0;
    _pesoTrabajo = _peso;
    _repsTrabajo = _reps;
  }

  /* ---------- Recomendaciones ---------- */

  PlanCalentamiento? get _planCalentamiento => _terminado
      ? null
      : calentamientoRecomendado(
          _ejercicios[_indice],
          hayCompuestoAnterior: _ejercicios.take(_indice).any((x) => x.compuesto && !x.porTiempo),
        );

  bool get _tocaCalentar {
    final plan = _planCalentamiento;
    return plan != null && _calentamientosHechos < plan.series.length && _serie == 1;
  }

  /// (código de tipo de serie, texto del consejo)
  (String, String) get _recomendacion {
    final e = _ejercicios[_indice];
    final plan = _planCalentamiento;
    if (_tocaCalentar) {
      final s = plan!.series[_calentamientosHechos];
      return ('C', 'Calentamiento ${_calentamientosHechos + 1} de ${plan.series.length}: ${s.texto}. ${plan.motivo}');
    }
    final (codigo, motivo) = recomendarTipoSerie(
      nivel: widget.nivelId,
      objetivo: widget.objetivoId,
      compuesto: e.compuesto,
      porTiempo: e.porTiempo,
      serie: _serie,
      totalSeries: _total,
    );
    final previo = plan == null && _serie == 1 && _hechas.isEmpty
        ? ' ${consejoSinCalentamiento(primerEjercicio: _indice == 0)}'
        : '';
    return (codigo, '$motivo$previo');
  }

  void _aplicarRecomendacion() {
    final (codigo, _) = _recomendacion;
    setState(() {
      _tipo = codigo;
      if (codigo == 'C') {
        final s = _planCalentamiento!.series[_calentamientosHechos];
        _reps = s.reps;
        _peso = s.pesoKg ?? 0;
      } else {
        _reps = _repsTrabajo;
        _peso = _pesoTrabajo;
        if (codigo == 'F') _rpe = 10;
      }
    });
  }

  Future<void> _guardarSeriesEnRutina() async {
    final e = _ejercicios[_indice];
    try {
      await widget.api.configurarSeries(e.rutinaDiaEjercicioId, _total);
      if (!mounted) return;
      setState(() => _seriesGuardadas[e.rutinaDiaEjercicioId] = _total);
      _aviso('Guardado: ${e.nombre} tendrá $_total series en tu rutina.');
    } on ApiExcepcion catch (err) {
      _aviso(err.mensaje);
    }
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
        tipoSerie: _tipo,
        notas: _notas.text.trim().isEmpty ? null : _notas.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        final medida = e.porTiempo ? '$_duracion s' : '$_reps reps';
        _hechas.add(_SerieHecha(
          tipo: TipoSerie.porCodigo(_tipo),
          detalle: '$medida${_peso > 0 ? ' · $_peso kg' : ''} · RPE $_rpe',
          notas: _notas.text.trim(),
        ));
        _notas.clear();
        // El calentamiento no consume series de trabajo; después se recuperan peso y repeticiones de trabajo
        if (_tipo == 'C') {
          _calentamientosHechos++;
          _tipo = 'N';
          _peso = _pesoTrabajo;
          _reps = _repsTrabajo;
          return;
        }
        _tipo = 'N';
        _pesoTrabajo = _peso;
        _repsTrabajo = _reps;
        if (_serie >= _total) {
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
        MaterialPageRoute<void>(
          builder: (_) => ResumenPantalla(api: widget.api, sesionId: id, dia: widget.dia, ajustes: ajustes),
        ),
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
    final error = _error;
    if (error != null) return Scaffold(appBar: AppBar(), body: Center(child: Text(error, textAlign: TextAlign.center)));
    if (_sesionId == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_terminado) return _pantallaTerminada();

    final e = _ejercicios[_indice];
    final objetivo = '${e.porTiempo ? '${rango(e.duracionSegMin, e.duracionSegMax)} s' : rango(e.repsMin, e.repsMax)}'
        '${e.pesoObjetivoKg == null ? '' : ' · ${formatearNumero(e.pesoObjetivoKg!)} kg'}';

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Cabecera(
            etiqueta: 'Ejercicio ${_indice + 1} de ${_ejercicios.length}',
            nombre: e.nombre,
            musculos: textoMusculos(e.principales, e.secundarios),
            alCerrar: () => Navigator.of(context).maybePop(),
            alVerTecnica: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => EjercicioPantalla(api: widget.api, ejercicioId: e.ejercicioId))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Serie $_serie de $_total'.toUpperCase(), style: Tema.titular(22))),
                    IconButton(
                      onPressed: _total > _serie ? () => setState(() => _total--) : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: 'Quitar una serie',
                    ),
                    IconButton(
                      onPressed: _total < 20 ? () => setState(() => _total++) : null,
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Añadir una serie',
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text('Objetivo $objetivo', style: const TextStyle(color: Tema.secundario, fontSize: 12)),
                    ),
                    if (_total != (_seriesGuardadas[e.rutinaDiaEjercicioId] ?? e.series))
                      TextButton.icon(
                        onPressed: _guardarSeriesEnRutina,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: Text('Guardar $_total series en mi rutina'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 1; i <= _total; i++) ...[
                      if (i > 1) const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: i < _serie
                                ? Tema.acento
                                : i == _serie
                                    ? Tema.acento.withValues(alpha: 0.55)
                                    : Tema.superficie2,
                            boxShadow: i == _serie
                                ? [BoxShadow(color: Tema.acento.withValues(alpha: 0.6), blurRadius: 10)]
                                : const [],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: e.porTiempo
                          ? _Entrada(
                              etiqueta: 'Segundos',
                              valor: '$_duracion',
                              alRestar: () => setState(() => _duracion = (_duracion - 5).clamp(5, 3600).toInt()),
                              alSumar: () => setState(() => _duracion = (_duracion + 5).clamp(5, 3600).toInt()),
                            )
                          : _Entrada(
                              etiqueta: 'Repeticiones',
                              valor: '$_reps',
                              alRestar: () => setState(() => _reps = (_reps - 1).clamp(1, 100).toInt()),
                              alSumar: () => setState(() => _reps = (_reps + 1).clamp(1, 100).toInt()),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Entrada(
                        etiqueta: 'Kilos',
                        valor: _peso == 0 ? '—' : '$_peso',
                        alRestar: () => setState(() => _peso = (_peso - 1).clamp(0, 1000).toInt()),
                        alSumar: () => setState(() => _peso = (_peso + 1).clamp(0, 1000).toInt()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Tarjeta(
                  radio: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Etiqueta('Esfuerzo (RPE)')),
                          Text('$_rpe', style: Tema.numero(30, color: Tema.acento)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _SelectorRpe(valor: _rpe, alCambiar: (v) => setState(() => _rpe = v)),
                      const SizedBox(height: 10),
                      Text(_descripcionRpe[_rpe]!, style: const TextStyle(color: Tema.secundario, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Tarjeta(
                  radio: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Recomendacion(
                        texto: _recomendacion.$2,
                        tipo: TipoSerie.porCodigo(_recomendacion.$1),
                        aplicada: _tipo == _recomendacion.$1,
                        alAplicar: _aplicarRecomendacion,
                      ),
                      const SizedBox(height: 14),
                      const Etiqueta('Tipo de serie'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in TipoSerie.todos)
                            ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(t.nombre),
                                  if (t.codigo == _recomendacion.$1) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.auto_awesome, size: 14, semanticLabel: 'recomendado'),
                                  ],
                                ],
                              ),
                              selected: _tipo == t.codigo,
                              onSelected: (_) => setState(() {
                                _tipo = t.codigo;
                                if (t.codigo == 'F') _rpe = 10; // al fallo equivale a RPE 10
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(TipoSerie.porCodigo(_tipo).descripcion, style: const TextStyle(color: Tema.secundario, fontSize: 13)),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _notas,
                        maxLength: 500,
                        minLines: 1,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Notas de la serie (opcional)',
                          hintText: 'Sensaciones, ajustes de peso, técnica…',
                          prefixIcon: Icon(Icons.edit_note),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                BotonBrillo(
                  texto: _tipo == 'C' ? 'Calentamiento hecho' : 'Serie completada',
                  onPressed: _ocupado ? null : _guardarSerie,
                  icono: Icons.check,
                ),
                if (_hechas.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Etiqueta('Series registradas'),
                  const SizedBox(height: 8),
                  for (final h in _hechas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Tarjeta(
                        padding: 12,
                        radio: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Pildora(h.tipo.nombre, color: h.tipo.codigo == 'C' ? Tema.secundario : Tema.acento),
                                const SizedBox(width: 8),
                                Expanded(child: Text(h.detalle, style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                            if (h.notas.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(h.notas, style: const TextStyle(color: Tema.secundario, fontSize: 13, fontStyle: FontStyle.italic)),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(onPressed: _ocupado ? null : _saltar, child: const Text('Saltar ejercicio')),
                    TextButton(onPressed: _ocupado ? null : _finalizar, child: const Text('Finalizar sesión')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pantallaTerminada() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Tema.acento),
                child: const Icon(Icons.check, size: 40, color: Tema.sobreAcento),
              ),
              const SizedBox(height: 20),
              Text('¡Todo hecho!'.toUpperCase(), textAlign: TextAlign.center, style: Tema.hero(48)),
              const SizedBox(height: 8),
              const Text('Has completado todos los ejercicios.', textAlign: TextAlign.center, style: TextStyle(color: Tema.secundario)),
              const SizedBox(height: 28),
              BotonBrillo(texto: 'Finalizar sesión', onPressed: _ocupado ? null : _finalizar),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabecera del ejercicio con acceso a la demostración de la técnica.
class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.etiqueta,
    required this.nombre,
    required this.alCerrar,
    required this.alVerTecnica,
    this.musculos = '',
  });

  final String etiqueta;
  final String nombre;
  final VoidCallback alCerrar;
  final VoidCallback alVerTecnica;
  final String musculos;

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.of(context).padding.top;
    return Container(
      height: 220 + arriba,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF20301A), Tema.fondo]),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: arriba - 10,
            child: Icon(Icons.fitness_center, size: 200, color: Tema.acento.withValues(alpha: 0.07)),
          ),
          Positioned(
            top: arriba + 8,
            left: 16,
            child: IconButton.filledTonal(onPressed: alCerrar, icon: const Icon(Icons.close), tooltip: 'Salir de la sesión'),
          ),
          Positioned(
            top: arriba + 8,
            right: 16,
            child: FilledButton.tonalIcon(
              onPressed: alVerTecnica,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Cómo se hace'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Etiqueta(etiqueta, color: Tema.acento),
                const SizedBox(height: 6),
                Text(nombre.toUpperCase(), style: Tema.titular(36)),
                if (musculos.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(musculos, style: const TextStyle(color: Tema.texto, fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Entrada numérica grande con botones de restar y sumar.
class _Entrada extends StatelessWidget {
  const _Entrada({required this.etiqueta, required this.valor, required this.alRestar, required this.alSumar});

  final String etiqueta;
  final String valor;
  final VoidCallback alRestar;
  final VoidCallback alSumar;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      padding: 14,
      radio: 24,
      child: Column(
        children: [
          Etiqueta(etiqueta),
          Semantics(liveRegion: true, child: Text(valor, style: Tema.hero(64))),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BotonRedondo(icono: Icons.remove, tooltip: 'Restar $etiqueta', alPulsar: alRestar),
              const SizedBox(width: 12),
              _BotonRedondo(icono: Icons.add, tooltip: 'Sumar $etiqueta', alPulsar: alSumar, destacado: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({required this.icono, required this.tooltip, required this.alPulsar, this.destacado = false});

  final IconData icono;
  final String tooltip;
  final VoidCallback alPulsar;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: alPulsar,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: destacado ? Tema.acento : Tema.superficie2,
        foregroundColor: destacado ? Tema.sobreAcento : Tema.texto,
        fixedSize: const Size(46, 46),
      ),
      icon: Icon(icono),
    );
  }
}

/// Selector de RPE (6-10) sobre una barra degradada; accesible como control deslizante.
class _SelectorRpe extends StatelessWidget {
  const _SelectorRpe({required this.valor, required this.alCambiar});

  final int valor;
  final ValueChanged<int> alCambiar;

  static const _minimo = 6, _maximo = 10;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      slider: true,
      label: 'Esfuerzo percibido',
      value: '$valor',
      increasedValue: '${(valor + 1).clamp(_minimo, _maximo)}',
      decreasedValue: '${(valor - 1).clamp(_minimo, _maximo)}',
      onIncrease: () => alCambiar((valor + 1).clamp(_minimo, _maximo).toInt()),
      onDecrease: () => alCambiar((valor - 1).clamp(_minimo, _maximo).toInt()),
      child: LayoutBuilder(
        builder: (context, limites) {
          const pomo = 26.0;
          final ancho = limites.maxWidth;
          int aValor(double x) =>
              (_minimo + ((x - pomo / 2) / (ancho - pomo) * (_maximo - _minimo)).round()).clamp(_minimo, _maximo).toInt();
          final x = (valor - _minimo) / (_maximo - _minimo) * (ancho - pomo);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => alCambiar(aValor(d.localPosition.dx)),
            onHorizontalDragUpdate: (d) => alCambiar(aValor(d.localPosition.dx)),
            child: Column(
              children: [
                SizedBox(
                  height: 32,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(colors: [Tema.baja, Tema.acento, Tema.fuego]),
                        ),
                      ),
                      Positioned(
                        left: x,
                        child: Container(
                          width: pomo,
                          height: pomo,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Tema.fondo, width: 4),
                            boxShadow: [BoxShadow(color: Tema.acento.withValues(alpha: 0.6), blurRadius: 12)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var v = _minimo; v <= _maximo; v++)
                      Text('$v', style: TextStyle(fontSize: 12, color: v == valor ? Tema.acento : Tema.secundario)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SerieHecha {
  const _SerieHecha({required this.tipo, required this.detalle, required this.notas});

  final TipoSerie tipo;
  final String detalle;
  final String notas;
}

/// Consejo de la app para la serie actual: la persona puede aplicarlo o elegir otra cosa.
class _Recomendacion extends StatelessWidget {
  const _Recomendacion({required this.texto, required this.tipo, required this.aplicada, required this.alAplicar});

  final String texto;
  final TipoSerie tipo;
  final bool aplicada;
  final VoidCallback alAplicar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Tema.acento.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Tema.acento.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: Tema.acento, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Etiqueta('Recomendado: ${tipo.nombre}', color: Tema.acento),
                const SizedBox(height: 4),
                Text(texto, style: const TextStyle(fontSize: 13, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          aplicada
              ? const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.check_circle, color: Tema.acento, semanticLabel: 'Aplicada'),
                )
              : TextButton(onPressed: alAplicar, child: const Text('Aplicar')),
        ],
      ),
    );
  }
}
