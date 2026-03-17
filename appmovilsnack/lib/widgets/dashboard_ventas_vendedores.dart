// Dashboard para que el admin vea la suma de ventas por vendedor
// Datos desde transacciones, con filtros por mes, anio y partido (evento).
// Cada vendedor se identifica por color en el gráfico; leyenda aparte.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart' as fl_chart;
import '../core/app_theme.dart';
import '../services/firestore_helpers.dart';

class DashboardVentasVendedores extends StatefulWidget {
  const DashboardVentasVendedores({super.key});

  @override
  State<DashboardVentasVendedores> createState() => _DashboardVentasVendedoresState();
}

class _DashboardVentasVendedoresState extends State<DashboardVentasVendedores> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _vendedores = [];
  List<Map<String, dynamic>> _eventos = [];
  int? _anioSeleccionado;
  int? _mesSeleccionado;
  String? _eventoIdSeleccionado;

  static const List<Color> _coloresVendedor = [
    Color(0xFFDABF41),
    Color(0xFF6B4D2F),
    Color(0xFF2B2B2B),
    Color(0xFF4A7C59),
    Colors.teal,
    Colors.blueGrey,
    Colors.orange,
    Colors.deepPurple,
    Colors.indigo,
    Colors.brown,
  ];

  Future<void> _cargarEventos() async {
    final snapshot = await FirestoreHelpers.getEventos();
    if (mounted) {
      setState(() {
        _eventos = snapshot.docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>?;
          return {'id': doc.id, 'nombre': d?['nombre'] ?? doc.id};
        }).toList();
      });
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _cargarEventos();

      Query<Map<String, dynamic>> q;
      if (_eventoIdSeleccionado != null && _eventoIdSeleccionado!.isNotEmpty) {
        q = FirebaseFirestore.instance
            .collection('transacciones')
            .where('eventoId', isEqualTo: _eventoIdSeleccionado!)
            .orderBy('fecha', descending: true)
            .limit(5000);
      } else {
        q = FirebaseFirestore.instance
            .collection('transacciones')
            .orderBy('fecha', descending: true)
            .limit(5000);
      }

      // Unificar misma persona: en transacciones puede estar el correo o el username
      final Map<String, String> emailToUsername = {};
      final usuariosSnapshot = await FirebaseFirestore.instance.collection('usuarios').get();
      for (var doc in usuariosSnapshot.docs) {
        final d = doc.data();
        final email = d['email']?.toString();
        final username = d['username']?.toString();
        if (email != null && email.isNotEmpty && username != null && username.isNotEmpty) {
          final e = email.trim().toLowerCase();
          emailToUsername[e] = username.trim();
        }
      }

      final snapshot = await q.get();
      final Map<String, double> totalPorVendedor = {};

      for (var doc in snapshot.docs) {
        final d = doc.data() as Map<String, dynamic>?;
        if (d == null) continue;
        final fecha = (d['fecha'] as Timestamp?)?.toDate();
        if (fecha != null) {
          if (_anioSeleccionado != null && fecha.year != _anioSeleccionado!) continue;
          if (_mesSeleccionado != null && fecha.month != _mesSeleccionado!) continue;
        }
        final nombreRaw = (d['vendedorNombre']?.toString() ?? '').trim();
        if (nombreRaw.isEmpty) continue;
        final clave = nombreRaw.contains('@')
            ? (emailToUsername[nombreRaw.toLowerCase()] ?? nombreRaw)
            : nombreRaw;
        final monto = (d['montoTotal'] as num?)?.toDouble() ?? 0.0;
        totalPorVendedor[clave] = (totalPorVendedor[clave] ?? 0) + monto;
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

  int _colorIndexForVendedor(int index) => index % _coloresVendedor.length;
  Color _colorForVendedor(int index) => _coloresVendedor[_colorIndexForVendedor(index)];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Ventas por vendedor',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.accent, fontSize: 18),
        ),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.accent,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(
                          'Error al cargar',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.onSurfaceVariant),
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
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFiltros(),
            const SizedBox(height: 16),
            Text(
              _subtitulo(),
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (_vendedores.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No hay ventas para los filtros seleccionados',
                    style: GoogleFonts.poppins(color: AppColors.onSurfaceVariant, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else ...[
              _buildBarChart(),
              const SizedBox(height: 24),
              Text(
                'Detalle por vendedor',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              ..._vendedores.map((v) => _buildCard(v)),
            ],
          ],
        ),
      ),
    );
  }

  String _subtitulo() {
    final partes = <String>[];
    if (_eventoIdSeleccionado != null) {
      final list = _eventos.where((e) => e['id'] == _eventoIdSeleccionado).toList();
      final nombre = list.isEmpty ? _eventoIdSeleccionado! : (list.first['nombre'] ?? _eventoIdSeleccionado).toString();
      partes.add(nombre);
    } else {
      partes.add('Todos los partidos');
    }
    if (_anioSeleccionado != null) partes.add('Año $_anioSeleccionado');
    if (_mesSeleccionado != null) {
      const meses = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
      partes.add(meses[_mesSeleccionado! - 1]);
    }
    if (partes.isEmpty) return 'Total vendido por vendedor';
    return 'Total vendido por vendedor · ${partes.join(' · ')}';
  }

  Widget _buildFiltros() {
    final anios = [DateTime.now().year, DateTime.now().year - 1, DateTime.now().year - 2];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      color: AppColors.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtros',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _eventoIdSeleccionado,
              decoration: const InputDecoration(
                labelText: 'Partido',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                ..._eventos.map((e) => DropdownMenuItem<String?>(
                      value: e['id'] as String?,
                      child: Text((e['nombre'] ?? e['id']).toString(), overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (v) {
                setState(() {
                  _eventoIdSeleccionado = v;
                  _cargar();
                });
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _anioSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Año',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
                      ...anios.map((a) => DropdownMenuItem<int?>(value: a, child: Text('$a'))),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _anioSeleccionado = v;
                        _cargar();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _mesSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Mes',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
                      ...List.generate(12, (i) => DropdownMenuItem<int?>(value: i + 1, child: Text(_nombreMes(i + 1)))),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _mesSeleccionado = v;
                        _cargar();
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _nombreMes(int mes) {
    const m = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    return m[mes - 1];
  }

  Widget _buildBarChart() {
    final top = _vendedores.take(10).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final maxV = (top.map((e) => e['totalVendido'] as double).reduce((a, b) => a > b ? a : b)) * 1.15;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      color: AppColors.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 10 vendedores',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: fl_chart.BarChart(
                fl_chart.BarChartData(
                  alignment: fl_chart.BarChartAlignment.spaceAround,
                  maxY: maxV,
                  minY: 0,
                  barTouchData: fl_chart.BarTouchData(
                    touchTooltipData: fl_chart.BarTouchTooltipData(
                      getTooltipItem: (_, __, ___, ____) => null,
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
                          final total = top[i]['totalVendido'] as double;
                          final short = nombre.length > 10 ? '${nombre.substring(0, 10)}..' : nombre;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _colorForVendedor(i),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  short,
                                  style: GoogleFonts.poppins(fontSize: 9, color: AppColors.onSurface, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  '\$${_fmt(total.toInt())}',
                                  style: GoogleFonts.poppins(fontSize: 9, color: AppColors.success, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        },
                        reservedSize: 52,
                        interval: 1,
                      ),
                    ),
                    leftTitles: fl_chart.AxisTitles(
                      sideTitles: fl_chart.SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) => Text(
                          value >= 1000 ? '${(value / 1000).toStringAsFixed(0)}k' : value.toInt().toString(),
                          style: GoogleFonts.poppins(fontSize: 10, color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    ),
                    topTitles: const fl_chart.AxisTitles(sideTitles: fl_chart.SideTitles(showTitles: false)),
                    rightTitles: const fl_chart.AxisTitles(sideTitles: fl_chart.SideTitles(showTitles: false)),
                  ),
                  gridData: fl_chart.FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => fl_chart.FlLine(color: AppColors.outline.withOpacity(0.5), strokeWidth: 1),
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
                          color: _colorForVendedor(i),
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                      showingTooltipIndicators: [],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: top.asMap().entries.map((e) {
                final i = e.key;
                final nombre = e.value['nombre'] as String? ?? '';
                final short = nombre.length > 15 ? '${nombre.substring(0, 15)}..' : nombre;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _colorForVendedor(i),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      short,
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.onSurface),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> v) {
    final nombre = v['nombre'] as String? ?? 'Sin nombre';
    final total = (v['totalVendido'] as num?)?.toDouble() ?? 0.0;
    final index = _vendedores.indexWhere((e) => e['nombre'] == nombre);
    final color = index >= 0 ? _colorForVendedor(index) : AppColors.accent;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      color: AppColors.surfaceCard,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Icon(Icons.person_outline, color: color, size: 22),
            ),
          ],
        ),
        title: Text(
          nombre,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 15),
        ),
        trailing: Text(
          '\$${_fmt(total.toInt())}',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success),
        ),
      ),
    );
  }
}
