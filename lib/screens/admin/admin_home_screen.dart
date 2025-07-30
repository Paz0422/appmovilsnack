import 'package:flutter/material.dart';
import 'package:front_appsnack/main.dart';
import 'package:front_appsnack/screens/home_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel de Administración')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          _buildMenuCard(
            context: context,
            icon: Icons.list_alt,
            title: 'Eventos Activos',
            onTap: () {
              // Navegar a la lista de eventos
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
          ),
          _buildMenuCard(
            context: context,
            icon: Icons.emoji_events,
            title: 'Ranking Vendedores',
            onTap: () {
              /* Lógica futura */
            },
          ),
          _buildMenuCard(
            context: context,
            icon: Icons.bar_chart,
            title: 'Estadísticas Partidos',
            onTap: () {
              /* Lógica futura */
            },
          ),
          _buildMenuCard(
            context: context,
            icon: Icons.calendar_today,
            title: 'Calendario Eventos',
            onTap: () {
              /* Lógica futura */
            },
          ),
          _buildMenuCard(
            context: context,
            icon: Icons.note_add,
            title: 'Bloc de Notas',
            onTap: () {
              /* Lógica futura */
            },
          ),
          _buildMenuCard(
            context: context,
            icon: Icons.logout,
            title: 'Cerrar Sesión',
            onTap: () {
              /* Lógica futura */
            },
          ),
        ],
      ),
    );
  }

  // Helper para crear las tarjetas del menú
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
