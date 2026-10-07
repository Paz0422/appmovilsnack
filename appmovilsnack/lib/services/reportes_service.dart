import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:front_appsnack/services/admin_estadisticas_service.dart';
import 'package:front_appsnack/services/vendedor_ventas_service.dart';

/// Datos del dashboard de Reportes (solo lecturas): mermas, stock y
/// diferencias en traspasos de los partidos activos, más ventas por categoría
/// y ranking del año. Cada pantalla de detalle sigue teniendo su propia carga.
class ReportesService {
  ReportesService._();

  static FirebaseFirestore? _dbPruebas;
  static FirebaseFirestore get _db => _dbPruebas ?? FirebaseFirestore.instance;

  /// Solo para tests: usa otra base (p. ej. FakeFirebaseFirestore).
  @visibleForTesting
  static set dbParaPruebas(FirebaseFirestore? db) => _dbPruebas = db;

  /// Desde cuántas unidades (o menos) un producto cuenta como "stock bajo".
  /// El mismo umbral usa "Stock por sector".
  static const umbralStockBajo = 10;

  static int _entero(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  /// Mermas, stock y traspasos de todos los sectores de los partidos activos.
  /// Una lectura de eventos y de sectores; por sector, las tres en paralelo.
  static Future<DatosSectores> cargarSectoresActivos() async {
    final eventos = await _db
        .collection('eventos')
        .where('activo', isEqualTo: true)
        .get();
    final sectoresPorEvento = await Future.wait(
      eventos.docs.map((e) => e.reference.collection('sectores').get()),
    );

    final lecturas = <Future<LecturaSector>>[];
    for (final (i, evento) in eventos.docs.indexed) {
      final eventoNombre = evento.data()['nombre']?.toString() ?? 'Sin nombre';
      for (final sector in sectoresPorEvento[i].docs) {
        lecturas.add(() async {
          final r = await Future.wait([
            sector.reference.collection('mermas').get(),
            sector.reference.collection('stock').get(),
            sector.reference
                .collection('traspasos_entrantes')
                .where('estado', isEqualTo: 'confirmado')
                .get(),
          ]);
          return (
            evento: eventoNombre,
            sector: sector.data()['nombre']?.toString() ?? 'Sector',
            mermas: r[0].docs.map((d) => d.data()).toList(),
            stock: r[1].docs.map((d) => d.data()).toList(),
            traspasos: r[2].docs.map((d) => d.data()).toList(),
          );
        }());
      }
    }
    final sectores = await Future.wait(lecturas);
    return DatosSectores.desde(sectores, variosEventos: eventos.docs.length > 1);
  }

  /// Todo el dashboard. Si un bloque falla, el error llega al dashboard.
  static Future<DashboardReportes> cargarDashboard() async {
    final r = await Future.wait<Object>([
      AdminEstadisticasService.cargarVentasPorCategoria(soloEventosActivos: true),
      cargarSectoresActivos(),
      VendedorVentasService.cargarRanking(),
    ]);
    return DashboardReportes(
      categorias: r[0] as VentasPorCategoriaResumen,
      sectores: r[1] as DatosSectores,
      ranking: (r[2] as List<RankingVendedor>)
          .where((v) => v.montoAnio > 0)
          .toList()
        ..sort((a, b) => b.montoAnio.compareTo(a.montoAnio)),
    );
  }
}

/// Lo leído de un sector de un partido activo.
typedef LecturaSector = ({
  String evento,
  String sector,
  List<Map<String, dynamic>> mermas,
  List<Map<String, dynamic>> stock,
  List<Map<String, dynamic>> traspasos,
});

typedef MontoNombrado = ({String nombre, double monto});

/// Stock de un sector: unidades y productos en alerta.
typedef StockSector = ({String nombre, int unidades, int bajo, int sinStock});

/// Resúmenes calculados en el cliente a partir de las lecturas por sector.
class DatosSectores {
  // Mermas
  final int unidadesPerdidas;
  final double valorPerdido;

  /// Pérdida por producto, de mayor a menor: en dinero si hay precios, si
  /// no en unidades ([mermasEnDinero]).
  final List<MontoNombrado> perdidaPorProducto;
  final List<MontoNombrado> perdidaPorMotivo;
  final bool mermasEnDinero;

  // Stock
  final List<StockSector> stockPorSector;

