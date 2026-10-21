import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_cliente.dart';
import '../modelos/catalogo.dart';
import '../modelos/formato.dart';
import '../tema.dart';
import '../widgets/silueta.dart';
import 'ejercicio_pantalla.dart';

/// Catálogo de ejercicios con buscador y filtros por músculo y material.
class CatalogoPantalla extends StatefulWidget {
  const CatalogoPantalla({super.key, required this.api});

  final ApiCliente api;

  @override
  State<CatalogoPantalla> createState() => _CatalogoPantallaState();
}

class _CatalogoPantallaState extends State<CatalogoPantalla> {
  Catalogo? _catalogo;
  late Future<List<EjercicioResumen>> _resultados;
  Timer? _espera;
  String _texto = '';
  int? _grupoId;
  int? _materialId;

  @override
  void initState() {
    super.initState();
    _resultados = _buscar();
    widget.api.catalogos().then((c) {
      if (mounted) setState(() => _catalogo = c);
    }).catchError((Object _) {
      // Sin catálogo solo se pierden los filtros; la búsqueda sigue funcionando
    });
  }

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  Future<List<EjercicioResumen>> _buscar() =>
      widget.api.buscarEjercicios(texto: _texto, grupoMuscularId: _grupoId, materialId: _materialId);

  void _actualizar() {
    setState(() {
      _resultados = _buscar();
    });
  }

  /// Espera a que se deje de escribir para no lanzar una petición por tecla.
  void _alEscribir(String texto) {
    _texto = texto.trim();
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), _actualizar);
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = _catalogo;

    return Scaffold(
      appBar: AppBar(title: const Text('Ejercicios')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar ejercicio',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _alEscribir,
            ),
          ),
          if (catalogo != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _Filtro(
                      etiqueta: 'Músculo',
                      opciones: catalogo.gruposMusculares,
                      valor: _grupoId,
                      alCambiar: (v) {
                        _grupoId = v;
                        _actualizar();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Filtro(
                      etiqueta: 'Material',
                      opciones: catalogo.materiales,
                      valor: _materialId,
                      alCambiar: (v) {
                        _materialId = v;
                        _actualizar();
                      },
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<EjercicioResumen>>(
              future: _resultados,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('No se pudo cargar el catálogo: ${snap.error}'));
                }
                final ejercicios = snap.data ?? const [];
                if (ejercicios.isEmpty) {
                  return const Center(child: Text('No hay ejercicios con esos filtros.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: ejercicios.length,
                  itemBuilder: (context, i) {
                    final e = ejercicios[i];
                    final nivel = catalogo?.nombreNivel(e.nivelMinimoId) ?? '';
                    return Card(
                      child: ListTile(
                        title: Text(e.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                        leading: Silueta(musculos: e.principales, secundarios: e.secundarios, ancho: 22),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (e.principales.isNotEmpty)
                              Text(textoMusculos(e.principales, e.secundarios),
                                  style: const TextStyle(color: Tema.acento, fontSize: 12)),
                            Text([nivel, e.medidaTexto].where((t) => t.isNotEmpty).join(' · ')),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Tema.secundario),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => EjercicioPantalla(api: widget.api, ejercicioId: e.ejercicioId),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Filtro extends StatelessWidget {
  const _Filtro({required this.etiqueta, required this.opciones, required this.valor, required this.alCambiar});

  final String etiqueta;
  final List<ItemCatalogo> opciones;
  final int? valor;
  final ValueChanged<int?> alCambiar;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: etiqueta, border: const OutlineInputBorder(), isDense: true),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: valor,
          isExpanded: true,
          isDense: true,
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
            for (final o in opciones) DropdownMenuItem<int?>(value: o.id, child: Text(o.nombre)),
          ],
          onChanged: alCambiar,
        ),
      ),
    );
  }
}
