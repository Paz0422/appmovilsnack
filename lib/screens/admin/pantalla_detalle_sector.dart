import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PantallaDetalleSector extends StatelessWidget {
  final String eventId;
  final String sectorName;

  const PantallaDetalleSector({
    super.key,
    required this.eventId,
    required this.sectorName,
  });

  @override
  Widget build(BuildContext context) {
    // Consulta que filtra los vendedores por el sector específico
    final Stream<QuerySnapshot> vendorsStream = FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventId)
        .collection('vendedores')
        .where('sector', isEqualTo: sectorName) // <-- El filtro clave
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text('Ranking Sector: $sectorName')),
      body: StreamBuilder<QuerySnapshot>(
        stream: vendorsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar vendedores.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Image.asset('assets/imagenes/logo.png', width: 100),
            );
          }

          return ListView(
            children: snapshot.data!.docs.map((document) {
              Map<String, dynamic> data =
                  document.data()! as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(
                    data['nombre'] ?? 'Sin nombre',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Items vendidos: ${data['itemsVendidos'] ?? 0}',
                  ),
                  trailing: Text(
                    '\$${data['totalVendido'] ?? 0}',
                    style: const TextStyle(fontSize: 16, color: Colors.green),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
