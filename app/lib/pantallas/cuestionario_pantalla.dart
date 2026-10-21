import 'package:flutter/material.dart';

import '../api/api_cliente.dart';
import '../modelos/entrenamiento.dart';
import '../tema.dart';
import '../widgets/ui.dart';

/// Cuestionario inicial: nivel, objetivo y días; después genera la rutina personalizada.
class CuestionarioPantalla extends StatefulWidget {
  const CuestionarioPantalla({super.key, required this.api, required this.alTerminar});

  final ApiCliente api;

  /// Se llama al pulsar "Empezar" con la rutina ya creada.
  final VoidCallback alTerminar;

  @override
  State<CuestionarioPantalla> createState() => _CuestionarioPantallaState();
}

class _CuestionarioPantallaState extends State<CuestionarioPantalla> {
  int _paso = 0; // 0 nivel · 1 objetivo · 2 días · 3 generando/resultado
  int? _nivel;
  int? _objetivo;
  int? _dias;
  Future<RecomendacionDias>? _recomendacion;
  ResultadoRutina? _resultado;
  bool _generando = false;

  static const _opcionesDias = [(2, '2'), (3, '3'), (4, '4'), (5, '5 o más')];

  bool get _puedeSeguir => switch (_paso) { 0 => _nivel != null, 1 => _objetivo != null, 2 => _dias != null, _ => false };

  void _siguiente() {
    if (_paso == 1) {
      // La recomendación depende de nivel y objetivo: se pide al llegar al paso de los días
      _recomendacion = widget.api.recomendacionDias(nivelId: _nivel!, objetivoId: _objetivo!).then((r) {
        if (mounted && _dias == null) setState(() => _dias = r.recomendado.clamp(2, 5).toInt());
        return r;
      });
    }
    if (_paso == 2) {
      _generar();
      return;
    }
    setState(() => _paso++);
  }

