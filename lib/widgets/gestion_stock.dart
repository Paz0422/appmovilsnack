import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// Paleta de colores basada en el logo "Fusión"
const Color _primaryColor = Color(0xFF2B2B2B);
const Color _accentColor = Color(0xFFDABF41);
const Color _secondaryColor = Color(0xFF6B4D2F);
const Color _backgroundColor = Color(0xFFFDFBF7);

/// Widget reutilizable para gestionar el stock de un sector
/// Lee de la colección: /eventos/{idevento}/sectores/{idsector}/stock
class GestionStock extends StatelessWidget {
  final String eventoId;
  final String sectorId;
  final String nombreSector;

  const GestionStock({
    super.key,
    required this.eventoId,
    required this.sectorId,
    required this.nombreSector,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          'Gestión de Stock',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: _accentColor,
          ),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: _accentColor,
      ),
      body: Column(
        children: [
          // Información del sector
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _accentColor.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sector: $nombreSector',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stock en tiempo real',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _secondaryColor,
                  ),
                ),
              ],
            ),
          ),
          // Lista de stock en tiempo real
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('eventos')
                  .doc(eventoId)
                  .collection('sectores')
                  .doc(sectorId)
                  .collection('stock')
                  .orderBy('nombre')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: _accentColor),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Error al cargar stock: ${snapshot.error}',
                        style: GoogleFonts.poppins(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: _secondaryColor.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay productos en stock',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: _secondaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Toca el botón + para agregar productos',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _secondaryColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final productos = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: productos.length,
                  itemBuilder: (context, index) {
                    final productoDoc = productos[index];
                    final data = productoDoc.data() as Map<String, dynamic>;
                    final nombre = data['nombre'] as String? ?? 'Sin nombre';
                    final precio = (data['precio'] as num?)?.toDouble() ?? 0.0;
                    final cantidad = data['cantidad'] as int? ?? 0;

                    return _ProductoStockCard(
                      productoId: productoDoc.id,
                      nombre: nombre,
                      precio: precio,
                      cantidad: cantidad,
                      eventoId: eventoId,
                      sectorId: sectorId,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarModalAgregarProducto(context),
        backgroundColor: _accentColor,
        foregroundColor: _primaryColor,
        icon: const Icon(Icons.add),
        label: Text(
          'Agregar Producto',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _mostrarModalAgregarProducto(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ModalBuscarProducto(
        eventoId: eventoId,
        sectorId: sectorId,
      ),
    );
  }
}

/// Card individual para cada producto en stock
class _ProductoStockCard extends StatelessWidget {
  final String productoId;
  final String nombre;
  final double precio;
  final int cantidad;
  final String eventoId;
  final String sectorId;

  const _ProductoStockCard({
    required this.productoId,
    required this.nombre,
    required this.precio,
    required this.cantidad,
    required this.eventoId,
    required this.sectorId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.fastfood,
            color: _secondaryColor,
            size: 28,
          ),
        ),
        title: Text(
          nombre,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: _primaryColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Precio: \$${precio.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _secondaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cantidad > 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Stock: $cantidad',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cantidad > 0 ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              color: _accentColor,
              onPressed: () => _editarCantidad(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: () => _eliminarProducto(context),
            ),
          ],
        ),
      ),
    );
  }

  void _editarCantidad(BuildContext context) {
    final cantidadController = TextEditingController(text: cantidad.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Editar Cantidad',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              nombre,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _secondaryColor,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cantidadController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cantidad',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.inventory_2),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: _secondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final nuevaCantidad = int.tryParse(cantidadController.text);
              if (nuevaCantidad == null || nuevaCantidad < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Ingresa una cantidad válida',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('eventos')
                    .doc(eventoId)
                    .collection('sectores')
                    .doc(sectorId)
                    .collection('stock')
                    .doc(productoId)
                    .update({'cantidad': nuevaCantidad});

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Cantidad actualizada',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error al actualizar: $e',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: _primaryColor,
            ),
            child: Text(
              'Guardar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _eliminarProducto(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Eliminar Producto',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar "$nombre" del stock?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: _secondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('eventos')
                    .doc(eventoId)
                    .collection('sectores')
                    .doc(sectorId)
                    .collection('stock')
                    .doc(productoId)
                    .delete();

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Producto eliminado',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error al eliminar: $e',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Eliminar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal para buscar y agregar productos desde la colección global
class _ModalBuscarProducto extends StatefulWidget {
  final String eventoId;
  final String sectorId;

  const _ModalBuscarProducto({
    required this.eventoId,
    required this.sectorId,
  });

  @override
  State<_ModalBuscarProducto> createState() => _ModalBuscarProductoState();
}

class _ModalBuscarProductoState extends State<_ModalBuscarProducto> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _productos = [];
  List<DocumentSnapshot> _productosFiltrados = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _searchController.addListener(_filtrarProductos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarProductos() async {
    try {
      // Cargar productos globales
      final productosSnapshot = await FirebaseFirestore.instance
          .collection('productos')
          .get();

      // Cargar productos que ya están en stock para evitar duplicados
      final stockSnapshot = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId)
          .collection('stock')
          .get();

      final productosEnStock = stockSnapshot.docs
          .map((doc) => doc.data()['productoId'] as String?)
          .where((id) => id != null)
          .toSet();

      // Filtrar productos que no están en stock
      final productosDisponibles = productosSnapshot.docs
          .where((doc) => !productosEnStock.contains(doc.id))
          .toList();

      setState(() {
        _productos = productosDisponibles;
        _productosFiltrados = _productos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar productos: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  Future<void> _agregarProductoAlStock(DocumentSnapshot productoDoc) async {
    final data = productoDoc.data() as Map<String, dynamic>;
    final nombre = data['nombre'] as String? ?? 'Sin nombre';
    final precio = (data['precio'] as num?)?.toDouble() ?? 0.0;

    final cantidadController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Agregar al Stock',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              nombre,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Precio: \$${precio.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _secondaryColor,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cantidadController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cantidad inicial',
                hintText: 'Ingresa la cantidad',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.inventory_2),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: _secondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final cantidad = int.tryParse(cantidadController.text);
              if (cantidad == null || cantidad < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Ingresa una cantidad válida',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('eventos')
                    .doc(widget.eventoId)
                    .collection('sectores')
                    .doc(widget.sectorId)
                    .collection('stock')
                    .doc(productoDoc.id)
                    .set({
                      'productoId': productoDoc.id,
                      'nombre': nombre,
                      'precio': precio,
                      'cantidad': cantidad,
                    });

                if (context.mounted) {
                  Navigator.of(context).pop(); // Cerrar diálogo de cantidad
                  Navigator.of(context).pop(); // Cerrar modal de búsqueda
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Producto agregado al stock',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error al agregar: $e',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: _primaryColor,
            ),
            child: Text(
              'Agregar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Buscar Producto',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar productos...',
              prefixIcon: Icon(Icons.search, color: _secondaryColor),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _accentColor))
                : _productosFiltrados.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'No hay productos disponibles'
                              : 'No se encontraron productos',
                          style: GoogleFonts.poppins(color: _secondaryColor),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _productosFiltrados.length,
                        itemBuilder: (context, index) {
                          final producto = _productosFiltrados[index];
                          final data = producto.data() as Map<String, dynamic>;
                          final nombre = data['nombre'] as String? ?? 'Sin nombre';
                          final precio = (data['precio'] as num?)?.toDouble() ?? 0.0;

                          return ListTile(
                            leading: Icon(Icons.fastfood, color: _secondaryColor),
                            title: Text(
                              nombre,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Precio: \$${precio.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                color: _secondaryColor,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.add_circle, color: _accentColor),
                              onPressed: () => _agregarProductoAlStock(producto),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

