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

  /// Cierres de turno de un sector, del más antiguo al más reciente. Usa el
  /// historial `sectores/{id}/cierres` (un documento por turno cerrado); en
  /// sectores cerrados antes de que existiera, el único dato es `ultimoCierre`.
  static List<Map<String, dynamic>> cierresDelSector({
    required List<Map<String, dynamic>> historial,
    Map<String, dynamic>? sectorData,
  }) {
    if (historial.isNotEmpty) {
      return [...historial]..sort((a, b) {
          final fa = a['fecha'];
          final fb = b['fecha'];
          if (fa is Timestamp && fb is Timestamp) return fa.compareTo(fb);
          return 0;
        });
    }
    final ultimo = sectorData?['ultimoCierre'];
    return ultimo is Map ? [Map<String, dynamic>.from(ultimo)] : [];
  }

  /// Dinero de todos los turnos cerrados del sector. Cada cierre trae solo las
  /// ventas de su turno (stock al abrir el conteo − contado), así que sumarlos
  /// no cuenta dos veces un turno anterior.
  static double montoCierres(List<Map<String, dynamic>> cierres) => cierres
      .fold(0.0, (t, c) => t + ((c['totalEstimado'] as num?)?.toDouble() ?? 0));

  /// Las ventas de bandejeo hasta el último cierre ya están dentro de él.
  static Timestamp? fechaUltimoCierre(List<Map<String, dynamic>> cierres) {
    final fecha = cierres.isEmpty ? null : cierres.last['fecha'];
    return fecha is Timestamp ? fecha : null;
  }

  static bool _posteriorA(dynamic fecha, Timestamp? corte) =>
      corte == null || fecha is! Timestamp || fecha.compareTo(corte) > 0;

  static Future<List<Map<String, dynamic>>> _leerCierresDelSector(
    DocumentReference sectorRef,
    Map<String, dynamic> sectorData,
  ) async {
    final snap = await sectorRef.collection('cierres').get();
    return cierresDelSector(
      historial: snap.docs.map((d) => d.data()).toList(),
      sectorData: sectorData,
    );
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

  /// Transacciones de bandejeo por sector (turno aún abierto), con su fecha
  /// para descontar las que ya entraron en un cierre anterior.
  static Future<Map<String, List<({dynamic fecha, double monto})>>>
      _montoBandejeoPorSector(Set<String> eventosActivos) async {
    final map = <String, List<({dynamic fecha, double monto})>>{};
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
        (map[key] ??= []).add((fecha: d['fecha'], monto: monto));
      }
    }
    return map;
  }

  static double _montoSectorAbierto(
    String eventoId,
    String sectorId,
    Map<String, List<({dynamic fecha, double monto})>> bandejeoPorSector, {
    Timestamp? desde,
  }) {
    return (bandejeoPorSector['$eventoId|$sectorId'] ?? const [])
        .where((t) => _posteriorA(t.fecha, desde))
        .fold(0.0, (total, t) => total + t.monto);
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

        // Turnos ya cerrados (más de uno si el sector se reabrió).
        final cierresSector =
            await _leerCierresDelSector(sectorDoc.reference, data);
        final montoTurnosCerrados = cierresSector.isNotEmpty
            ? montoCierres(cierresSector)
            : montoDesdeUltimoCierre(data);
        if (montoTurnosCerrados > 0) {
          monto += montoTurnosCerrados;
          cierres += cierresSector.isEmpty ? 1 : cierresSector.length;
          fuente = 'cierre_turno';
        }

        // Turno en curso: solo el bandejeo posterior al último cierre.
        if (!turnoCerrado) {
          final montoAbierto = _montoSectorAbierto(
            eventoId,
            sectorId,
            bandejeoPorSector,
            desde: fechaUltimoCierre(cierresSector),
          );
          if (montoAbierto > 0) {
            monto += montoAbierto;
            montoBandejeoTurnoAbierto += montoAbierto;
            fuente = fuente.isEmpty ? 'bandejeo' : 'cierre_turno+bandejeo';
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
        : <String, List<({dynamic fecha, double monto})>>{};

    double montoTotal = 0;
    int cierres = 0;

    for (final eventoDoc in eventosSnap.docs) {
      final eventoId = eventoDoc.id;
      final sectoresSnap = await eventoDoc.reference.collection('sectores').get();

      for (final sectorDoc in sectoresSnap.docs) {
        final sectorData = sectorDoc.data();
        final sectorId = sectorDoc.id;
        final turnoCerrado = sectorData['turnoCerrado'] == true;

        final cierresSector =
            await _leerCierresDelSector(sectorDoc.reference, sectorData);
        for (final cierre in cierresSector) {
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
        }

        if (!turnoCerrado) {
          final desde = fechaUltimoCierre(cierresSector);
          final montoSector = soloEventosActivos
              ? _montoSectorAbierto(
                  eventoId,
                  sectorId,
                  bandejeoPorSector,
                  desde: desde,
                )
              : await _montoBandejeoSectorDirecto(eventoId, sectorId, desde: desde);
          if (montoSector <= 0) continue;

          final qs = await _db
              .collection('transacciones')
              .where('eventoId', isEqualTo: eventoId)
              .where('sectorId', isEqualTo: sectorId)
              .get();

          for (final tDoc in qs.docs) {
            final t = tDoc.data();
            if (!_posteriorA(t['fecha'], desde)) continue;
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
    String sectorId, {
    Timestamp? desde,
  }) async {
    final qs = await _db
        .collection('transacciones')
        .where('eventoId', isEqualTo: eventoId)
        .where('sectorId', isEqualTo: sectorId)
        .get();
    var total = 0.0;
    for (final doc in qs.docs) {
      if (!_posteriorA(doc.data()['fecha'], desde)) continue;
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
