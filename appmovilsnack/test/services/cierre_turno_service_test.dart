import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_appsnack/services/cierre_turno_service.dart';
import 'package:front_appsnack/services/incidencias_service.dart';

const sectorPath = 'eventos/ev1/sectores/s1';

void main() {
  late FakeFirebaseFirestore db;
  late CierreTurnoService service;

  DocumentReference<Map<String, dynamic>> stock(String id) =>
      db.doc('$sectorPath/stock/$id');

  Future<int?> cantidad(String id) async =>
      (await stock(id).get()).data()?['cantidad'] as int?;

  Future<Set<String>> cerrar(
    Map<String, int> stockAlIniciar, {
    Map<String, int> conteoFinal = const {'p1': 3, 'p2': 1},
  }) =>
      service.cerrarTurno(
        eventoId: 'ev1',
        sectorId: 's1',
        stockAlIniciar: stockAlIniciar,
        conteoFinal: conteoFinal,
        cierreData: {'cierreId': 'c1', 'totalEstimado': 9000},
        totalEstimado: 9000,
        vendedorUid: 'vend1',
        vendedorNombre: 'paz',
        sectorNombre: 'Norte',
        nombresProductos: {'p1': 'Bebida', 'p2': 'Papas'},
      );

  Future<List<Map<String, dynamic>>> incidencias() async =>
      (await db.collection('eventos/ev1/discrepancias').get())
          .docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = CierreTurnoService(db);
    await db.doc(sectorPath).set({
      'nombre': 'Norte',
      'totalVendido': 0,
      'vendedoresasignados': [
        {'nombre': 'paz'},
        {'nombre': 'otro'},
      ],
      'borradorCierreTurno': {'enResumen': true},
    });
    await stock('p1').set({'nombre': 'Bebida', 'cantidad': 10});
    await stock('p2').set({'nombre': 'Papas', 'cantidad': 5});
  });

  group('movimientosPendientes', () {
    test('sin traspasos ni rondas abiertas se puede contar', () async {
      await db.doc('$sectorPath/traspasos_entrantes/t0').set({
        'estado': 'confirmado',
        'nombre': 'Bebida',
        'cantidadEnviada': 2,
      });
      await db.doc('$sectorPath/bandejeros/b1').set({'nombre': 'Pedro'});
      await db
          .doc('$sectorPath/bandejeros/b1/rondas/r1')
          .set({'estado': 'rendida'});

      expect(await service.movimientosPendientes('ev1', 's1'), isEmpty);
    });

    test('lista traspasos pendientes (uno por pedido) y rondas abiertas',
        () async {
      for (final (id, nombre, cant) in [('t1', 'Bebida', 5), ('t2', 'Papas', 2)]) {
        await db.doc('$sectorPath/traspasos_entrantes/$id').set({
          'estado': 'pendiente',
          'pedidoId': 'ped1',
          'sectorOrigenNombre': 'Sur',
          'nombre': nombre,
          'cantidadEnviada': cant,
        });
      }
      await db.doc('$sectorPath/bandejeros/b1').set({'nombre': 'Pedro'});
      await db
          .doc('$sectorPath/bandejeros/b1/rondas/r1')
          .set({'estado': 'en_curso'});

      expect(await service.movimientosPendientes('ev1', 's1'), [
        'Traspaso sin confirmar desde Sur: Bebida ×5, Papas ×2',
        'Ronda abierta de Pedro',
      ]);
    });
  });

  group('cerrarTurno', () {
    test('sin cambios: escribe el conteo y cierra el sector', () async {
      final cambiados = await cerrar({'p1': 10, 'p2': 5});

      expect(cambiados, isEmpty);
      expect(await cantidad('p1'), 3);
      expect(await cantidad('p2'), 1);
      final sector = (await db.doc(sectorPath).get()).data()!;
      expect(sector['turnoCerrado'], true);
      expect(sector['totalVendido'], 9000);
      expect(sector['ultimoCierre']['cierreId'], 'c1');
      expect(sector.containsKey('borradorCierreTurno'), isFalse);
      expect(sector['vendedoresasignados'], [
        {'nombre': 'otro'},
      ]);
      expect(await incidencias(), isEmpty);
    });

    test('sobrante: guarda lo contado y registra la incidencia en la misma transacción',
        () async {
      // Sistema: 10 bebidas; se contaron 12.
      final cambiados =
          await cerrar({'p1': 10, 'p2': 5}, conteoFinal: {'p1': 12, 'p2': 1});

      expect(cambiados, isEmpty);
      expect(await cantidad('p1'), 12);
      final lista = await incidencias();
      expect(lista, hasLength(1));
      final inc = lista.single;
      expect(inc['id'], 'c1_p1');
      expect(inc, containsPair('tipo', TipoIncidencia.sobranteConteo));
      expect(inc, containsPair('estado', 'pendiente'));
      expect(inc, containsPair('eventoId', 'ev1'));
      expect(inc, containsPair('cierreId', 'c1'));
      expect(inc, containsPair('sectorId', 's1'));
      expect(inc, containsPair('sectorNombre', 'Norte'));
      expect(inc, containsPair('productoId', 'p1'));
      expect(inc, containsPair('nombreProducto', 'Bebida'));
      expect(inc, containsPair('stockSistema', 10));
      expect(inc, containsPair('cantidadContada', 12));
      expect(inc, containsPair('diferencia', 2));
      expect(inc, containsPair('vendedorUid', 'vend1'));
      expect(inc, containsPair('vendedorNombre', 'paz'));
      expect(inc['fecha'], isNotNull);
    });

    test('si el stock cambió no se registra ningún sobrante', () async {
      await stock('p1').update({'cantidad': 14});

      await cerrar({'p1': 10, 'p2': 5}, conteoFinal: {'p1': 12, 'p2': 1});

      expect(await incidencias(), isEmpty);
      expect(await cantidad('p1'), 14);
    });

    test('traspaso confirmado durante el conteo: no escribe nada', () async {
      // Llegan 4 bebidas mientras se contaba (se abrió el conteo con 10).
      await stock('p1').update({'cantidad': 14});

      final cambiados = await cerrar({'p1': 10, 'p2': 5});

      expect(cambiados, {'p1'});
      expect(await cantidad('p1'), 14);
      expect(await cantidad('p2'), 5);
      final sector = (await db.doc(sectorPath).get()).data()!;
      expect(sector['turnoCerrado'], isNull);
      expect(sector['totalVendido'], 0);
      expect(sector.containsKey('borradorCierreTurno'), isTrue);
    });

    test('ronda rendida durante el conteo (devuelve sobrante): no escribe',
        () async {
      await stock('p2').update({'cantidad': 7});

      expect(await cerrar({'p1': 10, 'p2': 5}), {'p2'});
      expect(await cantidad('p1'), 10);
    });

    test('producto nuevo en el sector durante el conteo: no escribe', () async {
      await stock('p3').set({'nombre': 'Maní', 'cantidad': 6});

      expect(await cerrar({'p1': 10, 'p2': 5}), {'p3'});
      expect(await cantidad('p1'), 10);
    });

    test('producto borrado durante el conteo: no escribe', () async {
      await stock('p2').delete();

      expect(await cerrar({'p1': 10, 'p2': 5}), {'p2'});
      expect(await cantidad('p1'), 10);
    });

    test('turno ya cerrado desde otro dispositivo', () async {
      await db.doc(sectorPath).update({'turnoCerrado': true});

      expect(
        () => cerrar({'p1': 10, 'p2': 5}),
        throwsA(isA<TurnoYaCerradoException>()),
      );
    });
  });

  group('ventas con sobrante', () {
    test('las ventas nunca son negativas', () {
      expect(CierreTurnoService.unidadesVendidas(stockSistema: 10, contado: 3), 7);
      expect(CierreTurnoService.unidadesVendidas(stockSistema: 10, contado: 10), 0);
      expect(CierreTurnoService.unidadesVendidas(stockSistema: 10, contado: 12), 0);
      expect(CierreTurnoService.sobrante(stockSistema: 10, contado: 12), 2);
      expect(CierreTurnoService.sobrante(stockSistema: 10, contado: 3), 0);
    });

    test('un sobrante no resta del total ni de las unidades (ranking)', () {
      final sinSobrante = CierreTurnoService.totalesVenta([
        (stockSistema: 10, contado: 3, precio: 1000),
        (stockSistema: 5, contado: 5, precio: 500),
      ]);
      final conSobrante = CierreTurnoService.totalesVenta([
        (stockSistema: 10, contado: 3, precio: 1000),
        (stockSistema: 5, contado: 8, precio: 500),
      ]);

      expect(sinSobrante.monto, 7000);
      expect(sinSobrante.unidades, 7);
      // Contar 3 de más en Papas no descuenta 3 × 500 ni 3 unidades.
      expect(conSobrante.monto, 7000);
      expect(conSobrante.unidades, 7);
    });
  });

  test('productosCambiados compara cantidades, altas y bajas', () {
    expect(
      CierreTurnoService.productosCambiados(
        {'a': 1, 'b': 2, 'c': 3},
        {'a': 1, 'b': 5, 'd': 1},
      ),
      {'b', 'c', 'd'},
    );
  });
}
