import 'package:cloud_firestore/cloud_firestore.dart';

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
  /// Lanza [TurnoYaCerradoException] si otro dispositivo cerró antes.
  Future<Set<String>> cerrarTurno({
    required String eventoId,
    required String sectorId,
    required Map<String, int> stockAlIniciar,
    required Map<String, int> conteoFinal,
    required Map<String, dynamic> cierreData,
    required double totalEstimado,
    String? vendedorNombre,
  }) async {
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

      for (final entry in conteoFinal.entries) {
        tx.set(
          stockCol.doc(entry.key),
          {'cantidad': entry.value, 'cantidadFinal': entry.value},
          SetOptions(merge: true),
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
      tx.set(sector, sectorUpdate, SetOptions(merge: true));

      return <String>{};
    });
  }
}

class TurnoYaCerradoException implements Exception {
  @override
  String toString() => 'El turno de este sector ya fue cerrado.';
}
