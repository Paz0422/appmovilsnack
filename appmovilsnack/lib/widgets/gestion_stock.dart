import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:front_appsnack/utils/categorias_producto.dart';

// Paleta de colores basada en el logo "Fusión"
const Color _primaryColor = Color(0xFF2B2B2B);
const Color _accentColor = Color(0xFFDABF41);
const Color _secondaryColor = Color(0xFF6B4D2F);
const Color _backgroundColor = Color(0xFFFDFBF7);

/// Item de stock en memoria (hasta que se pulse Guardar)
Map<String, dynamic> _stockItem(String productoId, String nombre, double precio, int cantidad, [String categoria = 'Otros']) => {
  'productoId': productoId,
  'nombre': nombre,
  'precio': precio,
  'cantidad': cantidad,
  'categoria': categoria,
};

/// Widget reutilizable para gestionar el stock de un sector
/// Los cambios se guardan en Firestore solo al pulsar "Guardar".
/// [soloLectura]: si true, no permite agregar ni editar productos (solo ver)
class GestionStock extends StatefulWidget {
  final String eventoId;
  final String sectorId;
  final String nombreSector;
  final bool soloLectura;
  /// Si true, al guardar muestra advertencia de ingreso único y cierra la pantalla.
  final bool esIngresoInicial;
  /// Si se proporciona, se llama tras guardar con éxito.
  final VoidCallback? onGuardado;

  const GestionStock({
    super.key,
    required this.eventoId,
    required this.sectorId,
    required this.nombreSector,
    this.soloLectura = false,
    this.esIngresoInicial = false,
    this.onGuardado,
  });

  @override
  State<GestionStock> createState() => _GestionStockState();
}

