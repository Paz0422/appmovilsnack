// Panel › Reportes: dashboard con los gráficos de cada reporte. Cada tarjeta
// tiene "Ver detalle" para abrir el reporte completo.
import 'package:flutter/material.dart';
import 'package:front_appsnack/core/animaciones.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/core/margen_inferior.dart';
import 'package:front_appsnack/core/precio.dart';
import 'package:front_appsnack/core/tipografia.dart';
import 'package:front_appsnack/services/reportes_service.dart';
import 'package:front_appsnack/widgets/comunes/animados.dart';
import 'package:front_appsnack/widgets/comunes/cargando.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';
import 'package:front_appsnack/widgets/dashboard_card.dart';
import 'package:front_appsnack/widgets/graficos_admin.dart';
import 'package:front_appsnack/widgets/ranking_vendedores.dart';
import 'package:front_appsnack/widgets/reporte_diferencias_traspaso.dart';
import 'package:front_appsnack/widgets/reporte_mermas.dart';
import 'package:front_appsnack/widgets/stock_reports.dart';
import 'package:front_appsnack/widgets/ventas_por_categoria.dart';

class DashboardReportesAdmin extends StatefulWidget {
  const DashboardReportesAdmin({super.key, required this.abrir, this.cargar});

  /// Abre el reporte completo y termina al volver. Viene de HomeAdmin.
  final Future<void> Function(Widget Function() pantalla) abrir;

  /// Solo para tests: reemplaza la carga desde Firestore.
  @visibleForTesting
  final Future<DashboardReportes> Function()? cargar;

  @override
  State<DashboardReportesAdmin> createState() => _DashboardReportesAdminState();
}

class _DashboardReportesAdminState extends State<DashboardReportesAdmin> {
  late Future<DashboardReportes> _datos;

  @override
  void initState() {
    super.initState();
    _datos = _cargar();
  }

  Future<DashboardReportes> _cargar() =>
      (widget.cargar ?? ReportesService.cargarDashboard)();

  void _recargar() => setState(() => _datos = _cargar());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _recargar,
          ),
        ],
      ),
      body: FutureBuilder<DashboardReportes>(
        future: _datos,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorAmable(
              titulo: 'No pudimos cargar los reportes',
              detalle: '${snap.error}',
              onReintentar: _recargar,
            );
          }
          if (!snap.hasData) {
            return const CargandoTarjetas(cantidad: 5, alto: 120);
          }
          return RefreshIndicator(
            onRefresh: () async {
              _recargar();
              await _datos;
            },
            child: _Tablero(datos: snap.data!, abrir: widget.abrir),
          );
        },
      ),
    );
  }
}

class _Tablero extends StatelessWidget {
  const _Tablero({required this.datos, required this.abrir});

  final DashboardReportes datos;
  final Future<void> Function(Widget Function() pantalla) abrir;

  Widget _verDetalle(String que, Widget Function() pantalla) => TextButton.icon(
    onPressed: () => abrir(pantalla),
    icon: const Icon(Icons.open_in_new_rounded, size: 18),
    label: Text(que),
  );

