import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PanelVentas extends StatefulWidget {
  final String eventoId;
  final String nombreSector;
  final String sectorId;
  final String? vendedorNombre; // NUEVO: Nombre del vendedor

  const PanelVentas({
    super.key,
    required this.eventoId,
    required this.nombreSector,
    required this.sectorId,
    this.vendedorNombre, // NUEVO parámetro opcional
  });

  @override
  State<PanelVentas> createState() => _PanelVentasState();
}

class _PanelVentasState extends State<PanelVentas> {
  String? _sectorActualNombre;
  String? _sectorActualId;
  List<Map<String, String>> _todosLosSectores = [];
  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _productos = [];
  List<DocumentSnapshot> _productosFiltrados = [];

  List<Map<String, dynamic>> _carritoItems = [];
  double _montoTotal = 0.0;

  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);
  final Color backgroundColor = const Color(0xFFFDFBF7);

  @override
  void initState() {
    super.initState();
    _sectorActualNombre = widget.nombreSector;
    _sectorActualId = widget.sectorId;
    _cargarDatosIniciales();
    _searchController.addListener(_filtrarProductos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
      await _cargarSectoresDelEvento();
      await _cargarProductosPorSector();
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión: ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error inesperado: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cargarSectoresDelEvento() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .get();

      setState(() {
        _todosLosSectores = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'nombre': (data['nombre'] as String?) ?? 'Sin Nombre',
          };
        }).toList();
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _cargarProductosPorSector() async {
    if (_sectorActualId == null) return;
    try {
      final sectorDoc = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(_sectorActualId)
          .get();

      if (!sectorDoc.exists) {
        setState(() {
          _productos = [];
          _productosFiltrados = [];
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(_sectorActualId)
          .collection('stockInicial')
          .get();

      setState(() {
        _productos = snapshot.docs;
        _productosFiltrados = _productos;
      });
    } catch (e) {
      rethrow;
    }
  }

  void _filtrarProductos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _productosFiltrados = _productos.where((producto) {
        final data = producto.data() as Map<String, dynamic>?;
        if (data == null || !data.containsKey('nombre')) {
          return false;
        }
        final nombre = data['nombre'].toString().toLowerCase();
        return nombre.contains(query);
      }).toList();
    });
  }

  void _agregarItemAlCarrito(String nombre, double precio, int stock) {
    setState(() {
      bool itemEncontrado = false;
      for (var item in _carritoItems) {
        if (item['nombre'] == nombre) {
          if (item['cantidad'] < stock) {
            item['cantidad']++;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No hay más stock disponible para $nombre',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          itemEncontrado = true;
          break;
        }
      }
      if (!itemEncontrado) {
        _carritoItems.add({
          'nombre': nombre,
          'precio': precio,
          'cantidad': 1,
          'stock': stock,
        });
      }
      _recalcularTotal();
    });
  }

  void _quitarItemDelCarrito(String nombre) {
    setState(() {
      _carritoItems.removeWhere((item) => item['nombre'] == nombre);
      _recalcularTotal();
    });
  }

  void _incrementarCantidad(String nombre) {
    setState(() {
      for (var item in _carritoItems) {
        if (item['nombre'] == nombre) {
          int stock = item['stock'] ?? 0;
          if (item['cantidad'] < stock) {
            item['cantidad']++;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No hay más stock disponible para $nombre',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          break;
        }
      }
      _recalcularTotal();
    });
  }

  void _decrementarCantidad(String nombre) {
    setState(() {
      for (var item in _carritoItems) {
        if (item['nombre'] == nombre) {
          if (item['cantidad'] > 1) {
            item['cantidad']--;
          } else {
            _quitarItemDelCarrito(nombre);
            return;
          }
          break;
        }
      }
      _recalcularTotal();
    });
  }

  void _recalcularTotal() {
    _montoTotal = 0.0;
    for (var item in _carritoItems) {
      _montoTotal += (item['precio'] as num) * (item['cantidad'] as num);
    }
  }

  // NUEVA FUNCIÓN: Actualizar el total del vendedor en el sector
  Future<void> _actualizarTotalVendedor(Transaction transaction) async {
    if (widget.vendedorNombre == null) return; // Si no hay vendedor, salir

    final sectorRef = FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('sectores')
        .doc(_sectorActualId);

    // Obtener los datos actuales del sector
    final sectorSnapshot = await transaction.get(sectorRef);

    if (sectorSnapshot.exists) {
      final sectorData = sectorSnapshot.data() as Map<String, dynamic>;
      List<dynamic> vendedoresAsignados = List.from(
        sectorData['vendedoresasignados'] ?? [],
      );

      // Buscar si el vendedor ya existe en el array
      bool vendedorEncontrado = false;
      for (int i = 0; i < vendedoresAsignados.length; i++) {
        if (vendedoresAsignados[i]['nombre'] == widget.vendedorNombre) {
          // Si existe, sumar al total
          double totalActual = (vendedoresAsignados[i]['totalVendido'] ?? 0)
              .toDouble();
          vendedoresAsignados[i]['totalVendido'] = totalActual + _montoTotal;
          vendedorEncontrado = true;
          break;
        }
      }

      // Si no existe, agregarlo al array
      if (!vendedorEncontrado) {
        vendedoresAsignados.add({
          'nombre': widget.vendedorNombre,
          'totalVendido': _montoTotal,
        });
      }

      // Actualizar el documento del sector
      transaction.update(sectorRef, {
        'vendedoresasignados': vendedoresAsignados,
        'totalVendido': FieldValue.increment(
          _montoTotal,
        ), // También actualizar el total general del sector
      });
    }
  }

  Future<void> _realizarVenta(String metodoPago) async {
    if (_carritoItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El carrito está vacío.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Crear la venta
        final ventaRef = FirebaseFirestore.instance
            .collection('transacciones')
            .doc();
        transaction.set(ventaRef, {
          'eventoId': widget.eventoId,
          'sectorId': _sectorActualId,
          'vendedorNombre': widget.vendedorNombre, // NUEVO: Agregar el vendedor
          'fecha': FieldValue.serverTimestamp(),
          'montoTotal': _montoTotal,
          'metodoPago': metodoPago,
        });

        // 2. Actualizar el stock de cada producto
        for (var item in _carritoItems) {
          final productoNombre = item['nombre'] as String;
          final cantidadVendida = item['cantidad'] as int;

          final productoQuery = await FirebaseFirestore.instance
              .collection('eventos')
              .doc(widget.eventoId)
              .collection('sectores')
              .doc(_sectorActualId)
              .collection('stockInicial')
              .where('nombre', isEqualTo: productoNombre)
              .get();

          if (productoQuery.docs.isNotEmpty) {
            final productoDoc = productoQuery.docs.first;
            final productoRef = productoDoc.reference;
            final currentStock = productoDoc.data()['stock'] as int? ?? 0;

            if (currentStock >= cantidadVendida) {
              transaction.update(productoRef, {
                'stock': currentStock - cantidadVendida,
              });
            } else {
              throw Exception('Stock insuficiente para $productoNombre');
            }
          }
        }

        // 3. NUEVA FUNCIONALIDAD: Actualizar el total del vendedor en el sector
        await _actualizarTotalVendedor(transaction);
      });

      // Si la transacción fue exitosa
      _limpiarCarrito();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Venta realizada con éxito',
            style: GoogleFonts.poppins(color: primaryColor),
          ),
          backgroundColor: accentColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al realizar la venta: ${e.message}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _limpiarCarrito() {
    setState(() {
      _carritoItems = [];
      _montoTotal = 0.0;
    });
  }

  void _escanearCodigoBarras() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Función de escaneo de código de barras - Próximamente',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: accentColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // NUEVA FUNCIONALIDAD: Devolver información actualizada
            final resultado = {
              'sectorNombre': _sectorActualNombre,
              'sectorId': _sectorActualId,
              'actualizado': true,
            };
            Navigator.pop(context, resultado);
          },
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/imagenes/logo.png", height: 30),
            const SizedBox(width: 10),
            _isLoading
                ? Text(
                    'Cargando...',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                      fontSize: 16,
                    ),
                  )
                : Expanded(
                    child: DropdownButton<String>(
                      value: _sectorActualNombre,
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down, color: accentColor),
                      style: GoogleFonts.poppins(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                      dropdownColor: primaryColor,
                      underline: Container(),
                      onChanged: (String? nuevoSectorNombre) async {
                        if (nuevoSectorNombre != null) {
                          final nuevoSector = _todosLosSectores.firstWhere(
                            (sector) => sector['nombre'] == nuevoSectorNombre,
                          );
                          if (nuevoSector['id'] != _sectorActualId) {
                            setState(() {
                              _isLoading = true;
                              _sectorActualNombre = nuevoSectorNombre;
                              _sectorActualId = nuevoSector['id'];
                              _carritoItems.clear();
                              _montoTotal = 0.0;
                            });
                            await _cargarProductosPorSector();
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        }
                      },
                      items: _todosLosSectores.map<DropdownMenuItem<String>>((
                        Map<String, String> sector,
                      ) {
                        return DropdownMenuItem<String>(
                          value: sector['nombre'],
                          child: Text(sector['nombre']!),
                        );
                      }).toList(),
                    ),
                  ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: ElevatedButton.icon(
              onPressed: _escanearCodigoBarras,
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: Text('Escanear', style: GoogleFonts.poppins(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: accentColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: secondaryColor,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar productos...',
                      prefixIcon: Icon(Icons.search, color: secondaryColor),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Sección del carrito visible
                  if (_carritoItems.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Carrito de ventas',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              Text(
                                'Total: ${_montoTotal.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Divider(color: secondaryColor.withOpacity(0.3)),
                          const SizedBox(height: 8),
                          // Lista de items del carrito con altura fija y scroll
                          SizedBox(
                            height: 200, // Altura fija para el área de items
                            child: ListView.builder(
                              itemCount: _carritoItems.length,
                              itemBuilder: (context, index) {
                                final item = _carritoItems[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      // Cantidad
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: accentColor,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            item['cantidad'].toString(),
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Nombre del producto
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['nombre'],
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: primaryColor,
                                              ),
                                            ),
                                            Text(
                                              'Stock: ${item['stock'] ?? 0}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: secondaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Controles de cantidad
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                            ),
                                            color: secondaryColor,
                                            iconSize: 22,
                                            onPressed: () =>
                                                _decrementarCantidad(
                                                  item['nombre'],
                                                ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            child: Text(
                                              '${item['cantidad']}',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                            ),
                                            color: accentColor,
                                            iconSize: 22,
                                            onPressed: () =>
                                                _incrementarCantidad(
                                                  item['nombre'],
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      // Precio unitario
                                      Text(
                                        (item['precio'] as num).toStringAsFixed(
                                          0,
                                        ),
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: accentColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Botón eliminar
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        color: Colors.red,
                                        iconSize: 20,
                                        onPressed: () => _quitarItemDelCarrito(
                                          item['nombre'],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Botones de pago
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _realizarVenta('Efectivo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: secondaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.money, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Efectivo',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _realizarVenta('Tarjeta'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.credit_card, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Tarjeta',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Grid de productos
                  Expanded(
                    child:
                        _productosFiltrados.isEmpty &&
                            _searchController.text.isNotEmpty
                        ? Center(
                            child: Text(
                              'No se encontraron productos.',
                              style: GoogleFonts.poppins(color: secondaryColor),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 0.6,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                            itemCount: _productosFiltrados.length,
                            itemBuilder: (context, index) {
                              final producto = _productosFiltrados[index];
                              final data =
                                  producto.data() as Map<String, dynamic>?;

                              if (data == null) {
                                return const SizedBox.shrink();
                              }

                              final String nombreProducto =
                                  data['nombre']?.toString() ?? 'Sin nombre';
                              final num precioProducto =
                                  data['precio'] as num? ?? 0;
                              final int stockProducto =
                                  data['stock'] as int? ?? 0;

                              return Card(
                                elevation: stockProducto > 0 ? 4 : 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                color: stockProducto > 0
                                    ? Colors.white
                                    : Colors.grey.withOpacity(0.1),
                                child: InkWell(
                                  onTap: () {
                                    if (stockProducto > 0) {
                                      _agregarItemAlCarrito(
                                        nombreProducto,
                                        precioProducto.toDouble(),
                                        stockProducto,
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'No hay stock disponible para $nombreProducto',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(15),
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.fastfood,
                                              size: 40,
                                              color: stockProducto > 0
                                                  ? secondaryColor
                                                  : Colors.grey,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              nombreProducto,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: primaryColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              precioProducto.toStringAsFixed(0),
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: accentColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: primaryColor,
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                          child: Text(
                                            'Stock: $stockProducto',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
