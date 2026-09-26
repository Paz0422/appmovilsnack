import 'package:cloud_firestore/cloud_firestore.dart';

class StockException implements Exception {
  StockException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Reposición de stock durante el evento y protección de la carga inicial.
///
/// La carga de stock inicial (gestion_stock.dart) escribe cantidades
/// absolutas, así que solo se permite mientras el sector no tenga movimientos.
/// Después, las unidades nuevas entran con [agregarStock], que suma con
/// `FieldValue.increment` y deja registro en `eventos/{id}/movimientos`.
class StockService {
  StockService([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const tipoReposicion = 'reposicion';

  static const mensajeUsarAgregarStock =
      'Para sumar unidades, el administrador debe usar "Agregar stock".';

  DocumentReference<Map<String, dynamic>> _sector(
    String eventoId,
    String sectorId,
  ) =>
      _db.collection('eventos').doc(eventoId).collection('sectores').doc(sectorId);

  CollectionReference<Map<String, dynamic>> movimientos(String eventoId) =>
      _db.collection('eventos').doc(eventoId).collection('movimientos');

  /// Suma [cantidad] unidades al producto en un sector abierto y registra la
  /// reposición. Solo para administradores (las reglas lo exigen).
  Future<void> agregarStock({
    required String eventoId,
    required String sectorId,
    required String productoId,
    required int cantidad,
    required String adminUid,
    String? adminNombre,
    String? motivo,
  }) async {
    if (cantidad <= 0) {
      throw StockException('La cantidad debe ser mayor que cero.');
    }
    final sector = _sector(eventoId, sectorId);
    final stockRef = sector.collection('stock').doc(productoId);
    final movimientoRef = movimientos(eventoId).doc();
    final motivoLimpio = motivo?.trim();

    await _db.runTransaction((tx) async {
      final sectorSnap = await tx.get(sector);
      if (!sectorSnap.exists) {
        throw StockException('El sector ya no existe.');
      }
      if (sectorSnap.data()?['turnoCerrado'] == true) {
        throw StockException(
          'El sector ya cerró su turno: no se puede agregar stock.',
        );
      }
      final stockSnap = await tx.get(stockRef);
      if (!stockSnap.exists) {
        throw StockException('El producto no está en el stock del sector.');
      }

      // Nunca la cantidad absoluta: así no se pisa una venta, merma o
      // traspaso que ocurra al mismo tiempo.
      tx.update(stockRef, {'cantidad': FieldValue.increment(cantidad)});
      tx.set(movimientoRef, {
        'tipo': tipoReposicion,
        'sectorId': sectorId,
        'sectorNombre': sectorSnap.data()?['nombre'],
        'productoId': productoId,
        'nombreProducto': stockSnap.data()?['nombre'],
        'cantidad': cantidad,
        if (motivoLimpio != null && motivoLimpio.isNotEmpty) 'motivo': motivoLimpio,
        'adminUid': adminUid,
        'adminNombre': adminNombre,
        'fecha': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Motivos por los que ya no se puede cargar stock inicial en el sector
  /// (vacío si se puede). Los traspasos recibidos y confirmados antes de la
  /// carga no bloquean: la pantalla los suma como "por traspaso".
  Future<List<String>> bloqueosStockInicial(
    String eventoId,
    String sectorId,
  ) async {
    final sector = _sector(eventoId, sectorId);
    final bloqueos = <String>[];

    final sectorData = (await sector.get()).data() ?? const {};
    if (sectorData['turnoCerrado'] == true) {
      bloqueos.add('El turno del sector está cerrado.');
    } else if (sectorData['ultimoCierre'] != null) {
      bloqueos.add('El sector ya tuvo un cierre de turno.');
    }

    Future<bool> hay(Query<Map<String, dynamic>> q) async =>
        (await q.limit(1).get()).docs.isNotEmpty;

    if (await hay(_db
        .collection('transacciones')
        .where('eventoId', isEqualTo: eventoId)
        .where('sectorId', isEqualTo: sectorId))) {
      bloqueos.add('Hay ventas de bandejeo registradas.');
    }
    if (await hay(sector.collection('traspasos_salientes'))) {
      bloqueos.add('El sector ya envió traspasos.');
    }
    if (await hay(sector
        .collection('traspasos_entrantes')
        .where('estado', isEqualTo: 'pendiente'))) {
      bloqueos.add(
        'Hay traspasos entrantes sin confirmar: confírmelos primero y se '
        'sumarán al stock inicial.',
      );
    }
    for (final bandejero in (await sector.collection('bandejeros').get()).docs) {
      if (await hay(bandejero.reference.collection('rondas'))) {
        bloqueos.add('Hay rondas de bandejero registradas.');
        break;
      }
    }
    if (await hay(sector.collection('mermas'))) {
      bloqueos.add('Hay mermas registradas.');
    }
    if (await hay(movimientos(eventoId).where('sectorId', isEqualTo: sectorId))) {
      bloqueos.add('Ya se agregó stock durante el evento.');
    }

    return bloqueos;
  }
}
