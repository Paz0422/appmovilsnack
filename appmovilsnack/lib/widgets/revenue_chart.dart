import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ChartRange { weekly, monthly }

class RevenueChart extends StatefulWidget {
  final ChartRange range;

  const RevenueChart({super.key, this.range = ChartRange.weekly});

  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart> {
  List<Map<String, dynamic>> _revenueData = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRevenueData();
  }

  Future<void> _loadRevenueData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final snapshot = await FirebaseFirestore.instance
          .collection('transacciones')
          .orderBy('fecha', descending: false)
          .get();

      // Agrupar por fecha (día)
      final Map<DateTime, int> dailyRevenue = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final fecha = data['fecha'];
        final montoTotal = data['montoTotal'] ?? 0;

        DateTime date;
        if (fecha is Timestamp) {
          date = fecha.toDate();
        } else if (fecha is DateTime) {
          date = fecha;
        } else {
          continue;
        }

        // Normalizar a solo fecha (sin hora)
        final day = DateTime(date.year, date.month, date.day);
        dailyRevenue[day] =
            (dailyRevenue[day] ?? 0) + (montoTotal as num).toInt();
      }

      // Convertir a lista ordenada y limitar según el rango
      final sortedDates = dailyRevenue.keys.toList()..sort();
      final daysToShow = widget.range == ChartRange.weekly ? 7 : 30;
      final recentDates = sortedDates.length > daysToShow
          ? sortedDates.sublist(sortedDates.length - daysToShow)
          : sortedDates;

      final chartData = recentDates.map((date) {
        return {'date': date, 'revenue': dailyRevenue[date] ?? 0};
      }).toList();

      if (mounted) {
        setState(() {
          _revenueData = chartData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar datos: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final posFromEnd = s.length - i - 1;
      if (posFromEnd > 0 && posFromEnd % 3 == 0) buf.write('.');
    }
    return '\$${buf.toString()}';
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.amber[400], size: 24),
                  const SizedBox(width: 8),
                  Text(
                    widget.range == ChartRange.weekly
                        ? 'Transacciones Semanales'
                        : 'Transacciones Mensuales',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (!_isLoading && _revenueData.isEmpty)
                TextButton.icon(
                  onPressed: _loadRevenueData,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Actualizar'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.amber[400],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isLoading
                ? 'Cargando datos...'
                : _errorMessage != null
                ? _errorMessage!
                : _revenueData.isEmpty
                ? 'No hay datos de transacciones'
                : widget.range == ChartRange.weekly
                ? 'Últimos ${_revenueData.length} días (máximo 7 días)'
                : 'Últimos ${_revenueData.length} días (máximo 30 días)',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(color: Colors.amber),
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red[300]),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loadRevenueData,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          else if (_revenueData.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.show_chart, size: 48, color: Colors.grey[500]),
                    const SizedBox(height: 12),
                    Text(
                      'No hay transacciones para mostrar',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildChart(),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final maxRevenue = _revenueData.isEmpty
        ? 1
        : _revenueData
              .map((e) => e['revenue'] as int)
              .reduce((a, b) => a > b ? a : b);

    if (maxRevenue == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Text(
            'No hay revenue para mostrar',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Eje Y (valores)
          SizedBox(
            width: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(maxRevenue),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatCurrency((maxRevenue * 0.5).round()),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '\$0',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Gráfico de líneas
          Expanded(
            child: Column(
              children: [
                // Área del gráfico
                Expanded(
                  child: CustomPaint(
                    painter: LineChartPainter(
                      data: _revenueData,
                      maxRevenue: maxRevenue,
                      formatCurrency: _formatCurrency,
                    ),
                    child: Container(),
                  ),
                ),
                // Eje X (fechas)
                SizedBox(
                  height: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _revenueData.map((data) {
                      final date = data['date'] as DateTime;
                      return Expanded(
                        child: Center(
                          child: Text(
                            _formatDate(date),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }).toList(),
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

// Custom Painter para el gráfico de líneas con gradiente
class LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final int maxRevenue;
  final String Function(int) formatCurrency;

  LineChartPainter({
    required this.data,
    required this.maxRevenue,
    required this.formatCurrency,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paintLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final paintPoint = Paint()..style = PaintingStyle.fill;

    final paintShadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.amber.withOpacity(0.2);

    // Calcular puntos
    final double chartHeight = size.height - 30;
    final double chartWidth = size.width;
    final double stepX = data.length > 1 ? chartWidth / (data.length - 1) : 0;
    final double padding = 20.0;

    final List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      final revenue = data[i]['revenue'] as int;
      final y =
          chartHeight -
          ((revenue / maxRevenue) * (chartHeight - padding * 2)) -
          padding;
      final x = i * stepX + padding;
      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    // Dibujar línea de sombra suave
    final shadowPath = Path();
    shadowPath.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      shadowPath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(shadowPath, paintShadow);

    // Dibujar línea con gradiente dorado
    if (points.length > 1) {
      for (int i = 0; i < points.length - 1; i++) {
        final start = points[i];
        final end = points[i + 1];

        // Calcular color del gradiente basado en la posición
        final t = i / (points.length - 1);
        final colors = [
          const Color(0xFFB88912), // Dorado oscuro
          const Color(0xFFD4AF37), // Dorado medio
          const Color(0xFFF5D27B), // Dorado claro
        ];

        Color currentColor;
        if (t < 0.5) {
          currentColor = Color.lerp(colors[0], colors[1], t * 2)!;
        } else {
          currentColor = Color.lerp(colors[1], colors[2], (t - 0.5) * 2)!;
        }

        paintLine.color = currentColor;
        canvas.drawLine(start, end, paintLine);
      }
    }

    // Dibujar puntos con efecto brillante
    for (final point in points) {
      // Sombra del punto
      paintPoint.color = Colors.amber.withOpacity(0.3);
      canvas.drawCircle(point, 8, paintPoint);

      // Punto exterior (gradiente simulado)
      paintPoint.color = Colors.amber[400]!;
      canvas.drawCircle(point, 6, paintPoint);

      // Punto interior brillante
      paintPoint.color = Colors.amber[200]!;
      canvas.drawCircle(point, 3, paintPoint);
    }

    // Dibujar líneas de grid sutiles
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.grey[700]!.withOpacity(0.3);

    // Línea media
    final midY = chartHeight / 2;
    canvas.drawLine(
      Offset(padding, midY),
      Offset(chartWidth - padding, midY),
      gridPaint,
    );
  }

  @override
  bool shouldRepaint(LineChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.maxRevenue != maxRevenue;
  }
}
