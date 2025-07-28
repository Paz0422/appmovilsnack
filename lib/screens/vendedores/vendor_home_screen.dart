import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'package:front_appsnack/screens/pantalla_detalle_evento.dart';
import 'package:front_appsnack/screens/vendedores/pantalla_estadisticas_vendedor.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login_screen.dart';

class VendorHomeScreen extends StatelessWidget {
  const VendorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel de Vendedor')),
      body: GridView.count(
        crossAxisCount: 2, // 2 columnas
        padding: const EdgeInsets.all(16.0),
        childAspectRatio: 1.0, // Hace que los cuadrados sean cuadrados
        mainAxisSpacing: 10.0,
        crossAxisSpacing: 10.0,
        children: <Widget>[
          _buildMenuCard(
            context: context,
            icon: Icons.point_of_sale,
            title: 'Realizar Venta',
            onTap: () {
              final vendorData =
                  AuthManager().loggedInVendor?.data() as Map<String, dynamic>?;

              if (vendorData != null) {
                final String eventId = vendorData['idEventoAsig'] ?? '';
                final String eventName =
                    vendorData['eventoAsignado'] ?? 'Evento';

                // Navegamos a la pantalla de detalle, pasándole los datos del evento
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventDetailScreen(
                      eventName: eventName,
                      eventId: eventId,
                    ),
                  ),
                );
              }
            },
          ),
          _buildMenuCard(
            context: context,
            icon: Icons.bar_chart,
            title: 'Mis Estadísticas',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PantallaEstadisticasVendedor(),
                ),
              );
            },
          ),
          _buildMenuCard(
            context: context,
            icon: Icons.inventory,
            title: 'Ver Stock',
            onTap: () {
              // Es la misma lógica que 'Realizar Venta'
              final vendorData =
                  AuthManager().loggedInVendor?.data() as Map<String, dynamic>?;

              if (vendorData != null) {
                final String eventId = vendorData['idEventoAsig'] ?? '';
                final String eventName =
                    vendorData['eventoAsignado'] ?? 'Evento';

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventDetailScreen(
                      eventName: eventName,
                      eventId: eventId,
                    ),
                  ),
                );
              }
            },
          ),
          _buildMenuCard(
            context: context,
            icon: Icons.logout,
            title: 'Finalizar Turno',
            onTap: () async {
              // 1. Cerramos la sesión en Firebase
              await FirebaseAuth.instance.signOut();

              // 2. Navegamos de vuelta al Login y eliminamos las pantallas anteriores
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) =>
                      false, // Esta línea borra el historial
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // Widget helper para no repetir código
  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 50.0, color: Theme.of(context).primaryColor),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