  // Traspasos
  final int traspasosIncompletos;
  final int unidadesFaltantes;
  final double valorFaltante;

  const DatosSectores({
    required this.unidadesPerdidas,
    required this.valorPerdido,
    required this.perdidaPorProducto,
    required this.perdidaPorMotivo,
    required this.mermasEnDinero,
    required this.stockPorSector,
    required this.traspasosIncompletos,
    required this.unidadesFaltantes,
    required this.valorFaltante,
  });

  int get productosBajos => stockPorSector.fold(0, (t, s) => t + s.bajo);
  int get productosSinStock => stockPorSector.fold(0, (t, s) => t + s.sinStock);

  /// [variosEventos]: el nombre del sector lleva el partido entre paréntesis.
  factory DatosSectores.desde(
    List<LecturaSector> sectores, {
    bool variosEventos = false,
  }) {
    var unidades = 0;
    var valor = 0.0;
    final productoUnidades = <String, double>{};
    final productoValor = <String, double>{};
    final motivoUnidades = <String, double>{};
    final motivoValor = <String, double>{};
    final stock = <StockSector>[];
    var incompletos = 0;
    var faltantes = 0;
    var valorFaltante = 0.0;

    for (final s in sectores) {
      for (final m in s.mermas) {
        final cant = ReportesService._entero(m['cantidadPerdida']);
        final precio = (m['precio'] as num?)?.toDouble() ?? 0;
        final producto = m['nombreProducto']?.toString() ?? 'Sin nombre';
        final motivo = (m['motivo']?.toString().trim().isNotEmpty ?? false)
            ? m['motivo'].toString().trim()
            : 'Sin motivo';
        unidades += cant;
        valor += cant * precio;
        productoUnidades[producto] = (productoUnidades[producto] ?? 0) + cant;
        productoValor[producto] = (productoValor[producto] ?? 0) + cant * precio;
        motivoUnidades[motivo] = (motivoUnidades[motivo] ?? 0) + cant;
        motivoValor[motivo] = (motivoValor[motivo] ?? 0) + cant * precio;
      }

      var unidadesSector = 0;
      var bajo = 0;
      var sin = 0;
      for (final p in s.stock) {
        final c = ReportesService._entero(p['cantidad']);
        unidadesSector += c;
        if (c <= 0) {
          sin++;
        } else if (c <= ReportesService.umbralStockBajo) {
          bajo++;
        }
      }
      if (s.stock.isNotEmpty) {
        stock.add((
          nombre: variosEventos ? '${s.sector} (${s.evento})' : s.sector,
          unidades: unidadesSector,
          bajo: bajo,
          sinStock: sin,
        ));
      }

      for (final t in s.traspasos) {
        final enviada = ReportesService._entero(t['cantidadEnviada']);
        final recibida = ReportesService._entero(t['cantidadRecibida']);
        final dif = t.containsKey('cantidadDiferencia')
            ? ReportesService._entero(t['cantidadDiferencia'])
            : enviada - recibida;
        if (dif <= 0) continue;
        incompletos++;
        faltantes += dif;
        valorFaltante += dif * ((t['precio'] as num?)?.toDouble() ?? 0);
      }
    }

    final enDinero = valor > 0;
    List<MontoNombrado> ordenar(Map<String, double> m) => [
      for (final e in m.entries)
        if (e.value > 0) (nombre: e.key, monto: e.value),
    ]..sort((a, b) => b.monto.compareTo(a.monto));

    return DatosSectores(
      unidadesPerdidas: unidades,
      valorPerdido: valor,
      perdidaPorProducto: ordenar(enDinero ? productoValor : productoUnidades),
      perdidaPorMotivo: ordenar(enDinero ? motivoValor : motivoUnidades),
      mermasEnDinero: enDinero,
      stockPorSector: stock..sort((a, b) => b.unidades.compareTo(a.unidades)),
      traspasosIncompletos: incompletos,
      unidadesFaltantes: faltantes,
      valorFaltante: valorFaltante,
    );
  }
}

class DashboardReportes {
  final VentasPorCategoriaResumen categorias;
  final DatosSectores sectores;

  /// Vendedores con ventas este año, de mayor a menor.
  final List<RankingVendedor> ranking;

  const DashboardReportes({
    required this.categorias,
    required this.sectores,
    required this.ranking,
  });
}
