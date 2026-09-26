import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/services/incidencias_service.dart';

/// Cierre de turno de un sector: el conteo físico del vendedor pasa a ser el
/// stock, pero solo si nadie movió el stock mientras contaba.
class CierreTurnoService {
  CierreTurnoService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const mensajeStockCambio =
      'El stock cambió mientras contabas. Revisa los productos marcados y vuelve a contar.';

  DocumentReference<Map<String, dynamic>> sectorRef(
    String eventoId,
    String sectorId,
  ) =>
      _db
          .collection('eventos')
          .doc(eventoId)
          .collection('sectores')
          .doc(sectorId);

  static int cantidadDe(Map<String, dynamic>? data) =>
      (data?['cantidad'] as num?)?.toInt() ?? 0;

  /// Movimientos que cambiarían el stock del sector durante el conteo:
  /// traspasos entrantes sin confirmar y rondas de bandejero en curso.
  /// Devuelve una línea legible por cada uno; vacía si se puede contar.
  Future<List<String>> movimientosPendientes(
    String eventoId,
    String sectorId,
  ) async {
    final sector = sectorRef(eventoId, sectorId);
    final pendientes = <String>[];

    final entrantes = await sector
        .collection('traspasos_entrantes')
        .where('estado', isEqualTo: 'pendiente')
        .get();
    // Un pedido tiene una línea por producto; se muestra un renglón por pedido.
    final porPedido = <String, List<Map<String, dynamic>>>{};
    for (final doc in entrantes.docs) {
      final data = doc.data();
      final pedidoId = data['pedidoId']?.toString() ?? doc.id;
      porPedido.putIfAbsent(pedidoId, () => []).add(data);
    }
    for (final lineas in porPedido.values) {
      final origen =
          lineas.first['sectorOrigenNombre']?.toString() ?? 'otro sector';
      final detalle = lineas
          .map((l) => '${l['nombre'] ?? 'Producto'} ×${l['cantidadEnviada'] ?? 0}')
          .join(', ');
      pendientes.add('Traspaso sin confirmar desde $origen: $detalle');
    }

    final bandejeros = await sector.collection('bandejeros').get();
    for (final doc in bandejeros.docs) {
      final enCurso = await doc.reference
          .collection('rondas')
          .where('estado', isEqualTo: 'en_curso')
          .limit(1)
          .get();
      if (enCurso.docs.isNotEmpty) {
        final nombre = doc.data()['nombre']?.toString() ?? 'Bandejero';
        pendientes.add('Ronda abierta de $nombre');
      }
    }

    return pendientes;
  }

  /// Stock actual del sector ({productoId: cantidad}).
  Future<Map<String, int>> leerStock(String eventoId, String sectorId) async {
    final snap = await sectorRef(eventoId, sectorId).collection('stock').get();
    return {for (final d in snap.docs) d.id: cantidadDe(d.data())};
  }

  /// Productos cuya cantidad difiere entre [antes] y [ahora], incluidos los
  /// que aparecieron o desaparecieron.
  /// Stock con que empezó el turno actual de un sector reabierto: el conteo
  /// final del cierre anterior ({productoId: cantidadFinal}). `null` si el
  /// sector nunca cerró (el turno empezó con el stock inicial).
  static Map<String, int>? inicioDelTurno(Map<String, dynamic>? sectorData) {
    if (sectorData == null || sectorData['turnoCerrado'] == true) return null;
    final cierre = sectorData['ultimoCierre'];
    if (cierre is! Map) return null;
    final productos = cierre['productos'];
    return {
      if (productos is List)
        for (final p in productos.whereType<Map>())
          if (p['productoId'] != null)
            p['productoId'].toString(): (p['cantidadFinal'] as num?)?.toInt() ?? 0,
    };
  }

  /// Unidades vendidas según el conteo. Nunca negativas: si se contó más que
  /// el stock del sistema (sobrante), las ventas son 0.
  static int unidadesVendidas({required int stockSistema, required int contado}) =>
      contado >= stockSistema ? 0 : stockSistema - contado;

  /// Unidades contadas por sobre el stock del sistema.
  static int sobrante({required int stockSistema, required int contado}) =>
      contado > stockSistema ? contado - stockSistema : 0;

  /// Dinero y unidades del cierre (lo que va a `ultimoCierre`, `totalVendido`
  /// del sector y al ranking del vendedor). Los sobrantes suman 0.
  static ({double monto, int unidades}) totalesVenta(
    Iterable<({int stockSistema, int contado, double precio})> productos,
  ) {
    var monto = 0.0;
    var unidades = 0;
    for (final p in productos) {
      final vendidas =
          unidadesVendidas(stockSistema: p.stockSistema, contado: p.contado);
      monto += vendidas * p.precio;
      unidades += vendidas;
    }
    return (monto: monto, unidades: unidades);
  }

  static Set<String> productosCambiados(
    Map<String, int> antes,
    Map<String, int> ahora,
  ) =>
      {...antes.keys, ...ahora.keys}
          .where((id) => antes[id] != ahora[id])
          .toSet();

