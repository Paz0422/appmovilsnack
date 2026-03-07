import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/widgets/panel_ventas.dart';
import 'package:front_appsnack/widgets/gestion_stock.dart';
import 'package:front_appsnack/widgets/registro_merma.dart';
import 'package:front_appsnack/widgets/bandejeo_flow.dart';
import 'package:front_appsnack/widgets/estadio_selection.dart';
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
  // Paleta de colores basada en el logo "Fusión"
  final Color primaryColor = const Color(0xFF2B2B2B); // Negro/marrón oscuro
  final Color accentColor = const Color(0xFFDABF41); // Dorado brillante
  final Color secondaryColor = const Color(0xFF6B4D2F); // Marrón medio
  final Color backgroundColor = const Color(0xFFFDFBF7); // Fondo claro elegante

  // Variables para estadísticas dinámicas
  DateTime _currentTime = DateTime.now();
  late final String _currentSectorNombre;
  late final String _currentSectorId;
  bool _stockInicialAgregado = false;
  String? _nombreEvento;

  @override
  void initState() {
    super.initState();
    _currentSectorNombre = widget.nombreSector;
    _currentSectorId = widget.sectorId;
    _startTimer();
    _verificarStockInicial();
    _cargarNombreEvento();
  }

  Future<void> _cargarNombreEvento() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _nombreEvento = data?['nombre'] as String? ?? widget.eventId;
        });
      } else if (mounted) {
        setState(() {
          _nombreEvento = widget.eventId;
        });
      }
    } catch (e) {
      debugPrint("Error cargando nombre del evento: $e");
      if (mounted) {
        setState(() {
          _nombreEvento = widget.eventId;
        });
      }
    }
  }

  Future<void> _verificarStockInicial() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventId)
          .collection('sectores')
          .doc(_currentSectorId)
          .collection('stock')
          .get();

      if (mounted) {
        setState(() {
          _stockInicialAgregado = snapshot.docs.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint("Error verificando stock: $e");
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


  @override
  void dispose() {
    // Limpiar el timer cuando se cierre la pantalla
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Evento:',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: secondaryColor,
                                ),
                              ),
                              Text(
                                _nombreEvento ?? widget.eventId,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
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
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildMainSaleCard(),
                const SizedBox(height: 20),
                _buildActionButtons(),
                const SizedBox(height: 30),
                _buildQuickAccessPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accesos rápidos',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildQuickActionTile(
                icon: Icons.inventory_2_outlined,
                title: 'Bandejeo',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BandejeoFlow(
                        eventoId: widget.eventId,
                        sectorId: _currentSectorId,
                        nombreSector: _currentSectorNombre,
                      ),
                    ),
                  );
                },
              ),
              _buildQuickActionTile(
                icon: Icons.delete_outline,
                title: 'Merma',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RegistroMerma(
                        eventoId: widget.eventId,
                        sectorId: _currentSectorId,
                        nombreSector: _currentSectorNombre,
                      ),
                    ),
                  );
                },
              ),
              _buildQuickActionTile(
                icon: Icons.event_outlined,
                title: 'Cambiar evento',
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EstadioSelection(),
                    ),
                  );
                },
              ),
              _buildQuickActionTile(
                icon: Icons.logout_outlined,
                title: 'Cerrar sesión',
                danger: true,
                onTap: () async {
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
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final Color tileColor =
        danger ? Colors.red.withValues(alpha: 0.08) : backgroundColor;
    final Color borderColor =
        danger ? Colors.red.withValues(alpha: 0.25) : accentColor.withValues(alpha: 0.35);
    final Color iconColor = danger ? Colors.red : accentColor;

    return Material(
      color: tileColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Toca para abrir',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: secondaryColor.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
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
                _stockInicialAgregado ? Icons.inventory_2 : Icons.add_box,
                size: 18,
              ),
              label: Text(
                'Gestionar Stock',
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

            // Si el resultado de PanelVentas contiene información actualizada del sector
            if (result != null && result['actualizado'] == true) {
              setState(() {
                _currentSectorNombre = result['sectorNombre'] as String;
                _currentSectorId = result['sectorId'] as String;
              });
              await _verificarStockInicial();
            } else if (result == true) {
              // Si solo se indica una venta exitosa sin cambio de sector
              await _verificarStockInicial();
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

  void _agregarStockInicial() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GestionStock(
          eventoId: widget.eventId,
          nombreSector: _currentSectorNombre,
          sectorId: _currentSectorId,
        ),
      ),
    );

    await _verificarStockInicial();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stock actualizado',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _agregarStockFinal() async {
    // Ya no hay distinción entre stock inicial y final
    // Usamos la misma función
    _agregarStockInicial();
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
            '¿Estás seguro de que quieres cerrar el turno? No se podra realizar ninguna venta despues de cerrar el turno',
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
