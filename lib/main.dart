import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'auth/auth_manager.dart';
import 'screens/admin/admin_event_dashboard.dart';

void main() async {
  // async y await dice que tiene que sincronizarse con firebase antes de empezar
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
          seedColor: const Color.fromARGB(255, 255, 178, 11),
        ),
        fontFamily: 'WinkyRough', // Aplicamos la fuente personalizada
        useMaterial3: true,
      ),
      home:
          const LoginScreen(), // Especifica cuál será la primera pantalla que verá el usuario
    );
  }
}
