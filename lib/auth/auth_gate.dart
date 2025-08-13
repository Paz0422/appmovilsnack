import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'package:front_appsnack/auth/login_screen.dart';
import 'package:front_appsnack/screens/admin/admin_home_screen.dart';
import 'package:front_appsnack/screens/vendedores/vendor_home_screen.dart';
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

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final userRole = userData['rol'];
            AuthManager().loggedInVendor = userSnapshot.data;

            if (userRole == 'vendedor') {
              return const HomeVendedor();
            } else {
              return const HomeAdmin();
            }
          },
        );
      },
    );
  }

  // Función para buscar los datos del usuario en Firestore
  Future<DocumentSnapshot?> _getUserData(String uid) async {
    // Busca en todas las sub-colecciones 'vendedores'
    final querySnapshot = await FirebaseFirestore.instance
        .collectionGroup('vendedores')
        .where('auth_uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first;
    } else {
      return null;
    }
  }
}
