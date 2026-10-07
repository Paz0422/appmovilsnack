import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_appsnack/services/admin_estadisticas_service.dart';

Timestamp hora(int h) => Timestamp.fromDate(DateTime(2026, 9, 1, h));

/// Dos eventos con sectores cerrados, reabiertos, abiertos sin ventas y
/// cierres antiguos (solo `ultimoCierre`), más bandejeo antes y después del
/// último cierre. Fija los totales del panel admin.
Future<FakeFirebaseFirestore> escenario() async {
  final db = FakeFirebaseFirestore();
  await db.doc('productos/p1').set({'nombre': 'Agua', 'categoria': 'Bebestibles'});
  await db.doc('productos/p2').set({'nombre': 'Papas', 'categoria': 'Snacks'});

  await db.doc('eventos/e1').set({'nombre': 'Partido A', 'activo': true});
  await db.doc('eventos/e2').set({'nombre': 'Partido B', 'activo': false});

  // e1/s1: cerrado, con historial.
  final cierreC1 = {
    'cierreId': 'c1',
    'totalEstimado': 1000,
    'fecha': hora(10),
    'productos': [
      {'productoId': 'p1', 'cantidadVendida': 5, 'precio': 200},
    ],
  };
  await db.doc('eventos/e1/sectores/s1').set({
    'nombre': 'Norte',
    'turnoCerrado': true,
    'ultimoCierre': cierreC1,
  });
  await db.doc('eventos/e1/sectores/s1/cierres/c1').set(cierreC1);

  // e1/s2: cerró una vez y se reabrió.
  await db.doc('eventos/e1/sectores/s2').set({
    'nombre': 'Sur',
    'turnoCerrado': false,
  });
  await db.doc('eventos/e1/sectores/s2/cierres/c0').set({
    'cierreId': 'c0',
    'totalEstimado': 300,
    'fecha': hora(5),
    'productos': [
      {
        'productoId': 'p2',
        'categoria': 'Snacks',
        'cantidadInicial': 5,
        'cantidadFinal': 2,
        'precio': 100,
      },
    ],
  });

  // e1/s3: abierto, sin ventas.
  await db.doc('eventos/e1/sectores/s3').set({'nombre': 'Este'});

  // e2/s4: cerrado antes del historial (solo ultimoCierre).
  await db.doc('eventos/e2/sectores/s4').set({
    'nombre': 'Oeste',
    'turnoCerrado': true,
    'ultimoCierre': {
      'totalEstimado': 500,
      'fecha': hora(9),
      'productos': [
        {'productoId': 'p2', 'cantidadVendida': 2, 'precio': 250},
      ],
    },
  });

  final tx = db.collection('transacciones');
  // Antes del cierre c0: ya está dentro de él.
  await tx.doc('t1').set({
    'eventoId': 'e1',
    'sectorId': 's2',
    'fecha': hora(3),
    'montoTotal': 400,
    'productos': [
      {'productoId': 'p2', 'cantidadVendida': 4, 'precio': 100},
    ],
  });
  await tx.doc('t2').set({
    'eventoId': 'e1',
    'sectorId': 's2',
    'fecha': hora(7),
    'montoTotal': 250,
    'productos': [
      {'productoId': 'p1', 'cantidadVendida': 1, 'subtotal': 250},
    ],
  });
  await tx.doc('t3').set({'eventoId': 'e1', 'fecha': hora(8), 'montoTotal': 100});
  await tx.doc('t4').set({
    'eventoId': 'e2',
    'sectorId': 's4',
    'fecha': hora(8),
    'montoTotal': 70,
  });
  return db;
}

