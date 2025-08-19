import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'stock_screen.dart';

class PanelVentas extends StatefulWidget {
  final String eventoId;
  final String nombreSector;

  const PanelVentas({
    super.key,
    required this.eventoId,
    required this.nombreSector,
  });

  @override
  State<PanelVentas> createState() => _PanelVentasState();
}

class _PanelVentasState extends State<PanelVentas> {
  String? _sectorActual;
  List<String> _todosLosSectores = [];
  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _productos = [];
  List<DocumentSnapshot> _productosFiltrados = [];

  List<Map<String, dynamic>> _carritoItems = [];
  double _montoTotal = 0.0;
  bool _stockInicialAgregado = false;

  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);
  final Color backgroundColor = const Color(0xFFFDFBF7);

  @override
  void initState() {
    super.initState();
    _sectorActual = widget.nombreSector;
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
      await _cargarSectoresDelEvento();
      await _cargarProductos();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Error al cargar datos. Revisa tu conexión y permisos.';
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
      final docSnapshot = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final List<dynamic> sectoresFromDB = data['sectores'] ?? [];
        final List<String> nombresSectores = sectoresFromDB
            .map((sector) {
              if (sector is Map<String, dynamic>) {
                return sector['nombre'] as String;
              } else if (sector is String) {
                return sector;
              }
              return '';
            })
            .where((name) => name.isNotEmpty)
            .toList();
        setState(() {
          _todosLosSectores = nombresSectores;
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _cargarProductos() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('productos')
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
          // Verificar que no exceda el stock disponible
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

  void _limpiarCarrito() {
    setState(() {
      _carritoItems = [];
      _montoTotal = 0.0;
    });
  }

  void _realizarVenta() {
    _limpiarCarrito();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Venta realizada con éxito',
          style: GoogleFonts.poppins(color: primaryColor),
        ),
        backgroundColor: accentColor,
      ),
    );
  }

  void _agregarStockInicial() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StockScreen(
          eventoId: widget.eventoId,
          nombreSector: _sectorActual ?? widget.nombreSector,
          esStockInicial: true,
        ),
      ),
    );

    if (result == true) {
      setState(() {
        _stockInicialAgregado = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stock inicial configurado exitosamente',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _agregarStockFinal() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StockScreen(
          eventoId: widget.eventoId,
          nombreSector: _sectorActual ?? widget.nombreSector,
          esStockInicial: false,
        ),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stock final configurado exitosamente',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _escanearCodigoBarras() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Función de escaneo de código de barras - Próximamente',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: secondaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _cerrarTurno() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Cerrar Turno',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          content: Text(
            '¿Estás seguro de que quieres cerrar el turno?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(color: secondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(_sectorActual);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Turno cerrado exitosamente',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: primaryColor,
              ),
              child: Text(
                'Cerrar Turno',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _mostrarPanelPago() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Detalle de la venta',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _carritoItems.length,
                    itemBuilder: (context, index) {
                      final item = _carritoItems[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: accentColor.withOpacity(0.2),
                          child: Text(
                            item['cantidad'].toString(),
                            style: GoogleFonts.poppins(color: primaryColor),
                          ),
                        ),
                        title: Text(
                          item['nombre'],
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          'Stock disponible: ${item['stock'] ?? 0}',
                          style: GoogleFonts.poppins(
                            color: secondaryColor,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              color: secondaryColor,
                              onPressed: () =>
                                  _decrementarCantidad(item['nombre']),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item['cantidad']}',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              color: accentColor,
                              onPressed: () =>
                                  _incrementarCantidad(item['nombre']),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '\$${(item['precio'] as num).toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Total: \$${_montoTotal.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _realizarVenta,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: secondaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text('Efectivo', style: GoogleFonts.poppins()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _realizarVenta,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text('Tarjeta', style: GoogleFonts.poppins()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
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
            Navigator.pop(context, _sectorActual);
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
                      value: _sectorActual,
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down, color: accentColor),
                      style: GoogleFonts.poppins(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                      dropdownColor: primaryColor,
                      underline: Container(),
                      onChanged: (String? nuevoSector) {
                        if (nuevoSector != null) {
                          setState(() {
                            _sectorActual = nuevoSector;
                          });
                        }
                      },
                      items: _todosLosSectores.map<DropdownMenuItem<String>>((
                        String sector,
                      ) {
                        return DropdownMenuItem<String>(
                          value: sector,
                          child: Text(sector),
                        );
                      }).toList(),
                    ),
                  ),
          ],
        ),
        centerTitle: true,
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
                  // Barra de acciones
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
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _stockInicialAgregado
                                ? _agregarStockFinal
                                : _agregarStockInicial,
                            icon: Icon(
                              _stockInicialAgregado
                                  ? Icons.inventory_2
                                  : Icons.add_box,
                              size: 18,
                            ),
                            label: Text(
                              _stockInicialAgregado
                                  ? 'Stock Final'
                                  : 'Stock Inicial',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _stockInicialAgregado
                                  ? Colors.blue
                                  : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _escanearCodigoBarras,
                            icon: const Icon(Icons.qr_code_scanner, size: 18),
                            label: Text(
                              'Escanear',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: secondaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _cerrarTurno,
                            icon: const Icon(Icons.logout, size: 18),
                            label: Text(
                              'Cerrar Turno',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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

                              // Si los datos son nulos, no se renderiza el widget
                              if (data == null) {
                                return const SizedBox.shrink();
                              }

                              final String nombreProducto =
                                  data['nombre']?.toString() ?? 'Sin nombre';
                              final num precioProducto =
                                  data['precio'] as num? ?? 0;
                              final int stockProducto =
                                  data['cantidad'] as int? ?? 0;

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
                                    // Verificar que haya stock disponible
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
                                              '\$${precioProducto.toStringAsFixed(0)}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: accentColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: stockProducto > 0
                                                    ? Colors.green.withOpacity(
                                                        0.1,
                                                      )
                                                    : Colors.red.withOpacity(
                                                        0.1,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: stockProducto > 0
                                                      ? Colors.green
                                                      : Colors.red,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                'Stock: $stockProducto',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color: stockProducto > 0
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (stockProducto <= 0)
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(
                                                0.3,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'SIN STOCK',
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _montoTotal > 0
          ? FloatingActionButton.extended(
              onPressed: _mostrarPanelPago,
              backgroundColor: accentColor,
              foregroundColor: primaryColor,
              icon: const Icon(Icons.shopping_cart),
              label: Text(
                'Total: \$${_montoTotal.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}
