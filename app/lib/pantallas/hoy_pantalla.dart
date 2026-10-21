import 'package:flutter/material.dart';

import '../api/api_cliente.dart';
import '../modelos/estadisticas.dart';
import '../modelos/formato.dart';
import '../modelos/rutina.dart';
import '../tema.dart';
import '../widgets/silueta.dart';
import '../widgets/ui.dart';
import 'ejercicio_pantalla.dart';
import 'sesion_pantalla.dart';

/// Pantalla Hoy (diseño V2): entrenamiento del día, semana, volumen y ajustes automáticos.
class HoyPantalla extends StatefulWidget {
  const HoyPantalla({super.key, required this.api});

  final ApiCliente api;

  @override
  State<HoyPantalla> createState() => _HoyPantallaState();
}

class _HoyPantallaState extends State<HoyPantalla> {
  late Future<(Rutina?, ResumenInicio?)> _datos;
  int _diaSeleccionado = 0;
  bool _generando = false;

  @override
  void initState() {
    super.initState();
    _datos = _cargar();
  }

  /// Las estadísticas no bloquean la pantalla: si fallan, se muestra la rutina sin ellas.
  Future<(Rutina?, ResumenInicio?)> _cargar() async {
    final rutina = await widget.api.rutinaActiva();
    ResumenInicio? resumen;
    try {
      resumen = await widget.api.resumenInicio();
    } catch (_) {
      resumen = null;
    }
    return (rutina, resumen);
  }

  void _recargar() {
    setState(() {
      _datos = _cargar();
    });
  }

