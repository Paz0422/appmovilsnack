// Archivo: lib/widgets/stock_reports.dart
// Reportes de Stock - Monitoreo de niveles de stock

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class StockReports extends StatefulWidget {
  const StockReports({super.key});

  @override
  State<StockReports> createState() => _StockReportsState();
}

class _StockReportsState extends State<StockReports> {
  final TextEditingController _searchController = TextEditingController();
  
  String? _eventoSeleccionadoId;
  String? _eventoSeleccionadoNombre;
  String? _sectorSeleccionadoId;
  String? _sectorSeleccionadoNombre;
  
  List<Map<String, dynamic>> _stockData = [];
  List<Map<String, dynamic>> _stockDataFiltrados = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Umbral de stock bajo (se puede hacer configurable)
  final int _stockBajoUmbral = 10;

  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);
  final Color backgroundColor = const Color(0xFFFDFBF7);

  @override
  void initState() {
    super.initState();
    _cargarReportesStock();
    _searchController.addListener(_filtrarReportes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarReportesStock() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<Map<String, dynamic>> stockData = [];
      
      // Obtener todos los eventos
      final eventosSnapshot = await FirebaseFirestore.instance
          .collection('eventos')
          .get();

      for (var eventoDoc in eventosSnapshot.docs) {
        final eventoId = eventoDoc.id;
        final eventoData = eventoDoc.data();
        final eventoNombre = eventoData['nombre']?.toString() ?? 'Sin nombre';
        
        // Si hay un evento seleccionado y no coincide, saltar
        if (_eventoSeleccionadoId != null && _eventoSeleccionadoId != eventoId) {
          continue;
        }

        // Obtener todos los sectores del evento
        final sectoresSnapshot = await FirebaseFirestore.instance
            .collection('eventos')
            .doc(eventoId)
            .collection('sectores')
            .get();

        for (var sectorDoc in sectoresSnapshot.docs) {
          final sectorId = sectorDoc.id;
          final sectorData = sectorDoc.data();
          final sectorNombre = sectorData['nombre']?.toString() ?? 'Sin nombre';
          
          // Si hay un sector seleccionado y no coincide, saltar
          if (_sectorSeleccionadoId != null && _sectorSeleccionadoId != sectorId) {
            continue;
          }

          // Obtener el stock del sector
          final stockSnapshot = await FirebaseFirestore.instance
              .collection('eventos')
              .doc(eventoId)
              .collection('sectores')
              .doc(sectorId)
              .collection('stockInicial')
              .get();

          for (var stockDoc in stockSnapshot.docs) {
            final stockInfo = stockDoc.data();
            stockData.add({
              'eventoId': eventoId,
              'eventoNombre': eventoNombre,
              'sectorId': sectorId,
              'sectorNombre': sectorNombre,
              'productoId': stockInfo['productoId']?.toString() ?? stockDoc.id,
              'productoNombre': stockInfo['nombre']?.toString() ?? 'Sin nombre',
              'stock': stockInfo['stock'] as int? ?? 0,
              'precio': (stockInfo['precio'] as num?)?.toDouble() ?? 0.0,
            });
          }
        }
      }

      setState(() {
        _stockData = stockData;
        _stockDataFiltrados = stockData;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar reportes de stock: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _filtrarReportes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _stockDataFiltrados = List.from(_stockData);
      } else {
        _stockDataFiltrados = _stockData.where((item) {
          final productoNombre = item['productoNombre']?.toString().toLowerCase() ?? '';
          final eventoNombre = item['eventoNombre']?.toString().toLowerCase() ?? '';
          final sectorNombre = item['sectorNombre']?.toString().toLowerCase() ?? '';
          
          return productoNombre.contains(query) ||
                 eventoNombre.contains(query) ||
                 sectorNombre.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _seleccionarEvento() async {
    final eventosSnapshot = await FirebaseFirestore.instance
        .collection('eventos')
        .orderBy('nombre')
        .get();

    if (eventosSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No hay eventos disponibles',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final evento = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text(
          'Seleccionar Evento',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: eventosSnapshot.docs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  title: Text(
                    'Todos los eventos',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(context, {'id': '', 'nombre': 'Todos'});
                  },
                );
              }

              final eventoDoc = eventosSnapshot.docs[index - 1];
              final eventoData = eventoDoc.data();
              final eventoNombre = eventoData['nombre']?.toString() ?? 'Sin nombre';

              return ListTile(
                title: Text(eventoNombre, style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context, {
                    'id': eventoDoc.id,
                    'nombre': eventoNombre,
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    if (evento != null) {
      setState(() {
        _eventoSeleccionadoId = evento['id']?.isEmpty == true ? null : evento['id'];
        _eventoSeleccionadoNombre = evento['nombre'];
        _sectorSeleccionadoId = null;
        _sectorSeleccionadoNombre = null;
      });
      await _cargarReportesStock();
    }
  }

  Future<void> _seleccionarSector() async {
    if (_eventoSeleccionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Primero selecciona un evento',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final sectoresSnapshot = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(_eventoSeleccionadoId!)
        .collection('sectores')
        .orderBy('nombre')
        .get();

    if (sectoresSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No hay sectores disponibles',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final sector = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text(
          'Seleccionar Sector',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sectoresSnapshot.docs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  title: Text(
                    'Todos los sectores',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(context, {'id': '', 'nombre': 'Todos'});
                  },
                );
              }

              final sectorDoc = sectoresSnapshot.docs[index - 1];
              final sectorData = sectorDoc.data();
              final sectorNombre = sectorData['nombre']?.toString() ?? 'Sin nombre';

              return ListTile(
                title: Text(sectorNombre, style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context, {
                    'id': sectorDoc.id,
                    'nombre': sectorNombre,
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    if (sector != null) {
      setState(() {
        _sectorSeleccionadoId = sector['id']?.isEmpty == true ? null : sector['id'];
        _sectorSeleccionadoNombre = sector['nombre'];
      });
      await _cargarReportesStock();
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _eventoSeleccionadoId = null;
      _eventoSeleccionadoNombre = null;
      _sectorSeleccionadoId = null;
      _sectorSeleccionadoNombre = null;
    });
    _cargarReportesStock();
  }

  Map<String, dynamic> _calcularEstadisticas() {
    int totalProductos = _stockDataFiltrados.length;
    int productosConStockBajo = _stockDataFiltrados
        .where((item) => (item['stock'] as int? ?? 0) < _stockBajoUmbral)
        .length;
    int productosSinStock = _stockDataFiltrados
        .where((item) => (item['stock'] as int? ?? 0) == 0)
        .length;
    int totalStock = _stockDataFiltrados
        .fold(0, (sum, item) => sum + (item['stock'] as int? ?? 0));

    return {
      'totalProductos': totalProductos,
      'productosConStockBajo': productosConStockBajo,
      'productosSinStock': productosSinStock,
      'totalStock': totalStock,
    };
  }

  @override
  Widget build(BuildContext context) {
    final estadisticas = _calcularEstadisticas();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Reportes de Stock',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarReportesStock,
            tooltip: 'Actualizar',
          ),
        ],
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
                          onPressed: _cargarReportesStock,
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
                    // Filtros y búsqueda
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Column(
                        children: [
                          // Filtros de evento y sector
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _seleccionarEvento,
                                  icon: const Icon(Icons.event, size: 18),
                                  label: Text(
                                    _eventoSeleccionadoNombre ?? 'Todos los eventos',
                                    style: GoogleFonts.poppins(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor.withOpacity(0.1),
                                    foregroundColor: primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _seleccionarSector,
                                  icon: const Icon(Icons.location_on, size: 18),
                                  label: Text(
                                    _sectorSeleccionadoNombre ?? 'Todos los sectores',
                                    style: GoogleFonts.poppins(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor.withOpacity(0.1),
                                    foregroundColor: primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                              if (_eventoSeleccionadoId != null ||
                                  _sectorSeleccionadoId != null)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: _limpiarFiltros,
                                  tooltip: 'Limpiar filtros',
                                  color: primaryColor,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                                                     // Búsqueda
                           TextField(
                             controller: _searchController,
                             onChanged: (_) => setState(() {}),
                             decoration: InputDecoration(
                               hintText: 'Buscar producto, evento o sector...',
                               prefixIcon: const Icon(Icons.search),
                               suffixIcon: _searchController.text.isNotEmpty
                                   ? IconButton(
                                       icon: const Icon(Icons.clear),
                                       onPressed: () {
                                         _searchController.clear();
                                         setState(() {});
                                       },
                                     )
                                   : null,
                               border: OutlineInputBorder(
                                 borderRadius: BorderRadius.circular(12),
                               ),
                               filled: true,
                               fillColor: Colors.grey[100],
                             ),
                           ),
                        ],
                      ),
                    ),

                    // Estadísticas
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatCard(
                            icon: Icons.inventory_2,
                            label: 'Total',
                            value: estadisticas['totalProductos'].toString(),
                            color: primaryColor,
                          ),
                          _StatCard(
                            icon: Icons.warning_amber_rounded,
                            label: 'Stock Bajo',
                            value: estadisticas['productosConStockBajo'].toString(),
                            color: Colors.orange,
                          ),
                          _StatCard(
                            icon: Icons.error_outline,
                            label: 'Sin Stock',
                            value: estadisticas['productosSinStock'].toString(),
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ),

                    // Lista de productos
                    Expanded(
                      child: _stockDataFiltrados.isEmpty
                          ? Center(
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
                                      'No hay datos de stock disponibles',
                                      style: GoogleFonts.poppins(
                                        color: secondaryColor,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _stockDataFiltrados.length,
                              itemBuilder: (context, index) {
                                final item = _stockDataFiltrados[index];
                                final stock = item['stock'] as int? ?? 0;
                                final productoNombre = item['productoNombre'] ?? 'Sin nombre';
                                final eventoNombre = item['eventoNombre'] ?? '';
                                final sectorNombre = item['sectorNombre'] ?? '';
                                final precio = item['precio'] as double? ?? 0.0;

                                final isStockBajo = stock < _stockBajoUmbral;
                                final isSinStock = stock == 0;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isSinStock
                                          ? Colors.red
                                          : isStockBajo
                                              ? Colors.orange
                                              : Colors.transparent,
                                      width: isSinStock || isStockBajo ? 2 : 0,
                                    ),
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
                                        color: isSinStock
                                            ? Colors.red.withOpacity(0.1)
                                            : isStockBajo
                                                ? Colors.orange.withOpacity(0.1)
                                                : Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isSinStock
                                            ? Icons.error_outline
                                            : isStockBajo
                                                ? Icons.warning_amber_rounded
                                                : Icons.check_circle_outline,
                                        color: isSinStock
                                            ? Colors.red
                                            : isStockBajo
                                                ? Colors.orange
                                                : Colors.green,
                                        size: 28,
                                      ),
                                    ),
                                    title: Text(
                                      productoNombre,
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
                                          '$eventoNombre - $sectorNombre',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: secondaryColor,
                                          ),
                                        ),
                                        if (precio > 0) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Precio: \$${precio.toStringAsFixed(0)}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: secondaryColor,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Stock',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            color: secondaryColor,
                                          ),
                                        ),
                                        Text(
                                          stock.toString(),
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isSinStock
                                                ? Colors.red
                                                : isStockBajo
                                                    ? Colors.orange
                                                    : Colors.green,
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
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
