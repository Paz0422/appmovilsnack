import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/core/tipografia.dart';

/// "$1,2M", "$700k", "$950": para ejes y etiquetas cortas de los gráficos.
String abreviarMonto(double monto) {
  final m = monto.abs();
  String corto(double v) {
    final s = v.toStringAsFixed(v >= 10 ? 0 : 1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s.replaceAll('.', ',');
  }

  if (m >= 1000000) return '\$${corto(monto / 1000000)}M';
  if (m >= 1000) return '\$${corto(monto / 1000)}k';
  return '\$${monto.round()}';
}

/// Contenedor de gráfico: tarjeta pizarra con título y subtítulo.
class TarjetaGrafico extends StatelessWidget {
  const TarjetaGrafico({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.accion,
    required this.child,
  });

  final String titulo;
  final String? subtitulo;
  final Widget? accion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: AppGradientes.tarjeta,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.separador),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: AppFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.tinta,
                      ),
                    ),
                    if (subtitulo != null)
                      Text(
                        subtitulo!,
                        style: AppFonts.inter(
                          fontSize: 14,
                          color: AppColors.tintaSecundaria,
                        ),
                      ),
                  ],
                ),
              ),
              ?accion,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Dona con leyenda: de qué parte viene el total.
class GraficoDona extends StatefulWidget {
  const GraficoDona({
    super.key,
    required this.partes,
    required this.formatear,
    this.textoCentro,
  });

  /// (etiqueta, monto, color). Las partes en 0 se muestran en la leyenda
  /// pero no en la dona.
  final List<({String etiqueta, double monto, Color color})> partes;
  final String Function(double) formatear;
  final String? textoCentro;

  @override
  State<GraficoDona> createState() => _GraficoDonaState();
}

class _GraficoDonaState extends State<GraficoDona> {
  int? _tocada;

  @override
  Widget build(BuildContext context) {
    final total = widget.partes.fold<double>(0, (t, p) => t + p.monto);
    String pct(double v) =>
        total <= 0 ? '0 %' : '${(v * 100 / total).round()} %';

    final dona = SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 3,
              centerSpaceRadius: 50,
              pieTouchData: PieTouchData(
                touchCallback: (evento, respuesta) {
                  final i = respuesta?.touchedSection?.touchedSectionIndex;
                  setState(() {
                    _tocada = evento.isInterestedForInteractions &&
                            i != null &&
                            i >= 0
                        ? i
                        : null;
                  });
                },
              ),
              sections: [
                if (total <= 0)
                  PieChartSectionData(
                    value: 1,
                    color: AppColors.tarjetaAlta,
                    radius: 18,
                    showTitle: false,
                  )
                else
                  for (final (i, p) in widget.partes
                      .where((p) => p.monto > 0)
                      .indexed)
                    PieChartSectionData(
                      value: p.monto,
                      color: p.color,
                      radius: _tocada == i ? 24 : 18,
                      showTitle: false,
                    ),
              ],
            ),
          ),
          if (widget.textoCentro != null)
            Padding(
              padding: const EdgeInsets.all(28),
              child: FittedBox(
                child: Text(
                  widget.textoCentro!,
                  style: AppFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.tinta,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final leyenda = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in widget.partes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: p.color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.etiqueta,
                        style: AppFonts.inter(
                          fontSize: 14,
                          color: AppColors.tintaSecundaria,
                        ),
                      ),
                      Text(
                        '${widget.formatear(p.monto)} · ${pct(p.monto)}',
                        style: AppFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tinta,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return Semantics(
      label: [
        for (final p in widget.partes)
          '${p.etiqueta}: ${widget.formatear(p.monto)}, ${pct(p.monto)}',
      ].join('. '),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, c) {
          // En pantallas angostas la leyenda va debajo de la dona.
          if (c.maxWidth < 330) {
            return Column(
              children: [dona, const SizedBox(height: 12), leyenda],
            );
          }
          return Row(
            children: [
              dona,
              const SizedBox(width: 20),
              Expanded(child: leyenda),
            ],
          );
        },
      ),
    );
  }
}

/// Barras verticales con degradado dorado (y el resto en cian), valor
/// abreviado arriba y nombre abajo. Tocar una barra muestra el monto exacto.
class GraficoBarras extends StatelessWidget {
  const GraficoBarras({
    super.key,
    required this.items,
    required this.formatear,
    this.alto = 220,
  });

  /// Ya ordenados; se muestran como vienen.
  final List<({String nombre, double monto})> items;
  final String Function(double) formatear;
  final double alto;

