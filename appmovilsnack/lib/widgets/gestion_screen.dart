// Pantalla principal de Gestión con módulos

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/widgets/inventory_management.dart';
import 'package:front_appsnack/widgets/asignacion_personal.dart';
import 'package:front_appsnack/widgets/eventos_management.dart';

class GestionScreen extends StatelessWidget {
  const GestionScreen({super.key});

  static const _primaryColor = Color(0xFF2B2B2B);
  static const _accentColor = Color(0xFFDABF41);
  static const _secondaryColor = Color(0xFF6B4D2F);
  static const _backgroundColor = Color(0xFFFDFBF7);

  @override
  Widget build(BuildContext context) {
    final modulos = [
      _ModuloItem(
        title: 'Productos',
        descripcion: 'Inventario y precios',
        icon: Icons.inventory_2_outlined,
        color: _accentColor,
        onTap: (context) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const InventoryManagement(),
          ),
        ),
      ),
      _ModuloItem(
        title: 'Personal',
        descripcion: 'Empleados y asignación',
        icon: Icons.people_outline_rounded,
        color: _accentColor,
        onTap: (context) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AsignacionPersonal(),
          ),
        ),
      ),
      _ModuloItem(
        title: 'Eventos',
        descripcion: 'Eventos y sectores',
        icon: Icons.event_rounded,
        color: _secondaryColor,
        onTap: (context) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const EventosManagement(),
          ),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          'Gestión',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: _accentColor,
          ),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: _accentColor,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final ancho = constraints.maxWidth;
          final columnas = ancho >= 900 ? 3 : 2;
          final padding = ancho >= 600 ? 24.0 : 16.0;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ancho >= 600 ? 820 : double.infinity,
              ),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnas,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: columnas == 3 ? 1.05 : 0.95,
                  ),
                  itemCount: modulos.length,
                  itemBuilder: (context, index) => _ModuloCard(
                    item: modulos[index],
                    primaryColor: _primaryColor,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModuloItem {
  final String title;
  final String descripcion;
  final IconData icon;
  final Color color;
  final void Function(BuildContext context) onTap;

  const _ModuloItem({
    required this.title,
    required this.descripcion,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _ModuloCard extends StatelessWidget {
  final _ModuloItem item;
  final Color primaryColor;

  const _ModuloCard({
    required this.item,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => item.onTap(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.outline.withValues(alpha: 0.55),
            ),
            boxShadow: AppShadows.card,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(item.icon, size: 28, color: item.color),
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.descripcion,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
