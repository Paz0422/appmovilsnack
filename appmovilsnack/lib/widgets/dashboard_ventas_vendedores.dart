// Dashboard para que el admin vea la suma de ventas por vendedor
// (datos de vendedoresasignados en cada sector de eventos activos)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart' as fl_chart;

final Color _primaryColor = const Color(0xFF2B2B2B);
final Color _accentColor = const Color(0xFFDABF41);
final Color _backgroundColor = const Color(0xFFFDFBF7);

class DashboardVentasVendedores extends StatefulWidget {
  const DashboardVentasVendedores({super.key});

  @override
  State<DashboardVentasVendedores> createState() => _DashboardVentasVendedoresState();
}

class _DashboardVentasVendedoresState extends State<DashboardVentasVendedores> {
  bool _soloActivos = true;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _vendedores = [];

  Future<void> _cargar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Mapeo correo -> username para unificar la misma persona (en un sector puede estar el correo, en otro el username)
      final Map<String, String> emailToUsername = {};
      final usuariosSnapshot = await FirebaseFirestore.instance.collection('usuarios').get();
      for (var doc in usuariosSnapshot.docs) {
        final d = doc.data();
        final email = d['email']?.toString();
        final username = d['username']?.toString();
        if (email != null && email.isNotEmpty && username != null && username.isNotEmpty) {
          emailToUsername[email.trim()] = username.trim();
        }
      }

      QuerySnapshot eventosSnapshot;
      if (_soloActivos) {
        eventosSnapshot = await FirebaseFirestore.instance
            .collection('eventos')
            .where('activo', isEqualTo: true)
            .get();
      } else {
        eventosSnapshot = await FirebaseFirestore.instance.collection('eventos').get();
      }

      final Map<String, double> totalPorVendedor = {};

      for (var eventoDoc in eventosSnapshot.docs) {
        final eventoId = eventoDoc.id;
        final sectoresSnapshot = await FirebaseFirestore.instance
            .collection('eventos')
            .doc(eventoId)
            .collection('sectores')
            .get();

        for (var sectorDoc in sectoresSnapshot.docs) {
          final data = sectorDoc.data();
          final vendedoresAsignados = data['vendedoresasignados'] as List<dynamic>? ?? [];
          for (var v in vendedoresAsignados) {
            final s = v is Map ? v['nombre']?.toString() : null;
            final nombreRaw = (s != null ? s.trim() : null) ?? 'Sin nombre';
            final total = (v is Map ? (v['totalVendido'] as num?)?.toDouble() : null) ?? 0.0;
            if (nombreRaw.isEmpty) continue;
            // Unificar: si es correo, usar el username de la BD para que no aparezca duplicado
            final clave = nombreRaw.contains('@')
                ? (emailToUsername[nombreRaw] ?? nombreRaw)
                : nombreRaw;
            totalPorVendedor[clave] = (totalPorVendedor[clave] ?? 0) + total;
          }
        }
      }

      final list = totalPorVendedor.entries
          .map((e) => {'nombre': e.key, 'totalVendido': e.value})
          .toList();
      list.sort((a, b) => (b['totalVendido'] as double).compareTo(a['totalVendido'] as double));

      if (mounted) {
        setState(() {
          _vendedores = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final posFromEnd = s.length - i - 1;
      if (posFromEnd > 0 && posFromEnd % 3 == 0) buf.write('.');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          'Ventas por vendedor',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _accentColor, fontSize: 18),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: _accentColor,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Solo activos', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
                const SizedBox(width: 6),
                Switch(
                  value: _soloActivos,
                  onChanged: (v) {
                    setState(() => _soloActivos = v);
                    _cargar();
                  },
                  activeColor: _accentColor,
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accentColor))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Error al cargar',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _primaryColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _cargar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _vendedores.isEmpty
                  ? Center(
                      child: Text(
                        _soloActivos
                            ? 'No hay ventas de vendedores en eventos activos'
                            : 'No hay ventas registradas por vendedor',
                        style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      color: _accentColor,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _soloActivos ? 'Total vendido por vendedor (eventos activos)' : 'Total vendido por vendedor (todos los eventos)',
                              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            _buildBarChart(),
                            const SizedBox(height: 24),
                            Text(
                              'Detalle por vendedor',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor),
                            ),
                            const SizedBox(height: 12),
                            ..._vendedores.map((v) => _buildCard(v)),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildBarChart() {
    final top = _vendedores.take(10).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final maxV = (top.map((e) => e['totalVendido'] as double).reduce((a, b) => a > b ? a : b)) * 1.15;
    const colors = [
      Color(0xFFDABF41),
      Color(0xFF6B4D2F),
      Color(0xFF2B2B2B),
      Colors.green,
      Colors.teal,
      Colors.blueGrey,
      Colors.orange,
      Colors.deepPurple,
      Colors.indigo,
      Colors.brown,
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 10 vendedores',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: _primaryColor),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: fl_chart.BarChart(
                fl_chart.BarChartData(
                  alignment: fl_chart.BarChartAlignment.spaceAround,
                  maxY: maxV,
                  minY: 0,
                  barTouchData: fl_chart.BarTouchData(
                    touchTooltipData: fl_chart.BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        if (group.x.toInt() >= top.length) return null;
                        final nombre = top[group.x.toInt()]['nombre'] as String? ?? '';
                        final total = rod.toY;
                        return fl_chart.BarTooltipItem(
                          '$nombre\n\$${_fmt(total.toInt())}',
                          GoogleFonts.poppins(fontSize: 12, color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: fl_chart.FlTitlesData(
                    show: true,
                    bottomTitles: fl_chart.AxisTitles(
                      sideTitles: fl_chart.SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= top.length) return const SizedBox();
                          final nombre = top[i]['nombre'] as String? ?? '';
                          final short = nombre.length > 8 ? '${nombre.substring(0, 8)}..' : nombre;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              short,
                              style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[700]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                        reservedSize: 28,
                        interval: 1,
                      ),
                    ),
                    leftTitles: fl_chart.AxisTitles(
                      sideTitles: fl_chart.SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) => Text(
                          value >= 1000 ? '${(value / 1000).toStringAsFixed(0)}k' : value.toInt().toString(),
                          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
                        ),
                      ),
                    ),
                    topTitles: const fl_chart.AxisTitles(sideTitles: fl_chart.SideTitles(showTitles: false)),
                    rightTitles: const fl_chart.AxisTitles(sideTitles: fl_chart.SideTitles(showTitles: false)),
                  ),
                  gridData: fl_chart.FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => fl_chart.FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
                  ),
                  borderData: fl_chart.FlBorderData(show: false),
                  barGroups: top.asMap().entries.map((e) {
                    final i = e.key;
                    final total = e.value['totalVendido'] as double;
                    return fl_chart.BarChartGroupData(
                      x: i,
                      barRods: [
                        fl_chart.BarChartRodData(
                          toY: total,
                          color: colors[i % colors.length],
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                      showingTooltipIndicators: [0],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> v) {
    final nombre = v['nombre'] as String? ?? 'Sin nombre';
    final total = (v['totalVendido'] as num?)?.toDouble() ?? 0.0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: _accentColor.withOpacity(0.2),
          child: Icon(Icons.person_outline, color: _accentColor),
        ),
        title: Text(
          nombre,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _primaryColor, fontSize: 15),
        ),
        trailing: Text(
          '\$${_fmt(total.toInt())}',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700]),
        ),
      ),
    );
  }
}
