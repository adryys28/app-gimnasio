import 'package:flutter/material.dart';

import '../api/api_cliente.dart';
import '../modelos/estadisticas.dart';
import '../modelos/formato.dart';
import '../modelos/rutina.dart';
import '../modelos/sesion.dart';
import '../tema.dart';
import '../widgets/ui.dart';

/// Resumen de sesión (diseño V2): duración, récords, progresión y ajustes para la próxima vez.
class ResumenPantalla extends StatefulWidget {
  const ResumenPantalla({super.key, required this.api, required this.sesionId, required this.dia, required this.ajustes});

  final ApiCliente api;
  final int sesionId;
  final DiaRutina dia;
  final List<AjusteSesion> ajustes;

  @override
  State<ResumenPantalla> createState() => _ResumenPantallaState();
}

class _ResumenPantallaState extends State<ResumenPantalla> {
  late final Future<ResumenSesion?> _resumen = widget.api.resumenSesion(widget.sesionId).then<ResumenSesion?>(
        (r) => r,
        onError: (Object _) => null, // si fallan las estadísticas se muestran solo los ajustes
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<ResumenSesion?>(
        future: _resumen,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final r = snap.data;
          return Stack(
            children: [
              const Positioned(top: -140, left: -40, child: Brillo()),
              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Tema.acento),
                          child: const Icon(Icons.check, size: 18, color: Tema.sobreAcento),
                        ),
                        const SizedBox(width: 10),
                        const Etiqueta('Sesión completada', color: Tema.acento),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (r?.duracionSeg != null) Text(formatearDuracion(r!.duracionSeg!), style: Tema.hero(88)),
                    Text(
                      [widget.dia.nombre, if (r?.fecha != null) formatearFecha(r!.fecha!)].join(' · '),
                      style: const TextStyle(color: Tema.secundario),
                    ),
                    if (r != null) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(child: _Dato('Volumen', formatearVolumen(r.volumenKg))),
                          const SizedBox(width: 10),
                          Expanded(child: _Dato('Series', '${r.series}')),
                          const SizedBox(width: 10),
                          Expanded(child: _Dato('RPE medio', r.rpeMedio == null ? '–' : formatearNumero(r.rpeMedio!))),
                        ],
                      ),
                      for (final rec in r.records) ...[const SizedBox(height: 12), _Record(record: rec)],
                      if (r.progresion.length >= 2) ...[
                        const SizedBox(height: 12),
                        Tarjeta(
                          padding: 18,
                          radio: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Etiqueta('Progresión · ${r.ejercicioProgresion ?? ''}'),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${formatearNumero(r.progresion.last)} kg', style: Tema.numero(34)),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${conSigno(r.progresion.last - r.progresion.first, 'kg')} en ${r.progresion.length} sesiones',
                                    style: const TextStyle(color: Tema.acento, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              GraficoLinea(valores: r.progresion),
                            ],
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),
                    const Etiqueta('Tu próxima sesión'),
                    const SizedBox(height: 10),
                    if (widget.ajustes.isEmpty)
                      const Text('Sin ajustes automáticos para la próxima sesión.', style: TextStyle(color: Tema.secundario))
                    else
                      Tarjeta(
                        radio: 24,
                        child: Column(
                          children: [
                            for (var i = 0; i < widget.ajustes.length; i++) ...[
                              if (i > 0) const Divider(height: 22),
                              _FilaAjuste(ajuste: widget.ajustes[i]),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    BotonBrillo(texto: 'Hecho', onPressed: () => Navigator.of(context).popUntil((ruta) => ruta.isFirst)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      padding: 12,
      radio: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Etiqueta(etiqueta),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: Text(valor, style: Tema.numero(24))),
        ],
      ),
    );
  }
}

class _Record extends StatelessWidget {
  const _Record({required this.record});

  final RecordPersonal record;

  @override
  Widget build(BuildContext context) {
    final reps = record.reps == null ? '' : ' × ${record.reps}';
    return Tarjeta(
      radio: 22,
      colorBorde: Tema.fuego.withValues(alpha: 0.4),
      gradiente: const LinearGradient(colors: [Color(0xFF4A2408), Tema.tarjeta]),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Tema.fuego, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.emoji_events, color: Tema.sobreAcento, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Etiqueta('Nuevo récord personal', color: Tema.fuego),
                const SizedBox(height: 2),
                Text(
                  '${record.ejercicio} · ${formatearNumero(record.pesoKg)} kg$reps',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Text(
                  'Antes: ${formatearNumero(record.pesoAnteriorKg)} kg',
                  style: const TextStyle(color: Tema.secundario, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaAjuste extends StatelessWidget {
  const _FilaAjuste({required this.ajuste});

  final AjusteSesion ajuste;

  @override
  Widget build(BuildContext context) {
    final cambio = ajuste.cambioTexto;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ajuste.ejercicio, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              Text(cambio.isEmpty ? ajuste.motivo : cambio, style: const TextStyle(color: Tema.secundario, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Insignia(accion: ajuste.accion),
      ],
    );
  }
}
