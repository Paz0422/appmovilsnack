import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_appsnack/services/cierre_turno_service.dart';
import 'package:front_appsnack/services/stock_service.dart';

const evento = 'eventos/ev1';
const sector = '$evento/sectores/s1';

void main() {
  late FakeFirebaseFirestore db;
  late StockService service;

  Future<int?> cantidad(String producto) async =>
      (await db.doc('$sector/stock/$producto').get()).data()?['cantidad'] as int?;

  Future<List<Map<String, dynamic>>> movimientos() async =>
      (await db.collection('$evento/movimientos').get())
          .docs
          .map((d) => d.data())
          .toList();

  Future<void> agregar({int cantidad = 12, String? motivo, String producto = 'p1'}) =>
      service.agregarStock(
        eventoId: 'ev1',
        sectorId: 's1',
        productoId: producto,
        cantidad: cantidad,
        adminUid: 'admin1',
        adminNombre: 'admin',
        motivo: motivo,
      );

  Matcher falla(String mensaje) => throwsA(
        isA<StockException>().having((e) => e.mensaje, 'mensaje', mensaje),
      );

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = StockService(db);
    await db.doc(evento).set({'nombre': 'Partido'});
    await db.doc(sector).set({'nombre': 'Norte'});
    await db.doc('$sector/stock/p1').set({'nombre': 'Bebida', 'cantidad': 10});
  });

  group('agregarStock', () {
    test('suma las unidades y registra la reposición', () async {
      await agregar(motivo: '  Compra durante el evento ');

      expect(await cantidad('p1'), 22);
      final m = (await movimientos()).single;
      expect(m, containsPair('tipo', 'reposicion'));
      expect(m, containsPair('sectorId', 's1'));
      expect(m, containsPair('sectorNombre', 'Norte'));
      expect(m, containsPair('productoId', 'p1'));
      expect(m, containsPair('nombreProducto', 'Bebida'));
      expect(m, containsPair('cantidad', 12));
      expect(m, containsPair('motivo', 'Compra durante el evento'));
      expect(m, containsPair('adminUid', 'admin1'));
      expect(m, containsPair('adminNombre', 'admin'));
      expect(m['fecha'], isNotNull);
    });

    test('suma sobre lo que haya, no escribe una cantidad fija', () async {
      await agregar(cantidad: 5);
      // Una merma entre dos reposiciones no se pierde.
      await db.doc('$sector/stock/p1').update({'cantidad': 13});
      await agregar(cantidad: 5);

      expect(await cantidad('p1'), 18);
      expect(await movimientos(), hasLength(2));
    });

    test('el motivo es opcional', () async {
      await agregar(motivo: '   ');
      expect((await movimientos()).single.containsKey('motivo'), isFalse);
    });

    test('no en un sector con turno cerrado', () async {
      await db.doc(sector).update({'turnoCerrado': true});

      await expectLater(
        agregar(),
        falla('El sector ya cerró su turno: no se puede agregar stock.'),
      );
      expect(await cantidad('p1'), 10);
      expect(await movimientos(), isEmpty);
    });

    test('no un producto que no está en el sector, ni cantidades ≤ 0', () async {
      await expectLater(
        agregar(producto: 'nuevo'),
        falla('El producto no está en el stock del sector.'),
      );
      await expectLater(
        agregar(cantidad: 0),
        falla('La cantidad debe ser mayor que cero.'),
      );
      expect(await movimientos(), isEmpty);
    });

    test('una reposición durante el conteo activa el aviso de stock cambiado',
        () async {
      // El vendedor abre el conteo con 10 bebidas y cuenta 4.
      final stockAlIniciar = {'p1': 10};
      await agregar(cantidad: 6);

      final cambiados = await CierreTurnoService(db).cerrarTurno(
        eventoId: 'ev1',
        sectorId: 's1',
        stockAlIniciar: stockAlIniciar,
        conteoFinal: {'p1': 4},
        cierreData: {'cierreId': 'c1'},
        totalEstimado: 9000,
        vendedorUid: 'vend1',
      );

      expect(cambiados, {'p1'});
      expect(await cantidad('p1'), 16);
      expect((await db.doc(sector).get()).data()!['turnoCerrado'], isNull);
    });
  });

  group('bloqueosStockInicial', () {
    Future<List<String>> bloqueos() => service.bloqueosStockInicial('ev1', 's1');

    test('un sector sin movimientos puede cargar stock inicial', () async {
      expect(await bloqueos(), isEmpty);
    });

    test('un traspaso ya recibido y confirmado no bloquea (se suma solo)',
        () async {
      await db.doc('$sector/traspasos_entrantes/t1').set({'estado': 'confirmado'});
      expect(await bloqueos(), isEmpty);
    });

    test('cada movimiento bloquea con su motivo', () async {
      final casos = <String, Future<void> Function()>{
        'El turno del sector está cerrado.': () =>
            db.doc(sector).update({'turnoCerrado': true}),
        'El sector ya tuvo un cierre de turno.': () =>
            db.doc(sector).update({'ultimoCierre': {'cierreId': 'c1'}}),
        'Hay ventas de bandejeo registradas.': () => db
            .collection('transacciones')
            .add({'eventoId': 'ev1', 'sectorId': 's1', 'montoTotal': 1000}),
        'El sector ya envió traspasos.': () =>
            db.doc('$sector/traspasos_salientes/t1').set({'estado': 'pendiente'}),
        'Hay traspasos entrantes sin confirmar: confírmelos primero y se '
            'sumarán al stock inicial.': () =>
            db.doc('$sector/traspasos_entrantes/t2').set({'estado': 'pendiente'}),
        'Hay rondas de bandejero registradas.': () async {
          await db.doc('$sector/bandejeros/b1').set({'nombre': 'Pedro'});
          await db.doc('$sector/bandejeros/b1/rondas/r1').set({'estado': 'en_curso'});
        },
        'Hay mermas registradas.': () =>
            db.collection('$sector/mermas').add({'cantidadPerdida': 1}),
        'Ya se agregó stock durante el evento.': () => agregar(),
      };

      for (final caso in casos.entries) {
        db = FakeFirebaseFirestore();
        service = StockService(db);
        await db.doc(sector).set({'nombre': 'Norte'});
        await db.doc('$sector/stock/p1').set({'nombre': 'Bebida', 'cantidad': 10});
        await caso.value();

        expect(await bloqueos(), [caso.key], reason: caso.key);
      }
    });

    test('las ventas de otro sector no bloquean', () async {
      await db
          .collection('transacciones')
          .add({'eventoId': 'ev1', 'sectorId': 's2', 'montoTotal': 1000});
      await db.collection('$evento/movimientos').add({'sectorId': 's2'});
      expect(await bloqueos(), isEmpty);
    });
  });
}
