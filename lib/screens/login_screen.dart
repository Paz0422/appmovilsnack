import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'package:front_appsnack/screens/vendedores/vendor_home_screen.dart'; // <-- Importamos la nueva pantalla
import 'package:front_appsnack/screens/admin/admin_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> signIn() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Center(child: Image.asset('assets/imagenes/logo.png', width: 100)),
    );

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collectionGroup('vendedores')
          .where('username', isEqualTo: _usernameController.text.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        _showErrorSnackBar('Usuario no encontrado.');
        return;
      }

      final vendorDocument = querySnapshot.docs.first;
      final vendorData = vendorDocument.data();
      final String email = vendorData['email'];
      final String userRole = vendorData['rol'];

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      AuthManager().loggedInVendor = vendorDocument;

      if (mounted) {
        if (userRole == 'vendedor') {
          // Si es vendedor, va a su nuevo panel
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  const VendorHomeScreen(), // <-- LÍNEA CORREGIDA
            ),
          );
        } else {
          // Si es admin o dueño, va a la lista de eventos
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
          );
        }
      }
    } on FirebaseAuthException {
      if (mounted) Navigator.of(context).pop();
      _showErrorSnackBar('PIN o usuario incorrecto.');
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      print('Ocurrió un error: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/imagenes/logo.png', width: 150),
              const Text(
                'Bienvenido!',
                style: TextStyle(
                  fontSize: 28, // Tamaño de letra
                  fontWeight: FontWeight.bold, // Letra en negrita
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de Usuario',
                  labelStyle: TextStyle(fontStyle: FontStyle.italic),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'PIN (Contraseña)',
                  labelStyle: TextStyle(fontStyle: FontStyle.italic),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),
                ),
                onPressed: signIn,
                child: const Text('Ingresar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
