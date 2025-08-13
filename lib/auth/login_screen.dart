import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'package:front_appsnack/screens/admin/admin_home_screen.dart';
import 'package:front_appsnack/screens/vendedores/vendor_home_screen.dart';

// NUEVO: Imports para las mejoras visuales
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  // La lógica de negocio no cambia, está perfecta como la tenías.
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lato()),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> signIn() async {
    // El loading animado se mantiene, ¡es una buena idea!
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: RotationTransition(
          turns: _animationController,
          child: Image.asset('assets/imagenes/logo.png', width: 100),
        ),
      ),
    );

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('vendedores')
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
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeVendedor()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeAdmin()),
          );
        }
      }
    } on FirebaseAuthException {
      if (mounted) Navigator.of(context).pop();
      _showErrorSnackBar('PIN o usuario incorrecto.');
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showErrorSnackBar('Ocurrió un error: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // =================================================================
  // AQUI COMIENZAN TODOS LOS CAMBIOS VISUALES
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // 1. FONDO CON GRADIENTE
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6E45E2), Color.fromARGB(255, 255, 243, 132)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          // 2. SCROLL PARA EVITAR OVERFLOW CON EL TECLADO
          child: SingleChildScrollView(
            child: Container(
              // 3. TARJETA PARA AGRUPAR EL FORMULARIO
              margin: const EdgeInsets.symmetric(horizontal: 24.0),
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 4. ANIMACIONES EN CADA ELEMENTO
                  Image.asset('assets/imagenes/logo.png', width: 120)
                      .animate()
                      .fade(duration: 900.ms)
                      .scale(delay: 300.ms, duration: 600.ms),

                  const SizedBox(height: 16),

                  Text(
                        '¡Bienvenido!',
                        // 5. TIPOGRAFÍA PERSONALIZADA
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF333333),
                        ),
                      )
                      .animate()
                      .fade(delay: 500.ms)
                      .slideY(
                        begin: -0.5,
                        duration: 500.ms,
                        curve: Curves.easeOut,
                      ),

                  const SizedBox(height: 24),

                  // 6. TEXTFIELD CON DISEÑO MEJORADO
                  TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre de Usuario',
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                          filled: true,
                          fillColor: const Color.fromARGB(255, 255, 255, 255),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: const BorderSide(
                              color: Color(0xFF6E45E2),
                              width: 2,
                            ),
                          ),
                          labelStyle: GoogleFonts.lato(),
                        ),
                      )
                      .animate()
                      .fade(delay: 700.ms)
                      .slideX(
                        begin: -0.5,
                        duration: 600.ms,
                        curve: Curves.easeOut,
                      ),

                  const SizedBox(height: 18),

                  TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'PIN (Contraseña)',
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: Colors.grey,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: const BorderSide(
                              color: Color(0xFF6E45E2),
                              width: 2,
                            ),
                          ),
                          labelStyle: GoogleFonts.lato(),
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                      )
                      .animate()
                      .fade(delay: 900.ms)
                      .slideX(
                        begin: 0.5,
                        duration: 600.ms,
                        curve: Curves.easeOut,
                      ),

                  const SizedBox(height: 32),

                  // BOTÓN CON ESTILO Y ANIMACIÓN
                  ElevatedButton(
                    onPressed: signIn,
                    style:
                        ElevatedButton.styleFrom(
                          // 1. Este es tu color de fondo NORMAL
                          backgroundColor: const Color.fromARGB(
                            255,
                            148,
                            140,
                            170,
                          ),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 15,
                          ),
                          elevation: 5,
                        ).copyWith(
                          // <-- La magia empieza aquí
                          // 2. Definimos el color que se superpone al presionar
                          overlayColor: MaterialStateProperty.resolveWith<Color?>((
                            Set<MaterialState> states,
                          ) {
                            if (states.contains(MaterialState.pressed)) {
                              // Este es tu morado más vivo para cuando se presiona
                              return const Color.fromARGB(255, 120, 90, 200);
                            }
                            // Puedes devolver 'null' para usar el comportamiento por defecto
                            // en otros estados (como hover).
                            return null;
                          }),
                        ),
                    child: Text(
                      'Ingresar',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ).animate().fade(delay: 1100.ms).slideY(begin: 1.0, curve: Curves.easeOut),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
