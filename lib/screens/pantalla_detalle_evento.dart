import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'scanner_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventName;
  final String eventId;

  const EventDetailScreen({
    super.key,
    required this.eventName,
    required this.eventId,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final Map<String, int> _shoppingCart = {};
  List<QueryDocumentSnapshot> _products = [];
  String _searchQuery = '';
  final _searchController = TextEditingController();

  Future<void> _processSale(String paymentMethod) async {
    final vendorId = AuthManager().loggedInVendor?.id;
    if (vendorId == null) return;

    final vendorDocRef = FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventId)
        .collection('vendedores')
        .doc(vendorId);

    final salesCollectionRef = FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventId)
        .collection('sales');

    WriteBatch batch = FirebaseFirestore.instance.batch();
    double totalSaleValue = 0;
    int totalItemsSold = 0;

    final saleDocRef = salesCollectionRef.doc();

    List<Map<String, dynamic>> itemsList = [];

    _shoppingCart.forEach((productId, quantity) {
      if (quantity > 0) {
        final productDoc = _products.firstWhere((p) => p.id == productId);
        final productData = productDoc.data() as Map<String, dynamic>;

        batch.update(productDoc.reference, {
          'stock': FieldValue.increment(-quantity),
        });

        double salePrice = (productData['precio'] * quantity).toDouble();
        totalSaleValue += salePrice;
        totalItemsSold += quantity;

        itemsList.add({
          'productId': productId,
          'productName': productData['nombreproduct'],
          'quantity': quantity,
          'price': salePrice,
        });
      }
    });

    batch.set(saleDocRef, {
      'vendorId': vendorId,
      'paymentMethod': paymentMethod,
      'timestamp': FieldValue.serverTimestamp(),
      'total': totalSaleValue,
      'items': itemsList,
    });

    batch.update(vendorDocRef, {
      'totalVendido': FieldValue.increment(totalSaleValue),
      'itemsVendidos': FieldValue.increment(totalItemsSold),
    });

    await batch.commit();
    setState(() {
      _shoppingCart.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Venta realizada con éxito!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Stream<QuerySnapshot> productsStream = FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventId)
        .collection('stock_productos')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text(widget.eventName)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar producto...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final scannedCode = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ScannerScreen(),
                      ),
                    );

                    if (scannedCode != null) {
                      setState(() {
                        _searchController.text = scannedCode;
                        _searchQuery = scannedCode;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: productsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error al cargar productos.'),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Image.asset('assets/imagenes/logo.png', width: 100),
                  );
                }

                _products = snapshot.data!.docs;

                final filteredProducts = _products.where((product) {
                  final productName =
                      (product.data() as Map<String, dynamic>)['nombreproduct']
                          ?.toLowerCase() ??
                      '';
                  return productName.contains(_searchQuery.toLowerCase());
                }).toList();

                return ListView(
                  children: filteredProducts.map((document) {
                    final data = document.data()! as Map<String, dynamic>;
                    final productId = document.id;
                    final currentQuantity = _shoppingCart[productId] ?? 0;

                    return ListTile(
                      title: Text(data['nombreproduct'] ?? 'Sin nombre'),
                      subtitle: Text('Stock: ${data['stock']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              if (currentQuantity > 0) {
                                setState(
                                  () => _shoppingCart[productId] =
                                      currentQuantity - 1,
                                );
                              }
                            },
                          ),
                          Text(
                            '$currentQuantity',
                            style: const TextStyle(fontSize: 18),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              if (currentQuantity < data['stock']) {
                                setState(
                                  () => _shoppingCart[productId] =
                                      currentQuantity + 1,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_shoppingCart.values.every((qty) => qty == 0)) {
            return;
          }

          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Confirmar Venta'),
                content: const Text('Seleccione el método de pago.'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Efectivo'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _processSale('Efectivo');
                    },
                  ),
                  TextButton(
                    child: const Text('Tarjeta'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _processSale('Tarjeta');
                    },
                  ),
                  // --- BOTÓN DE CANCELAR AÑADIDO ---
                  TextButton(
                    child: const Text('Cancelar'),
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop(); // Simplemente cierra el diálogo
                    },
                  ),
                ],
              );
            },
          );
        },
        label: const Text('Realizar Venta'),
        icon: const Icon(Icons.shopping_cart_checkout),
      ),
    );
  }
}
