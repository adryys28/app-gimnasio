import 'dart:io';

import 'package:app_gimnasio/modelos/catalogo.dart';
import 'package:app_gimnasio/pantallas/ejercicio_pantalla.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _detalle(List<Map<String, dynamic>>? imagenes) => {
      'ejercicio': {'ejercicioId': 1, 'nombre': 'Press de banca con barra', 'nivelMinimoId': 2, 'tipoMedida': 'R'},
      'musculos': [],
      'materiales': [],
      if (imagenes != null) 'imagenes': imagenes,
    };

const _imagenes = [
  {'archivo': 'bench-press-1.webp', 'autor': 'Everkinetic', 'licencia': 'CC BY-SA 4.0'},
  {'archivo': 'bench-press-2.webp', 'autor': 'Everkinetic', 'licencia': 'CC BY-SA 4.0'},
];

void main() {
  test('EjercicioDetalle lee las imágenes y tolera que no vengan', () {
    final d = EjercicioDetalle.fromJson(_detalle(_imagenes));
    expect(d.imagenes, hasLength(2));
    expect(d.imagenes.first.ruta, 'assets/ejercicios/bench-press-1.webp');
    expect(EjercicioDetalle.fromJson(_detalle(null)).imagenes, isEmpty);
    expect(EjercicioDetalle.fromJson(_detalle([])).imagenes, isEmpty);
  });

  test('cada imagen asignada en el script 17 existe en assets/ejercicios', () {
    final sql = File('../sql/17_imagenes_ejercicios.sql').readAsStringSync();
    final archivos = RegExp(r"\(N'[^']+', [12], '([^']+\.webp)'\)").allMatches(sql).map((m) => m.group(1)!).toList();
    expect(archivos, isNotEmpty);
    for (final a in archivos) {
      expect(File('assets/ejercicios/$a').existsSync(), isTrue, reason: a);
    }
    expect(File('assets/ejercicios/LICENCIA.txt').existsSync(), isTrue);
  });

  testWidgets('muestra las dos ilustraciones con la atribución', (tester) async {
    final imagenes = [for (final i in _imagenes) ImagenEjercicio.fromJson(i)];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: IlustracionEjercicio(imagenes: imagenes, nombre: 'Press de banca con barra')),
    ));
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('Ilustración: Everkinetic · CC BY-SA 4.0'), findsOneWidget);
    expect(find.bySemanticsLabel('Ilustración de Press de banca con barra'), findsOneWidget);
  });
}
