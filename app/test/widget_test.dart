import 'dart:convert';

import 'package:app_gimnasio/api/api_cliente.dart';
import 'package:app_gimnasio/modelos/actividad.dart';
import 'package:app_gimnasio/modelos/catalogo.dart';
import 'package:app_gimnasio/modelos/cuenta.dart';
import 'package:app_gimnasio/modelos/entrenamiento.dart';
import 'package:app_gimnasio/modelos/estadisticas.dart';
import 'package:app_gimnasio/modelos/formato.dart';
import 'package:app_gimnasio/modelos/recomendaciones.dart';
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

    test('distancias', () {
      expect(formatearDistancia(2277), '2,28 km');
      expect(formatearDistancia(1000), '1 km');
      expect(formatearDistancia(850), '850 m');
    });

    test('fechas UTC de la API sin zona horaria', () {
      expect(aFechaLocal('2026-10-15T08:00:00')!.toUtc(), DateTime.utc(2026, 10, 15, 8));
      expect(aFechaLocal('2026-10-15T08:00:00Z')!.toUtc(), DateTime.utc(2026, 10, 15, 8));
      expect(aFechaLocal(null), isNull);
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

  group('Cardio y cuenta', () {
    test('ActividadDetalle: ruta GeoJSON en tramos [lat, lon] y fuente de kcal', () {
      final a = ActividadDetalle.fromJson({
        'resumen': {
          'actividadId': 7, 'tipo': 'Carrera', 'fechaInicio': '2026-10-15T08:00:00',
          'distanciaM': 2277.0, 'ritmoMedioTxt': '5:03', 'kcal': 175, 'fuenteKcal': 'FC', 'coberturaFcPct': 100.0,
        },
        'parciales': [
          {'km': 1, 'distanciaM': 1000.0, 'duracionSeg': 303.0, 'duracionTxt': '5:03', 'ritmoTxt': '5:03'},
          {'km': 3, 'distanciaM': 277.0, 'duracionSeg': 84.0, 'duracionTxt': '1:24', 'ritmoTxt': '5:03'},
        ],
        'ruta': {
          'type': 'MultiLineString',
          'coordinates': [
            [[-3.6845, 40.4153], [-3.6845, 40.4200]],
            [[-3.6845, 40.4300]], // tramo de un solo punto: se descarta
          ],
        },
        'rutaPublica': null,
      });

      expect(a.ruta.length, 1);
      expect(a.ruta.first.first.latitude, 40.4153);
      expect(a.ruta.first.first.longitude, -3.6845);
      expect(a.fuenteKcalTexto, 'por pulsaciones (100 % del tiempo)');
      expect(a.parciales[0].etiqueta, '1');
      expect(a.parciales[1].etiqueta, '3 (277 m)');
    });

    test('EstadoPlan: descripción de las fuentes de acceso', () {
      final e = EstadoPlan.fromJson({
        'premium': true,
        'fuentes': [
          {'fuente': 'SUSCRIPCION', 'plan': 'PREMIUM', 'plataforma': 'APPLE',
           'fechaFin': '2026-11-15T10:50:33', 'renovacionAutomatica': true},
          {'fuente': 'GIMNASIO', 'plan': 'PREMIUM', 'organizacion': 'Gimnasio de prueba', 'fechaFin': '2027-10-15T00:00:00'},
        ],
        'funciones': [
          {'funcion': 'CARDIO_GPS', 'nombre': 'Cardio', 'limite': null},
        ],
      });

      expect(e.premium, isTrue);
      expect(e.fuentes[0].descripcion, startsWith('Suscripción en App Store hasta el '));
      expect(e.fuentes[0].descripcion, endsWith('(se renueva automáticamente)'));
      expect(e.fuentes[1].descripcion, startsWith('Licencia de Gimnasio de prueba'));
      expect(e.funciones.single.limite, isNull);
    });
  });

  group('Diseño V2', () {
    test('formatos de miles, duración, volumen y signo', () {
      expect(formatearMiles(2340), '2.340');
      expect(formatearMiles(1234567), '1.234.567');
      expect(formatearMiles(85), '85');
      expect(formatearDuracion(2892), '48:12');
      expect(formatearDuracion(3930), '1:05:30');
      expect(formatearVolumen(850), '850 kg');
      expect(formatearVolumen(4810), '4,8 t');
      expect(conSigno(1, 'kg'), '+1 kg');
      expect(conSigno(-5, 's'), '−5 s');
    });

    test('ResumenInicio y valor de los ajustes recientes', () {
      final r = ResumenInicio.fromJson({
        'resumen': {
          'nombre': 'Adrián Poveda', 'objetivoSemana': 3, 'sesionesSemana': 2,
          'volumenSemanaKg': 4810.0, 'volumenSemanaAnteriorKg': 4300.0, 'rachaDias': 12,
        },
        'volumenSemana': [
          for (var i = 0; i < 7; i++) {'diaSemana': i, 'fecha': '2026-10-12T00:00:00', 'volumenKg': i == 2 ? 2340.0 : 0.0},
        ],
        'ajustes': [
          {'ejercicio': 'Remo con mancuerna', 'accion': 'SUBIR', 'fecha': '2026-10-15T09:00:00', 'pesoAntes': 16.0, 'pesoDespues': 17.0},
          {'ejercicio': 'Flexiones', 'accion': 'SUBIR', 'fecha': '2026-10-15T09:00:00', 'repsMinAntes': 10, 'repsMinDespues': 12},
          {'ejercicio': 'Plancha frontal', 'accion': 'BAJAR', 'fecha': '2026-10-15T09:00:00', 'durMinAntes': 30, 'durMinDespues': 25},
        ],
      });
      expect(r.nombreCorto, 'Adrián');
      expect(r.volumenDias.length, 7);
      expect(r.variacionVolumenPct, 12);
      expect(r.ajustes.map((a) => a.valor).toList(), ['+1 kg', '+2 reps', '−5 s']);
    });
  });

  group('Cuestionario, IA y tipos de serie', () {
    test('RecomendacionDias y ResultadoRutina', () {
      final rec = RecomendacionDias.fromJson({
        'recomendado': 4, 'minimo': 3, 'maximo': 4, 'motivo': 'Texto', 'fuente': 'ACSM (2009)',
      });
      expect(rec.recomendado, 4);

      final res = ResultadoRutina.fromJson({
        'generadaConIa': true,
        'rutina': {
          'rutinaId': 9, 'nombre': 'Torso/Pierna', 'origen': 'I', 'activa': true,
          'descripcion': 'Cuatro días alternando torso y pierna.',
          'dias': [
            {'rutinaDiaId': 1, 'orden': 1, 'nombre': 'Torso A', 'musculos': ['Pecho', 'Espalda'], 'ejercicios': []},
          ],
        },
      });
      expect(res.generadaConIa, isTrue);
      expect(res.rutina.generadaConIa, isTrue);
      expect(res.rutina.descripcion, startsWith('Cuatro días'));
      expect(res.rutina.dias.single.musculos, ['Pecho', 'Espalda']);
    });

    test('Opciones del cuestionario coinciden con los Id de la base de datos', () {
      expect(nivelesCuestionario.map((o) => o.id), [1, 2, 3]);
      // gym.Objetivo: 1 Fuerza, 2 Hipertrofia, 3 Pérdida de grasa
      expect({for (final o in objetivosCuestionario) o.titulo: o.id},
          {'Perder grasa': 3, 'Ganar fuerza': 1, 'Ganar músculo': 2});
    });

    test('Tipos de serie', () {
      expect(TipoSerie.todos.map((t) => t.codigo), ['N', 'C', 'F', 'D', 'R']);
      expect(TipoSerie.porCodigo('D').nombre, 'Dropset');
      expect(TipoSerie.porCodigo('X').codigo, 'N');
    });
  });

  group('Recomendaciones de sesión', () {
    EjercicioRutina ej({bool compuesto = true, String tipo = 'R', double? peso = 60}) => EjercicioRutina(
          rutinaDiaEjercicioId: 1, orden: 1, ejercicioId: 1, nombre: 'Press de banca con barra',
          series: 3, tipoMedida: tipo, descansoSeg: 120, repsMin: 6, repsMax: 10,
          pesoObjetivoKg: peso, compuesto: compuesto,
        );

    test('calentamiento: 2 series en el primer compuesto, 1 en los siguientes, ninguna en aislamiento', () {
      final primero = calentamientoRecomendado(ej(), hayCompuestoAnterior: false)!;
      expect(primero.series.map((s) => s.texto), ['30 kg × 10', '45 kg × 5']);
      expect(calentamientoRecomendado(ej(), hayCompuestoAnterior: true)!.texto, '36 kg × 6');
      expect(calentamientoRecomendado(ej(peso: null), hayCompuestoAnterior: false)!.texto, '10 reps ligeras · 5 reps ligeras');
      expect(calentamientoRecomendado(ej(compuesto: false), hayCompuestoAnterior: false), isNull);
      expect(calentamientoRecomendado(ej(tipo: 'T'), hayCompuestoAnterior: false), isNull);
    });

    test('tipo de serie recomendado', () {
      String tipo(int nivel, int objetivo, bool compuesto, int serie) => recomendarTipoSerie(
            nivel: nivel, objetivo: objetivo, compuesto: compuesto, porTiempo: false, serie: serie, totalSeries: 3,
          ).$1;
      expect(tipo(1, 2, false, 3), 'N'); // principiante
      expect(tipo(3, 1, false, 3), 'N'); // fuerza
      expect(tipo(3, 2, true, 3), 'N');  // compuesto
      expect(tipo(2, 2, false, 2), 'N'); // no es la última
      expect(tipo(2, 2, false, 3), 'F'); // intermedio, músculo, última de aislamiento
      expect(tipo(3, 2, false, 3), 'D'); // avanzado
      expect(tipo(2, 3, false, 3), 'R'); // perder grasa
    });
  });

  group('Músculos por ejercicio', () {
    test('texto de músculos principales y secundarios', () {
      expect(textoMusculos(['Pecho'], ['Tríceps', 'Hombros']), 'Pecho · también Tríceps y Hombros');
      expect(textoMusculos(['Espalda'], ['Bíceps']), 'Espalda · también Bíceps');
      expect(textoMusculos(['Bíceps'], []), 'Bíceps');
      expect(textoMusculos([], ['Core']), '');
    });

    test('catálogo y rutina leen los grupos musculares', () {
      final e = EjercicioResumen.fromJson({
        'ejercicioId': 1, 'nombre': 'Press de banca con barra', 'nivelMinimoId': 2, 'tipoMedida': 'R',
        'principales': 'Pecho', 'secundarios': 'Tríceps|Hombros',
      });
      expect(e.principales, ['Pecho']);
      expect(e.secundarios, ['Tríceps', 'Hombros']);

      final r = EjercicioRutina.fromJson({
        'rutinaDiaEjercicioId': 1, 'orden': 1, 'ejercicioId': 1, 'nombre': 'Remo con barra',
        'series': 3, 'tipoMedida': 'R', 'descansoSeg': 90,
        'musculosPrincipales': ['Espalda'], 'musculosSecundarios': ['Bíceps', 'Lumbares'],
      });
      expect(r.principales, ['Espalda']);
      expect(r.secundarios, ['Bíceps', 'Lumbares']);
    });
  });
}
