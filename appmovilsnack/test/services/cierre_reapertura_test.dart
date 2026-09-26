import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_appsnack/services/admin_estadisticas_service.dart';
import 'package:front_appsnack/services/cierre_turno_service.dart';
import 'package:front_appsnack/services/vendedor_ventas_service.dart';

const sectorPath = 'eventos/ev1/sectores/s1';
const precio = 1000.0;

/// Cierre, reapertura y segundo cierre de un sector: cada turno cuenta solo
/// sus propias ventas en el sector, el ranking y las estadísticas.
void main() {
  late FakeFirebaseFirestore db;
  late CierreTurnoService service;

  Future<Map<String, dynamic>> sector() async =>
      (await db.doc(sectorPath).get()).data()!;

  /// Replica ResumenCierreTurno: abre el conteo (stock actual), cuenta
  /// [contado], calcula totales, cierra y suma al ranking del vendedor.
  Future<({double monto, int unidades})> cerrarTurno(
    String cierreId,
    int contado,
  ) async {
    final stockAlIniciar = await service.leerStock('ev1', 's1');
    final totales = CierreTurnoService.totalesVenta([
      (stockSistema: stockAlIniciar['p1']!, contado: contado, precio: precio),
    ]);
    final cambiados = await service.cerrarTurno(
      eventoId: 'ev1',
      sectorId: 's1',
      stockAlIniciar: stockAlIniciar,
      conteoFinal: {'p1': contado},
      cierreData: {
        'cierreId': cierreId,
        'fecha': FieldValue.serverTimestamp(),
        'totalEstimado': totales.monto,
        'totalUnidadesVendidas': totales.unidades,
        'productos': [
          {
            'productoId': 'p1',
            'cantidadMaxima': stockAlIniciar['p1'],
            'cantidadFinal': contado,
            'cantidadVendida': totales.unidades,
            'subtotal': totales.monto,
          },
        ],
      },
      totalEstimado: totales.monto,
      vendedorUid: 'vend1',
    );
    expect(cambiados, isEmpty);
    await VendedorVentasService.registrarCierreTurno(
      vendedorUid: 'vend1',
      cierreId: cierreId,
      monto: totales.monto,
      unidades: totales.unidades,
    );
    return totales;
  }

  /// Replica EventosManagement._reabrirSector.
  Future<void> reabrir() => db.doc(sectorPath).update({
        'turnoCerrado': false,
        'turnoCerradoAt': FieldValue.delete(),
      });

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = CierreTurnoService(db);
    VendedorVentasService.usarFirestoreDePrueba(db);
    await db.doc('usuarios/vend1').set({'rol': 'vendedor', 'username': 'paz'});
    await db.doc('eventos/ev1').set({'nombre': 'Partido'});
    await db.doc(sectorPath).set({'nombre': 'Norte', 'totalVendido': 0.0});
    await db.doc('$sectorPath/stock/p1').set({
      'nombre': 'Bebida',
      'precio': precio,
      'cantidad': 10,
      'cantidadInicial': 10,
    });
  });

  tearDown(() => VendedorVentasService.usarFirestoreDePrueba(null));

  test('stock 10 → cierre con 6 → reapertura → cierre con 2: 8 vendidas, no 12',
      () async {
    final turno1 = await cerrarTurno('c1', 6);
    expect(turno1.unidades, 4);

    await reabrir();
    // El segundo turno parte del conteo del primero, no del stock inicial.
    expect(CierreTurnoService.inicioDelTurno(await sector()), {'p1': 6});
    expect(await service.leerStock('ev1', 's1'), {'p1': 6});

    final turno2 = await cerrarTurno('c2', 2);
    expect(turno2.unidades, 4, reason: 'desde 6, no desde el stock inicial 10');

    // Sector: suma ambos turnos una sola vez.
    final s = await sector();
    expect(s['totalVendido'], 8 * precio);
    expect(s['ultimoCierre']['cierreId'], 'c2');

    // Historial y estadísticas: los dos turnos, 8 unidades.
    final historial = (await db.collection('$sectorPath/cierres').get())
        .docs
        .map((d) => d.data())
        .toList();
    final cierres =
        AdminEstadisticasService.cierresDelSector(historial: historial, sectorData: s);
    expect(cierres.map((c) => c['cierreId']), ['c1', 'c2']);
    expect(AdminEstadisticasService.montoCierres(cierres), 8 * precio);
    expect(
      cierres.fold<int>(0, (t, c) => t + (c['totalUnidadesVendidas'] as int)),
      8,
    );

    // Ranking del vendedor: 8 unidades en 2 cierres.
    final usuario = (await db.doc('usuarios/vend1').get()).data()!;
    expect(usuario['ventasAcumuladas']['unidades'], 8);
    expect(usuario['ventasAcumuladas']['monto'], 8 * precio);
    expect(usuario['ventasAcumuladas']['cierres'], 2);
    expect(usuario['itemsvendidos'], 8);
    expect(usuario['totalvendido'], 8 * precio);
  });

  test('registrar dos veces el mismo cierre en el ranking no lo duplica',
      () async {
    await cerrarTurno('c1', 6);
    await VendedorVentasService.registrarCierreTurno(
      vendedorUid: 'vend1',
      cierreId: 'c1',
      monto: 4 * precio,
      unidades: 4,
    );

    final usuario = (await db.doc('usuarios/vend1').get()).data()!;
    expect(usuario['ventasAcumuladas']['unidades'], 4);
    expect(usuario['ventasAcumuladas']['cierres'], 1);
  });

  test('un sector nunca cerrado empieza el turno con el stock inicial', () async {
    expect(CierreTurnoService.inicioDelTurno(await sector()), isNull);
  });

  test('sectores cerrados antes del historial usan ultimoCierre', () {
    final cierres = AdminEstadisticasService.cierresDelSector(
      historial: const [],
      sectorData: {
        'ultimoCierre': {'cierreId': 'viejo', 'totalEstimado': 5000},
      },
    );
    expect(cierres.map((c) => c['cierreId']), ['viejo']);
    expect(AdminEstadisticasService.montoCierres(cierres), 5000);
  });

  test('el bandejeo anterior al último cierre ya está dentro de él', () {
    final t1 = Timestamp.fromMillisecondsSinceEpoch(1000);
    final t2 = Timestamp.fromMillisecondsSinceEpoch(2000);
    final cierres = AdminEstadisticasService.cierresDelSector(
      historial: [
        {'cierreId': 'c2', 'fecha': t2},
        {'cierreId': 'c1', 'fecha': t1},
      ],
    );
    expect(cierres.map((c) => c['cierreId']), ['c1', 'c2']);
    expect(AdminEstadisticasService.fechaUltimoCierre(cierres), t2);
  });
}
