// lib/home_admin.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:front_appsnack/auth/login_screen.dart';
import 'package:front_appsnack/widgets/dashboard_card.dart';
import 'package:front_appsnack/widgets/gestion_screen.dart';
import 'package:front_appsnack/widgets/stock_reports.dart';
import 'package:front_appsnack/widgets/ventas_por_categoria.dart';
import 'package:front_appsnack/widgets/reporte_mermas.dart';
import 'package:front_appsnack/widgets/reporte_diferencias_traspaso.dart';
import 'package:front_appsnack/widgets/gestion_categorias.dart';
import 'package:front_appsnack/widgets/gestion_roles_usuarios.dart';
import 'package:front_appsnack/widgets/ranking_vendedores.dart';
import 'package:front_appsnack/widgets/estadio_selection.dart';
import 'package:front_appsnack/widgets/cierres_partidos_activos.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/services/admin_estadisticas_service.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeAdmin extends StatefulWidget {
  const HomeAdmin({super.key});

  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {
  AdminResumenActivos? _resumen;
  bool _cargando = true;
  String? _errorCarga;

  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final resumen = await AdminEstadisticasService.cargarResumenActivos();
      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCarga = e.toString();
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Panel de Administración',
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarEstadisticas,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                        const Text(
                          'Resumen de ventas',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cierres de turno en sectores y ventas de bandejeo',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _LiveReloj(darkText: true),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Deslizá hacia abajo para actualizar',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
              const SizedBox(height: 16),
              if (_cargando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorCarga != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Text(
                        'Error al cargar: $_errorCarga',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _cargarEstadisticas,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              else ...[
                if (_resumen!.sinVentasRegistradas) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[800]),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Todavía no hay ventas cargadas. Aparecen cuando un sector '
                            'cierra turno (inventario final) o cuando se rinde una ronda de bandejeo.',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.orange[900],
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: DashboardCard.kpi(
                    title: 'Total vendido',
                    value: '\$${_fmtMiles(_resumen!.totalVendido)}',
                    subtitle:
                        '${_resumen!.eventosConVentas} partido${_resumen!.eventosConVentas == 1 ? '' : 's'} con ventas · '
                        '${_resumen!.cantidadEventosActivos} activo${_resumen!.cantidadEventosActivos == 1 ? '' : 's'} ahora',
                    icon: Icons.payments_outlined,
                    iconColor: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Detalle',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final stats = _resumen!.toStatsMap();
                    final ancho = MediaQuery.of(context).size.width;
                    final cross = ancho < 400 ? 1 : 2;

                    return GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 8,
                        mainAxisExtent: 72,
                      ),
                      children: [
                        DashboardCard.stat(
                          title: 'Cierres de turno',
                          value: _fmtMiles(
                            (stats['cantidadCierres'] as int?) ?? 0,
                          ),
                          icon: Icons.receipt_long_outlined,
                        ),
                        DashboardCard.stat(
                          title: 'Promedio por cierre',
                          value:
                              '\$${_fmtMiles(((stats['promedioPorCierre'] as num?) ?? 0).round())}',
                          icon: Icons.trending_up,
                        ),
                        DashboardCard.stat(
                          title: 'Rondas bandejeo',
                          value: '${stats['transaccionesBandejeo'] ?? 0}',
                          icon: Icons.shopping_basket_outlined,
                        ),
                        DashboardCard.stat(
                          title: 'Bandejeo en turno abierto',
                          value:
                              '\$${_fmtMiles((stats['montoBandejeoTurnosAbiertos'] as int?) ?? 0)}',
                          icon: Icons.point_of_sale_outlined,
                        ),
                        DashboardCard.stat(
                          title: 'Partidos con ventas',
                          value: '${stats['eventosConVentas'] ?? 0}',
                          icon: Icons.emoji_events_outlined,
                        ),
                        DashboardCard.stat(
                          title: 'Partidos activos',
                          value: '${stats['cantidadEventosActivos'] ?? 0}',
                          icon: Icons.event_available,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Por partido',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Solo partidos que ya tienen ventas registradas',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 12),
                _EventosIngresosWidget(ingresos: _resumen!.ingresosPorEvento),
                const SizedBox(height: 24),
                const Text(
                  'Por sector',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Puestos con más venta (cierre o bandejeo)',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 12),
                _AnalisisSectoresWidget(sectores: _resumen!.ingresosPorSector),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _fmtMiles(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final posFromEnd = s.length - i - 1;
      if (posFromEnd > 0 && posFromEnd % 3 == 0) buf.write('.');
    }
    return buf.toString();
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: primaryColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.transparent),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: accentColor,
                    child: Icon(Icons.person, size: 35, color: primaryColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Administrador',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Panel de Control',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            _drawerSectionLabel('Operación'),
            _buildDrawerItem(
              icon: Icons.storefront_outlined,
              title: 'Panel de vendedor',
              subtitle: 'Elegir sector y operar como vendedor',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const EstadioSelection(fromAdmin: true),
                  ),
                );
              },
            ),
            const Divider(color: Colors.white24, height: 1),
            _drawerSectionLabel('Reportes'),
            _buildDrawerItem(
              icon: Icons.assessment_outlined,
              title: 'Reportes de Stock',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StockReports()),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.pie_chart_outline,
              title: 'Ventas por categoría',
              subtitle: 'Estimación por inventario (inicial − final)',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VentasPorCategoria(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.remove_circle_outline,
              title: 'Reporte de mermas',
              subtitle: 'Ver mermas y motivo',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReporteMermas(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.sync_problem_rounded,
              title: 'Diferencias en traspasos',
              subtitle: 'Recibido menos de lo enviado',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const ReporteDiferenciasTraspaso(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.lock_clock_outlined,
              title: 'Cierres de partidos activos',
              subtitle: 'Ver sectores cerrados por partido',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CierresPartidosActivos(),
                  ),
                );
              },
            ),
            const Divider(color: Colors.white24, height: 1),
            _drawerSectionLabel('Configuración'),
            _buildDrawerItem(
              icon: Icons.category_outlined,
              title: 'Categorías de productos',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GestionCategorias(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.settings_outlined,
              title: 'Productos, personal y eventos',
              subtitle: 'Inventario, empleados, eventos y sectores',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GestionScreen(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.badge_outlined,
              title: 'Roles de usuarios',
              subtitle: 'Admin y vendedor por usuario',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GestionRolesUsuarios(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.leaderboard_outlined,
              title: 'Ranking de vendedores',
              subtitle: 'Ventas acumuladas por cierre de turno',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RankingVendedores(),
                  ),
                );
              },
            ),
            const Divider(color: Colors.white24, height: 1),
            _buildDrawerItem(
              icon: Icons.logout_outlined,
              title: 'Cerrar Sesión',
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (Route<dynamic> route) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _drawerSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: accentColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: accentColor, size: 24),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white60),
            )
          : null,
      onTap: onTap,
      hoverColor: accentColor.withValues(alpha: 0.1),
    );
  }
}

