import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/services/firestore_helpers.dart';
import 'package:front_appsnack/utils/categorias_producto.dart';

/// Agregación de datos reales desde Firestore para el panel administrador.
class AdminEstadisticasService {
  AdminEstadisticasService._();

  static final _db = FirebaseFirestore.instance;

  /// Monto de un cierre de turno guardado en el sector.
  static double montoDesdeUltimoCierre(Map<String, dynamic>? sectorData) {
    if (sectorData == null) return 0;
    if (sectorData['turnoCerrado'] != true) return 0;
    final cierre = sectorData['ultimoCierre'];
    if (cierre is Map<String, dynamic>) {
      final est = cierre['totalEstimado'];
      if (est is num && est > 0) return est.toDouble();
    }
    final tv = sectorData['totalVendido'];
    if (tv is num && tv > 0) return tv.toDouble();
    return 0;
  }

  static Future<Map<String, String>> _nombresEventos({
    bool soloActivos = false,
  }) async {
    final snap = soloActivos
        ? await FirestoreHelpers.getEventosActivos()
        : await FirestoreHelpers.getEventos();
    return {
      for (final d in snap.docs)
        d.id: (d.data() as Map<String, dynamic>?)?['nombre']?.toString() ??
            'Sin nombre',
    };
  }

  static Future<int> _contarEventosActivos() async {
    final snap = await FirestoreHelpers.getEventosActivos();
    return snap.docs.length;
  }

  /// Transacciones de bandejeo por sector (turno aún abierto).
  static Future<Map<String, double>> _montoBandejeoPorSector(
    Set<String> eventosActivos,
  ) async {
    final map = <String, double>{};
    for (final eventoId in eventosActivos) {
      final qs = await _db
          .collection('transacciones')
          .where('eventoId', isEqualTo: eventoId)
          .get();
      for (final doc in qs.docs) {
        final d = doc.data();
        final sectorId = d['sectorId']?.toString();
        if (sectorId == null || sectorId.isEmpty) continue;
        final monto = (d['montoTotal'] as num?)?.toDouble() ?? 0;
        if (monto <= 0) continue;
        final key = '$eventoId|$sectorId';
        map[key] = (map[key] ?? 0) + monto;
      }
    }
    return map;
  }

  static double _montoSectorAbierto(
    String eventoId,
    String sectorId,
    Map<String, double> bandejeoPorSector,
  ) {
    return bandejeoPorSector['$eventoId|$sectorId'] ?? 0;
  }

  /// KPIs y totales (cierres de turno + bandejeo en sectores abiertos).
  static Future<AdminResumenActivos> cargarResumenActivos({
    bool soloEventosActivos = false,
  }) async {
    final nombresEventos = await _nombresEventos(soloActivos: soloEventosActivos);
    final eventosIds = nombresEventos.keys.toSet();
    final cantidadActivosCatalogo = await _contarEventosActivos();

    if (eventosIds.isEmpty) {
      return AdminResumenActivos.vacio(
        cantidadEventosActivos: cantidadActivosCatalogo,
      );
    }

    final bandejeoPorSector = await _montoBandejeoPorSector(eventosIds);

    double totalGeneral = 0;
    int cierres = 0;
    int transaccionesBandejeo = 0;
    double montoBandejeoTurnoAbierto = 0;

    final porEvento = <String, double>{for (final id in eventosIds) id: 0};
    final porSector = <Map<String, dynamic>>[];

    for (final eventoId in eventosIds) {
      final sectoresSnap = await FirestoreHelpers.getSectores(eventoId);
      for (final sectorDoc in sectoresSnap.docs) {
        final data = sectorDoc.data() as Map<String, dynamic>? ?? {};
        final sectorId = sectorDoc.id;
        final nombreSector = data['nombre']?.toString() ?? 'Sector';
        final turnoCerrado = data['turnoCerrado'] == true;

        double monto = 0;
        String fuente = '';

        if (turnoCerrado) {
          monto = montoDesdeUltimoCierre(data);
          if (monto > 0) {
            cierres++;
            fuente = 'cierre_turno';
          }
        } else {
          monto = _montoSectorAbierto(eventoId, sectorId, bandejeoPorSector);
          if (monto > 0) {
            fuente = 'bandejeo';
            montoBandejeoTurnoAbierto += monto;
          }
        }

        if (monto <= 0) continue;

        totalGeneral += monto;
        porEvento[eventoId] = (porEvento[eventoId] ?? 0) + monto;
        porSector.add({
          'eventoId': eventoId,
          'sectorId': sectorId,
          'nombreEvento': nombresEventos[eventoId] ?? 'Sin nombre',
          'nombreSector': nombreSector,
          'total': monto,
          'fuente': fuente,
          'turnoCerrado': turnoCerrado,
        });
      }
    }

    for (final eventoId in eventosIds) {
      final qs = await _db
          .collection('transacciones')
          .where('eventoId', isEqualTo: eventoId)
          .get();
      transaccionesBandejeo += qs.docs.length;
    }

    porSector.sort(
      (a, b) => (b['total'] as double).compareTo(a['total'] as double),
    );

    final eventosIngresos = porEvento.entries
        .where((e) => e.value > 0)
        .map((e) {
          return {
            'eventoId': e.key,
            'nombre': nombresEventos[e.key] ?? 'Sin nombre',
            'ingresos': e.value,
          };
        })
        .toList()
      ..sort(
        (a, b) =>
            (b['ingresos'] as double).compareTo(a['ingresos'] as double),
      );

    final eventosConVentas = eventosIngresos.length;

    return AdminResumenActivos(
      totalVendido: totalGeneral.round(),
      cantidadCierres: cierres,
      promedioPorCierre: cierres > 0 ? totalGeneral / cierres : 0,
      cantidadEventosActivos: cantidadActivosCatalogo,
      eventosConVentas: eventosConVentas,
      transaccionesBandejeo: transaccionesBandejeo,
      montoBandejeoTurnosAbiertos: montoBandejeoTurnoAbierto.round(),
      ingresosPorEvento: eventosIngresos,
      ingresosPorSector: porSector,
    );
  }

