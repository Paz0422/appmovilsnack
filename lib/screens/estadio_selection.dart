import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:front_appsnack/screens/sector_selection_screen.dart'; // La nueva pantalla que crearemos

// Nota: Para que sea más claro, podrías renombrar este archivo a "evento_selection_screen.dart" en el futuro.

class EstadioSelection extends StatefulWidget {
  const EstadioSelection({super.key});

  @override
  State<EstadioSelection> createState() => _EstadioSelectionState();
}

class _EstadioSelectionState extends State<EstadioSelection> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elige un Evento'),
        backgroundColor: const Color.fromARGB(255, 218, 188, 20),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('eventos')
            .where('activo', isEqualTo: true)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay eventos activos.'));
          }

          final eventos = snapshot.data!.docs;

          return ListView.builder(
            itemCount: eventos.length,
            itemBuilder: (context, index) {
              final eventoDoc = eventos[index];
              final eventoData = eventoDoc.data() as Map<String, dynamic>;
              final nombreEvento = eventoData['nombre'] ?? 'Sin nombre';
              final ubicacionEvento =
                  eventoData['ubicacion'] ?? 'Sin ubicación';

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(nombreEvento),
                  subtitle: Text(ubicacionEvento),
                  onTap: () {
                    // Al tocar un evento, vamos a la pantalla de sectores de ESE evento
                    /* Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SectorSelectionScreen(eventId: eventoDoc.id),
                      ),
                    );*/
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
