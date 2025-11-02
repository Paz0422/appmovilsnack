import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb; // Importante para detectar la web

import 'firebase_options.dart';
import 'auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- LÓGICA DE INICIALIZACIÓN PARA MÚLTIPLES PLATAFORMAS ---
  if (kIsWeb) {
    // --- Ejecución en la WEB ---

    // Configuración de Firebase para la web (obtenida de tu captura)
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDyGxBTz7ZoGo7VHg-BW1hnsQLjfVbibc",
        authDomain: "snack-estadio.firebaseapp.com",
        projectId: "snack-estadio",
        storageBucket: "snack-estadio.firebasestorage.app",
        messagingSenderId: "300612690116",
        appId: "1:300612690116:web:0846b7b0b9c961eb172991",
        measurementId: "G-6868QCC7VD",
      ),
    );
  } else {
    // --- Ejecución en ANDROID o iOS ---
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Habilita la persistencia de Firestore (solo funciona en móvil, en web se ignora sin dar error)
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (e) {
    // Ignorar error en web, donde la persistencia se maneja de otra forma.
  }

  // Configura la persistencia de Firebase Auth solo en web
  if (kIsWeb) {
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      print('Persistencia de Auth configurada en web');
    } catch (e) {
      print('Error configurando persistencia en web: $e');
    }
  } else {
    // En móvil, la persistencia se maneja automáticamente
    print('Persistencia de Auth automática en móvil');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snacks App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 213, 180, 109),
        ),
        fontFamily: 'WinkyRough',
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
