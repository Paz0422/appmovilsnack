import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_appsnack/services/traspaso_service.dart';

const evento = 'eventos/ev1';

void main() {
  late FakeFirebaseFirestore db;
  late TraspasoService service;

  Future<int?> cantidad(String sector, String producto) async =>
      (await db.doc('$evento/sectores/$sector/stock/$producto').get())
          .data()?['cantidad'] as int?;

  Future<void> cerrarTurno(String sector) =>
      db.doc('$evento/sectores/$sector').update({'turnoCerrado': true});

  Future<String> enviar({int cantidad = 5}) => service.enviar(
        eventoId: 'ev1',
        origenId: 'sur',
        origenNombre: 'Sur',
        destinoId: 'norte',
        destinoNombre: 'Norte',
        lineas: [
          LineaEnvio(
            productoId: 'p1',
            nombre: 'Bebida',
            precio: 1500,
            cantidad: cantidad,
          ),
        ],
      );

  Future<List<String>> idsEntrantes() async => (await db
          .collection('$evento/sectores/norte/traspasos_entrantes')
          .get())
      .docs
      .map((d) => d.id)
      .toList();

  Future<ResultadoConfirmacion> confirmar(List<String> ids, int recibida) =>
      service.confirmarRecepcion(
        eventoId: 'ev1',
        sectorId: 'norte',
        traspasoIds: ids,
        recibidas: {for (final id in ids) id: recibida},
        comentarios: {for (final id in ids) id: 'Faltaron'},
        vendedorUid: 'vend1',
        vendedorNombre: 'paz',
      );

  Future<List<Map<String, dynamic>>> discrepancias() async =>
      (await db.collection('$evento/discrepancias').get())
          .docs
          .map((d) => d.data())
          .toList();

  Matcher mensaje(String texto) => throwsA(
        isA<TraspasoException>().having((e) => e.mensaje, 'mensaje', texto),
      );

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = TraspasoService(db);
    await db.doc(evento).set({'nombre': 'Partido'});
    for (final (id, nombre) in [('sur', 'Sur'), ('norte', 'Norte')]) {
      await db.doc('$evento/sectores/$id').set({'nombre': nombre});
      await db
          .doc('$evento/sectores/$id/stock/p1')
          .set({'nombre': 'Bebida', 'cantidad': 20});
    }
  });

  group('enviar', () {
    test('entre sectores abiertos descuenta el origen y deja el pedido pendiente',
        () async {
      await enviar();

      expect(await cantidad('sur', 'p1'), 15);
      final entrantes = await db
          .collection('$evento/sectores/norte/traspasos_entrantes')
          .get();
      expect(entrantes.docs.single.data()['estado'], 'pendiente');
      final salientes =
          await db.collection('$evento/sectores/sur/traspasos_salientes').get();
      expect(salientes.docs.single.id, entrantes.docs.single.id);
    });

    test('hacia un sector con turno cerrado: no envía nada', () async {
      await cerrarTurno('norte');

      await expectLater(
        enviar(),
        mensaje(TraspasoService.mensajeEnvioADestinoCerrado('Norte')),
      );
      expect(await cantidad('sur', 'p1'), 20);
      expect(await idsEntrantes(), isEmpty);
    });

    test('desde un sector con turno cerrado: no envía nada', () async {
      await cerrarTurno('sur');

      await expectLater(
        enviar(),
        mensaje(TraspasoService.mensajeOrigenCerradoEnvio('Sur')),
      );
      expect(await cantidad('sur', 'p1'), 20);
      expect(await idsEntrantes(), isEmpty);
    });
  });

  group('confirmarRecepcion', () {
    test('completa: suma al destino', () async {
      await enviar();
      await confirmar(await idsEntrantes(), 5);

      expect(await cantidad('norte', 'p1'), 25);
      expect(await cantidad('sur', 'p1'), 15);
    });

    test('con diferencia: devuelve lo faltante al origen', () async {
      await enviar();
      final r = await confirmar(await idsEntrantes(), 3);

      expect(r.unidadesDevueltas, 2);
      expect(r.faltanteRegistrado, 0);
      expect(await cantidad('norte', 'p1'), 23);
      expect(await cantidad('sur', 'p1'), 17);
      expect(await discrepancias(), isEmpty);
    });

    test('destino con turno cerrado: "El sector destino ya cerró su turno"',
        () async {
      await enviar();
      final ids = await idsEntrantes();
      await cerrarTurno('norte');

      await expectLater(confirmar(ids, 5), mensaje('El sector destino ya cerró su turno'));
      expect(await cantidad('norte', 'p1'), 20);
      final entrante = await db
          .doc('$evento/sectores/norte/traspasos_entrantes/${ids.single}')
          .get();
      expect(entrante.data()!['estado'], 'pendiente');
    });

    test('origen cerrado con diferencia: confirma lo recibido y registra el faltante',
        () async {
      await enviar();
      final ids = await idsEntrantes();
      await cerrarTurno('sur');

      final r = await confirmar(ids, 3);

      expect(r.faltanteRegistrado, 2);
      expect(r.unidadesDevueltas, 0);
      expect(
        TraspasoService.mensajeFaltanteRegistrado(r.faltanteRegistrado),
        'Se registró un faltante de 2 unidades. El administrador lo revisará.',
      );
      // Destino suma lo recibido; el origen cerrado no recupera nada.
      expect(await cantidad('norte', 'p1'), 23);
      expect(await cantidad('sur', 'p1'), 15);

      final entrante = (await db
              .doc('$evento/sectores/norte/traspasos_entrantes/${ids.single}')
              .get())
          .data()!;
      expect(entrante['estado'], 'confirmado');
      expect(entrante['discrepanciaId'], ids.single);

      final discrepancia =
          (await db.doc('$evento/discrepancias/${ids.single}').get()).data()!;
      expect(discrepancia, containsPair('estado', 'pendiente'));
      expect(discrepancia, containsPair('sectorOrigenNombre', 'Sur'));
      expect(discrepancia, containsPair('sectorDestinoNombre', 'Norte'));
      expect(discrepancia, containsPair('productoId', 'p1'));
      expect(discrepancia, containsPair('cantidadEnviada', 5));
      expect(discrepancia, containsPair('cantidadRecibida', 3));
      expect(discrepancia, containsPair('diferencia', 2));
      expect(discrepancia, containsPair('vendedorUid', 'vend1'));
      expect(discrepancia, containsPair('vendedorNombre', 'paz'));
      expect(discrepancia['fecha'], isNotNull);
    });

    test('el admin ve las discrepancias pendientes y las resuelve', () async {
      await enviar();
      final ids = await idsEntrantes();
      await cerrarTurno('sur');
      await confirmar(ids, 3);

      final pendientes = await service.discrepanciasPendientes();
      expect(pendientes.map((d) => d.id), [ids.single]);

      await service.resolverDiscrepancia(
        eventoId: 'ev1',
        discrepanciaId: ids.single,
        adminUid: 'admin1',
        nota: 'Se descontó',
      );

      expect(await service.discrepanciasPendientes(), isEmpty);
      final resuelta = (await db.doc('$evento/discrepancias/${ids.single}').get())
          .data()!;
      expect(resuelta, containsPair('estado', 'resuelta'));
      expect(resuelta, containsPair('resueltaPor', 'admin1'));
      expect(resuelta, containsPair('notaResolucion', 'Se descontó'));
    });

    test('origen cerrado sin diferencia: se puede confirmar', () async {
      await enviar();
      final ids = await idsEntrantes();
      await cerrarTurno('sur');

      final r = await confirmar(ids, 5);
      expect(r.faltanteRegistrado, 0);
      expect(await cantidad('norte', 'p1'), 25);
      expect(await cantidad('sur', 'p1'), 15);
      expect(await discrepancias(), isEmpty);
    });

    test('un pedido ya confirmado no se confirma dos veces', () async {
      await enviar();
      final ids = await idsEntrantes();
      await confirmar(ids, 5);

      await expectLater(confirmar(ids, 5), mensaje('Este pedido ya fue procesado.'));
      expect(await cantidad('norte', 'p1'), 25);
    });
  });
}
