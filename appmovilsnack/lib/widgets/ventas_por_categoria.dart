// Ventas por categoría: cierres de turno + bandejeo (eventos activos).
import 'package:flutter/material.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:front_appsnack/services/admin_estadisticas_service.dart';
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

  String _fmtMonto(num valor) {
    final s = valor.round().abs().toString();
    final neg = valor < 0;
    final buf = StringBuffer(neg ? '-' : '');
    for (int i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final resto = s.length - i - 1;
      if (resto > 0 && resto % 3 == 0) buf.write('.');
    }
    return buf.toString();
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

      final resumen =
          await AdminEstadisticasService.cargarVentasPorCategoria(
        soloEventosActivos: true,
      );

      for (final entry in resumen.montoPorCategoria.entries) {
        montoCat[entry.key] = (montoCat[entry.key] ?? 0) + entry.value;
      }
      for (final entry in resumen.cantidadPorCategoria.entries) {
        cantCat[entry.key] = (cantCat[entry.key] ?? 0) + entry.value;
      }

      if (mounted) {
        setState(() {
          _montoPorCategoria = montoCat;
          _cantidadPorCategoria = cantCat;
          _totalCierres = resumen.totalCierres;
          _montoTotal = resumen.montoTotal;
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
              'Sin ventas registradas en eventos activos aún',
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
    final leyenda = <({String cat, Color color, double monto, double pct})>[];
    for (final cat in ordenCategorias) {
      final monto = _montoPorCategoria[cat] ?? 0;
      if (monto <= 0) continue;
      final color = _coloresGrafico[colorIndex % _coloresGrafico.length];
      final pct = monto / _montoTotal * 100;
      secciones.add(
        PieChartSectionData(
          value: monto,
          color: color,
          radius: 44,
          showTitle: false,
        ),
      );
      leyenda.add((cat: cat, color: color, monto: monto, pct: pct));
      colorIndex++;
    }

    leyenda.sort((a, b) => b.monto.compareTo(a.monto));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1.35,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final lado = constraints.maxWidth.clamp(160.0, 280.0);
              final hueco = lado * 0.34;
              return Center(
                child: SizedBox(
                  width: lado,
                  height: lado,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: hueco,
                          sections: secciones,
                        ),
                      ),
                      SizedBox(
                        width: hueco * 1.75,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total estimado',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '\$${_fmtMonto(_montoTotal)}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryLight,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        ...leyenda.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: e.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.cat,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${e.pct.toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '\$${_fmtMonto(e.monto)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryLight,
                  ),
                ),
              ],
            ),
          );
        }),
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
                                '\$${_fmtMonto(_montoTotal)}',
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
                                'Cierres de turno y ventas de bandejeo (eventos activos)',
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
                              '\$${_fmtMonto(monto)} · $cant u. · ${pct.toStringAsFixed(1)}%',
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
                              '\$${_fmtMonto(_montoPorCategoria[categoriaDefault] ?? 0)} · '
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
