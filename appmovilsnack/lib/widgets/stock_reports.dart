// Archivo: lib/widgets/stock_reports.dart
// Reportes de Stock - Monitoreo de niveles de stock

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';
import 'package:front_appsnack/core/tipografia.dart';
import 'package:front_appsnack/core/margen_inferior.dart';
import 'package:front_appsnack/core/app_theme.dart';

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

  final Color primaryColor = AppColors.primaryLight;
  final Color accentColor = AppColors.accent;
  final Color secondaryColor = AppColors.secondary;
  final Color backgroundColor = AppColors.surface;

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
        if (_eventoSeleccionadoId != null &&
            _eventoSeleccionadoId != eventoId) {
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
          if (_sectorSeleccionadoId != null &&
              _sectorSeleccionadoId != sectorId) {
            continue;
          }

          // Obtener el stock del sector
          final stockSnapshot = await FirebaseFirestore.instance
              .collection('eventos')
              .doc(eventoId)
              .collection('sectores')
              .doc(sectorId)
              .collection('stock')
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
              'stock': stockInfo['cantidad'] as int? ?? 0,
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
          final productoNombre =
              item['productoNombre']?.toString().toLowerCase() ?? '';
          final eventoNombre =
              item['eventoNombre']?.toString().toLowerCase() ?? '';
          final sectorNombre =
              item['sectorNombre']?.toString().toLowerCase() ?? '';

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

    if (!mounted) return;
    if (eventosSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay eventos disponibles', style: AppFonts.inter()),
          backgroundColor: AppColors.avisoFuerte,
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
          style: AppFonts.inter(
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
                    style: AppFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(context, {'id': '', 'nombre': 'Todos'});
                  },
                );
              }

              final eventoDoc = eventosSnapshot.docs[index - 1];
              final eventoData = eventoDoc.data();
              final eventoNombre =
                  eventoData['nombre']?.toString() ?? 'Sin nombre';

              return ListTile(
                title: Text(eventoNombre, style: AppFonts.inter()),
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

    if (!mounted) return;
    if (evento != null) {
      setState(() {
        _eventoSeleccionadoId = evento['id']?.isEmpty == true
            ? null
            : evento['id'];
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
            'Primero seleccione un evento',
            style: AppFonts.inter(),
          ),
          backgroundColor: AppColors.avisoFuerte,
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

    if (!mounted) return;
    if (sectoresSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay sectores disponibles', style: AppFonts.inter()),
          backgroundColor: AppColors.avisoFuerte,
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
          style: AppFonts.inter(
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
                    style: AppFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(context, {'id': '', 'nombre': 'Todos'});
                  },
                );
              }

              final sectorDoc = sectoresSnapshot.docs[index - 1];
              final sectorData = sectorDoc.data();
              final sectorNombre =
                  sectorData['nombre']?.toString() ?? 'Sin nombre';

              return ListTile(
                title: Text(sectorNombre, style: AppFonts.inter()),
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

    if (!mounted) return;
    if (sector != null) {
      setState(() {
        _sectorSeleccionadoId = sector['id']?.isEmpty == true
            ? null
            : sector['id'];
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
    int totalStock = _stockDataFiltrados.fold(
      0,
      (total, item) => total + (item['stock'] as int? ?? 0),
    );

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
          'Stock por sector',
          style: AppFonts.inter(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarReportesStock,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppFonts.inter(
                        color: secondaryColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _cargarReportesStock,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dorado,
                        foregroundColor: AppColors.negro,
                      ),
                      child: Text(
                        'Reintentar',
                        style: AppFonts.inter(fontWeight: FontWeight.bold),
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
                  color: AppColors.tarjeta,
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
                                _eventoSeleccionadoNombre ??
                                    'Todos los eventos',
                                style: AppFonts.inter(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor.withValues(
                                  alpha: 0.1,
                                ),
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
                                _sectorSeleccionadoNombre ??
                                    'Todos los sectores',
                                style: AppFonts.inter(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor.withValues(
                                  alpha: 0.1,
                                ),
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
                          fillColor: AppColors.tarjetaAlta,
                        ),
                      ),
                    ],
                  ),
                ),

                // Estadísticas
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.tarjeta,
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
                        color: AppColors.aviso,
                      ),
                      _StatCard(
                        icon: Icons.error_outline,
                        label: 'Sin Stock',
                        value: estadisticas['productosSinStock'].toString(),
                        color: AppColors.error,
                      ),
                    ],
                  ),
                ),

                // Lista de productos
                Expanded(
                  child: _stockDataFiltrados.isEmpty
                      ? EstadoVacio(titulo: 'No hay datos de stock disponibles')
                      : ListView.builder(
                          padding: conMargenInferior(
                            context,
                            const EdgeInsets.all(16),
                          ),
                          itemCount: _stockDataFiltrados.length,
                          itemBuilder: (context, index) {
                            final item = _stockDataFiltrados[index];
                            final stock = item['stock'] as int? ?? 0;
                            final productoNombre =
                                item['productoNombre'] ?? 'Sin nombre';
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
                                      ? AppColors.error
                                      : isStockBajo
                                      ? AppColors.aviso
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
                                        ? AppColors.error.withValues(alpha: 0.1)
                                        : isStockBajo
                                        ? AppColors.aviso.withValues(alpha: 0.1)
                                        : AppColors.exito.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isSinStock
                                        ? Icons.error_outline
                                        : isStockBajo
                                        ? Icons.warning_amber_rounded
                                        : Icons.check_circle_outline,
                                    color: isSinStock
                                        ? AppColors.error
                                        : isStockBajo
                                        ? AppColors.aviso
                                        : AppColors.exito,
                                    size: 28,
                                  ),
                                ),
                                title: Text(
                                  productoNombre,
                                  style: AppFonts.inter(
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
                                      style: AppFonts.inter(
                                        fontSize: 14,
                                        color: secondaryColor,
                                      ),
                                    ),
                                    if (precio > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Precio: \$${precio.toStringAsFixed(0)}',
                                        style: AppFonts.inter(
                                          fontSize: 14,
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
                                      style: AppFonts.inter(
                                        fontSize: 14,
                                        color: secondaryColor,
                                      ),
                                    ),
                                    Text(
                                      stock.toString(),
                                      style: AppFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isSinStock
                                            ? AppColors.error
                                            : isStockBajo
                                            ? AppColors.aviso
                                            : AppColors.exito,
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
          style: AppFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppFonts.inter(fontSize: 14, color: AppColors.tintaSecundaria),
        ),
      ],
    );
  }
}