  /// Ventas por categoría: cierres confirmados + bandejeo (turnos abiertos).
  static Future<VentasPorCategoriaResumen> cargarVentasPorCategoria({
    bool soloEventosActivos = true,
  }) async {
    final Map<String, double> montoCat = {};
    final Map<String, int> cantCat = {};
    final Map<String, String> catPorProducto = {};

    final productosSnap = await _db.collection('productos').get();
    for (final doc in productosSnap.docs) {
      final c = doc.data()['categoria']?.toString();
      catPorProducto[doc.id] = _normalizarCategoria(c);
    }

    String catKey(String? cat, String? productoId) {
      if (cat != null && cat.trim().isNotEmpty) {
        return _normalizarCategoria(cat);
      }
      if (productoId != null && productoId.isNotEmpty) {
        return catPorProducto[productoId] ?? categoriaDefault;
      }
      return categoriaDefault;
    }

    void acumular(String key, double subtotal, int unidades) {
      if (subtotal <= 0 || unidades <= 0) return;
      montoCat[key] = (montoCat[key] ?? 0) + subtotal;
      cantCat[key] = (cantCat[key] ?? 0) + unidades;
    }

    final eventosSnap = soloEventosActivos
        ? await FirestoreHelpers.getEventosActivos()
        : await FirestoreHelpers.getEventos();

    final eventosIds = eventosSnap.docs.map((d) => d.id).toSet();
    final bandejeoPorSector = soloEventosActivos
        ? await _montoBandejeoPorSector(eventosIds)
        : <String, double>{};

    double montoTotal = 0;
    int cierres = 0;

    for (final eventoDoc in eventosSnap.docs) {
      final eventoId = eventoDoc.id;
      final sectoresSnap = await eventoDoc.reference.collection('sectores').get();

      for (final sectorDoc in sectoresSnap.docs) {
        final sectorData = sectorDoc.data();
        final sectorId = sectorDoc.id;
        final turnoCerrado = sectorData['turnoCerrado'] == true;

        if (turnoCerrado) {
          final cierre = sectorData['ultimoCierre'];
          if (cierre is! Map<String, dynamic>) continue;
          cierres++;
          final productos = cierre['productos'] as List<dynamic>? ?? [];
          for (final raw in productos) {
            if (raw is! Map) continue;
            final m = Map<String, dynamic>.from(raw);
            final vendido = (m['cantidadVendida'] as int?) ??
                (((m['cantidadInicial'] as int?) ?? 0) -
                    ((m['cantidadFinal'] as int?) ?? 0));
            if (vendido <= 0) continue;
            final precio = (m['precio'] as num?)?.toDouble() ?? 0;
            final subtotal = (m['subtotal'] as num?)?.toDouble() ??
                (vendido * precio);
            if (subtotal <= 0) continue;
            final productoId = m['productoId']?.toString() ?? '';
            final key = catKey(m['categoria']?.toString(), productoId);
            acumular(key, subtotal, vendido);
            montoTotal += subtotal;
          }
        } else {
          final montoSector = soloEventosActivos
              ? _montoSectorAbierto(eventoId, sectorId, bandejeoPorSector)
              : await _montoBandejeoSectorDirecto(eventoId, sectorId);
          if (montoSector <= 0) continue;

          final qs = await _db
              .collection('transacciones')
              .where('eventoId', isEqualTo: eventoId)
              .where('sectorId', isEqualTo: sectorId)
              .get();

          for (final tDoc in qs.docs) {
            final t = tDoc.data();
            final productos = t['productos'] as List<dynamic>? ?? [];
            for (final raw in productos) {
              if (raw is! Map) continue;
              final m = Map<String, dynamic>.from(raw);
              final vendido = (m['cantidadVendida'] as num?)?.toInt() ?? 0;
              if (vendido <= 0) continue;
              final subtotal = (m['subtotal'] as num?)?.toDouble() ??
                  ((m['precio'] as num?)?.toDouble() ?? 0) * vendido;
              if (subtotal <= 0) continue;
              final productoId = m['productoId']?.toString() ?? '';
              final key = catKey(null, productoId);
              acumular(key, subtotal, vendido);
              montoTotal += subtotal;
            }
          }
        }
      }
    }

    return VentasPorCategoriaResumen(
      montoPorCategoria: montoCat,
      cantidadPorCategoria: cantCat,
      montoTotal: montoTotal,
      totalCierres: cierres,
    );
  }

