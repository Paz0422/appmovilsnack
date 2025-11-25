import 'package:cloud_firestore/cloud_firestore.dart';
import 'item_carrito.dart'; // ¡IMPORTANTE! Ahora importa el modelo desde su propio archivo

// La clase de servicio centraliza toda la lógica de Firestore
class VentasService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // La función principal que encapsula toda la lógica de la venta
  Future<void> procesarVenta({
    required String eventoId,
    required String sectorId,
    required String? vendedorNombre,
    required List<ItemCarrito> carritoItems,
    required double montoTotal,
    required String metodoPago,
  }) async {
    // Usamos una transacción para asegurar que todas las operaciones se completen
    // o ninguna lo haga, manteniendo la consistencia de los datos.
    await _db.runTransaction((transaction) async {
      // Paso 1: Crear el documento de la venta
      final ventaRef = _db.collection('ventas').doc();
      transaction.set(ventaRef, {
        'eventoId': eventoId,
        'sectorId': sectorId,
        'vendedorNombre': vendedorNombre,
        'fecha': FieldValue.serverTimestamp(),
        'montoTotal': montoTotal,
        // Convertimos cada ItemCarrito a un Map usando el método toJson
        'items': carritoItems.map((item) => item.toJson()).toList(),
      });

      // Paso 2: Actualizar el stock de cada producto en el sector
      for (final item in carritoItems) {
        final productoQuery = await _db
            .collection('eventos')
            .doc(eventoId)
            .collection('sectores')
            .doc(sectorId)
            .collection('stockInicial')
            .where('nombre', isEqualTo: item.nombre)
            .limit(1)
            .get();

        if (productoQuery.docs.isNotEmpty) {
          final productoDoc = productoQuery.docs.first;
          final currentStock = productoDoc.data()['stock'] as int? ?? 0;

          if (currentStock >= item.cantidad) {
            transaction.update(productoDoc.reference, {
              'stock': FieldValue.increment(
                -item.cantidad,
              ), // Forma más segura de restar
            });
          } else {
            // Si el stock no es suficiente, la transacción entera se cancelará
            throw Exception('Stock insuficiente para ${item.nombre}');
          }
        }
      }

      // Paso 3: Actualizar el total vendido por el vendedor en el sector
      await _actualizarTotalVendedor(
        transaction: transaction,
        eventoId: eventoId,
        sectorId: sectorId,
        vendedorNombre: vendedorNombre,
        montoVenta: montoTotal,
      );
    });
  }

  // Función privada de ayuda que solo es usada dentro de esta clase
  Future<void> _actualizarTotalVendedor({
    required Transaction transaction,
    required String eventoId,
    required String sectorId,
    required String? vendedorNombre,
    required double montoVenta,
  }) async {
    if (vendedorNombre == null) return;

    final sectorRef = _db
        .collection('eventos')
        .doc(eventoId)
        .collection('sectores')
        .doc(sectorId);

    final sectorSnapshot = await transaction.get(sectorRef);

    if (sectorSnapshot.exists) {
      final sectorData = sectorSnapshot.data() as Map<String, dynamic>;
      List<dynamic> vendedoresAsignados = List.from(
        sectorData['vendedoresasignados'] ?? [],
      );

      int indexVendedor = vendedoresAsignados.indexWhere(
        (v) => v['nombre'] == vendedorNombre,
      );

      if (indexVendedor != -1) {
        // Si el vendedor existe, actualiza su total
        double totalActual =
            (vendedoresAsignados[indexVendedor]['totalVendido'] ?? 0)
                .toDouble();
        vendedoresAsignados[indexVendedor]['totalVendido'] =
            totalActual + montoVenta;
      } else {
        // Si no existe, lo agrega
        vendedoresAsignados.add({
          'nombre': vendedorNombre,
          'totalVendido': montoVenta,
        });
      }

      transaction.update(sectorRef, {
        'vendedoresasignados': vendedoresAsignados,
        'totalVendido': FieldValue.increment(montoVenta),
      });
    }
  }
}
