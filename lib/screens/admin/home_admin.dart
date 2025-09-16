// lib/home_admin.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/widgets/dashboard_card.dart';

class HomeAdmin extends StatefulWidget {
  const HomeAdmin({super.key});

  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {
  Future<int> _getMontoTotal() async {
    final salesSnapshot = await FirebaseFirestore.instance
        .collection('transacciones')
        .get();
    int total = 0;
    for (var doc in salesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['monto'] ?? 0) as int;
    }
    return total;
  }

  final Gradient _gold = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5D27B), Color(0xFFD4AF37), Color(0xFFB88912)],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      // 🔹 Drawer (menú hamburguesa)
      drawer: const _AdminDrawer(),

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

            _BigGradientCard(
              gradient: _gold,
              icon: Icons.insights,
              title: 'Indicadores del Sistema',
              subtitle: 'Toca para ver detalle de ventas, usuarios y stock',
              onTap: () {},
              darkText: true,
            ),
            const SizedBox(height: 20),

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

            const SizedBox(height: 16),

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
}

// ===== Drawer (menú hamburguesa) =====

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer();

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final bg = const Color(0xFF1E1F23); // fondo oscuro

    return Drawer(
      child: Container(
        color: bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 12,
              ),
              child: Column(
                children: const [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: gold,
                    child: Icon(Icons.person, size: 34, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Administrador',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Andes 1',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white24, height: 1),

            // Items
            _DrawerItem(
              icon: Icons.bar_chart_rounded,
              text: 'Mis Estadísticas',
              onTap: () {
                Navigator.pop(context);
                // TODO: navegar a estadísticas
              },
            ),
            _DrawerItem(
              icon: Icons.inbox_rounded,
              text: 'Bandejeo',
              onTap: () {
                Navigator.pop(context);
                // TODO: navegar a bandejeo
              },
            ),
            Divider(color: Colors.white24, height: 1),
            _DrawerItem(
              icon: Icons.logout_rounded,
              text: 'Cerrar Sesión',
              onTap: () async {
                Navigator.pop(context);
                // TODO: cerrar sesión
              },
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: gold, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        ),
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

class _BigGradientCard extends StatelessWidget {
  final Gradient gradient;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool darkText;

  const _BigGradientCard({
    required this.gradient,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.darkText = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = darkText ? Colors.black87 : Colors.white;

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 42, color: Colors.black.withOpacity(0.85)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.black87, size: 28),
        ],
      ),
    );

    return onTap == null
        ? child
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: child,
          );
  }
}
