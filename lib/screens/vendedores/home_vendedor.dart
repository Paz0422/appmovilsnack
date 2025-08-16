import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:front_appsnack/screens/panel_ventas.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeVendedor extends StatefulWidget {
  final String eventId;
  final String nombreSector;

  const HomeVendedor({
    super.key,
    required this.eventId,
    required this.nombreSector,
  });

  @override
  State<HomeVendedor> createState() => _HomeVendedorState();
}

class _HomeVendedorState extends State<HomeVendedor> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const Color colorPrimarioAmarillo = Color(0xFFFFC107);
  static const Color colorPrimarioNegro = Color(0xFF121212);
  static const Color colorFondo = Color(0xFFF5F5F5);
  static const Color colorTextoNegro = Color(0xFF212121);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colorFondo,
      appBar: AppBar(
        title: Text(
          'Panel de Vendedor',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: colorPrimarioAmarillo,
          ),
        ),
        backgroundColor: colorPrimarioNegro,
        foregroundColor: colorPrimarioAmarillo,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      endDrawer: _buildDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sector: ${widget.nombreSector}',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorTextoNegro,
              ),
            ),
            const SizedBox(height: 20),
            _buildMainSaleCard(),
            const SizedBox(height: 30),
            Text(
              'Estadísticas del Sector',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorTextoNegro,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatisticsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainSaleCard() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [colorPrimarioNegro, Color(0xFF212121)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PanelVentas(
                  eventoId: widget.eventId,
                  nombreSector: widget.nombreSector,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.point_of_sale_outlined,
                  size: 60,
                  color: colorPrimarioAmarillo,
                ),
                const SizedBox(height: 16),
                Text(
                  'Realizar Venta',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Toca para comenzar una nueva venta',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsGrid() {
    return Column(
      children: [
        // Estadística principal grande
        _buildMainStatCard(
          title: 'Total Vendido',
          value: '\$7,234.50',
          icon: Icons.attach_money_outlined,
        ),
        const SizedBox(height: 20),

        // Tres estadísticas pequeñas en fila
        Row(
          children: [
            Expanded(
              child: _buildSmallStatCard(
                title: 'Productos',
                value: '342',
                icon: Icons.inventory_2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallStatCard(
                title: 'Fecha',
                value: '23/12',
                icon: Icons.calendar_today,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallStatCard(
                title: 'Promedio',
                value: '\$45.20',
                icon: Icons.trending_up,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: colorPrimarioAmarillo),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: colorTextoNegro,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: colorPrimarioAmarillo),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorTextoNegro,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: colorPrimarioNegro,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.transparent),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: colorPrimarioAmarillo,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: colorPrimarioNegro,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Vendedor',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    widget.nombreSector,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
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
      leading: Icon(icon, color: colorPrimarioAmarillo, size: 24),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      onTap: onTap,
      hoverColor: colorPrimarioAmarillo.withOpacity(0.1),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature - Próximamente disponible',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: colorPrimarioNegro,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