  Future<void> _generar() async {
    setState(() {
      _paso = 3;
      _generando = true;
    });
    try {
      final r = await widget.api.crearRutinaCuestionario(nivelId: _nivel!, objetivoId: _objetivo!, diasSemana: _dias!);
      if (mounted) setState(() => _resultado = r);
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
      setState(() => _paso = 2);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo conectar con el servidor.')));
      setState(() => _paso = 2);
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned(top: -160, right: -80, child: Brillo()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: _paso == 3 ? _final() : _pregunta(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pregunta() {
    final (titulo, subtitulo) = switch (_paso) {
      0 => ('¿Qué nivel tienes?', 'Así ajustamos los ejercicios y la intensidad.'),
      1 => ('¿Qué buscas?', 'Tu objetivo define las repeticiones, los descansos y el volumen.'),
      _ => ('¿Cuántos días quieres entrenar?', 'Elige los días por semana que puedes mantener.'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (_paso > 0)
              IconButton(
                onPressed: () => setState(() => _paso--),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Volver',
              ),
            const Spacer(),
            Text('Paso ${_paso + 1} de 3', style: const TextStyle(color: Tema.secundario)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= _paso ? Tema.acento : Tema.superficie2,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 28),
        Text(titulo.toUpperCase(), style: Tema.hero(44)),
        const SizedBox(height: 8),
        Text(subtitulo, style: const TextStyle(color: Tema.secundario, fontSize: 15)),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            children: switch (_paso) {
              0 => <Widget>[for (final o in nivelesCuestionario) _Opcion(opcion: o, seleccionada: _nivel == o.id, alPulsar: () => setState(() => _nivel = o.id))],
              1 => <Widget>[
                  for (final o in objetivosCuestionario)
                    _Opcion(
                      opcion: o,
                      icono: switch (o.id) { 3 => Icons.local_fire_department, 1 => Icons.fitness_center, _ => Icons.trending_up },
                      seleccionada: _objetivo == o.id,
                      alPulsar: () => setState(() => _objetivo = o.id),
                    ),
                ],
              _ => <Widget>[_selectorDias()],
            },
          ),
        ),
        BotonBrillo(texto: _paso == 2 ? 'Crear mi rutina' : 'Siguiente', onPressed: _puedeSeguir ? _siguiente : null),
      ],
    );
  }

  Widget _selectorDias() {
    return FutureBuilder<RecomendacionDias>(
      future: _recomendacion,
      builder: (context, snap) {
        final rec = snap.data;
        final recomendado = rec?.recomendado.clamp(2, 5).toInt();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 0; i < _opcionesDias.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _BotonDia(
                      texto: _opcionesDias[i].$2,
                      seleccionado: _dias == _opcionesDias[i].$1,
                      recomendado: recomendado == _opcionesDias[i].$1,
                      alPulsar: () => setState(() => _dias = _opcionesDias[i].$1),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            if (snap.connectionState != ConnectionState.done)
              const Center(child: CircularProgressIndicator())
            else if (rec != null)
              Tarjeta(
                radio: 22,
                colorBorde: Tema.acento.withValues(alpha: 0.3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Tema.acento, size: 18),
                        const SizedBox(width: 8),
                        Etiqueta('Recomendado: ${rec.recomendado} días (${rec.minimo}-${rec.maximo})', color: Tema.acento),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(rec.motivo, style: const TextStyle(fontSize: 14, height: 1.4)),
                    const SizedBox(height: 8),
                    Text('Fuente: ${rec.fuente}', style: const TextStyle(fontSize: 11, color: Tema.secundario)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _final() {
    final r = _resultado;
    if (_generando || r == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 5))),
          const SizedBox(height: 24),
          Text('Creando tu rutina'.toUpperCase(), textAlign: TextAlign.center, style: Tema.hero(40)),
          const SizedBox(height: 8),
          const Text(
            'Estamos eligiendo los ejercicios, las series y los descansos para tu objetivo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Tema.secundario),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [
              const SizedBox(height: 24),
              Row(children: [Pildora(r.generadaConIa ? 'Generada con IA' : 'Personalizada para ti')]),
              const SizedBox(height: 12),
              Text('Tu rutina está lista'.toUpperCase(), style: Tema.hero(44)),
              const SizedBox(height: 8),
              Text(r.rutina.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              if ((r.rutina.descripcion ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(r.rutina.descripcion!, style: const TextStyle(color: Tema.secundario, height: 1.4)),
              ],
              const SizedBox(height: 20),
              for (final d in r.rutina.dias)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Tarjeta(
                    padding: 14,
                    radio: 18,
                    child: Row(
                      children: [
                        Expanded(child: Text(d.nombre, style: const TextStyle(fontWeight: FontWeight.w600))),
                        Text('${d.ejercicios.length} ejercicios · ${d.totalSeries} series',
                            style: const TextStyle(color: Tema.secundario, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        BotonBrillo(texto: 'Empezar', onPressed: widget.alTerminar),
      ],
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({required this.opcion, required this.seleccionada, required this.alPulsar, this.icono});

  final OpcionCuestionario opcion;
  final bool seleccionada;
  final VoidCallback alPulsar;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        selected: seleccionada,
        button: true,
        child: InkWell(
          onTap: alPulsar,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: seleccionada ? Tema.acento.withValues(alpha: 0.12) : Tema.tarjeta,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: seleccionada ? Tema.acento : Tema.linea, width: seleccionada ? 2 : 1),
            ),
            child: Row(
              children: [
                if (icono != null) ...[
                  Icon(icono, color: seleccionada ? Tema.acento : Tema.secundario, size: 28),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(opcion.titulo.toUpperCase(), style: Tema.titular(24, color: seleccionada ? Tema.acento : Tema.texto)),
                      const SizedBox(height: 4),
                      Text(opcion.descripcion, style: const TextStyle(color: Tema.secundario, fontSize: 13)),
                    ],
                  ),
                ),
                if (seleccionada) const Icon(Icons.check_circle, color: Tema.acento),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonDia extends StatelessWidget {
  const _BotonDia({required this.texto, required this.seleccionado, required this.recomendado, required this.alPulsar});

  final String texto;
  final bool seleccionado;
  final bool recomendado;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: seleccionado,
      button: true,
      label: recomendado ? '$texto días, recomendado' : '$texto días',
      child: InkWell(
        onTap: alPulsar,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 96,
          decoration: BoxDecoration(
            color: seleccionado ? Tema.acento : Tema.tarjeta,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: recomendado && !seleccionado ? Tema.acento : Tema.linea, width: recomendado ? 2 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(texto, style: Tema.numero(texto.length > 2 ? 22 : 40, color: seleccionado ? Tema.sobreAcento : Tema.texto)),
              ),
              if (recomendado)
                Text('Recomendado',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: seleccionado ? Tema.sobreAcento : Tema.acento)),
            ],
          ),
        ),
      ),
    );
  }
}
