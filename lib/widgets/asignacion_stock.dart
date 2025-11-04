// Archivo: lib/widgets/asignacion_stock.dart
// Módulo de Asignación Stock - Gestión de stock por sector de evento

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AsignacionStock extends StatefulWidget {
  const AsignacionStock({super.key});

  @override
  State<AsignacionStock> createState() => _AsignacionStockState();
}

class _AsignacionStockState extends State<AsignacionStock> {
  String? _eventoSeleccionadoId;
  String? _nombreEventoSeleccionado;
  String? _sectorSeleccionadoId;
  String? _nombreSectorSeleccionado;
  
  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);
  final Color backgroundColor = const Color(0xFFFDFBF7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Asignación de Stock',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
        actions: [
          if (_eventoSeleccionadoId != null && _sectorSeleccionadoId != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar',
              onPressed: () {
                setState(() {
                  _eventoSeleccionadoId = null;
                  _nombreEventoSeleccionado = null;
                  _sectorSeleccionadoId = null;
                  _nombreSectorSeleccionado = null;
                });
              },
            ),
        ],
      ),
      body: _eventoSeleccionadoId == null
          ? _buildSeleccionEvento()
          : _sectorSeleccionadoId == null
              ? _buildSeleccionSector()
              : _buildGestionStock(),
    );
  }

  Widget _buildSeleccionEvento() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eventos')
          .orderBy('nombre')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: accentColor),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar eventos: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: secondaryColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 64,
                    color: secondaryColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay eventos disponibles',
                    style: GoogleFonts.poppins(
                      color: secondaryColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final eventos = snapshot.data!.docs;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecciona un Evento',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: eventos.length,
                  itemBuilder: (context, index) {
                    final evento = eventos[index];
                    final data = evento.data() as Map<String, dynamic>;
                    final nombreEvento = data['nombre']?.toString() ?? 'Sin nombre';

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
                            Icons.event,
                            color: accentColor,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          nombreEvento,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: primaryColor,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: accentColor,
                          size: 20,
                        ),
                        onTap: () {
                          setState(() {
                            _eventoSeleccionadoId = evento.id;
                            _nombreEventoSeleccionado = nombreEvento;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeleccionSector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eventos')
          .doc(_eventoSeleccionadoId!)
          .collection('sectores')
          .orderBy('nombre')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: accentColor),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar sectores: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: secondaryColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _eventoSeleccionadoId = null;
                        _nombreEventoSeleccionado = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: primaryColor,
                    ),
                    child: Text(
                      'Volver',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 64,
                    color: secondaryColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay sectores disponibles para este evento',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: secondaryColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _eventoSeleccionadoId = null;
                        _nombreEventoSeleccionado = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: primaryColor,
                    ),
                    child: Text(
                      'Volver',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final sectores = snapshot.data!.docs;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: accentColor),
                    onPressed: () {
                      setState(() {
                        _eventoSeleccionadoId = null;
                        _nombreEventoSeleccionado = null;
                      });
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evento: $_nombreEventoSeleccionado',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: secondaryColor,
                          ),
                        ),
                        Text(
                          'Selecciona un Sector',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: sectores.length,
                  itemBuilder: (context, index) {
                    final sector = sectores[index];
                    final data = sector.data() as Map<String, dynamic>;
                    final nombreSector = data['nombre']?.toString() ?? 'Sin nombre';

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
                            color: secondaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: secondaryColor,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          nombreSector,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: primaryColor,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: accentColor,
                          size: 20,
                        ),
                        onTap: () {
                          setState(() {
                            _sectorSeleccionadoId = sector.id;
                            _nombreSectorSeleccionado = nombreSector;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGestionStock() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('productos')
          .orderBy('nombre')
          .snapshots(),
      builder: (context, productosSnapshot) {
        if (productosSnapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: accentColor),
          );
        }

        if (productosSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar productos: ${productosSnapshot.error}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: secondaryColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _sectorSeleccionadoId = null;
                        _nombreSectorSeleccionado = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: primaryColor,
                    ),
                    child: Text(
                      'Volver',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!productosSnapshot.hasData || productosSnapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
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
                    'No hay productos disponibles',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: secondaryColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _sectorSeleccionadoId = null;
                        _nombreSectorSeleccionado = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: primaryColor,
                    ),
                    child: Text(
                      'Volver',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final productos = productosSnapshot.data!.docs;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: primaryColor.withOpacity(0.05),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: accentColor),
                    onPressed: () {
                      setState(() {
                        _sectorSeleccionadoId = null;
                        _nombreSectorSeleccionado = null;
                      });
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evento: $_nombreEventoSeleccionado',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: secondaryColor,
                          ),
                        ),
                        Text(
                          'Sector: $_nombreSectorSeleccionado',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: productos.length,
                itemBuilder: (context, index) {
                  final producto = productos[index];
                  final productoData = producto.data() as Map<String, dynamic>;
                  final nombreProducto = productoData['nombre']?.toString() ?? 'Sin nombre';
                  final precioProducto = (productoData['precio'] as num?)?.toDouble() ?? 0.0;

                  return _StockProductoCard(
                    productoId: producto.id,
                    nombreProducto: nombreProducto,
                    precioProducto: precioProducto,
                    eventoId: _eventoSeleccionadoId!,
                    sectorId: _sectorSeleccionadoId!,
                    primaryColor: primaryColor,
                    accentColor: accentColor,
                    secondaryColor: secondaryColor,
                    backgroundColor: backgroundColor,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StockProductoCard extends StatefulWidget {
  final String productoId;
  final String nombreProducto;
  final double precioProducto;
  final String eventoId;
  final String sectorId;
  final Color primaryColor;
  final Color accentColor;
  final Color secondaryColor;
  final Color backgroundColor;

  const _StockProductoCard({
    required this.productoId,
    required this.nombreProducto,
    required this.precioProducto,
    required this.eventoId,
    required this.sectorId,
    required this.primaryColor,
    required this.accentColor,
    required this.secondaryColor,
    required this.backgroundColor,
  });

  @override
  State<_StockProductoCard> createState() => _StockProductoCardState();
}

class _StockProductoCardState extends State<_StockProductoCard> {
  int _stockActual = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarStock();
  }

  Future<void> _cargarStock() async {
    try {
      final stockQuery = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId)
          .collection('stockInicial')
          .where('productoId', isEqualTo: widget.productoId)
          .limit(1)
          .get();

      if (stockQuery.docs.isNotEmpty) {
        final stockData = stockQuery.docs.first.data();
        setState(() {
          _stockActual = stockData['stock'] as int? ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _stockActual = 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar stock: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _actualizarStock(int nuevoStock) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final stockRef = FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId)
          .collection('stockInicial')
          .where('productoId', isEqualTo: widget.productoId)
          .limit(1);

      final stockQuery = await stockRef.get();

      final stockData = {
        'productoId': widget.productoId,
        'nombre': widget.nombreProducto,
        'precio': widget.precioProducto,
        'stock': nuevoStock,
        'actualizado': FieldValue.serverTimestamp(),
      };

      if (stockQuery.docs.isNotEmpty) {
        // Actualizar stock existente
        await stockQuery.docs.first.reference.update(stockData);
      } else {
        // Crear nuevo registro de stock
        await FirebaseFirestore.instance
            .collection('eventos')
            .doc(widget.eventoId)
            .collection('sectores')
            .doc(widget.sectorId)
            .collection('stockInicial')
            .add(stockData);
      }

      setState(() {
        _stockActual = nuevoStock;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stock actualizado exitosamente',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al actualizar stock: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _mostrarDialogoEditarStock() async {
    final stockController = TextEditingController(
      text: _stockActual.toString(),
    );

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: widget.backgroundColor,
          title: Text(
            'Editar Stock',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: widget.primaryColor,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.nombreProducto,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: widget.secondaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Cantidad de Stock',
                    labelStyle: GoogleFonts.poppins(color: widget.secondaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: widget.accentColor, width: 2),
                    ),
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
                style: GoogleFonts.poppins(color: widget.secondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final stockStr = stockController.text.trim();
                final nuevoStock = int.tryParse(stockStr);

                if (nuevoStock == null || nuevoStock < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Por favor, ingresa una cantidad válida mayor o igual a 0.',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop();
                await _actualizarStock(nuevoStock);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accentColor,
                foregroundColor: widget.primaryColor,
              ),
              child: Text(
                'Guardar',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircularProgressIndicator(
            strokeWidth: 2,
            color: widget.accentColor,
          ),
          title: Text(
            widget.nombreProducto,
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }

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
            color: widget.accentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.fastfood,
            color: widget.accentColor,
            size: 28,
          ),
        ),
        title: Text(
          widget.nombreProducto,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: widget.primaryColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Precio: \$${widget.precioProducto.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: widget.secondaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.inventory_2,
                  size: 16,
                  color: _stockActual > 0 ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  'Stock: $_stockActual',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _stockActual > 0 ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: _isSaving
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.accentColor,
                ),
              )
            : IconButton(
                icon: Icon(
                  Icons.edit,
                  color: widget.accentColor,
                ),
                onPressed: _mostrarDialogoEditarStock,
                tooltip: 'Editar stock',
              ),
      ),
    );
  }
}
