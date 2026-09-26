import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:front_appsnack/utils/categorias_producto.dart';

/// Agregación de datos reales desde Firestore para el panel administrador.
class AdminEstadisticasService {
  AdminEstadisticasService._();

  static FirebaseFirestore? _dbPruebas;
  static FirebaseFirestore get _db => _dbPruebas ?? FirebaseFirestore.instance;

  /// Solo para tests: usa otra base (p. ej. FakeFirebaseFirestore).
  @visibleForTesting
  static set dbParaPruebas(FirebaseFirestore? db) => _dbPruebas = db;

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

  static Future<QuerySnapshot<Map<String, dynamic>>> _leerEventos({
    required bool soloActivos,
  }) {
    final eventos = _db.collection('eventos');
    return soloActivos
        ? eventos.where('activo', isEqualTo: true).get()
        : eventos.get();
  }

  /// Sectores de los eventos con sus cierres. Las lecturas van en paralelo
  /// (antes era una consulta tras otra por evento y por sector); el orden
  /// del resultado es el de los eventos y, dentro, el de los sectores.
  static Future<List<_SectorLeido>> _leerSectores(
    Iterable<String> eventosIds,
  ) async {
    final porEvento = await Future.wait(
      eventosIds.map((eventoId) async {
        final snap = await _db
            .collection('eventos')
            .doc(eventoId)
            .collection('sectores')
            .get();
        return Future.wait(
          snap.docs.map(
            (doc) async => (
              eventoId: eventoId,
              doc: doc,
              cierres: await _leerCierresDelSector(doc.reference, doc.data()),
            ),
          ),
        );
      }),
    );
    return porEvento.expand((sectores) => sectores).toList();
  }

  /// Transacciones de bandejeo de los eventos: una consulta por evento, en
  /// paralelo. [porSector] las agrupa por 'eventoId|sectorId'; [total] cuenta
  /// todas, también las que no tienen sector.
  static Future<_Bandejeo> _leerBandejeo(Iterable<String> eventosIds) async {
    final ids = eventosIds.toList();
    final snaps = await Future.wait(
      ids.map(
        (id) => _db
            .collection('transacciones')
            .where('eventoId', isEqualTo: id)
            .get(),
      ),
    );
    var total = 0;
    final porSector = <String, List<Map<String, dynamic>>>{};
    for (var i = 0; i < ids.length; i++) {
      total += snaps[i].docs.length;
      for (final doc in snaps[i].docs) {
        final d = doc.data();
        final sectorId = d['sectorId']?.toString();
        if (sectorId == null || sectorId.isEmpty) continue;
        (porSector['${ids[i]}|$sectorId'] ??= []).add(d);
      }
    }
    return (total: total, porSector: porSector);
  }

  /// Bandejeo posterior a [desde] (lo anterior ya está dentro de un cierre).
  static List<Map<String, dynamic>> _bandejeoDelTurno(
    _Bandejeo bandejeo,
    String eventoId,
    String sectorId,
    Timestamp? desde,
  ) =>
      (bandejeo.porSector['$eventoId|$sectorId'] ?? const [])
          .where((t) => _posteriorA(t['fecha'], desde))
          .toList();

  static double _montoBandejeo(List<Map<String, dynamic>> transacciones) =>
      transacciones.fold(0.0, (total, t) {
        final monto = (t['montoTotal'] as num?)?.toDouble() ?? 0;
        return monto > 0 ? total + monto : total;
      });

  /// KPIs y totales (cierres de turno + bandejeo en sectores abiertos).
  static Future<AdminResumenActivos> cargarResumenActivos({
    bool soloEventosActivos = false,
  }) async {
    // Una sola lectura de eventos: de ahí salen los nombres y cuántos están
    // activos.
    final eventosSnap = await _leerEventos(soloActivos: soloEventosActivos);
    final nombresEventos = {
      for (final d in eventosSnap.docs)
        d.id: d.data()['nombre']?.toString() ?? 'Sin nombre',
    };
    final eventosIds = nombresEventos.keys.toSet();
    final cantidadActivosCatalogo = eventosSnap.docs
        .where((d) => soloEventosActivos || d.data()['activo'] == true)
        .length;

    if (eventosIds.isEmpty) {
      return AdminResumenActivos.vacio(
        cantidadEventosActivos: cantidadActivosCatalogo,
      );
    }

    // Future.wait (y no un record .wait) para que un error llegue tal cual,
    // p. ej. el permission-denied que el panel explica.
    final lecturas = await Future.wait<Object>([
      _leerSectores(eventosIds),
      _leerBandejeo(eventosIds),
    ]);
    final sectores = lecturas[0] as List<_SectorLeido>;
    final bandejeo = lecturas[1] as _Bandejeo;

    double totalGeneral = 0;
    int cierres = 0;
    double montoBandejeoTurnoAbierto = 0;

    final porEvento = <String, double>{for (final id in eventosIds) id: 0};
    final porSector = <Map<String, dynamic>>[];

    for (final (:eventoId, :doc, cierres: cierresSector) in sectores) {
      final data = doc.data();
      final sectorId = doc.id;
      final nombreSector = data['nombre']?.toString() ?? 'Sector';
      final turnoCerrado = data['turnoCerrado'] == true;

      double monto = 0;
      String fuente = '';

      // Turnos ya cerrados (más de uno si el sector se reabrió).
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
        final montoAbierto = _montoBandejeo(
          _bandejeoDelTurno(
            bandejeo,
            eventoId,
            sectorId,
            fechaUltimoCierre(cierresSector),
          ),
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
      transaccionesBandejeo: bandejeo.total,
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

    final catalogoYEventos = await Future.wait([
      _db.collection('productos').get(),
      _leerEventos(soloActivos: soloEventosActivos),
    ]);
    for (final doc in catalogoYEventos[0].docs) {
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

    final eventosIds = catalogoYEventos[1].docs.map((d) => d.id).toSet();
    final lecturas = await Future.wait<Object>([
      _leerSectores(eventosIds),
      _leerBandejeo(eventosIds),
    ]);
    final sectores = lecturas[0] as List<_SectorLeido>;
    final bandejeo = lecturas[1] as _Bandejeo;

    double montoTotal = 0;
    int cierres = 0;

    for (final (:eventoId, :doc, cierres: cierresSector) in sectores) {
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

      if (doc.data()['turnoCerrado'] == true) continue;

      final delTurno = _bandejeoDelTurno(
        bandejeo,
        eventoId,
        doc.id,
        fechaUltimoCierre(cierresSector),
      );
      if (_montoBandejeo(delTurno) <= 0) continue;

      for (final t in delTurno) {
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

    return VentasPorCategoriaResumen(
      montoPorCategoria: montoCat,
      cantidadPorCategoria: cantCat,
      montoTotal: montoTotal,
      totalCierres: cierres,
    );
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

typedef _SectorLeido = ({
  String eventoId,
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
  List<Map<String, dynamic>> cierres,
});

typedef _Bandejeo = ({
  int total,
  Map<String, List<Map<String, dynamic>>> porSector,
});
