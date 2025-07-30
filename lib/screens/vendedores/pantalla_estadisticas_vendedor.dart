import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/auth_manager.dart';

class PantallaEstadisticasVendedor extends StatelessWidget {
  const PantallaEstadisticasVendedor({super.key});

  @override
  Widget build(BuildContext context) {
    final vendorData =
        AuthManager().loggedInVendor?.data() as Map<String, dynamic>?;

    final String vendorName = vendorData?['nombre'] ?? 'Vendedor';
    final int itemsSold = vendorData?['itemsVendidos'] ?? 0;
    final double totalSold = (vendorData?['totalVendido'] ?? 0).toDouble();
    final double commission = totalSold * 0.10;

    return Scaffold(
      appBar: AppBar(title: Text('Estadísticas de $vendorName')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatCard(
              title: 'Total Vendido',
              value: '\$${totalSold.toStringAsFixed(0)}',
              icon: Icons.attach_money,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              title: 'Items Vendidos',
              value: itemsSold.toString(),
              icon: Icons.shopping_bag,
              color: const Color.fromARGB(255, 3, 90, 161),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40.0, color: color),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
