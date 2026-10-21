import 'package:flutter/material.dart';

import 'api/api_cliente.dart';
import 'pantallas/arranque_pantalla.dart';
import 'tema.dart';

void main() {
  runApp(AppGimnasio(api: ApiCliente()));
}

class AppGimnasio extends StatelessWidget {
  const AppGimnasio({super.key, required this.api});

  final ApiCliente api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Gimnasio',
      debugShowCheckedModeBanner: false,
      theme: Tema.oscuro(),
      home: ArranquePantalla(api: api),
    );
  }
}