  static Future<double> _montoBandejeoSectorDirecto(
    String eventoId,
    String sectorId,
  ) async {
    final qs = await _db
        .collection('transacciones')
        .where('eventoId', isEqualTo: eventoId)
        .where('sectorId', isEqualTo: sectorId)
        .get();
    var total = 0.0;
    for (final doc in qs.docs) {
      total += (doc.data()['montoTotal'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  static String _normalizarCategoria(String? cat) {
    final c = cat?.trim();
    if (c == null || c.isEmpty) return categoriaDefault;
    return categoriasProducto.contains(c) ? c : categoriaDefault;
  }
}

class AdminResumenActivos {
  final int totalVendido;
  final int cantidadCierres;
  final double promedioPorCierre;
  /// Partidos marcados activos en Gestión → Eventos.
  final int cantidadEventosActivos;
  /// Partidos con al menos un peso de venta registrado.
  final int eventosConVentas;
  final int transaccionesBandejeo;
  final int montoBandejeoTurnosAbiertos;
  final List<Map<String, dynamic>> ingresosPorEvento;
  final List<Map<String, dynamic>> ingresosPorSector;

  const AdminResumenActivos({
    required this.totalVendido,
    required this.cantidadCierres,
    required this.promedioPorCierre,
    required this.cantidadEventosActivos,
    required this.eventosConVentas,
    required this.transaccionesBandejeo,
    required this.montoBandejeoTurnosAbiertos,
    required this.ingresosPorEvento,
    required this.ingresosPorSector,
  });

  bool get sinVentasRegistradas =>
      totalVendido <= 0 &&
      cantidadCierres == 0 &&
      transaccionesBandejeo == 0;

  factory AdminResumenActivos.vacio({int cantidadEventosActivos = 0}) =>
      AdminResumenActivos(
        totalVendido: 0,
        cantidadCierres: 0,
        promedioPorCierre: 0,
        cantidadEventosActivos: cantidadEventosActivos,
        eventosConVentas: 0,
        transaccionesBandejeo: 0,
        montoBandejeoTurnosAbiertos: 0,
        ingresosPorEvento: [],
        ingresosPorSector: [],
      );

  Map<String, dynamic> toStatsMap() => {
        'totalVendido': totalVendido,
        'cantidadCierres': cantidadCierres,
        'promedioPorCierre': promedioPorCierre,
        'cantidadEventosActivos': cantidadEventosActivos,
        'eventosConVentas': eventosConVentas,
        'transaccionesBandejeo': transaccionesBandejeo,
        'montoBandejeoTurnosAbiertos': montoBandejeoTurnosAbiertos,
      };
}

class VentasPorCategoriaResumen {
  final Map<String, double> montoPorCategoria;
  final Map<String, int> cantidadPorCategoria;
  final double montoTotal;
  final int totalCierres;

  const VentasPorCategoriaResumen({
    required this.montoPorCategoria,
    required this.cantidadPorCategoria,
    required this.montoTotal,
    required this.totalCierres,
  });
}
