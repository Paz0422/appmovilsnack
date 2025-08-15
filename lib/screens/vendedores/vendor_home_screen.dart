import 'package:flutter/material.dart';
import 'package:front_appsnack/screens/estadio_selection.dart';
import 'package:front_appsnack/auth/login_screen.dart'; // Para cerrar sesión
import 'package:firebase_auth/firebase_auth.dart';

class HomeVendedor extends StatefulWidget {
  final String eventId;
  // Más adelante, aquí recibiremos los datos del evento desde la pantalla de login
  const HomeVendedor({super.key, required this.eventId});

  @override
  State<HomeVendedor> createState() => _HomeVendedorState();
}

class _HomeVendedorState extends State<HomeVendedor> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Vendedor'),
        automaticallyImplyLeading: false,
      ),
      // Usamos padding para dar un poco de espacio en los bordes
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        // PASO 1: Añadir el GridView para la cuadrícula
        child: GridView.count(
          crossAxisCount: 2, // 2 columnas
          crossAxisSpacing: 16, // Espacio horizontal entre tarjetas
          mainAxisSpacing: 16, // Espacio vertical entre tarjetas
          children: [
            _buildMenuCard(
              context: context,
              title: 'Elegir estadio',
              icon: Icons.stadium_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EstadioSelection(),
                  ),
                );
              },
            ),
            _buildMenuCard(
              context: context,
              title: 'Cerrar Sesión',
              icon: Icons.logout_outlined,
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                // 2. Navega de vuelta al Login y elimina el historial de pantallas
                //    El 'if (mounted)' es una buena práctica para evitar errores.
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

  Widget _buildMenuCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color.fromARGB(255, 255, 222, 114),
      elevation: 10.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(45.0)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(45.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 50.0, color: const Color.fromARGB(176, 0, 0, 0)),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
