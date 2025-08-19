import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'package:front_appsnack/screens/admin/home_admin.dart';
import 'package:front_appsnack/screens/estadio_selection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui'; // Necesario para ImageFilter.blur
import 'package:wave/wave.dart';
import 'package:wave/config.dart';
import 'package:front_appsnack/auth/register_screen.dart';
import 'package:front_appsnack/auth/reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  final TextStyle _inputStyle = GoogleFonts.lato(fontStyle: FontStyle.italic);

  static const Color primaryColor = Color.fromARGB(255, 117, 85, 163);
  static const Color accentColor = Color.fromARGB(255, 87, 58, 131);
  static const Color backgroundColorStart = Color.fromARGB(255, 161, 149, 35);
  static const Color backgroundColorEnd = Color.fromARGB(220, 255, 243, 132);

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
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showErrorSnackBar('Por favor, completa todos los campos.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: primaryColor, strokeWidth: 5),
      ),
    );

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('vendedores')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        _showErrorSnackBar('Usuario no encontrado.');
        return;
      }

      final vendorDocument = querySnapshot.docs.first;
      final vendorData = vendorDocument.data() as Map<String, dynamic>;

      final String userRole = vendorData['rol'] ?? 'vendedor';

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: vendorData['email'],
        password: password,
      );

      AuthManager().loggedInVendor = vendorDocument;

      if (mounted) {
        Navigator.of(context).pop(); // Cierra el indicador de carga

        // Lógica de redirección
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => (userRole == 'admin')
                ? const HomeAdmin() // Si es admin, va a su home
                : const EstadioSelection(), // Si es vendedor, va a la selección del estadio
          ),
          (route) => false, // Elimina todas las rutas anteriores de la pila
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.of(context).pop();
      // Manejo de errores más específico para FirebaseAuthException
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        _showErrorSnackBar('PIN o usuario incorrecto.');
      } else {
        _showErrorSnackBar('Error de autenticación: ${e.message}');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showErrorSnackBar('Ocurrió un error inesperado: ${e.toString()}');
    }
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  void _navigateToResetPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ResetPasswordScreen()),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      body: Stack(
        children: [
          // Capa 1: Fondo
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [backgroundColorStart, backgroundColorEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Capa 2: Olas
          if (!isKeyboardVisible)
            Align(
              alignment: Alignment.bottomCenter,
              child: WaveWidget(
                config: CustomConfig(
                  colors: [
                    const Color.fromARGB(255, 255, 255, 255).withOpacity(0.5),
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.01),
                  ],
                  durations: [5000, 4000, 3000, 6000],
                  heightPercentages: [0.08, 0.10, 0.12, 0.15],
                ),
                size: const Size(double.infinity, 150.0),
                waveAmplitude: 0,
              ),
            ),
          // Capa 3: Formulario
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 32.0,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.4),
                          Colors.white.withOpacity(0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/imagenes/logo.png', width: 120)
                            .animate()
                            .fade(duration: 900.ms)
                            .scale(delay: 300.ms, duration: 600.ms),
                        const SizedBox(height: 16),
                        Text(
                              '¡Bienvenido!',
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
                        const SizedBox(height: 32),
                        TextField(
                              controller: _usernameController,
                              style: _inputStyle,
                              decoration: _buildInputDecoration(
                                'Nombre de Usuario',
                                Icons.person_outline,
                              ),
                            )
                            .animate()
                            .fade(delay: 700.ms)
                            .slideX(
                              begin: -0.5,
                              duration: 600.ms,
                              curve: Curves.easeOut,
                            ),
                        const SizedBox(height: 20),
                        // CAMBIO AQUÍ: Eliminado keyboardType para permitir letras y números
                        TextField(
                              controller: _passwordController,
                              style: _inputStyle,
                              obscureText: !_isPasswordVisible,
                              // keyboardType: TextInputType.number, // <--- ESTA LÍNEA FUE ELIMINADA
                              decoration:
                                  _buildInputDecoration(
                                    'Pin (Contraseña)',
                                    Icons.lock_outline,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.black54,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isPasswordVisible =
                                              !_isPasswordVisible;
                                        });
                                      },
                                    ),
                                  ),
                            )
                            .animate()
                            .fade(delay: 900.ms)
                            .slideX(
                              begin: 0.5,
                              duration: 600.ms,
                              curve: Curves.easeOut,
                            ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                              onPressed: signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 50,
                                  vertical: 15,
                                ),
                                elevation: 8,
                                shadowColor: Colors.black.withOpacity(0.5),
                              ),
                              child: Text(
                                'Ingresar',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            )
                            .animate()
                            .fade(delay: 1100.ms)
                            .slideY(begin: 1.0, curve: Curves.easeOut),
                        const SizedBox(height: 10),

                        TextButton(
                          onPressed: _navigateToResetPassword,
                          child: Text(
                            '¿Olvidaste tu contraseña?',
                            style: GoogleFonts.lato(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),

                        TextButton(
                          onPressed: _navigateToRegister,
                          child: Text(
                            '¿No tienes cuenta? Regístrate',
                            style: GoogleFonts.lato(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData prefixIcon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(prefixIcon, color: const Color.fromARGB(137, 0, 0, 0)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: primaryColor, width: 2.5),
      ),
      labelStyle: _inputStyle,
    );
  }
}