  /// Escribe el cierre en una transacción que relee el stock y lo compara con
  /// [stockAlIniciar] (el stock al abrir el conteo).
  ///
  /// Si algún producto cambió, no escribe nada y devuelve sus ids. Si no,
  /// guarda el conteo como stock y marca el sector cerrado; devuelve vacío.
  /// Cada producto contado por sobre el stock del sistema queda como incidencia
  /// [TipoIncidencia.sobranteConteo] en la misma transacción.
  /// Lanza [TurnoYaCerradoException] si otro dispositivo cerró antes.
  ///
  /// [cierreData] debe traer `cierreId`. [vendedorUid] es el uid de Auth.
  Future<Set<String>> cerrarTurno({
    required String eventoId,
    required String sectorId,
    required Map<String, int> stockAlIniciar,
    required Map<String, int> conteoFinal,
    required Map<String, dynamic> cierreData,
    required double totalEstimado,
    required String vendedorUid,
    String? vendedorNombre,
    String? sectorNombre,
    Map<String, String> nombresProductos = const {},
  }) async {
    final cierreId = cierreData['cierreId']?.toString() ?? '';
    if (cierreId.isEmpty) {
      throw ArgumentError('cierreData debe incluir cierreId');
    }
    final sector = sectorRef(eventoId, sectorId);
    final stockCol = sector.collection('stock');

    // Las transacciones del cliente no admiten consultas: un producto nuevo en
    // el sector (p. ej. llegó por traspaso) se detecta con esta lectura previa.
    final idsActuales =
        (await stockCol.get()).docs.map((d) => d.id).toSet();
    final idsNuevos = idsActuales.difference(stockAlIniciar.keys.toSet());
    if (idsNuevos.isNotEmpty) return idsNuevos;

    return _db.runTransaction<Set<String>>((tx) async {
      final sectorSnap = await tx.get(sector);
      if (!sectorSnap.exists) {
        throw StateError('El sector ya no existe.');
      }
      if (sectorSnap.data()?['turnoCerrado'] == true) {
        throw TurnoYaCerradoException();
      }

      final cambiados = <String>{};
      for (final entry in stockAlIniciar.entries) {
        final snap = await tx.get(stockCol.doc(entry.key));
        final actual = snap.exists ? cantidadDe(snap.data()) : null;
        if (actual != entry.value) cambiados.add(entry.key);
      }
      if (cambiados.isNotEmpty) return cambiados;

      // El sector y cada producto existen (se leyeron arriba): update.
      for (final entry in conteoFinal.entries) {
        tx.update(
          stockCol.doc(entry.key),
          {'cantidad': entry.value, 'cantidadFinal': entry.value},
        );
      }

      final sectorUpdate = <String, dynamic>{
        'ultimoCierre': cierreData,
        'turnoCerrado': true,
        'turnoCerradoAt': FieldValue.serverTimestamp(),
        'totalVendido': FieldValue.increment(totalEstimado),
        'borradorCierreTurno': FieldValue.delete(),
      };
      final sectorData = sectorSnap.data();
      if (sectorData != null) {
        final vendedores =
            List<dynamic>.from(sectorData['vendedoresasignados'] ?? []);
        if (vendedorNombre != null && vendedorNombre.isNotEmpty) {
          vendedores.removeWhere((v) {
            final n = v is Map ? v['nombre']?.toString() : null;
            return n == vendedorNombre;
          });
        }
        sectorUpdate['vendedoresasignados'] = vendedores;
      }
      tx.update(sector, sectorUpdate);
      // Historial de cierres: `ultimoCierre` se sobrescribe si el sector se
      // reabre y vuelve a cerrar, y las estadísticas necesitan todos los turnos.
      tx.set(sector.collection('cierres').doc(cierreId), cierreData);

      final discrepancias = _db
          .collection('eventos')
          .doc(eventoId)
          .collection('discrepancias');
      for (final entry in conteoFinal.entries) {
        final stockSistema = stockAlIniciar[entry.key] ?? 0;
        final sobrante = entry.value - stockSistema;
        if (sobrante <= 0) continue;
        tx.set(discrepancias.doc('${cierreId}_${entry.key}'), {
          'tipo': TipoIncidencia.sobranteConteo,
          'eventoId': eventoId,
          'cierreId': cierreId,
          'sectorId': sectorId,
          'sectorNombre': sectorNombre ?? sectorSnap.data()?['nombre'],
          'productoId': entry.key,
          'nombreProducto': nombresProductos[entry.key],
          'stockSistema': stockSistema,
          'cantidadContada': entry.value,
          'diferencia': sobrante,
          'vendedorUid': vendedorUid,
          'vendedorNombre': vendedorNombre,
          'fecha': FieldValue.serverTimestamp(),
          'estado': 'pendiente',
        });
      }

      return <String>{};
    });
  }
}

class TurnoYaCerradoException implements Exception {
  @override
  String toString() => 'El turno de este sector ya fue cerrado.';
}
