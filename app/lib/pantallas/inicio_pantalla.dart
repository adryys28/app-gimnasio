import 'package:flutter/material.dart';

import '../api/api_cliente.dart';
import '../widgets/ui.dart';
import 'actividades_pantalla.dart';
import 'catalogo_pantalla.dart';
import 'cuenta_pantalla.dart';
import 'hoy_pantalla.dart';

/// Navegación principal con barra flotante: Hoy, Cardio, Ejercicios y Perfil.
class InicioPantalla extends StatefulWidget {
  const InicioPantalla({super.key, required this.api});

  final ApiCliente api;

  @override
  State<InicioPantalla> createState() => _InicioPantallaState();
}

class _InicioPantallaState extends State<InicioPantalla> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    return Scaffold(
      // IndexedStack conserva el estado de cada pestaña al cambiar entre ellas
      body: IndexedStack(
        index: _indice,
        children: [
          HoyPantalla(api: api),
          ActividadesPantalla(api: api),
          CatalogoPantalla(api: api),
          CuentaPantalla(api: api),
        ],
      ),
      bottomNavigationBar: NavFlotante(indice: _indice, alCambiar: (i) => setState(() => _indice = i)),
    );
  }
}
