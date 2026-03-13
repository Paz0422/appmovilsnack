// lib/home_admin.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:front_appsnack/auth/login_screen.dart';
import 'package:front_appsnack/widgets/dashboard_card.dart';
import 'package:front_appsnack/widgets/revenue_chart.dart'
    show RevenueChart, ChartRange;
import 'package:front_appsnack/widgets/gestion_screen.dart';
import 'package:front_appsnack/widgets/stock_reports.dart';
import 'package:front_appsnack/widgets/transaction_reports.dart';
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

            // Ingresos por Evento - Widget scrolleable vertical
            const Text(
              'Ingresos por Evento',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            
            SizedBox(
              height: 300,
              child: _EventosIngresosWidget(),
            ),

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
              icon: Icons.settings_outlined,
              title: 'Gestión',
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
              icon: Icons.receipt_long_outlined,
              title: 'Reportes de Transacciones',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TransactionReports(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.shopping_basket_outlined,
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

// Widget scrolleable de ingresos por evento
class _EventosIngresosWidget extends StatelessWidget {
  const _EventosIngresosWidget();

  Future<List<Map<String, dynamic>>> _cargarIngresosPorEvento() async {
    try {
      // Obtener todos los eventos
      final eventosSnapshot = await FirebaseFirestore.instance
          .collection('eventos')
          .get();

      // Obtener todas las transacciones
      final transaccionesSnapshot = await FirebaseFirestore.instance
          .collection('transacciones')
          .get();

      // Crear mapa de ingresos por evento
      final Map<String, double> ingresosPorEvento = {};
      final Map<String, String> nombresEventos = {};

      // Inicializar mapas con eventos
      for (var eventoDoc in eventosSnapshot.docs) {
        final eventoId = eventoDoc.id;
        final eventoData = eventoDoc.data();
        nombresEventos[eventoId] = eventoData['nombre']?.toString() ?? 'Sin nombre';
        ingresosPorEvento[eventoId] = 0.0;
      }

      // Calcular ingresos por evento
      for (var transDoc in transaccionesSnapshot.docs) {
        final transData = transDoc.data();
        final eventoId = transData['eventoId']?.toString();
        
        if (eventoId != null && ingresosPorEvento.containsKey(eventoId)) {
          final montoTotal = transData['montoTotal'];
          double monto = 0.0;
          
          if (montoTotal != null) {
            if (montoTotal is num) {
              monto = montoTotal.toDouble();
            } else if (montoTotal is int) {
              monto = montoTotal.toDouble();
            } else if (montoTotal is double) {
              monto = montoTotal;
            }
          }
          
          ingresosPorEvento[eventoId] = (ingresosPorEvento[eventoId] ?? 0.0) + monto;
        }
      }

      // Convertir a lista y ordenar por ingresos descendente
      final List<Map<String, dynamic>> eventosIngresos = [];
      ingresosPorEvento.forEach((eventoId, ingresos) {
        eventosIngresos.add({
          'eventoId': eventoId,
          'nombre': nombresEventos[eventoId] ?? 'Sin nombre',
          'ingresos': ingresos,
        });
      });

      // Ordenar por ingresos descendente
      eventosIngresos.sort((a, b) => (b['ingresos'] as double).compareTo(a['ingresos'] as double));

      return eventosIngresos;
    } catch (e) {
      return [];
    }
  }

  String _formatearMonto(double monto) {
    return '\$${monto.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _cargarIngresosPorEvento(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              snapshot.hasError 
                  ? 'Error al cargar datos'
                  : 'No hay eventos disponibles',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          );
        }

        final eventos = snapshot.data!;

        return ListView.builder(
          scrollDirection: Axis.vertical,
          padding: const EdgeInsets.symmetric(horizontal: 0),
          itemCount: eventos.length,
          itemBuilder: (context, index) {
            final evento = eventos[index];
            final nombre = evento['nombre'] as String;
            final ingresos = evento['ingresos'] as double;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDABF41).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.event,
                          color: Color(0xFFDABF41),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2B2B2B),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ingresos totales',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatearMonto(ingresos),
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
