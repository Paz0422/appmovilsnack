// Archivo: lib/widgets/inventory_management.dart
// Gestión de Inventario - CRUD completo de productos

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class InventoryManagement extends StatefulWidget {
  const InventoryManagement({super.key});

  @override
  State<InventoryManagement> createState() => _InventoryManagementState();
}

class _InventoryManagementState extends State<InventoryManagement> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _productos = [];
  List<DocumentSnapshot> _productosFiltrados = [];
  bool _isLoading = true;
  String? _errorMessage;

  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);
  final Color backgroundColor = const Color(0xFFFDFBF7);

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
      final snapshot = await FirebaseFirestore.instance
          .collection('productos')
          .orderBy('nombre')
          .get();

      setState(() {
        _productos = snapshot.docs;
        _productosFiltrados = _productos;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Error al cargar productos. Revisa tu conexión y permisos.';
          _isLoading = false;
        });
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

  Future<void> _mostrarDialogoProducto({DocumentSnapshot? producto}) async {
    final nombreController = TextEditingController(
      text: producto?.data() != null
          ? (producto!.data() as Map<String, dynamic>)['nombre'] ?? ''
          : '',
    );
    final precioController = TextEditingController(
      text: producto?.data() != null
          ? ((producto!.data() as Map<String, dynamic>)['precio'] ?? 0)
                .toString()
          : '',
    );

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text(
            producto == null ? 'Agregar Producto' : 'Editar Producto',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre del Producto',
                    labelStyle: GoogleFonts.poppins(color: secondaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: accentColor, width: 2),
                    ),
                  ),
                  style: GoogleFonts.poppins(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: precioController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Precio',
                    labelStyle: GoogleFonts.poppins(color: secondaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: accentColor, width: 2),
                    ),
                    prefixText: '\$ ',
                  ),
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
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
              onPressed: () async {
                final nombre = nombreController.text.trim();
                final precioStr = precioController.text.trim();

                if (nombre.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Por favor, ingresa un nombre para el producto.',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final precio = double.tryParse(precioStr);
                if (precio == null || precio <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Por favor, ingresa un precio válido mayor a 0.',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop();

                try {
                  final productoData = <String, dynamic>{
                    'nombre': nombre,
                    'precio': precio,
                  };

                  if (producto == null) {
                    // Agregar nuevo producto
                    await FirebaseFirestore.instance
                        .collection('productos')
                        .add(productoData);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Producto agregado exitosamente',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } else {
                    // Editar producto existente
                    await producto.reference.update(productoData);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Producto actualizado exitosamente',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }

                  await _cargarProductos();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Error al guardar el producto: $e',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: primaryColor,
              ),
              child: Text(
                producto == null ? 'Agregar' : 'Guardar',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _eliminarProducto(DocumentSnapshot producto) async {
    final nombre =
        (producto.data() as Map<String, dynamic>)['nombre'] ?? 'este producto';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text(
            'Confirmar Eliminación',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar "$nombre"? Esta acción no se puede deshacer.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(color: secondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
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
        );
      },
    );

    if (confirmar == true) {
      try {
        await producto.reference.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Producto eliminado exitosamente',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        await _cargarProductos();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al eliminar el producto: $e',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Gestión de Inventario',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: secondaryColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _cargarProductos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: primaryColor,
                      ),
                      child: Text(
                        'Reintentar',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar productos...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: secondaryColor,
                            ),
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
                      ),
                      const SizedBox(width: 12),
                      FloatingActionButton(
                        onPressed: () => _mostrarDialogoProducto(),
                        backgroundColor: accentColor,
                        foregroundColor: primaryColor,
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _productosFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: secondaryColor.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'No hay productos registrados'
                                    : 'No se encontraron productos',
                                style: GoogleFonts.poppins(
                                  color: secondaryColor,
                                  fontSize: 16,
                                ),
                              ),
                              if (_searchController.text.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: ElevatedButton.icon(
                                    onPressed: () => _mostrarDialogoProducto(),
                                    icon: const Icon(Icons.add),
                                    label: Text(
                                      'Agregar Primer Producto',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentColor,
                                      foregroundColor: primaryColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                    color: accentColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.fastfood,
                                    color: accentColor,
                                    size: 28,
                                  ),
                                ),
                                title: Text(
                                  nombreProducto,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: primaryColor,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${precioProducto.toStringAsFixed(0)}',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        color: accentColor,
                                      ),
                                      onPressed: () => _mostrarDialogoProducto(
                                        producto: producto,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () =>
                                          _eliminarProducto(producto),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoProducto(),
        backgroundColor: accentColor,
        foregroundColor: primaryColor,
        icon: const Icon(Icons.add),
        label: Text(
          'Agregar Producto',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
