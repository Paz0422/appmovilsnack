// Ventas por categoría: cierres de turno + bandejeo (eventos activos).
import 'package:flutter/material.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/core/tipografia.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:front_appsnack/services/admin_estadisticas_service.dart';
import 'package:front_appsnack/utils/categorias_producto.dart';
import 'package:front_appsnack/core/margen_inferior.dart';
import 'package:front_appsnack/widgets/comunes/cargando.dart';
import 'package:front_appsnack/core/animaciones.dart';
import 'package:front_appsnack/widgets/comunes/animados.dart';
import 'package:front_appsnack/widgets/graficos_admin.dart';
import 'package:front_appsnack/core/precio.dart';

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

  /// Colores de la serie de gráficos del tema (el primero, el de la marca).
  static const List<Color> _coloresGrafico = [...AppColors.grafico, AppColors.cafe];

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

      final resumen = await AdminEstadisticasService.cargarVentasPorCategoria(
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
              style: AppFonts.inter(color: AppColors.secondary, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Los datos aparecen al cerrar turno con stock inicial y final.',
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                color: AppColors.secondary.withValues(alpha: 0.85),
                fontSize: 14,
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
          radius: 48,
          showTitle: false,
          // Separa los sectores con el color de la tarjeta.
          borderSide: const BorderSide(color: AppColors.tarjeta, width: 2),
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
                      ProgresoEntrada(
                        duracion: const Duration(milliseconds: 1200),
                        curva: Curves.easeOutCubic,
                        builder: (t) => PieChart(
                          swapAnimationDuration: Duration.zero,
                          PieChartData(
                            startDegreeOffset: -90,
                            sectionsSpace: t < 1 ? 0 : 3,
                            centerSpaceRadius: hueco,
                            sections: [
                              ...secciones,
                              ?seccionDibujo(
                                total: _montoTotal,
                                avance: t,
                                radio: 48,
                              ),
                            ],
                          ),
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
                              style: AppFonts.inter(
                                fontSize: 14,
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: CifraAnimada(
                                valor: _montoTotal,
                                formatear: formatearPesos,
                                textAlign: TextAlign.center,
                                style: AppFonts.inter(
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
        ...leyenda.indexed.map((par) {
          final (i, e) = par;
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
                    style: AppFonts.inter(
                      fontSize: 14,
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${e.pct.toStringAsFixed(1)}%',
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatearPesos(e.monto),
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryLight,
                  ),
                ),
              ],
            ),
          ).entradaLateral(orden: i + 3);
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
          style: AppFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _cargar,
          ),
        ],
      ),
      body: _loading
          ? const CargandoTarjetas()
          : _error != null
          ? ErrorAmable(
              titulo: 'No pudimos cargar las ventas',
              detalle: 'Error: $_error',
              onReintentar: _cargar,
            )
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: conMargenInferior(context, const EdgeInsets.all(16)),
                children: [
                  Card(
                    color: AppColors.doradoSuave,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      side: BorderSide(
                        color: AppColors.cafe.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Total estimado (inventario)',
                            style: AppFonts.inter(
                              fontSize: 14,
                              color: AppColors.secondary,
                            ),
                          ),
                          CifraAnimada(
                            valor: _montoTotal,
                            formatear: formatearPesos,
                            style: AppFonts.inter(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: AppColors.dorado,
                            ),
                          ),
                          Text(
                            '$_totalCierres sectores con cierre registrado',
                            style: AppFonts.inter(
                              fontSize: 14,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Cierres de turno y ventas de bandejeo (eventos activos)',
                            textAlign: TextAlign.center,
                            style: AppFonts.inter(
                              fontSize: 14,
                              color: AppColors.secondary.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).entrada(),
                  const SizedBox(height: 24),
                  const TituloSeccion(
                    icono: Icons.pie_chart_outline_rounded,
                    titulo: 'Distribución por categoría',
                  ).entrada(orden: 1),
                  const SizedBox(height: 16),
                  _buildGraficoCircular(),
                  const SizedBox(height: 24),
                  const TituloSeccion(
                    icono: Icons.list_alt_rounded,
                    titulo: 'Detalle por categoría',
                  ).entrada(orden: 2),
                  const SizedBox(height: 12),
                  ..._categorias.indexed.map((par) {
                    final (i, e) = par;
                    final cat = e['nombre'] ?? '';
                    if (cat.isEmpty) return const SizedBox.shrink();
                    final monto = _montoPorCategoria[cat] ?? 0;
                    final cant = _cantidadPorCategoria[cat] ?? 0;
                    final pct = _montoTotal > 0
                        ? (monto / _montoTotal * 100)
                        : 0.0;
                    final icono = e['icono'] ?? '';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accent.withValues(
                            alpha: 0.2,
                          ),
                          child: Icon(
                            icono.isNotEmpty
                                ? iconoCategoriaConIcono(icono)
                                : iconoCategoria(cat),
                            color: AppColors.secondary,
                          ),
                        ),
                        title: Text(
                          cat,
                          style: AppFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${formatearPesos(monto)} · $cant u. · ${pct.toStringAsFixed(1)}%',
                              style: AppFonts.inter(
                                fontSize: 14,
                                color: AppColors.secondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _BarraPorcentaje(fraccion: pct / 100),
                          ],
                        ),
                        trailing: Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: AppFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryLight,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ).entradaEnLista(i + 3);
                  }),
                  if ((_montoPorCategoria[categoriaDefault] ?? 0) > 0 &&
                      !_categorias.any(
                        (e) => (e['nombre'] ?? '') == categoriaDefault,
                      ))
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accent.withValues(
                            alpha: 0.2,
                          ),
                          child: Icon(
                            iconoCategoria(categoriaDefault),
                            color: AppColors.secondary,
                          ),
                        ),
                        title: Text(
                          categoriaDefault,
                          style: AppFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${formatearPesos(_montoPorCategoria[categoriaDefault] ?? 0)} · '
                          '${_cantidadPorCategoria[categoriaDefault] ?? 0} u.',
                          style: AppFonts.inter(
                            fontSize: 14,
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

/// Barra fina dorado → café que crece hasta el porcentaje de la categoría.
class _BarraPorcentaje extends StatelessWidget {
  const _BarraPorcentaje({required this.fraccion});

  final double fraccion;

  @override
  Widget build(BuildContext context) {
    final destino = fraccion.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          Container(height: 6, color: AppColors.tarjetaAlta),
          ProgresoEntrada(
            duracion: const Duration(milliseconds: 1000),
            curva: Curves.easeOutCubic,
            builder: (t) => FractionallySizedBox(
              widthFactor: destino * t,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: AppGradientes.marca,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
