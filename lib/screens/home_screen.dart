import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'package:front_appsnack/screens/admin/admin_event_dashboard.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Stream<QuerySnapshot> eventsStream = FirebaseFirestore.instance
        .collection('eventos')
        .where('Estado', isEqualTo: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos Activos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: eventsStream,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Algo salió mal'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Image.asset('assets/imagenes/logo.png', width: 100),
            );
          }
          return ListView(
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              Map<String, dynamic> data =
                  document.data()! as Map<String, dynamic>;
              return ListTile(
                title: Text(data['nomevent'] ?? 'Sin nombre'),
                subtitle: Text(data['estadio'] ?? 'Sin estadio'),
                onTap: () {
                  final userRole =
                      (AuthManager().loggedInVendor?.data()
                          as Map<String, dynamic>?)?['rol'];

                  if (userRole == 'admin_caja' || userRole == 'dueño') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminEventDashboard(
                          eventName: data['nomevent'] ?? 'Evento',
                          eventId: document.id,
                        ),
                      ),
                    );
                  }
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