void main() {
  setUp(() async {
    AdminEstadisticasService.dbParaPruebas = await escenario();
  });
  tearDown(() => AdminEstadisticasService.dbParaPruebas = null);

  test('resumen de todos los eventos', () async {
    final r = await AdminEstadisticasService.cargarResumenActivos();

    expect(r.totalVendido, 2050);
    expect(r.cantidadCierres, 3);
    expect(r.promedioPorCierre, closeTo(2050 / 3, 0.001));
    expect(r.cantidadEventosActivos, 1);
    expect(r.eventosConVentas, 2);
    expect(r.transaccionesBandejeo, 4);
    expect(r.montoBandejeoTurnosAbiertos, 250);
    expect(
      r.ingresosPorEvento.map((e) => (e['nombre'], e['ingresos'])).toList(),
      [('Partido A', 1550.0), ('Partido B', 500.0)],
    );
    expect(
      r.ingresosPorSector
          .map((s) => (s['nombreSector'], s['total'], s['fuente']))
          .toList(),
      [
        ('Norte', 1000.0, 'cierre_turno'),
        ('Sur', 550.0, 'cierre_turno+bandejeo'),
        ('Oeste', 500.0, 'cierre_turno'),
      ],
    );
  });

  test('ventas en el tiempo: mismas ventas que el total, por hora', () async {
    final r = await AdminEstadisticasService.cargarResumenActivos();
    final serie = r.ventasEnElTiempo;

    expect(serie.porHora, isTrue);
    // Cierres c0 (5 h), Oeste (9 h), c1 (10 h) y bandejeo del turno
    // abierto (7 h); las horas sin venta quedan en 0.
    expect(
      serie.tramos.map((t) => (t.fecha.hour, t.monto)).toList(),
      [(5, 300.0), (6, 0.0), (7, 250.0), (8, 0.0), (9, 500.0), (10, 1000.0)],
    );
    expect(
      serie.tramos.fold<double>(0, (t, v) => t + v.monto),
      r.totalVendido,
    );
  });

  test('ventas en el tiempo de varios días: un tramo por día con ventas', () {
    final serie = AdminEstadisticasService.agruparVentasEnElTiempo([
      (fecha: DateTime(2026, 9, 7, 21), monto: 200),
      (fecha: DateTime(2026, 9, 1, 18), monto: 100),
      (fecha: DateTime(2026, 9, 1, 20), monto: 50),
    ]);

    expect(serie.porHora, isFalse);
    expect(
      serie.tramos.map((t) => (t.fecha, t.monto)).toList(),
      [(DateTime(2026, 9, 1), 150.0), (DateTime(2026, 9, 7), 200.0)],
    );
  });

  test('partido que cierra pasada la medianoche sigue por hora', () {
    final serie = AdminEstadisticasService.agruparVentasEnElTiempo([
      (fecha: DateTime(2026, 9, 6, 22, 15), monto: 100),
      (fecha: DateTime(2026, 9, 7, 0, 40), monto: 300),
    ]);

    expect(serie.porHora, isTrue);
    expect(
      serie.tramos.map((t) => (t.fecha.hour, t.monto)).toList(),
      [(22, 100.0), (23, 0.0), (0, 300.0)],
    );
  });

  test('ventas en el tiempo sin ventas', () {
    final serie = AdminEstadisticasService.agruparVentasEnElTiempo([]);
    expect(serie.tramos, isEmpty);
  });

  test('resumen solo de eventos activos', () async {
    final r = await AdminEstadisticasService.cargarResumenActivos(
      soloEventosActivos: true,
    );

    expect(r.totalVendido, 1550);
    expect(r.cantidadCierres, 2);
    expect(r.cantidadEventosActivos, 1);
    expect(r.transaccionesBandejeo, 3);
  });

  test('resumen sin eventos', () async {
    AdminEstadisticasService.dbParaPruebas = FakeFirebaseFirestore();
    final r = await AdminEstadisticasService.cargarResumenActivos();
    expect(r.sinVentasRegistradas, isTrue);
    expect(r.cantidadEventosActivos, 0);
  });

  test('ventas por categoría en eventos activos', () async {
    final r = await AdminEstadisticasService.cargarVentasPorCategoria();

    expect(r.montoPorCategoria, {'Bebestibles': 1250.0, 'Snacks': 300.0});
    expect(r.cantidadPorCategoria, {'Bebestibles': 6, 'Snacks': 3});
    expect(r.montoTotal, 1550);
    expect(r.totalCierres, 2);
  });

  test('ventas por categoría en todos los eventos', () async {
    final r = await AdminEstadisticasService.cargarVentasPorCategoria(
      soloEventosActivos: false,
    );

    expect(r.montoPorCategoria, {'Bebestibles': 1250.0, 'Snacks': 800.0});
    expect(r.cantidadPorCategoria, {'Bebestibles': 6, 'Snacks': 5});
    expect(r.montoTotal, 2050);
    expect(r.totalCierres, 3);
  });
}
