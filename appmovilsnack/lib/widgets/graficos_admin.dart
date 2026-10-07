import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/core/animaciones.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/core/tipografia.dart';
import 'package:front_appsnack/widgets/comunes/animados.dart';

/// "$1,2M", "$700k", "$950": para ejes y etiquetas cortas de los gráficos.
String abreviarMonto(double monto) {
  final m = monto.abs();
  String corto(double v) {
    final s = v.toStringAsFixed(v >= 10 ? 0 : 1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s.replaceAll('.', ',');
  }

  // Desde 999.500 el redondeo ya da "1000k": se muestra como millón.
  if (m >= 999500) return '\$${corto(monto / 1000000)}M';
  if (m >= 999.5) return '\$${corto(monto / 1000)}k';
  return '\$${monto.round()}';
}

/// Paso "redondo" del eje (100k, 250k, 500k…) y techo con [margen] sobre
/// el máximo (1,1 = 10 % de aire arriba).
({double paso, double techo}) _escala(double maximo, double margen) {
  final paso = _pasoRedondo(maximo <= 0 ? 1 : maximo / 3);
  return (paso: paso, techo: ((maximo * margen) / paso).ceil() * paso);
}

/// Líneas horizontales punteadas en cada paso del eje.
FlGridData _cuadricula(double paso) => FlGridData(
  show: true,
  drawVerticalLine: false,
  horizontalInterval: paso,
  getDrawingHorizontalLine: (_) => const FlLine(
    color: AppColors.separador,
    strokeWidth: 1,
    dashArray: [4, 4],
  ),
);

/// Eje izquierdo con montos abreviados ("$250k"), sin el 0 ni el techo.
AxisTitles _ejeMontos(double paso, double techo) => AxisTitles(
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
          style: AppFonts.inter(fontSize: 12, color: AppColors.tintaSecundaria),
        ),
      );
    },
  ),
);

/// Borde café de los tooltips (fondo azul noche).
final _bordeTooltip = BorderSide(color: AppColors.cafe.withValues(alpha: 0.6));

/// Sección transparente que se achica mientras [avance] va de 0 a 1: hace
/// que una dona o torta "se dibuje" en el sentido del reloj. null al final.
PieChartSectionData? seccionDibujo({
  required double total,
  required double avance,
  required double radio,
}) => avance >= 1
    ? null
    : PieChartSectionData(
        value: total * (1 - avance) / math.max(avance, 0.001),
        color: Colors.transparent,
        radius: radio,
        showTitle: false,
      );

/// Progreso del elemento [i] de [n] cuando el gráfico va en [t]: cada uno
/// arranca un poco después del anterior.
double _escalonado(double t, int i, int n, {Curve curva = Curves.easeOutCubic}) {
  if (n <= 1) return curva.transform(t.clamp(0, 1));
  final paso = math.min(0.08, 0.45 / n);
  final p = ((t - i * paso) / (1 - (n - 1) * paso)).clamp(0.0, 1.0);
  return curva.transform(p);
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
                    const SizedBox(height: 4),
                    const FiletMarca(ancho: 32),
                    if (subtitulo != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitulo!,
                        style: AppFonts.inter(
                          fontSize: 14,
                          color: AppColors.tintaSecundaria,
                        ),
                      ),
                    ],
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

