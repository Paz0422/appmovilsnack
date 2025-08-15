import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'package:front_appsnack/auth/login_screen.dart';
import 'package:front_appsnack/screens/admin/admin_home_screen.dart'; // Corregido: Nombre de la pantalla de admin
import 'package:front_appsnack/screens/vendedores/vendor_home_screen.dart'; // Corregido: Nombre de la pantalla de vendedor
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        return FutureBuilder<DocumentSnapshot?>(
          future: _getUserData(snapshot.data!.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                body: Center(
                  // Es buena idea usar un indicador de carga aquí también
                  child: Image.asset('assets/imagenes/logo.png', width: 100),
                ),
              );
            }

            if (!userSnapshot.hasData ||
                userSnapshot.data == null ||
                !userSnapshot.data!.exists) {
              // Si no encuentra al usuario en la BD, lo desloguea por seguridad
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }

            // --- INICIO DE LA MODIFICACIÓN ---

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final userRole = userData['rol'];
            AuthManager().loggedInVendor = userSnapshot.data;

            if (userRole == 'vendedor') {
              // 1. Extraemos el ID del evento desde los datos del usuario
              final eventId = userData['idEventoAsignado'];

              // 2. Verificamos por seguridad que el eventId no sea nulo
              if (eventId != null) {
                // 3. Pasamos el eventId a HomeVendedor y quitamos 'const'
                return HomeVendedor(eventId: eventId as String);
              }
            } else if (userRole == 'admin') {
              // Corregido para usar el nombre correcto de la pantalla de admin
              return const HomeAdmin();
            }

            // Si el rol no es reconocido o falta el eventId, lo mandamos al login
            FirebaseAuth.instance.signOut();
            return const LoginScreen();

            // --- FIN DE LA MODIFICACIÓN ---
          },
        );
      },
    );
  }

  // --- MODIFICACIÓN SUGERIDA EN LA CONSULTA ---
  Future<DocumentSnapshot?> _getUserData(String uid) async {
    // Basado en tus capturas, 'vendedores' es una colección principal
    // y el ID de cada documento debería ser el UID del usuario de Firebase.
    // Esta consulta es más directa y correcta para tu estructura.
    final userDoc = await FirebaseFirestore.instance
        .collection('vendedores')
        .doc(uid)
        .get();

    // Si el documento existe, lo devolvemos, si no, devolvemos null.
    return userDoc.exists ? userDoc : null;
  }
}