  static const _degradados = [
    [Color(0xFFF7DB86), AppColors.doradoOscuro],
    [Color(0xFF7FDBF7), Color(0xFF2E9FC7)],
    [Color(0xFFFFB3AB), Color(0xFFE0645A)],
    [Color(0xFFC8BEFF), Color(0xFF7D6BE0)],
    [Color(0xFF86E6B3), Color(0xFF2FA86A)],
  ];

  @override
  Widget build(BuildContext context) {
    final maximo = items.isEmpty ? 1.0 : items.map((e) => e.monto).reduce(math.max);
    // Escala con pasos "redondos" (100k, 250k, 500k…) para el eje.
    final paso = _pasoRedondo(maximo <= 0 ? 1 : maximo / 3);
    final techo = ((maximo * 1.1) / paso).ceil() * paso;

    return Semantics(
      label: [
        for (final i in items) '${i.nombre}: ${formatear(i.monto)}',
      ].join('. '),
      excludeSemantics: true,
      child: SizedBox(
        height: alto,
        child: BarChart(
          BarChartData(
            maxY: techo,
            minY: 0,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: paso,
              getDrawingHorizontalLine: (_) => const FlLine(
                color: AppColors.separador,
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  interval: paso,
                  getTitlesWidget: (v, meta) {
                    if (v == 0 || v >= techo) return const SizedBox.shrink();
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        abreviarMonto(v),
                        maxLines: 1,
                        softWrap: false,
                        style: AppFonts.inter(
                          fontSize: 12,
                          color: AppColors.tintaSecundaria,
                        ),
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= items.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: SizedBox(
                        width: 72,
                        child: Text(
                          items[i].nombre,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.tintaSecundaria,
                            height: 1.15,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: AppColors.negro,
                tooltipRoundedRadius: 10,
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                getTooltipItem: (grupo, _, barra, _) => BarTooltipItem(
                  '${items[grupo.x].nombre}\n',
                  AppFonts.inter(
                    fontSize: 12,
                    color: AppColors.tintaSecundaria,
                  ),
                  children: [
                    TextSpan(
                      text: formatear(barra.toY),
                      style: AppFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dorado,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            barGroups: [
              for (final (i, item) in items.indexed)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: item.monto,
                      width: items.length <= 3 ? 34 : 22,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10),
                        bottom: Radius.circular(4),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _degradados[i % _degradados.length],
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: techo,
                        color: AppColors.tarjetaAlta.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

double _pasoRedondo(double bruto) {
  final magnitud = math.pow(10, (math.log(bruto) / math.ln10).floor()).toDouble();
  for (final m in [1, 2, 2.5, 5, 10]) {
    if (m * magnitud >= bruto) return m * magnitud;
  }
  return 10 * magnitud;
}

/// Ranking con barras horizontales de degradado: se lee bien en teléfono
/// aunque los nombres sean largos.
class RankingBarras extends StatelessWidget {
  const RankingBarras({
    super.key,
    required this.items,
    required this.formatear,
  });

  /// Ya ordenados de mayor a menor.
  final List<({String nombre, String? detalle, double monto})> items;
  final String Function(double) formatear;

  @override
  Widget build(BuildContext context) {
    final maximo =
        items.isEmpty ? 1.0 : items.map((e) => e.monto).reduce(math.max);
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _fila(i, items[i], maximo),
        ],
      ],
    );
  }

  Widget _fila(
    int posicion,
    ({String nombre, String? detalle, double monto}) item,
    double maximo,
  ) {
    final color = AppColors.grafico[posicion % AppColors.grafico.length];
    final fraccion = maximo <= 0 ? 0.0 : (item.monto / maximo).clamp(0.0, 1.0);
    return Semantics(
      label: 'Puesto ${posicion + 1}: ${item.nombre}, ${formatear(item.monto)}',
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '${posicion + 1}',
              style: AppFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.tinta,
                            ),
                          ),
                          if (item.detalle != null && item.detalle!.isNotEmpty)
                            Text(
                              item.detalle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.inter(
                                fontSize: 13,
                                color: AppColors.tintaSecundaria,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatear(item.monto),
                      style: AppFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.tinta,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Stack(
                    children: [
                      Container(height: 10, color: AppColors.tarjetaAlta),
                      FractionallySizedBox(
                        widthFactor: fraccion < 0.02 ? 0.02 : fraccion,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              colors: [color.withValues(alpha: 0.55), color],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
