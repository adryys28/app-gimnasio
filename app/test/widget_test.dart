import 'dart:convert';

import 'package:app_gimnasio/api/api_cliente.dart';
import 'package:app_gimnasio/modelos/formato.dart';
import 'package:app_gimnasio/modelos/rutina.dart';
import 'package:app_gimnasio/modelos/sesion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Formato', () {
    test('números con coma decimal y sin ceros sobrantes', () {
      expect(formatearNumero(17), '17');
      expect(formatearNumero(2.5), '2,5');
      expect(formatearNumero(16.25), '16,25');
    });

    test('rangos', () {
      expect(rango(10, 12), '10–12');
      expect(rango(8, 8), '8');
      expect(rango(null, 5), '');
    });
  });

  group('Modelos', () {
    final json = {
      'rutinaId': 1,
      'nombre': 'Full body 3 días',
      'origen': 'S',
      'activa': true,
      'dias': [
        {
          'rutinaDiaId': 10,
          'orden': 1,
          'nombre': 'Día A',
          'ejercicios': [
            {
              'rutinaDiaEjercicioId': 100, 'orden': 1, 'ejercicioId': 3, 'nombre': 'Remo con mancuerna',
              'series': 3, 'tipoMedida': 'R', 'repsMin': 8, 'repsMax': 10, 'pesoObjetivoKg': 17.0,
              'descansoSeg': 90,
            },
            {
              'rutinaDiaEjercicioId': 101, 'orden': 2, 'ejercicioId': 6, 'nombre': 'Plancha frontal',
              'series': 3, 'tipoMedida': 'T', 'duracionSegMin': 30, 'duracionSegMax': 45,
              'descansoSeg': 60,
            },
          ],
        },
      ],
    };

    test('Rutina.fromJson y texto del objetivo', () {
      final rutina = Rutina.fromJson(json);
      final dia = rutina.dias.single;
      expect(dia.totalSeries, 6);
      expect(dia.ejercicios[0].objetivoTexto, '3 × 8–10 reps · 17 kg');
      expect(dia.ejercicios[1].objetivoTexto, '3 × 30–45 s');
      expect(dia.ejercicios[1].porTiempo, isTrue);
    });

    test('AjusteSesion.cambioTexto', () {
      AjusteSesion ajuste(Map<String, dynamic> extra) =>
          AjusteSesion.fromJson({'ejercicio': 'X', 'motivo': 'm', ...extra});

      expect(
        ajuste({'accion': 'SUBIR', 'repsMinAntes': 10, 'repsMaxAntes': 12, 'repsMinNuevo': 12, 'repsMaxNuevo': 14})
            .cambioTexto,
        '10–12 → 12–14 reps',
      );
      expect(ajuste({'accion': 'CALIBRAR', 'pesoNuevo': 16.0}).cambioTexto, 'Peso de referencia: 16 kg');
      expect(ajuste({'accion': 'SUBIR', 'pesoAntes': 16.0, 'pesoNuevo': 17.0}).cambioTexto, '16 → 17 kg');
      expect(
        ajuste({'accion': 'BAJAR', 'durMinAntes': 30, 'durMaxAntes': 45, 'durMinNueva': 25, 'durMaxNueva': 40})
            .cambioTexto,
        '30–45 → 25–40 s',
      );
      expect(ajuste({'accion': 'MANTENER'}).cambioTexto, '');
    });
  });

  group('ApiCliente', () {
    http.Response respuesta(Object cuerpo, int estado) =>
        http.Response.bytes(utf8.encode(jsonEncode(cuerpo)), estado, headers: {'content-type': 'application/json'});

    test('sin rutina activa (404) devuelve null', () async {
      final api = ApiCliente(
        cliente: MockClient((_) async => respuesta({'title': 'No encontrada', 'status': 404}, 404)),
        baseUrl: 'http://prueba',
        devSub: 'dev-prueba',
      );
      expect(await api.rutinaActiva(), isNull);
    });

    test('envía la cabecera de desarrollo e interpreta requierePremium', () async {
      late http.BaseRequest recibida;
      final api = ApiCliente(
        cliente: MockClient((peticion) async {
          recibida = peticion;
          return respuesta({
            'title': 'La conexión con relojes está incluida en el plan Premium.',
            'status': 403,
            'requierePremium': true,
          }, 403);
        }),
        baseUrl: 'http://prueba',
        devSub: 'dev-prueba',
      );

      await expectLater(
        api.iniciarSesion(10),
        throwsA(isA<ApiExcepcion>()
            .having((e) => e.estado, 'estado', 403)
            .having((e) => e.requierePremium, 'requierePremium', isTrue)
            .having((e) => e.mensaje, 'mensaje', contains('Premium'))),
      );
      expect(recibida.headers['X-Dev-Sub'], 'dev-prueba');
    });
  });
}