// ===== Componentes UI existentes =====

class _HeaderStrip extends StatelessWidget {
  final String titleLeft;
  final Widget? rightChild;
  final bool darkText;
  const _HeaderStrip({
    required this.titleLeft,
    this.rightChild,
    this.darkText = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = darkText ? Colors.black : Colors.white;
    return Row(
      children: [
        Expanded(
          child: Text(
            titleLeft,
            style: TextStyle(
              color: color,
              fontSize: 16.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (rightChild != null) rightChild!,
      ],
    );
  }
}

/// Reloj y fecha en vivo; solo este widget se redibuja cada segundo.
class _LiveReloj extends StatefulWidget {
  final bool darkText;
  const _LiveReloj({this.darkText = false});

  @override
  State<_LiveReloj> createState() => _LiveRelojState();
}

class _LiveRelojState extends State<_LiveReloj> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final hora = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    final fecha = '${two(now.day)}/${two(now.month)}/${now.year}';
    final color = widget.darkText ? Colors.black : Colors.white;
    final sub = widget.darkText ? Colors.black54 : Colors.white70;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          hora,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        Text(fecha, style: TextStyle(color: sub, fontSize: 12)),
      ],
    );
  }
}

/// Triángulo pequeño que apunta hacia abajo (para la burbuja del gráfico).
class _TrianglePointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..moveTo(size.width * 0.5, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Gráfico de barras con diseño limpio (sin fl_chart).
/// Al tocar una barra se muestra un texto arriba apuntando a la barra.
class _SimpleBarChart extends StatefulWidget {
  final List<String> labels;
  final List<double> values;
  final List<Color> colors;
  final double? maxY;
  final double chartHeight;
  final String Function(double) formatValue;

  const _SimpleBarChart({
    super.key,
    required this.labels,
    required this.values,
    required this.colors,
    this.maxY,
    this.chartHeight = 220,
    required this.formatValue,
  });

  @override
  State<_SimpleBarChart> createState() => _SimpleBarChartState();
}

class _SimpleBarChartState extends State<_SimpleBarChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final values = widget.values;
    final colors = widget.colors;
    final formatValue = widget.formatValue;
    if (values.isEmpty) return const SizedBox(height: 140);
    final maxVal = widget.maxY ?? (values.reduce((a, b) => a > b ? a : b));
    final safeMax = maxVal <= 0 ? 1.0 : maxVal * 1.12;
    const leftAxisWidth = 46.0;
    const hintHeight = 28.0;
    final barAreaHeight = widget.chartHeight - hintHeight - 12;

    return SizedBox(
      height: widget.chartHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: leftAxisWidth,
            height: barAreaHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [3, 2, 1, 0].map((i) {
                final frac = i / 3;
                final val = safeMax * frac;
                return Padding(
                  padding: const EdgeInsets.only(right: 6, top: 2, bottom: 2),
                  child: Text(
                    formatValue(val),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: barAreaHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      clipBehavior: Clip.none,
                      child: Stack(
                        children: [
                          ...List.generate(4, (i) {
                            final top = (i + 1) * (barAreaHeight / 4);
                            return Positioned(
                              left: 0,
                              right: 0,
                              top: top - 1,
                              child: Container(
                                height: 1,
                                color: Colors.grey.withValues(alpha: 0.15),
                              ),
                            );
                          }),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(values.length, (i) {
                                final v = values[i];
                                final h = safeMax > 0
                                    ? (v / safeMax) * (barAreaHeight - 16)
                                    : 0.0;
                                final barH = h.clamp(6.0, double.infinity);
                                final c = colors[i % colors.length];
                                const barWidth = 18.0;
                                const barSpacing = 10.0;
                                final isSelected = _selectedIndex == i;
                                return Padding(
                                  padding: EdgeInsets.only(
                                    right: i < values.length - 1
                                        ? barSpacing
                                        : 0,
                                  ),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        _selectedIndex = _selectedIndex == i
                                            ? null
                                            : i;
                                      });
                                    },
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.bottomCenter,
                                      children: [
                                        SizedBox(
                                          width: barWidth,
                                          height: barH,
                                          child: Container(
                                            width: barWidth,
                                            height: barH,
                                            decoration: BoxDecoration(
                                              color: c,
                                              border: Border.all(
                                                color:
                                                    Color.lerp(
                                                      c,
                                                      Colors.black,
                                                      0.2,
                                                    ) ??
                                                    c,
                                                width: 1,
                                              ),
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topLeft: Radius.circular(6),
                                                    topRight: Radius.circular(
                                                      6,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          Positioned(
                                            bottom: barH + 6,
                                            child: UnconstrainedBox(
                                              alignment: Alignment.bottomCenter,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 5,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withValues(
                                                                alpha: 0.1,
                                                              ),
                                                          blurRadius: 4,
                                                          offset: const Offset(
                                                            0,
                                                            1,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Text(
                                                      formatValue(v),
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors
                                                                .grey[900],
                                                          ),
                                                      maxLines: 1,
                                                      softWrap: false,
                                                    ),
                                                  ),
                                                  CustomPaint(
                                                    size: const Size(12, 6),
                                                    painter:
                                                        _TrianglePointerPainter(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: List.generate(values.length, (i) {
                    final name = labels.length > i ? labels[i] : '';
                    final short = name.length > 14
                        ? '${name.substring(0, 14)}...'
                        : name;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colors[i % colors.length],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          short,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Análisis de ingresos por sector (datos reales desde AdminEstadisticasService).
class _AnalisisSectoresWidget extends StatelessWidget {
  final List<Map<String, dynamic>> sectores;

  const _AnalisisSectoresWidget({required this.sectores});

  String _formatearMontoSector(double monto) {
    return '\$${monto.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    if (sectores.isEmpty) {
      return Center(
        child: Text(
          'Aún no hay ventas por sector',
          style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
        ),
      );
    }

    final topItems = sectores.take(12).toList();
        final maxTotal = topItems.isEmpty
            ? 1.0
            : (topItems
                  .map((e) => e['total'] as double)
                  .reduce((a, b) => a > b ? a : b));
        const sectorBarColors = [
          Color(0xFF6B4D2F),
          Color(0xFFDABF41),
          Color(0xFF2B2B2B),
          Colors.green,
          Colors.teal,
          Colors.blueGrey,
          Colors.orange,
          Colors.deepPurple,
          Colors.indigo,
          Colors.brown,
          Colors.cyan,
          Colors.pink,
        ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SimpleBarChart(
              key: const ValueKey('chart_sectores'),
              chartHeight: 260,
              labels: topItems
                  .map((e) => e['nombreSector'] as String? ?? '')
                  .toList(),
              values: topItems.map((e) => e['total'] as double).toList(),
              colors: sectorBarColors,
              maxY: maxTotal * 1.15,
              formatValue: _formatearMontoSector,
            ),
          ],
        ),
      ),
    );
  }
}

// Ingresos por evento (datos reales desde AdminEstadisticasService).
class _EventosIngresosWidget extends StatelessWidget {
  final List<Map<String, dynamic>> ingresos;

  const _EventosIngresosWidget({required this.ingresos});

  String _formatearMonto(double monto) {
    return '\$${monto.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final conDatos =
        ingresos.where((e) => (e['ingresos'] as double? ?? 0) > 0).toList();
    if (conDatos.isEmpty) {
      return Center(
        child: Text(
          'Aún no hay ventas por partido',
          style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
        ),
      );
    }

    final eventos = conDatos;
    final maxIngreso = eventos
        .map((e) => e['ingresos'] as double)
        .reduce((a, b) => a > b ? a : b);
    const barColors = [
      Color(0xFFDABF41),
      Color(0xFF6B4D2F),
      Color(0xFF2B2B2B),
      Colors.green,
      Colors.teal,
      Colors.blueGrey,
      Colors.orange,
      Colors.deepPurple,
    ];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SimpleBarChart(
              key: const ValueKey('chart_eventos'),
              chartHeight: 220,
              labels: eventos
                  .map((e) => e['nombre'] as String? ?? '')
                  .toList(),
              values: eventos.map((e) => e['ingresos'] as double).toList(),
              colors: barColors,
              maxY: maxIngreso * 1.15,
              formatValue: _formatearMonto,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: eventos.asMap().entries.map((e) {
                final i = e.key;
                final nombre = e.value['nombre'] as String;
                final ing = e.value['ingresos'] as double;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: barColors[i % barColors.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${nombre.length > 15 ? '${nombre.substring(0, 15)}...' : nombre}: ${_formatearMonto(ing)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[700],
                      ),
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
}
