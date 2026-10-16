import 'package:flutter/material.dart';

import '../api/api_cliente.dart';
import 'actividades_pantalla.dart';
import 'catalogo_pantalla.dart';
import 'cuenta_pantalla.dart';
import 'hoy_pantalla.dart';

/// Navegación inferior: Hoy, Cardio, Ejercicios y Cuenta.
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Hoy'),
          NavigationDestination(
            icon: Icon(Icons.directions_run_outlined),
            selectedIcon: Icon(Icons.directions_run),
            label: 'Cardio',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Ejercicios',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cuenta'),
        ],
      ),
    );
  }
}
