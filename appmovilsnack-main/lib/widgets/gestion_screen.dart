// Archivo: lib/widgets/gestion_screen.dart
// Pantalla principal de Gestión con módulos

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:front_appsnack/widgets/inventory_management.dart';
import 'package:front_appsnack/widgets/asignacion_stock.dart';
import 'package:front_appsnack/widgets/asignacion_personal.dart';
import 'package:front_appsnack/widgets/eventos_management.dart';

class GestionScreen extends StatelessWidget {
  const GestionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF2B2B2B);
    final Color accentColor = const Color(0xFFDABF41);
    final Color secondaryColor = const Color(0xFF6B4D2F);
    final Color backgroundColor = const Color(0xFFFDFBF7);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Gestión',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _ModuloCard(
              title: 'Productos',
              icon: Icons.inventory_2_outlined,
              color: accentColor,
              primaryColor: primaryColor,
              backgroundColor: backgroundColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const InventoryManagement(),
                  ),
                );
              },
            ),
            _ModuloCard(
              title: 'Stock',
              icon: Icons.assignment_outlined,
              color: accentColor,
              primaryColor: primaryColor,
              backgroundColor: backgroundColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AsignacionStock(),
                  ),
                );
              },
            ),
            _ModuloCard(
              title: 'Personal',
              icon: Icons.people_outline,
              color: accentColor,
              primaryColor: primaryColor,
              backgroundColor: backgroundColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AsignacionPersonal(),
                  ),
                );
              },
            ),
            _ModuloCard(
              title: 'Eventos',
              icon: Icons.event,
              color: secondaryColor,
              primaryColor: primaryColor,
              backgroundColor: backgroundColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EventosManagement(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuloCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color primaryColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _ModuloCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.primaryColor,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
