// Estadísticas de ventas por categoría (Bebestibles, Snacks, Masas, Galletas, Otros)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:front_appsnack/utils/categorias_producto.dart';

class VentasPorCategoria extends StatefulWidget {
  const VentasPorCategoria({super.key});

  @override
  State<VentasPorCategoria> createState() => _VentasPorCategoriaState();
}

class _VentasPorCategoriaState extends State<VentasPorCategoria> {
  bool _loading = true;
  String? _error;
  Map<String, double> _montoPorCategoria = {};
  Map<String, int> _cantidadPorCategoria = {};
  List<Map<String, String>> _categorias = [];
  int _totalTransacciones = 0;
  double _montoTotal = 0;

  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);

  /// Colores para cada porción del gráfico circular (por índice)
  static const List<Color> _coloresGrafico = [
    Color(0xFFDABF41), // dorado - Bebestibles
    Color(0xFF6B4D2F), // marrón - Snacks
    Color(0xFF8B4513), // saddle brown - Masas
    Color(0xFFCD853F), // peru - Galletas
    Color(0xFFA0522D), // sienna - Otros
    Color(0xFFBC8F8F), // rosy brown - extra
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
      _montoPorCategoria = {};
      _cantidadPorCategoria = {};
    });
    try {
      _categorias = await cargarCategoriasFirestore();
      final nombresCat = _categorias.map((e) => e['nombre'] ?? '').where((s) => s.isNotEmpty).toList();
      if (nombresCat.isEmpty) _categorias = categoriasProductoDefault.map((c) => {'nombre': c, 'icono': ''}).toList();

      final snap = await FirebaseFirestore.instance
          .collection('transacciones')
          .get();
      double montoTotal = 0;
      int countTrans = 0;
      final Map<String, double> montoCat = {};
      final Map<String, int> cantCat = {};
      for (final e in _categorias) {
        final c = e['nombre'] ?? '';
        if (c.isNotEmpty) {
          montoCat[c] = 0;
          cantCat[c] = 0;
        }
      }
      montoCat[categoriaDefault] = 0;
      cantCat[categoriaDefault] = 0;

      for (final doc in snap.docs) {
        final d = doc.data();
        countTrans++;
        final monto = (d['montoTotal'] as num?)?.toDouble() ?? 0;
        montoTotal += monto;
        final items = d['items'] as List<dynamic>?;
        if (items != null) {
          for (final it in items) {
            final map = it as Map<String, dynamic>?;
            if (map == null) continue;
            final cat = map['categoria']?.toString() ?? categoriaDefault;
            final key = categoriasProducto.contains(cat) ? cat : categoriaDefault;
            final precio = (map['precio'] as num?)?.toDouble() ?? 0;
            final cantidad = (map['cantidad'] as int?) ?? 0;
            final subtotal = precio * cantidad;
            montoCat[key] = (montoCat[key] ?? 0) + subtotal;
            cantCat[key] = (cantCat[key] ?? 0) + cantidad;
          }
        }
      }

      if (mounted) {
        setState(() {
          _montoPorCategoria = montoCat;
          _cantidadPorCategoria = cantCat;
          _totalTransacciones = countTrans;
          _montoTotal = montoTotal;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Widget _buildGraficoCircular() {
    // Orden fijo: categorías de la lista + Otros al final (mismo orden que la lista de abajo)
    final ordenCategorias = <String>[
      ..._categorias.map((e) => e['nombre'] ?? '').where((s) => s.isNotEmpty),
    ];
    if (!ordenCategorias.contains(categoriaDefault)) ordenCategorias.add(categoriaDefault);

    final listaConMonto = <MapEntry<String, double>>[];
    for (var i = 0; i < ordenCategorias.length; i++) {
      final cat = ordenCategorias[i];
      final monto = _montoPorCategoria[cat] ?? 0;
      if (monto > 0) listaConMonto.add(MapEntry(cat, monto));
    }

    if (listaConMonto.isEmpty || _montoTotal <= 0) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline, size: 64, color: secondaryColor.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(
              'Sin ventas por categoría aún',
              style: GoogleFonts.poppins(color: secondaryColor, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Color por índice en orden fijo (para que coincida con la leyenda)
    int colorIndex = 0;
    final secciones = <PieChartSectionData>[];
    final leyenda = <MapEntry<String, Color>>[];
    for (final cat in ordenCategorias) {
      final monto = _montoPorCategoria[cat] ?? 0;
      if (monto <= 0) continue;
      final color = _coloresGrafico[colorIndex % _coloresGrafico.length];
      final pct = (monto / _montoTotal * 100).toStringAsFixed(1);
      secciones.add(
        PieChartSectionData(
          value: monto,
          title: '$pct%',
          color: color,
          radius: 72,
          titleStyle: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          titlePositionPercentageOffset: 0.55,
        ),
      );
      leyenda.add(MapEntry(cat, color));
      colorIndex++;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 42,
                  sections: secciones,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: secondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '\$${_montoTotal.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: leyenda.map((e) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: e.value,
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withOpacity(0.3), width: 1),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  e.key,
                  style: GoogleFonts.poppins(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w500),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: Text(
          'Ventas por categoría',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: accentColor),
        ),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _cargar,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error: $_error',
                      style: GoogleFonts.poppins(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        color: accentColor.withOpacity(0.15),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                'Total ventas',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: secondaryColor,
                                ),
                              ),
                              Text(
                                '\$${_montoTotal.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              Text(
                                '$_totalTransacciones transacciones',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Distribución por categoría',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildGraficoCircular(),
                      const SizedBox(height: 24),
                      Text(
                        'Detalle por categoría',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._categorias.map((e) {
                        final cat = e['nombre'] ?? '';
                        if (cat.isEmpty) return const SizedBox.shrink();
                        final monto = _montoPorCategoria[cat] ?? 0;
                        final cant = _cantidadPorCategoria[cat] ?? 0;
                        final pct = _montoTotal > 0 ? (monto / _montoTotal * 100) : 0.0;
                        final icono = e['icono'] ?? '';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: accentColor.withOpacity(0.2),
                              child: Icon(
                                icono.isNotEmpty ? iconoCategoriaConIcono(icono) : iconoCategoria(cat),
                                color: secondaryColor,
                              ),
                            ),
                            title: Text(
                              cat,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '\$${monto.toStringAsFixed(0)} · $cant ítems · ${pct.toStringAsFixed(1)}%',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: secondaryColor,
                              ),
                            ),
                            trailing: Text(
                              '\$${monto.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      }),
                      if ((_montoPorCategoria[categoriaDefault] ?? 0) > 0)
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: accentColor.withOpacity(0.2),
                              child: Icon(iconoCategoria(categoriaDefault), color: secondaryColor),
                            ),
                            title: Text(
                              categoriaDefault,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '\$${(_montoPorCategoria[categoriaDefault] ?? 0).toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(fontSize: 13, color: secondaryColor),
                            ),
                            trailing: Text(
                              '\$${(_montoPorCategoria[categoriaDefault] ?? 0).toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
