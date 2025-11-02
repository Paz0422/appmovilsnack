import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/widgets/panel_ventas.dart';
import 'package:front_appsnack/widgets/stock_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeVendedor extends StatefulWidget {
  final String eventId;
  final String sectorId;
  final String nombreSector;

  const HomeVendedor({
    super.key,
    required this.eventId,
    required this.sectorId,
    required this.nombreSector,
  });

  @override
  State<HomeVendedor> createState() => _HomeVendedorState();
}

class _HomeVendedorState extends State<HomeVendedor> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Paleta de colores basada en el logo "Fusión"
  final Color primaryColor = const Color(0xFF2B2B2B); // Negro/marrón oscuro
  final Color accentColor = const Color(0xFFDABF41); // Dorado brillante
  final Color secondaryColor = const Color(0xFF6B4D2F); // Marrón medio
  final Color backgroundColor = const Color(0xFFFDFBF7); // Fondo claro elegante

  // Variables para estadísticas dinámicas
  Map<String, dynamic> _sectorStats = {};
  DateTime _currentTime = DateTime.now();
  late final String _currentSectorNombre;
  late final String _currentSectorId;
  bool _stockInicialAgregado = false;

  @override
  void initState() {
    super.initState();
    _currentSectorNombre = widget.nombreSector;
    _currentSectorId = widget.sectorId;
    _loadSectorStats();
    _startTimer();
    _verificarStockInicial();
  }

  Future<void> _verificarStockInicial() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventId)
          .collection('sectores')
          .doc(_currentSectorId)
          .collection('stockInicial')
          .get();

      if (mounted) {
        setState(() {
          _stockInicialAgregado = snapshot.docs.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint("Error verificando stock inicial: $e");
    }
  }

  void _startTimer() {
    // Actualizar la hora cada segundo
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
        _startTimer(); // Continuar el timer
      }
    });
  }

  Future<void> _loadSectorStats() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventId)
          .collection('sectores')
          .doc(_currentSectorId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final num totalVendido = data['totalVendido'] as num? ?? 0.0;
        final int productosVendidos = data['productosVendidos'] as int? ?? 0;
        final num promedio = productosVendidos > 0
            ? totalVendido / productosVendidos
            : 0.0;

        setState(() {
          _sectorStats = {
            'totalVendido': '\$${totalVendido.toStringAsFixed(0)}',
            'productosVendidos': productosVendidos.toString(),
            'promedio': '\$${promedio.toStringAsFixed(0)}',
          };
        });
      }
    } catch (e) {
      debugPrint("Error cargando estadísticas del sector: $e");
      // Opcional: Mostrar un SnackBar al usuario
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar estadísticas: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Limpiar el timer cuando se cierre la pantalla
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/imagenes/logo.png", height: 35),
            const SizedBox(width: 10),
            Text(
              'Panel de Vendedor',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: accentColor,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
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
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reloj en tiempo real
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sector:',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: secondaryColor,
                            ),
                          ),
                          Text(
                            _currentSectorNombre,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')}',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                          Text(
                            '${_currentTime.day.toString().padLeft(2, '0')}/${_currentTime.month.toString().padLeft(2, '0')}/${_currentTime.year}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: secondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildMainSaleCard(),
                const SizedBox(height: 20),
                _buildActionButtons(),
                const SizedBox(height: 30),
                Text(
                  'Estadísticas del Sector',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildFloatingStats(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _stockInicialAgregado
                  ? _agregarStockFinal
                  : _agregarStockInicial,
              icon: Icon(
                _stockInicialAgregado
                    ? Icons.inventory_2
                    : Icons.add_box,
                size: 18,
              ),
              label: Text(
                _stockInicialAgregado
                    ? 'Stock Final'
                    : 'Stock Inicial',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _stockInicialAgregado
                    ? Colors.blue
                    : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _escanearCodigoBarras,
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: Text(
                'Escanear',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: secondaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _cerrarTurno,
              icon: const Icon(Icons.logout, size: 18),
              label: Text(
                'Cerrar Turno',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainSaleCard() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor, // Dorado
            secondaryColor, // Marrón medio
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PanelVentas(
                  eventoId: widget.eventId,
                  nombreSector: _currentSectorNombre,
                  sectorId: _currentSectorId,
                ),
              ),
            );

            // Si el resultado de PanelVentas es 'true', significa que se realizó una venta
            if (result == true) {
              _loadSectorStats();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.point_of_sale_outlined,
                  size: 60,
                  color: Colors.white,
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

  Widget _buildFloatingStats() {
    return Column(
      children: [
        // Estadística principal - Total Vendido
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 30),
          child: Column(
            children: [
              Text(
                'Total Vendido',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: secondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Icon(
                Icons.emoji_events, // Icono de copa 🏆
                color: accentColor,
                size: 32,
              ),
              Text(
                _sectorStats['totalVendido'] ?? '\$0',
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
        // Dos estadísticas pequeñas flotantes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildFloatingStatItem(
              icon: Icons.inventory_2,
              title: 'Productos Vendidos',
              value: _sectorStats['productosVendidos'] ?? '0',
            ),
            _buildFloatingStatItem(
              icon: Icons.trending_up,
              title: 'Promedio',
              value: _sectorStats['promedio'] ?? '\$0',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFloatingStatItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: accentColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: secondaryColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
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
                    'Vendedor',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentSectorNombre,
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

  void _agregarStockInicial() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StockScreen(
          eventoId: widget.eventId,
          nombreSector: _currentSectorNombre,
          sectorId: _currentSectorId,
          esStockInicial: true,
        ),
      ),
    );

    if (result == true) {
      await _verificarStockInicial();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stock inicial configurado exitosamente',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _agregarStockFinal() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StockScreen(
          eventoId: widget.eventId,
          nombreSector: _currentSectorNombre,
          sectorId: _currentSectorId,
          esStockInicial: false,
        ),
      ),
    );

    if (result == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stock final configurado exitosamente',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _escanearCodigoBarras() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Función de escaneo de código de barras - Próximamente',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: secondaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _cerrarTurno() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Cerrar Turno',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          content: Text(
            '¿Estás seguro de que quieres cerrar el turno?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(color: secondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Turno cerrado exitosamente',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: primaryColor,
              ),
              child: Text(
                'Cerrar Turno',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
