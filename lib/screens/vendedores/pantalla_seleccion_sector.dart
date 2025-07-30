import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/screens/vendedores/vendor_home_screen.dart';

class PantallaSeleccionSector extends StatelessWidget {
  final String eventId;
  final String eventName;

  final Map<String, dynamic> puntosDeVenta;

  const PantallaSeleccionSector({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.puntosDeVenta,
  });

  @override
  Widget build(BuildContext context) {
    // Nueva consulta que lee la sub-colección 'sectores'
    final Stream<QuerySnapshot> sectoresStream = FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventId)
        .collection('sectores')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Selecciona tu Sector')),
      body: StreamBuilder<QuerySnapshot>(
        stream: sectoresStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar sectores.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay sectores definidos.'));
          }

          // Tomamos el primer (y único) documento de la sub-colección
          final sectorData =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
          final puntosDeVenta = sectorData.entries.toList();

          return ListView.builder(
            itemCount: puntosDeVenta.length,
            itemBuilder: (context, index) {
              final sector = puntosDeVenta[index];
              final sectorName = sector.key;
              final subPuntos = List<String>.from(sector.value);

              return ExpansionTile(
                title: Text(
                  sectorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                children: subPuntos.map((punto) {
                  return ListTile(
                    title: Text(punto),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VendorHomeScreen(),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}