class _GestionStockState extends State<GestionStock> {
  List<Map<String, dynamic>> _items = [];
  bool _dirty = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarStock();
  }

  Future<void> _cargarStock() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId)
          .collection('stock')
          .get();
      if (!mounted) return;
      setState(() {
        _items = snap.docs.map((d) {
          final data = d.data();
          final cat = data['categoria']?.toString() ?? categoriaDefault;
          return _stockItem(
            d.id,
            data['nombre']?.toString() ?? 'Sin nombre',
            (data['precio'] as num?)?.toDouble() ?? 0.0,
            data['cantidad'] as int? ?? 0,
            categoriasProducto.contains(cat) ? cat : categoriaDefault,
          );
        }).toList();
        _items.sort((a, b) {
          final oa = ordenCategoria(a['categoria'] as String);
          final ob = ordenCategoria(b['categoria'] as String);
          if (oa != ob) return oa.compareTo(ob);
          return (a['nombre'] as String).compareTo(b['nombre'] as String);
        });
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _resumenStockLectura() {
    final totalUnidades = _items.fold<int>(
      0,
      (sum, item) => sum + (item['cantidad'] as int? ?? 0),
    );
    final n = _items.length;
    return '$n producto${n == 1 ? '' : 's'} · $totalUnidades u. en stock';
  }

  Future<bool> _persistirStock() async {
    try {
      final col = FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId)
          .collection('stock');
      final batch = FirebaseFirestore.instance.batch();
      for (final item in _items) {
        final ref = col.doc(item['productoId'] as String);
        batch.set(ref, {
          'productoId': item['productoId'],
          'nombre': item['nombre'],
          'precio': item['precio'],
          'cantidad': item['cantidad'],
          'cantidadInicial': item['cantidad'],
          'categoria': item['categoria'] ?? categoriaDefault,
        });
      }
      final existing = await col.get();
      for (final doc in existing.docs) {
        if (!_items.any((i) => i['productoId'] == doc.id)) {
          batch.delete(doc.reference);
        }
      }
      await batch.commit();
      await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId)
          .set({'stockInicialIngresado': true}, SetOptions(merge: true));
      if (!mounted) return false;
      setState(() => _dirty = false);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _guardarYSalir() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Agregue al menos un producto antes de finalizar.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (widget.esIngresoInicial) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Finalizar ingreso de stock inicial',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _primaryColor),
          ),
          content: Text(
            'Atención: esta es la ÚNICA vez que podrá ingresar stock manualmente para este sector.\n\n'
            'Si necesita agregar stock después, debe ser mediante TRASPASO entre sectores.\n\n'
            '¿Desea guardar y finalizar?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancelar', style: GoogleFonts.poppins(color: _secondaryColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: _primaryColor,
              ),
              child: Text(
                'Guardar y salir',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    } else if (_dirty) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Guardar cambios', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text(
            '¿Desea guardar los cambios antes de salir?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancelar', style: GoogleFonts.poppins(color: _secondaryColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Guardar y salir', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }

    final ok = await _persistirStock();
    if (!ok || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Stock inicial guardado', style: GoogleFonts.poppins()),
        backgroundColor: Colors.green,
      ),
    );
    widget.onGuardado?.call();
    if (mounted) Navigator.of(context).pop();
  }

  void _agregarItemLocal(String productoId, String nombre, double precio, int cantidad, [String categoria = 'Otros']) {
    setState(() {
      _items.add(_stockItem(productoId, nombre, precio, cantidad, categoriasProducto.contains(categoria) ? categoria : categoriaDefault));
      _items.sort((a, b) {
        final oa = ordenCategoria(a['categoria'] as String);
        final ob = ordenCategoria(b['categoria'] as String);
        if (oa != ob) return oa.compareTo(ob);
        return (a['nombre'] as String).compareTo(b['nombre'] as String);
      });
      _dirty = true;
    });
  }

  void _actualizarCantidadLocal(String productoId, int cantidad) {
    setState(() {
      final i = _items.indexWhere((e) => e['productoId'] == productoId);
      if (i >= 0) {
        _items[i]['cantidad'] = cantidad;
        _dirty = true;
      }
    });
  }

  void _eliminarItemLocal(String productoId) {
    setState(() {
      _items.removeWhere((e) => e['productoId'] == productoId);
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.soloLectura || !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final salir = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Sin guardar', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: Text(
              'Si sale ahora no se guardará el stock. ¿Salir sin guardar?',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancelar', style: GoogleFonts.poppins(color: _secondaryColor)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Salir sin guardar', style: GoogleFonts.poppins(color: Colors.red)),
              ),
            ],
          ),
        );
        if (salir == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.soloLectura ? 'Ver stock' : 'Stock inicial del punto',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: _accentColor,
          ),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: _accentColor,
      ),
      bottomNavigationBar: widget.soloLectura
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _guardarYSalir,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      'Guardar y salir',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      body: Column(
        children: [
          // Información del sector
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _accentColor.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sector: ${widget.nombreSector}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.soloLectura
                      ? 'Consultá las cantidades disponibles en tu sector'
                      : widget.esIngresoInicial
                          ? 'Ingrese las cantidades y pulse Guardar y salir'
                          : 'Ingrese las cantidades iniciales y pulse Guardar',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _secondaryColor,
                  ),
                ),
              ],
            ),
          ),
          // Lista de stock (estado local hasta Guardar)
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _accentColor))
                : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: _secondaryColor.withValues(alpha: 0.5),
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
                            if (!widget.soloLectura)
                              Text(
                                'Apriete "+" para agregar productos al stock inicial',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: _secondaryColor.withValues(alpha: 0.8),
                                ),
                              ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Text(
                              widget.soloLectura
                                  ? _resumenStockLectura()
                                  : 'Stock inicial — agregue con "+" y pulse Guardar y salir',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: _secondaryColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return _ProductoStockCard(
                                  productoId: item['productoId'] as String,
                                  nombre: item['nombre'] as String,
                                  precio: (item['precio'] as num).toDouble(),
                                  cantidad: item['cantidad'] as int,
                                  soloLectura: widget.soloLectura,
                                  onEditarCantidad: (nuevaCantidad) =>
                                      _actualizarCantidadLocal(item['productoId'] as String, nuevaCantidad),
                                  onEliminar: () =>
                                      _eliminarItemLocal(item['productoId'] as String),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
      ],
    ),
      floatingActionButton: widget.soloLectura
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _mostrarModalAgregarProducto(context),
              backgroundColor: _accentColor,
              foregroundColor: _primaryColor,
              icon: const Icon(Icons.add),
              label: Text(
                'Agregar Producto',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
    ),
    );
  }

  void _mostrarModalAgregarProducto(BuildContext context) {
    final idsEnStock = _items.map((e) => e['productoId'] as String).toSet();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ModalBuscarProducto(
        eventoId: widget.eventoId,
        sectorId: widget.sectorId,
        productIdsEnStock: idsEnStock,
        onAgregarLocal: _agregarItemLocal,
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
  final bool soloLectura;
  final void Function(int nuevaCantidad)? onEditarCantidad;
  final VoidCallback? onEliminar;

  const _ProductoStockCard({
    required this.productoId,
    required this.nombre,
    required this.precio,
    required this.cantidad,
    this.soloLectura = false,
    this.onEditarCantidad,
    this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.fastfood, color: _secondaryColor, size: 28),
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
              style: GoogleFonts.poppins(fontSize: 12, color: _secondaryColor),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cantidad > 0
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                soloLectura ? 'Stock: $cantidad' : 'Stock inicial: $cantidad',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cantidad > 0 ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
          ],
        ),
        trailing: soloLectura
            ? null
            : Row(
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
              style: GoogleFonts.poppins(fontSize: 14, color: _secondaryColor),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cantidadController,
              autofocus: true,
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
            onPressed: () {
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
              Navigator.of(context).pop();
              onEditarCantidad?.call(nuevaCantidad);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Cantidad actualizada. No olvide Guardar.',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.green,
                ),
              );
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
            onPressed: () {
              Navigator.of(context).pop();
              onEliminar?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Producto eliminado de la lista. No olvide Guardar.',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.green,
                ),
              );
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
  final Set<String> productIdsEnStock;
  final void Function(String productoId, String nombre, double precio, int cantidad, [String categoria]) onAgregarLocal;

  const _ModalBuscarProducto({
    required this.eventoId,
    required this.sectorId,
    required this.productIdsEnStock,
    required this.onAgregarLocal,
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
      final productosSnapshot = await FirebaseFirestore.instance
          .collection('productos')
          .get();

      final productosDisponibles = productosSnapshot.docs
          .where((doc) => !widget.productIdsEnStock.contains(doc.id))
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
    final categoria = data['categoria']?.toString() ?? categoriaDefault;

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
              style: GoogleFonts.poppins(fontSize: 14, color: _secondaryColor),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cantidadController,
              autofocus: true,
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
            onPressed: () {
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
              Navigator.of(context).pop();
              widget.onAgregarLocal(productoDoc.id, nombre, precio, cantidad, categoria);
              setState(() {
                _productos = _productos.where((d) => d.id != productoDoc.id).toList();
                _productosFiltrados = _productos.where((producto) {
                  final data = producto.data() as Map<String, dynamic>?;
                  if (data == null || !data.containsKey('nombre')) return false;
                  final nombreP = data['nombre'].toString().toLowerCase();
                  return nombreP.contains(_searchController.text.toLowerCase());
                }).toList();
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Producto agregado. No olvide Guardar. Puede seguir agregando más.',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
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
                      final precio =
                          (data['precio'] as num?)?.toDouble() ?? 0.0;

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
                          style: GoogleFonts.poppins(color: _secondaryColor),
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
