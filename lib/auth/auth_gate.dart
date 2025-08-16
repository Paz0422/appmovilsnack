import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/screens/admin/home_admin.dart';
import 'package:front_appsnack/screens/estadio_selection.dart';
import 'package:front_appsnack/auth/login_screen.dart'; // Asegúrate de que la ruta sea correcta
import 'package:front_appsnack/screens/panel_ventas.dart'; // Asegúrate de que la ruta sea correcta

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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

                // Si no encuentra el documento del vendedor o hay un error...
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
                final String? eventoIdAsignado = vendorData['idEventoAsignado'];
                final String? sectorAsignado = vendorData['sectorAsignado'];
                final String userRole = vendorData['rol'] ?? 'vendedor';

                // 4. Decidimos a qué pantalla redirigir

                // Caso 1: Vendedor con puesto asignado
                if (eventoIdAsignado != null &&
                    sectorAsignado != null &&
                    eventoIdAsignado.isNotEmpty &&
                    sectorAsignado.isNotEmpty) {
                  return PanelVentas(
                    eventoId: eventoIdAsignado,
                    nombreSector: sectorAsignado,
                  );
                }

                // Caso 2 y 3: Sin asignación, decidimos por rol
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
