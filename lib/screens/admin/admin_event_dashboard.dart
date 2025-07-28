import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'pantalla_detalle_sector.dart';

class AdminEventDashboard extends StatelessWidget {
  final String eventId;
  final String eventName;

  const AdminEventDashboard({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  Widget build(BuildContext context) {
    final Stream<QuerySnapshot> vendorsStream = FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventId)
        .collection('vendedores')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text('Dashboard: $eventName')),
      body: StreamBuilder<QuerySnapshot>(
        stream: vendorsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar datos.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Image.asset('assets/imagenes/logo.png', width: 100),
            );
          }

          // Lógica para agrupar las ventas por sector
          final vendors = snapshot.data!.docs;
          final Map<String, double> salesBySector = {};

          for (var vendor in vendors) {
            final data = vendor.data() as Map<String, dynamic>;
            final sector = data['sector'] ?? 'Sin Sector';
            final totalSold = (data['totalVendido'] ?? 0).toDouble();

            salesBySector[sector] = (salesBySector[sector] ?? 0) + totalSold;
          }

          final sectors = salesBySector.entries.toList();

          return ListView.builder(
            itemCount: sectors.length,
            itemBuilder: (context, index) {
              final sector = sectors[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    sector.key,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Text(
                    '\$${sector.value.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PantallaDetalleSector(
                          eventId: eventId,
                          sectorName:
                              sector.key, // Pasamos el nombre del sector
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