/// Dona con leyenda: de qué parte viene el total. Al aparecer, el anillo
/// se dibuja de a poco en el sentido del reloj.
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
    final visibles = widget.partes.where((p) => p.monto > 0).toList();

    Widget dona(double t) {
      final avance = Curves.easeOutCubic.transform(t);
      return SizedBox(
        width: 150,
        height: 150,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              swapAnimationDuration: Duration.zero,
              PieChartData(
                startDegreeOffset: -90,
                sectionsSpace: avance < 1 ? 0 : 3,
                centerSpaceRadius: 50,
                pieTouchData: PieTouchData(
                  touchCallback: (evento, respuesta) {
                    final i = respuesta?.touchedSection?.touchedSectionIndex;
                    setState(() {
                      _tocada = evento.isInterestedForInteractions &&
                              i != null &&
                              i >= 0 &&
                              i < visibles.length
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
                  else ...[
                    for (final (i, p) in visibles.indexed)
                      PieChartSectionData(
                        value: p.monto,
                        color: p.color,
                        radius: _tocada == i ? 26 : 18,
                        showTitle: false,
                      ),
                    ?seccionDibujo(total: total, avance: avance, radio: 18),
                  ],
                ],
              ),
            ),
            if (widget.textoCentro != null)
              Padding(
                padding: const EdgeInsets.all(28),
                child: Opacity(
                  opacity: Curves.easeIn.transform(t),
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
              ),
          ],
        ),
      );
    }

    final leyenda = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, p) in widget.partes.indexed)
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
          ).entradaLateral(orden: i + 2),
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
          final grafico = ProgresoEntrada(builder: dona);
          // En pantallas angostas la leyenda va debajo de la dona.
          if (c.maxWidth < 330) {
            return Column(
              children: [grafico, const SizedBox(height: 12), leyenda],
            );
          }
          return Row(
            children: [
              grafico,
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
/// Al aparecer, las barras crecen una tras otra.
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

  @override
  Widget build(BuildContext context) {
    final maximo = items.isEmpty ? 1.0 : items.map((e) => e.monto).reduce(math.max);
    // Escala con pasos "redondos" (100k, 250k, 500k…) para el eje.
    final (:paso, :techo) = _escala(maximo, 1.1);

    return Semantics(
      label: [
        for (final i in items) '${i.nombre}: ${formatear(i.monto)}',
      ].join('. '),
      excludeSemantics: true,
      child: SizedBox(
        height: alto,
        child: ProgresoEntrada(
          duracion: const Duration(milliseconds: 1300),
          builder: (t) => BarChart(
            swapAnimationDuration: Duration.zero,
            _datos(t, techo, paso),
          ),
        ),
      ),
    );
  }

  BarChartData _datos(double t, double techo, double paso) {
    return BarChartData(
      maxY: techo,
      minY: 0,
      alignment: BarChartAlignment.spaceAround,
      borderData: FlBorderData(show: false),
      gridData: _cuadricula(paso),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: _ejeMontos(paso, techo),
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
          tooltipBorder: _bordeTooltip,
          tooltipPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          getTooltipItem: (grupo, _, _, _) => BarTooltipItem(
            '${items[grupo.x].nombre}\n',
            AppFonts.inter(
              fontSize: 12,
              color: AppColors.tintaSecundaria,
            ),
            children: [
              TextSpan(
                // El monto real, aunque la barra todavía esté creciendo.
                text: formatear(items[grupo.x].monto),
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
                toY: item.monto *
                    _escalonado(t, i, items.length, curva: Curves.easeOutBack),
                width: items.length <= 3 ? 34 : 22,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                  bottom: Radius.circular(4),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: AppGradientes.barras[i % AppGradientes.barras.length],
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

/// Evolución de las ventas: línea dorado → café con el área degradada
/// debajo, un punto por tramo con venta y el mejor tramo destacado. Al
/// aparecer, la curva sube desde el piso.
class GraficoEvolucion extends StatelessWidget {
  const GraficoEvolucion({
    super.key,
    required this.tramos,
    required this.porHora,
    required this.formatear,
    this.alto = 220,
  });

  /// En orden cronológico (ver `VentasEnElTiempo`).
  final List<({DateTime fecha, double monto})> tramos;

  /// true: un tramo por hora; false: uno por día.
  final bool porHora;
  final String Function(double) formatear;
  final double alto;

  static String _dosCifras(int n) => n.toString().padLeft(2, '0');

  /// Etiqueta corta del eje: "21 h" o "07/09".
  String etiquetaCorta(DateTime f) => porHora
      ? '${f.hour} h'
      : '${_dosCifras(f.day)}/${_dosCifras(f.month)}';

  /// Etiqueta del tooltip y del lector: "21:00 – 22:00" o "07/09/2026".
  String etiquetaLarga(DateTime f) => porHora
      ? '${_dosCifras(f.hour)}:00 – ${_dosCifras((f.hour + 1) % 24)}:00'
      : '${_dosCifras(f.day)}/${_dosCifras(f.month)}/${f.year}';

  @override
  Widget build(BuildContext context) {
    // Con un solo tramo una línea no dice nada: se muestra como barra.
    if (tramos.length < 2) {
      return GraficoBarras(
        alto: alto,
        formatear: formatear,
        items: [
          for (final t in tramos)
            (nombre: etiquetaLarga(t.fecha), monto: t.monto),
        ],
      );
    }

    final maximo = tramos.map((e) => e.monto).reduce(math.max);
    final iMejor = tramos.indexWhere((e) => e.monto == maximo);
    final (:paso, :techo) = _escala(maximo, 1.15);
    // Hasta ~6 etiquetas en el eje para que no se pisen.
    final cadaCuantos = math.max(1, (tramos.length / 6).ceil());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EtiquetaCafe(
          icono: Icons.local_fire_department_rounded,
          texto:
              '${porHora ? 'Hora peak' : 'Mejor día'}: '
              '${etiquetaLarga(tramos[iMejor].fecha)} · ${formatear(maximo)}',
        ).entradaLateral(orden: 2),
        const SizedBox(height: 14),
        Semantics(
          label: [
            for (final t in tramos.where((t) => t.monto > 0))
              '${etiquetaLarga(t.fecha)}: ${formatear(t.monto)}',
          ].join('. '),
          excludeSemantics: true,
          child: SizedBox(
            height: alto,
            child: ProgresoEntrada(
              duracion: const Duration(milliseconds: 1400),
              builder: (t) => LineChart(
                duration: Duration.zero,
                _datos(t, techo, paso, iMejor, cadaCuantos),
              ),
            ),
          ),
        ),
      ],
    );
  }

  LineChartData _datos(
    double t,
    double techo,
    double paso,
    int iMejor,
    int cadaCuantos,
  ) {
    final n = tramos.length;
    return LineChartData(
      minX: 0,
      maxX: (n - 1).toDouble(),
      minY: 0,
      maxY: techo,
      borderData: FlBorderData(show: false),
      gridData: _cuadricula(paso),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: _ejeMontos(paso, techo),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (v, meta) {
              final i = v.round();
              if (v != i || i < 0 || i >= n || i % cadaCuantos != 0) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(
                  etiquetaCorta(tramos[i].fecha),
                  style: AppFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: i == iMejor
                        ? AppColors.dorado
                        : AppColors.tintaSecundaria,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: AppColors.negro,
          tooltipRoundedRadius: 10,
          tooltipBorder: _bordeTooltip,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          maxContentWidth: 160,
          getTooltipItems: (tocados) => [
            for (final s in tocados)
              LineTooltipItem(
                '${etiquetaLarga(tramos[s.x.round()].fecha)}\n',
                AppFonts.inter(fontSize: 12, color: AppColors.tintaSecundaria),
                children: [
                  TextSpan(
                    text: formatear(tramos[s.x.round()].monto),
                    style: AppFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dorado,
                    ),
                  ),
                ],
              ),
          ],
        ),
        getTouchedSpotIndicator: (barra, indices) => [
          for (final _ in indices)
            TouchedSpotIndicatorData(
              FlLine(
                color: AppColors.cafe.withValues(alpha: 0.7),
                strokeWidth: 2,
                dashArray: [4, 4],
              ),
              FlDotData(
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 7,
                  color: AppColors.dorado,
                  strokeColor: AppColors.negro,
                  strokeWidth: 3,
                ),
              ),
            ),
        ],
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (final (i, tramo) in tramos.indexed)
              FlSpot(i.toDouble(), tramo.monto * _escalonado(t, i, n)),
          ],
          isCurved: true,
          curveSmoothness: 0.3,
          preventCurveOverShooting: true,
          barWidth: 3.5,
          isStrokeCapRound: true,
          gradient: AppGradientes.marca,
          shadow: Shadow(
            color: AppColors.dorado.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: AppGradientes.areaGrafico(AppColors.dorado),
          ),
          dotData: FlDotData(
            show: true,
            checkToShowDot: (spot, _) => tramos[spot.x.round()].monto > 0,
            getDotPainter: (spot, _, _, i) => FlDotCirclePainter(
              radius: i == iMejor ? 6.5 : 4,
              color: i == iMejor ? AppColors.dorado : AppColors.tarjeta,
              strokeColor: i == iMejor ? AppColors.negro : AppColors.dorado,
              strokeWidth: i == iMejor ? 3 : 2.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Ranking con barras horizontales de degradado: se lee bien en teléfono
/// aunque los nombres sean largos. Los tres primeros llevan oro, plata y
/// bronce (café, como el anillo del logo); las barras crecen escalonadas.
class RankingBarras extends StatelessWidget {
  const RankingBarras({
    super.key,
    required this.items,
    required this.formatear,
  });

  /// Ya ordenados de mayor a menor.
  final List<({String nombre, String? detalle, double monto})> items;
  final String Function(double) formatear;

  static Color colorPuesto(int posicion) => posicion < AppColors.podio.length
      ? AppColors.podio[posicion]
      : AppColors.grafico[(posicion - 2) % AppColors.grafico.length];

  @override
  Widget build(BuildContext context) {
    final maximo =
        items.isEmpty ? 1.0 : items.map((e) => e.monto).reduce(math.max);
    return ProgresoEntrada(
      duracion: const Duration(milliseconds: 1300),
      builder: (t) => Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _fila(i, items[i], maximo, _escalonado(t, i, items.length)),
          ],
        ],
      ),
    );
  }

  Widget _fila(
    int posicion,
    ({String nombre, String? detalle, double monto}) item,
    double maximo,
    double avance,
  ) {
    final color = colorPuesto(posicion);
    final podio = posicion < 3;
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
                color: color.withValues(alpha: podio ? 0.2 : 0.14),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: podio ? Border.all(color: color, width: 1.5) : null,
              ),
              child: posicion == 0
                  ? Icon(Icons.emoji_events_rounded, color: color, size: 20)
                  : Text(
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
                          widthFactor: math.max(0.02, fraccion * avance),
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
