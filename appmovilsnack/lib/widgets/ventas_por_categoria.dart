// Estimación por categoría según cierres de inventario (stock inicial − stock final)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/core/app_theme.dart';
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
  int _totalCierres = 0;
  double _montoTotal = 0;

  static const List<Color> _coloresGrafico = [
    AppColors.accent,
    AppColors.secondary,
    Color(0xFF8B4513),
    Color(0xFFCD853F),
    Color(0xFFA0522D),
    Color(0xFFBC8F8F),
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  String _catKey(String? cat) {
    final c = cat?.trim();
    if (c == null || c.isEmpty) return categoriaDefault;
    return categoriasProducto.contains(c) ? c : categoriaDefault;
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
      if (_categorias.isEmpty) {
        _categorias = categoriasProductoDefault
            .map((c) => {'nombre': c, 'icono': ''})
            .toList();
      }

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

      // Cache categoría por productoId (catálogo global)
      final productosSnap =
          await FirebaseFirestore.instance.collection('productos').get();
      final Map<String, String> catPorProducto = {
        for (final doc in productosSnap.docs)
          doc.id: _catKey(doc.data()['categoria']?.toString()),
      };

      double montoTotal = 0;
      int cierres = 0;

      final eventosSnap =
          await FirebaseFirestore.instance.collection('eventos').get();

      for (final eventoDoc in eventosSnap.docs) {
        final sectoresSnap = await eventoDoc.reference
            .collection('sectores')
            .get();

        for (final sectorDoc in sectoresSnap.docs) {
          final sectorData = sectorDoc.data();
          final cierre = sectorData['ultimoCierre'];
          if (cierre is! Map<String, dynamic>) continue;

          cierres++;
          final productos = cierre['productos'] as List<dynamic>? ?? [];

          for (final raw in productos) {
            if (raw is! Map) continue;
            final m = Map<String, dynamic>.from(raw);

            final vendido = (m['cantidadVendida'] as int?) ??
                (((m['cantidadInicial'] as int?) ?? 0) -
                    ((m['cantidadFinal'] as int?) ?? 0));
            if (vendido <= 0) continue;

            final precio = (m['precio'] as num?)?.toDouble() ?? 0;
            final subtotal = (m['subtotal'] as num?)?.toDouble() ??
                (vendido * precio);
            if (subtotal <= 0) continue;

            final productoId = m['productoId']?.toString() ?? '';
            final key = _catKey(
              m['categoria']?.toString() ??
                  (productoId.isNotEmpty ? catPorProducto[productoId] : null),
            );

            montoCat[key] = (montoCat[key] ?? 0) + subtotal;
            cantCat[key] = (cantCat[key] ?? 0) + vendido;
            montoTotal += subtotal;
          }
        }
      }

      if (mounted) {
        setState(() {
          _montoPorCategoria = montoCat;
          _cantidadPorCategoria = cantCat;
          _totalCierres = cierres;
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
    final ordenCategorias = <String>[
      ..._categorias.map((e) => e['nombre'] ?? '').where((s) => s.isNotEmpty),
    ];
    if (!ordenCategorias.contains(categoriaDefault)) {
      ordenCategorias.add(categoriaDefault);
    }

    final listaConMonto = <MapEntry<String, double>>[];
    for (final cat in ordenCategorias) {
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
            Icon(
              Icons.pie_chart_outline,
              size: 64,
              color: AppColors.secondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Sin cierres de inventario aún',
              style: GoogleFonts.poppins(
                color: AppColors.secondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Los datos aparecen al cerrar turno con stock inicial y final.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppColors.secondary.withValues(alpha: 0.85),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

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
                    'Total estimado',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '\$${_montoTotal.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryLight,
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
                    border: Border.all(
                      color: AppColors.primaryLight.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  e.key,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w500,
                  ),
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Ventas por categoría',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
        ),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.accent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _cargar,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
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
                        color: AppColors.accent.withValues(alpha: 0.15),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                'Total estimado (inventario)',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.secondary,
                                ),
                              ),
                              Text(
                                '\$${_montoTotal.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                              Text(
                                '$_totalCierres sectores con cierre registrado',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.secondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Calculado: stock inicial − stock final por producto',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.secondary.withValues(alpha: 0.9),
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
                          color: AppColors.primaryLight,
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
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._categorias.map((e) {
                        final cat = e['nombre'] ?? '';
                        if (cat.isEmpty) return const SizedBox.shrink();
                        final monto = _montoPorCategoria[cat] ?? 0;
                        final cant = _cantidadPorCategoria[cat] ?? 0;
                        final pct =
                            _montoTotal > 0 ? (monto / _montoTotal * 100) : 0.0;
                        final icono = e['icono'] ?? '';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.accent.withValues(alpha: 0.2),
                              child: Icon(
                                icono.isNotEmpty
                                    ? iconoCategoriaConIcono(icono)
                                    : iconoCategoria(cat),
                                color: AppColors.secondary,
                              ),
                            ),
                            title: Text(
                              cat,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '\$${monto.toStringAsFixed(0)} · $cant u. · ${pct.toStringAsFixed(1)}%',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.secondary,
                              ),
                            ),
                            trailing: Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      }),
                      if ((_montoPorCategoria[categoriaDefault] ?? 0) > 0 &&
                          !_categorias.any(
                            (e) => (e['nombre'] ?? '') == categoriaDefault,
                          ))
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.accent.withValues(alpha: 0.2),
                              child: Icon(
                                iconoCategoria(categoriaDefault),
                                color: AppColors.secondary,
                              ),
                            ),
                            title: Text(
                              categoriaDefault,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '\$${(_montoPorCategoria[categoriaDefault] ?? 0).toStringAsFixed(0)} · '
                              '${_cantidadPorCategoria[categoriaDefault] ?? 0} u.',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.secondary,
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
