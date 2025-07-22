import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  // asynv y await dice que tiene que sincronizarse con firebase antes de empezar
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp()); //una vez conectado con firebase, inicia la Myapp
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      //Activa el diseño estándar de Material Design de Google
      title: 'Snacks App', //nombre app
      theme: ThemeData(
        //colores y estilo
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 255, 190, 48),
        ),
        useMaterial3: true,
      ),
      home:
          const HomeScreen(), // Especifica cuál será la primera pantalla que verá el usuario
    );
  }
}

class HomeScreen extends StatelessWidget {
  //pantalla que lista los eventos y contiene la lógica más importante
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Stream<QuerySnapshot> eventsStream = FirebaseFirestore.instance
        .collection('eventos')
        .snapshots(); //  cada vez que algo cambie en esa colección (se agregue, edite o borre un evento)

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos Activos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: eventsStream,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            // Si hubo un error al conectar, muestra un texto de error.
            return const Center(child: Text('Algo salió mal'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              Map<String, dynamic> data =
                  document.data()! as Map<String, dynamic>;
              return ListTile(
                // AQUÍ ESTÁN LAS CORRECCIONES
                title: Text(data['nomevent'] ?? 'Sin nombre'),
                subtitle: Text(data['estadio'] ?? 'Sin estadio'),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
