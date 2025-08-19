import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/screens/admin/home_admin.dart';
import 'package:front_appsnack/screens/estadio_selection.dart';
import 'package:front_appsnack/auth/login_screen.dart'; // Asegúrate de que la ruta sea correcta
import 'package:front_appsnack/screens/panel_ventas.dart'; // Asegúrate de que la ruta sea correcta

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Verificar si hay una sesión existente al iniciar la app
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Hay una sesión activa, verificar que sea válida
        await user.reload();
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        // 1. Escuchamos el estado de autenticación de Firebase
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          // Si está esperando, muestra un cargador
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Si el usuario TIENE sesión iniciada
          if (authSnapshot.hasData) {
            final user = authSnapshot.data!;

            // 2. Ahora que sabemos que está logueado, buscamos sus datos en Firestore
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('vendedores')
                  .doc(user.uid)
                  .get(),
              builder: (context, userSnapshot) {
                // Mientras busca los datos del vendedor...
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (userSnapshot.hasError ||
                    !userSnapshot.hasData ||
                    !userSnapshot.data!.exists) {
                  // Lo mandamos a la pantalla de login para evitar problemas.
                  // También podrías mostrar un mensaje de error.
                  return const LoginScreen();
                }

                // 3. ¡Tenemos los datos del vendedor! Aplicamos la misma lógica del signIn.
                final vendorData =
                    userSnapshot.data!.data() as Map<String, dynamic>;
                final String userRole = vendorData['rol'] ?? 'vendedor';

                if (userRole == 'admin') {
                  return const HomeAdmin(); // Admin
                } else {
                  return const EstadioSelection(); // Vendedor sin asignar
                }
              },
            );
          }
          // Si el usuario NO tiene sesión iniciada
          else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