  @override
  Widget build(BuildContext context) {
    final s = datos.sectores;
    final tarjetas = <Widget>[
      _categorias(),
      _mermas(),
      _stock(),
      _ranking(),
      _diferencias(),
    ];

    return ListView(
      padding: conMargenInferior(context, const EdgeInsets.fromLTRB(16, 8, 16, 24)),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Partidos activos · ranking del año',
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tintaSecundaria,
                  ),
                ).entrada(),
                const SizedBox(height: 12),
                _Cifras(
                  cifras: [
                    (
                      'Pérdida por mermas',
                      s.mermasEnDinero
                          ? formatearPesos(s.valorPerdido)
                          : '${s.unidadesPerdidas} u.',
                      s.mermasEnDinero ? s.valorPerdido : s.unidadesPerdidas.toDouble(),
                      s.mermasEnDinero
                          ? formatearPesos
                          : (double v) => '${v.round()} u.',
                      Icons.remove_circle_outline,
                      AppColors.coral,
                    ),
                    (
                      'Unidades en stock',
                      separarMiles(s.stockPorSector.fold(0, (t, x) => t + x.unidades)),
                      s.stockPorSector.fold(0, (t, x) => t + x.unidades).toDouble(),
                      separarMiles,
                      Icons.inventory_2_outlined,
                      AppColors.cian,
                    ),
                    (
                      'Productos sin stock',
                      '${s.productosSinStock}',
                      s.productosSinStock.toDouble(),
                      (double v) => '${v.round()}',
                      Icons.production_quantity_limits_rounded,
                      AppColors.aviso,
                    ),
                    (
                      'Faltantes en traspasos',
                      '${s.unidadesFaltantes} u.',
                      s.unidadesFaltantes.toDouble(),
                      (double v) => '${v.round()} u.',
                      Icons.sync_problem_rounded,
                      AppColors.violeta,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Dos tarjetas por fila en pantallas anchas; una en teléfono.
                LayoutBuilder(
                  builder: (context, c) {
                    if (c.maxWidth < 760) {
                      return Column(
                        children: [
                          for (final (i, t) in tarjetas.indexed) ...[
                            if (i > 0) const SizedBox(height: 16),
                            t.entrada(orden: i + 2),
                          ],
                        ],
                      );
                    }
                    return Column(
                      children: [
                        for (var i = 0; i < tarjetas.length; i += 2) ...[
                          if (i > 0) const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: tarjetas[i].entrada(orden: i + 2)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: i + 1 < tarjetas.length
                                    ? tarjetas[i + 1].entrada(orden: i + 3)
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _vacio(String texto) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      texto,
      style: AppFonts.inter(fontSize: 15, color: AppColors.tintaSecundaria),
    ),
  );

  Widget _categorias() {
    final c = datos.categorias;
    final partes = c.montoPorCategoria.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return TarjetaGrafico(
      titulo: 'Ventas por categoría',
      subtitulo: 'Qué tipo de producto se vende más',
      accion: _verDetalle('Ver detalle', () => const VentasPorCategoria()),
      child: partes.isEmpty
          ? _vacio('Aún no hay ventas en los partidos activos')
          : GraficoDona(
              formatear: formatearPesos,
              textoCentro: abreviarMonto(c.montoTotal),
              partes: [
                for (final (i, e) in partes.take(6).indexed)
                  (
                    etiqueta: e.key,
                    monto: e.value,
                    color: AppColors.grafico[i % AppColors.grafico.length],
                  ),
              ],
            ),
    );
  }

  Widget _mermas() {
    final s = datos.sectores;
    final formato = s.mermasEnDinero
        ? formatearPesos
        : (double v) => '${v.round()} u.';
    return TarjetaGrafico(
      titulo: 'Mermas',
      subtitulo: s.mermasEnDinero
          ? 'Productos con más pérdida, en dinero'
          : 'Productos con más pérdida, en unidades',
      accion: _verDetalle('Ver detalle', () => const ReporteMermas()),
      child: s.perdidaPorProducto.isEmpty
          ? _vacio('Sin mermas registradas. ¡Bien!')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RankingBarras(
                  formatear: formato,
                  items: [
                    for (final p in s.perdidaPorProducto.take(5))
                      (nombre: p.nombre, detalle: null, monto: p.monto),
                  ],
                ),
                if (s.perdidaPorMotivo.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in s.perdidaPorMotivo.take(4))
                        EtiquetaCafe(
                          icono: Icons.label_outline_rounded,
                          texto: '${m.nombre}: ${formato(m.monto)}',
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Widget _stock() {
    final s = datos.sectores;
    return TarjetaGrafico(
      titulo: 'Stock por sector',
      subtitulo: 'Unidades que quedan en cada puesto',
      accion: _verDetalle('Ver detalle', () => const StockReports()),
      child: s.stockPorSector.isEmpty
          ? _vacio('Aún no hay stock cargado en los partidos activos')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GraficoBarras(
                  formatear: (v) => '${separarMiles(v)} u.',
                  items: [
                    for (final x in s.stockPorSector.take(6))
                      (nombre: x.nombre, monto: x.unidades.toDouble()),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Alerta(
                      texto: '${s.productosBajos} con stock bajo '
                          '(≤ ${ReportesService.umbralStockBajo})',
                      color: AppColors.avisoTexto,
                      fondo: AppColors.avisoSuave,
                      icono: Icons.trending_down_rounded,
                    ),
                    _Alerta(
                      texto: '${s.productosSinStock} sin stock',
                      color: AppColors.error,
                      fondo: AppColors.errorSuave,
                      icono: Icons.remove_shopping_cart_outlined,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _ranking() {
    final top = datos.ranking.take(5).toList();
    return TarjetaGrafico(
      titulo: 'Ranking de vendedores',
      subtitulo: 'Monto vendido este año en cierres de turno',
      accion: _verDetalle('Ver ranking', () => const RankingVendedores()),
      child: top.isEmpty
          ? _vacio('Aún no hay cierres este año')
          : RankingBarras(
              formatear: formatearPesos,
              items: [
                for (final v in top)
                  (
                    nombre: v.nombre,
                    detalle:
                        '${v.cierresAnio} cierre${v.cierresAnio == 1 ? '' : 's'}',
                    monto: v.montoAnio,
                  ),
              ],
            ),
    );
  }

  Widget _diferencias() {
    final s = datos.sectores;
    final hay = s.traspasosIncompletos > 0;
    return TarjetaGrafico(
      titulo: 'Diferencias en traspasos',
      subtitulo: 'Traspasos que llegaron con menos unidades',
      accion: _verDetalle(
        'Ver detalle',
        () => const ReporteDiferenciasTraspaso(),
      ),
      child: !hay
          ? Row(
              children: [
                const Icon(Icons.verified_rounded, color: AppColors.exito)
                    .aparicionRebote(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Todos los traspasos llegaron completos',
                    style: AppFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.tinta,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _Dato(
                    valor: '${s.traspasosIncompletos}',
                    etiqueta:
                        'traspaso${s.traspasosIncompletos == 1 ? '' : 's'} incompleto${s.traspasosIncompletos == 1 ? '' : 's'}',
                  ),
                ),
                Expanded(
                  child: _Dato(
                    valor: '${s.unidadesFaltantes}',
                    etiqueta: 'unidades faltantes',
                  ),
                ),
                if (s.valorFaltante > 0)
                  Expanded(
                    child: _Dato(
                      valor: formatearPesos(s.valorFaltante),
                      etiqueta: 'valor estimado',
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Las cuatro cifras de arriba: 2 × 2 en teléfono, en una fila en tablet.
class _Cifras extends StatelessWidget {
  const _Cifras({required this.cifras});

  final List<
    (String, String, double, String Function(double), IconData, Color)
  > cifras;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = c.maxWidth >= 760 ? 4 : (c.maxWidth < 340 ? 1 : 2);
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnas,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 96,
          ),
          children: [
            for (final (i, (titulo, valor, cifra, formato, icono, color))
                in cifras.indexed)
              DashboardCard.stat(
                title: titulo,
                value: valor,
                cifra: cifra,
                formatearCifra: formato,
                icon: icono,
                acento: color,
              ).entrada(orden: i + 1),
          ],
        );
      },
    );
  }
}

class _Alerta extends StatelessWidget {
  const _Alerta({
    required this.texto,
    required this.color,
    required this.fondo,
    required this.icono,
  });

  final String texto;
  final Color color;
  final Color fondo;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            texto,
            style: AppFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            valor,
            style: AppFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.violeta,
            ),
          ),
        ),
        Text(
          etiqueta,
          style: AppFonts.inter(fontSize: 13, color: AppColors.tintaSecundaria),
        ),
      ],
    );
  }
}
