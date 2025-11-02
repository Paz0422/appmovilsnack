// lib/home_admin.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:front_appsnack/auth/login_screen.dart';
import 'package:front_appsnack/widgets/dashboard_card.dart';
import 'package:front_appsnack/widgets/revenue_chart.dart'
    show RevenueChart, ChartRange;
import 'package:google_fonts/google_fonts.dart';

class HomeAdmin extends StatefulWidget {
  const HomeAdmin({super.key});

  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {
  Future<int> _getMontoTotal() async {
    try {
      final salesSnapshot = await FirebaseFirestore.instance
          .collection('transacciones')
          .get();
      int total = 0;
      for (var doc in salesSnapshot.docs) {
        final data = doc.data();
        final montoTotal = data['montoTotal'];

        // Manejar diferentes tipos de datos de Firestore
        if (montoTotal == null) {
          continue;
        } else if (montoTotal is num) {
          total += montoTotal.toInt();
        } else if (montoTotal is int) {
          total += montoTotal;
        } else if (montoTotal is double) {
          total += montoTotal.toInt();
        }
      }
      return total;
    } catch (e) {
      // Re-lanzar el error para que FutureBuilder pueda manejarlo
      throw e;
    }
  }

  // Paleta de colores para el drawer
  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      // 🔹 Drawer (menú hamburguesa)
      drawer: _buildDrawer(),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // Al tener drawer, el ícono de hamburguesa aparece solo
        title: const Text(
          'Panel de Administración',
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderStrip(
              titleLeft: 'Resumen Global',
              titleRight: _relojAhora(),
              subtitleRight: _fechaCorta(),
              darkText: true,
            ),
            const SizedBox(height: 12),

            const Text(
              'Total Vendido',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),

            // ✅ Opción A: forzar ancho completo
            SizedBox(
              width: double.infinity,
              child: FutureBuilder<int>(
                future: _getMontoTotal(),
                builder: (context, snapshot) {
                  String value;
                  IconData icon = Icons.emoji_events;
                  Color color = Colors.amber;

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    value = '—';
                  } else if (snapshot.hasError) {
                    value = 'Error';
                    icon = Icons.error_outline;
                    color = Colors.red;
                  } else {
                    final total = snapshot.data ?? 0;
                    value = '\$${_fmtMiles(total)}';
                  }

                  // Usa tu DashboardCard (vertical, protagónico)
                  return DashboardCard(
                    title: 'Suma de transacciones',
                    value: value,
                    subtitle: 'Actualizado ahora',
                    icon: icon,
                    color: color,
                    darkText: true,
                    backgroundColor: Colors.white,
                    elevation: 6,
                    emphasis: true,
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Revenue Charts - Semanal y Mensual
            const Text(
              'Análisis de Transacciones',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            // Gráfico Semanal
            const RevenueChart(range: ChartRange.weekly),

            const SizedBox(height: 16),

            // Gráfico Mensual
            const RevenueChart(range: ChartRange.monthly),

            const SizedBox(height: 24),

            const Text(
              'Estadísticas Rápidas',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),

            LayoutBuilder(
              builder: (context, c) {
                final isNarrow = c.maxWidth < 360;
                final cross = isNarrow ? 1 : 2;

                return GridView.count(
                  crossAxisCount: cross,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 3.0, // alto suficiente

                  children: [
                    DashboardCard(
                      title: 'Productos',
                      value: '456',
                      icon: Icons.inventory_2_outlined,
                      color: Colors.black54,
                      darkText: true,
                      backgroundColor: Colors.white,
                      borderColor: Colors.grey[300],
                      elevation: 0,
                      compact: true, // layout horizontal
                    ),
                    DashboardCard(
                      title: 'Usuarios',
                      value: '1,234',
                      icon: Icons.people_alt_outlined,
                      color: Colors.black54,
                      darkText: true,
                      backgroundColor: Colors.white,
                      borderColor: Colors.grey[300],
                      elevation: 0,
                      compact: true,
                    ),
                    DashboardCard(
                      title: 'Órdenes Pendientes',
                      value: '23',
                      icon: Icons.receipt_long_outlined,
                      color: Colors.black54,
                      darkText: true,
                      backgroundColor: Colors.white,
                      borderColor: Colors.grey[300],
                      elevation: 0,
                      compact: true,
                    ),
                    DashboardCard(
                      title: 'Promedio Ticket',
                      value: '\$0',
                      icon: Icons.trending_up,
                      color: Colors.black54,
                      darkText: true,
                      backgroundColor: Colors.white,
                      borderColor: Colors.grey[300],
                      elevation: 0,
                      compact: true,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _relojAhora() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  String _fechaCorta() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.day)}/${two(now.month)}/${now.year}';
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
            _buildDrawerItem(
              icon: Icons.bar_chart_outlined,
              title: 'Mis Estadísticas',
              onTap: () {
                Navigator.pop(context);
                _showComingSoon(context, 'Mis Estadísticas');
              },
            ),
            _buildDrawerItem(
              icon: Icons.inventory_2_outlined,
              title: 'Bandejeo',
              onTap: () {
                Navigator.pop(context);
                _showComingSoon(context, 'Bandejeo');
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
            // Espacio adicional al final para evitar overflow
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
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
      onTap: onTap,
      hoverColor: accentColor.withValues(alpha: 0.1),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature - Próximamente disponible',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ===== Componentes UI existentes =====

class _HeaderStrip extends StatelessWidget {
  final String titleLeft;
  final String titleRight;
  final String? subtitleRight;
  final bool darkText;
  const _HeaderStrip({
    required this.titleLeft,
    required this.titleRight,
    this.subtitleRight,
    this.darkText = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = darkText ? Colors.black : Colors.white;
    final sub = darkText ? Colors.black54 : Colors.white70;
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              titleRight,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            if (subtitleRight != null)
              Text(subtitleRight!, style: TextStyle(color: sub, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