  Future<void> _generar() async {
    setState(() => _generando = true);
    try {
      await widget.api.generarRutinaSugerida();
      if (!mounted) return;
      _recargar();
    } on ApiExcepcion catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _empezar(Rutina rutina, DiaRutina dia) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SesionPantalla(
          api: widget.api,
          dia: dia,
          nivelId: rutina.nivelId ?? 1,
          objetivoId: rutina.objetivoId ?? 2,
        ),
      ),
    );
    if (mounted) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<(Rutina?, ResumenInicio?)>(
        future: _datos,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _Vacio(texto: 'No se pudo cargar la rutina: ${snap.error}', boton: 'Reintentar', alPulsar: _recargar);
          }
          final (rutina, resumen) = snap.data!;
          return Stack(
            children: [
              const Positioned(top: -160, right: -60, child: Brillo()),
              SafeArea(
                bottom: false,
                child: RefreshIndicator(
                  onRefresh: () async => _recargar(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    children: [
                      _Cabecera(resumen: resumen),
                      const SizedBox(height: 18),
                      if (rutina == null || rutina.dias.isEmpty)
                        _Vacio(
                          texto: 'Todavía no tienes una rutina activa.',
                          boton: _generando ? 'Generando…' : 'Generar rutina',
                          alPulsar: _generando ? null : _generar,
                        )
                      else
                        ..._contenido(rutina, resumen),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _contenido(Rutina rutina, ResumenInicio? resumen) {
    final indice = _diaSeleccionado < rutina.dias.length ? _diaSeleccionado : 0;
    final dia = rutina.dias[indice];
    final hoy = DateTime.now().weekday - 1;

    return [
      if (rutina.dias.length > 1) ...[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < rutina.dias.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(rutina.dias[i].nombre),
                    selected: i == indice,
                    onSelected: (_) => setState(() => _diaSeleccionado = i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],

      // Tarjeta protagonista
      Tarjeta(
        padding: 20,
        radio: 28,
        colorBorde: Tema.acento.withValues(alpha: 0.3),
        gradiente: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C2610), Tema.tarjeta, Color(0xFF0F1A22)],
          stops: [0, 0.55, 1],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Flexible(child: Etiqueta('Entrenamiento de hoy', color: Tema.acento)),
                          if (rutina.generadaConIa) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.auto_awesome, size: 14, color: Tema.acento, semanticLabel: 'Generada con IA'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(dia.nombre, style: Tema.hero(54)),
                      const SizedBox(height: 6),
                      Text(
                        '${dia.ejercicios.length} ejercicios · ${dia.totalSeries} series · ~${dia.minutosEstimados} min',
                        style: const TextStyle(color: Tema.secundario, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: [for (final m in dia.musculos.take(4)) Pildora(m)]),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Silueta(musculos: dia.musculos),
              ],
            ),
            if ((rutina.descripcion ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(rutina.descripcion!, style: const TextStyle(color: Tema.secundario, fontSize: 13, height: 1.35)),
            ],
            const SizedBox(height: 18),
            BotonBrillo(texto: 'Empezar', onPressed: dia.ejercicios.isEmpty ? null : () => _empezar(rutina, dia)),
          ],
        ),
      ),

      if (resumen != null) ...[
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Tarjeta(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Etiqueta('Esta semana'),
                      const SizedBox(height: 10),
                      Center(
                        child: AnilloProgreso(
                          valor: resumen.objetivoSemana == 0 ? 0 : resumen.sesionesSemana / resumen.objetivoSemana,
                          centro: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${resumen.sesionesSemana}/${resumen.objetivoSemana}', style: Tema.numero(28)),
                              const Text('sesiones', style: TextStyle(fontSize: 10, color: Tema.secundario)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Tarjeta(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Etiqueta('Volumen'),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(child: Text(formatearVolumen(resumen.volumenSemanaKg), style: Tema.numero(28))),
                          if (resumen.variacionVolumenPct != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              conSigno(resumen.variacionVolumenPct!.toDouble(), '%'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: resumen.variacionVolumenPct! >= 0 ? Tema.acento : Tema.baja,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      BarrasSemana(valores: resumen.volumenDias, hoy: hoy),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (resumen.ajustes.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Etiqueta('Ajustes automáticos'),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < resumen.ajustes.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _MiniAjuste(ajuste: resumen.ajustes[i])),
              ],
            ],
          ),
        ],
      ],

      const SizedBox(height: 20),
      const Etiqueta('Ejercicios'),
      const SizedBox(height: 10),
      for (final e in dia.ejercicios)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          // Al pulsar se abre el detalle con la animación de cómo se hace
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => EjercicioPantalla(api: widget.api, ejercicioId: e.ejercicioId))),
            child: Tarjeta(
              padding: 14,
              radio: 18,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Tema.superficie2, borderRadius: BorderRadius.circular(12)),
                    child: Text('${e.orden}', style: Tema.numero(20, color: Tema.acento)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        Text(e.objetivoTexto, style: const TextStyle(color: Tema.secundario, fontSize: 13)),
                        if (e.principales.isNotEmpty)
                          Text(textoMusculos(e.principales, e.secundarios),
                              style: const TextStyle(color: Tema.acento, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Silueta(musculos: e.principales, secundarios: e.secundarios, ancho: 22),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Tema.secundario, semanticLabel: 'Ver cómo se hace'),
                ],
              ),
            ),
          ),
        ),
    ];
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.resumen});

  final ResumenInicio? resumen;

  @override
  Widget build(BuildContext context) {
    final r = resumen;
    final nombre = r?.nombreCorto ?? '';
    final subtitulo = r == null
        ? 'Tu entrenamiento de hoy'
        : r.sesionesSemana >= r.objetivoSemana
            ? 'Objetivo semanal cumplido'
            : 'Vamos a por la sesión ${r.sesionesSemana + 1}';
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Tema.degradadoAcento),
          child: Text(nombre.isEmpty ? '·' : nombre[0].toUpperCase(), style: Tema.titular(22, color: Tema.sobreAcento)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre.isEmpty ? 'Hola' : 'Hola, $nombre', style: const TextStyle(color: Tema.secundario, fontSize: 13)),
              Text(subtitulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
        ),
        if (r != null && r.rachaDias > 0)
          Semantics(
            label: 'Racha de ${r.rachaDias} días',
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
              decoration: BoxDecoration(color: Tema.fuegoFondo, borderRadius: BorderRadius.circular(999)),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Tema.fuego, size: 18),
                  const SizedBox(width: 4),
                  Text('${r.rachaDias}', style: Tema.numero(22, color: Tema.fuego)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MiniAjuste extends StatelessWidget {
  const _MiniAjuste({required this.ajuste});

  final AjusteReciente ajuste;

  @override
  Widget build(BuildContext context) {
    final color = ajuste.sube ? Tema.acento : Tema.baja;
    return Tarjeta(
      padding: 12,
      radio: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ajuste.sube ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: color),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: Text(ajuste.valor, style: Tema.numero(22, color: color))),
          Text(ajuste.ejercicio, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Tema.secundario)),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.texto, required this.boton, required this.alPulsar});

  final String texto;
  final String boton;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          BotonBrillo(texto: boton, onPressed: alPulsar),
        ],
      ),
    );
  }
}
