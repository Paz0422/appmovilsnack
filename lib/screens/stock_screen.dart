import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StockScreen extends StatefulWidget {
  final String eventoId;
  final String nombreSector;
  final bool esStockInicial;

  const StockScreen({
    super.key,
    required this.eventoId,
    required this.nombreSector,
    required this.esStockInicial,
  });

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  bool _isLoading = true;
  List<DocumentSnapshot> _productos = [];
  Map<String, TextEditingController> _controllers = {};
  Map<String, int> _stockInicial = {};

  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);
  final Color backgroundColor = const Color(0xFFFDFBF7);

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    // Limpiar todos los controllers
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      // Cargar productos
      final snapshot = await FirebaseFirestore.instance
          .collection('productos')
          .get();

      // Si es stock final, cargar stock inicial para mostrar como referencia
      if (!widget.esStockInicial) {
        final stockInicialDoc = await FirebaseFirestore.instance
            .collection('eventos')
            .doc(widget.eventoId)
            .collection('sectores')
            .doc(widget.nombreSector)
            .collection('stock_inicial')
            .doc('productos')
            .get();

        if (stockInicialDoc.exists) {
          final data = stockInicialDoc.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('productos')) {
            final productosData = data['productos'] as Map<String, dynamic>?;
            if (productosData != null) {
              productosData.forEach((key, value) {
                _stockInicial[key] = value as int? ?? 0;
              });
            }
          }
        }
      }

      setState(() {
        _productos = snapshot.docs;

        // Crear controllers para cada producto
        for (var producto in _productos) {
          final data = producto.data() as Map<String, dynamic>?;
          if (data != null) {
            final String nombreProducto = data['nombre']?.toString() ?? '';
            if (nombreProducto.isNotEmpty) {
              _controllers[nombreProducto] = TextEditingController();

              // Si es stock final, pre-llenar con el stock inicial
              if (!widget.esStockInicial &&
                  _stockInicial.containsKey(nombreProducto)) {
                _controllers[nombreProducto]!.text =
                    _stockInicial[nombreProducto].toString();
              }
            }
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al cargar datos: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _guardarStock() async {
    try {
      Map<String, int> stockActual = {};

      // Recopilar todos los valores de stock
      for (var producto in _productos) {
        final data = producto.data() as Map<String, dynamic>?;
        if (data != null) {
          final String nombreProducto = data['nombre']?.toString() ?? '';
          if (nombreProducto.isNotEmpty) {
            final controller = _controllers[nombreProducto];
            if (controller != null) {
              final stockValue = int.tryParse(controller.text) ?? 0;
              stockActual[nombreProducto] = stockValue;
            }
          }
        }
      }

      String collectionName = widget.esStockInicial
          ? 'stock_inicial'
          : 'stock_final';

      if (widget.esStockInicial) {
        // Guardar stock inicial
        await FirebaseFirestore.instance
            .collection('eventos')
            .doc(widget.eventoId)
            .collection('sectores')
            .doc(widget.nombreSector)
            .collection(collectionName)
            .doc('productos')
            .set({
              'fecha': DateTime.now().toIso8601String(),
              'productos': stockActual,
            });
      } else {
        // Calcular ventas realizadas para stock final
        Map<String, int> ventasRealizadas = {};
        _stockInicial.forEach((producto, stockInicial) {
          final stockFinal = stockActual[producto] ?? 0;
          final ventas = stockInicial - stockFinal;
          if (ventas > 0) {
            ventasRealizadas[producto] = ventas;
          }
        });

        // Guardar stock final con cálculos
        await FirebaseFirestore.instance
            .collection('eventos')
            .doc(widget.eventoId)
            .collection('sectores')
            .doc(widget.nombreSector)
            .collection(collectionName)
            .doc('productos')
            .set({
              'fecha': DateTime.now().toIso8601String(),
              'productos': stockActual,
              'ventas_realizadas': ventasRealizadas,
              'resumen': {
                'total_productos_vendidos': ventasRealizadas.values.fold(
                  0,
                  (sum, ventas) => sum + ventas,
                ),
                'productos_con_ventas': ventasRealizadas.length,
              },
            });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.esStockInicial
                ? 'Stock inicial guardado exitosamente'
                : 'Stock final guardado exitosamente',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(true); // Retornar true para indicar éxito
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al guardar stock: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String titulo = widget.esStockInicial
        ? 'Stock Inicial - ${widget.nombreSector}'
        : 'Stock Final - ${widget.nombreSector}';

    final String descripcion = widget.esStockInicial
        ? 'Ingresa la cantidad inicial de cada producto para el sector ${widget.nombreSector}'
        : 'Ingresa la cantidad final de cada producto para calcular las ventas';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/imagenes/logo.png", height: 30),
            const SizedBox(width: 10),
            Text(
              titulo,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: accentColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
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
                      children: [
                        Icon(
                          widget.esStockInicial
                              ? Icons.inventory_2
                              : Icons.assessment,
                          size: 48,
                          color: accentColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.esStockInicial
                              ? 'Configurar Stock Inicial'
                              : 'Configurar Stock Final',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          descripcion,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: secondaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _productos.length,
                      itemBuilder: (context, index) {
                        final producto = _productos[index];
                        final data = producto.data() as Map<String, dynamic>?;

                        if (data == null) {
                          return const SizedBox.shrink();
                        }

                        final String nombreProducto =
                            data['nombre']?.toString() ?? 'Sin nombre';
                        final num precioProducto = data['precio'] as num? ?? 0;
                        final controller = _controllers[nombreProducto];
                        final stockInicial = _stockInicial[nombreProducto] ?? 0;

                        if (controller == null) {
                          return const SizedBox.shrink();
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.fastfood,
                                    color: accentColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombreProducto,
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.esStockInicial
                                            ? 'Precio: \$${precioProducto.toStringAsFixed(0)}'
                                            : 'Precio: \$${precioProducto.toStringAsFixed(0)} | Inicial: $stockInicial',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: secondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      labelText: widget.esStockInicial
                                          ? 'Stock'
                                          : 'Final',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                    ),
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
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
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _guardarStock,
                    icon: const Icon(Icons.save),
                    label: Text(
                      widget.esStockInicial
                          ? 'Guardar Stock Inicial'
                          : 'Guardar Stock Final',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}


