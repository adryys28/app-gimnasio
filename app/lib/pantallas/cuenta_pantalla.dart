import 'package:flutter/material.dart';

import '../api/api_cliente.dart';
import '../modelos/cuenta.dart';
import '../tema.dart';
import 'cuestionario_pantalla.dart';
import 'inicio_pantalla.dart';

/// Plan contratado y consentimientos de privacidad (RGPD).
class CuentaPantalla extends StatefulWidget {
  const CuentaPantalla({super.key, required this.api});

  final ApiCliente api;

  @override
  State<CuentaPantalla> createState() => _CuentaPantallaState();
}

class _CuentaPantallaState extends State<CuentaPantalla> {
  late Future<(EstadoPlan, List<Consentimiento>)> _datos;
  bool _guardando = false;

  // Textos breves para la app. El texto informativo completo debe validarlo
  // la persona responsable de protección de datos.
  static const _consentimientos = [
    (
      tipo: 'UBICACION',
      titulo: 'Ubicación',
      descripcion: 'Necesaria para registrar rutas al aire libre.',
      alRetirar: 'Se borrarán tus rutas y puntos GPS. Se conservarán las distancias y los tiempos.',
    ),
    (
      tipo: 'SALUD',
      titulo: 'Datos de salud',
      descripcion: 'Pulsaciones, VO2máx y FC máxima, para calcular mejor las calorías.',
      alRetirar: 'Se borrarán tus pulsaciones, VO2máx y FC máxima guardados.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _datos = _cargar();
  }

  Future<(EstadoPlan, List<Consentimiento>)> _cargar() async =>
      (await widget.api.estadoPlan(), await widget.api.consentimientos());

  void _recargar() {
    setState(() {
      _datos = _cargar();
    });
  }

  Future<void> _cambiar(String tipo, bool otorgar, String avisoAlRetirar) async {
    if (!otorgar) {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (contexto) => AlertDialog(
          title: const Text('Retirar consentimiento'),
          content: Text(avisoAlRetirar),
          actions: [
            TextButton(onPressed: () => Navigator.of(contexto).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(contexto).pop(true), child: const Text('Retirar')),
          ],
        ),
      );
      if (confirmado != true) return;
    }

    setState(() => _guardando = true);
    try {
      await widget.api.registrarConsentimiento(tipo, otorgado: otorgar);
      if (mounted) _recargar();
    } on ApiExcepcion catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      body: FutureBuilder<(EstadoPlan, List<Consentimiento>)>(
        future: _datos,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('No se pudo cargar la cuenta: ${snap.error}'));

          final (plan, consentimientos) = snap.data!;
          final textos = Theme.of(context).textTheme;
          bool otorgado(String tipo) => consentimientos.any((c) => c.tipo == tipo && c.otorgado);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Tu plan', style: textos.titleMedium),
              const SizedBox(height: 6),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(plan.premium ? Icons.workspace_premium : Icons.person_outline, color: Tema.acento),
                          const SizedBox(width: 8),
                          Text(
                            plan.premium ? 'Premium' : 'Gratuito',
                            style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      for (final f in plan.fuentes.where((f) => f.fuente != 'BASE'))
                        Padding(padding: const EdgeInsets.only(top: 6), child: Text(f.descripcion)),
                      const Divider(height: 24),
                      for (final f in plan.funciones)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.check, size: 18, color: Tema.acento),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(f.limite == null ? f.nombre : '${f.nombre}: ${f.limite}'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome, color: Tema.acento),
                  title: const Text('Rehacer mi plan'),
                  subtitle: const Text('Responde de nuevo al cuestionario y genera otra rutina.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CuestionarioPantalla(
                        api: widget.api,
                        alTerminar: () => Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute<void>(builder: (_) => InicioPantalla(api: widget.api)),
                          (_) => false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Privacidad', style: textos.titleMedium),
              const SizedBox(height: 6),
              Card(
                child: Column(
                  children: [
                    for (final c in _consentimientos)
                      SwitchListTile(
                        title: Text(c.titulo),
                        subtitle: Text(c.descripcion),
                        value: otorgado(c.tipo),
                        onChanged: _guardando ? null : (v) => _cambiar(c.tipo, v, c.alRetirar),
                      ),
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
