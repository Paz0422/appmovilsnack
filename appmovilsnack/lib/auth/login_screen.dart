import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'package:front_appsnack/screens/admin/home_admin.dart';
import 'package:front_appsnack/widgets/estadio_selection.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wave/wave.dart';
import 'package:wave/config.dart';
import 'package:front_appsnack/auth/firebase_auth_messages.dart';
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

  final TextStyle _inputStyle = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    color: AppColors.onSurface,
  );

  static const Color _snackError = Color(0xFF722F37);

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: _snackError,
        showCloseIcon: true,
        closeIconColor: Colors.white70,
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_person_outlined,
              color: Colors.white.withValues(alpha: 0.95),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
        child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 3),
      ),
    );

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        _showErrorSnackBar(
          'Usuario no encontrado. Revisa el nombre o pide que te den de alta.',
        );
        return;
      }

      final userDocument = querySnapshot.docs.first;
      final userData = userDocument.data();

      final emailRaw = userData['email'];
      final email = emailRaw is String
          ? emailRaw.trim()
          : emailRaw?.toString().trim();
      if (email == null || email.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        _showErrorSnackBar(
          'Falta el correo en tu perfil. Pide al administrador que lo agregue.',
        );
        return;
      }

      final userRole = AuthManager.normalizarRol(userData['rol']?.toString());

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      AuthManager().loggedInVendor = userDocument;

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
      _showErrorSnackBar(mensajeInicioSesion(e));
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showErrorSnackBar(mensajeErrorInesperado(e));
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
          // Fondo: gradiente Fusión (oscuro + dorado)
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primaryLight,
                  Color(0xFF3D3528),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Marca de agua sutil
          Center(
            child: Opacity(
              opacity: 0.06,
              child: Image.asset(
                'assets/imagenes/logo.png',
                width: 280,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Olas en la parte inferior
          if (!isKeyboardVisible)
            Align(
              alignment: Alignment.bottomCenter,
              child: WaveWidget(
                config: CustomConfig(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.08),
                    AppColors.surface.withValues(alpha: 0.05),
                  ],
                  durations: [5000, 4000, 6000],
                  heightPercentages: [0.12, 0.15, 0.18],
                ),
                size: const Size(double.infinity, 160),
                waveAmplitude: 8,
              ),
            ),
          // Formulario: card con glass y bordes redondeados
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/imagenes/logo.png', width: 100)
                            .animate()
                            .fade(duration: 700.ms)
                            .scale(delay: 200.ms, duration: 500.ms),
                        const SizedBox(height: 12),
                        Text(
                          'Bienvenido',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: -0.5,
                          ),
                        )
                            .animate()
                            .fade(delay: 400.ms)
                            .slideY(begin: -0.3, duration: 450.ms, curve: Curves.easeOut),
                        const SizedBox(height: 28),
                        TextField(
                          controller: _usernameController,
                          autofocus: true,
                          style: _inputStyle,
                          decoration: _buildInputDecoration('Usuario', Icons.person_outline_rounded),
                        )
                            .animate()
                            .fade(delay: 550.ms)
                            .slideX(begin: -0.2, duration: 450.ms, curve: Curves.easeOut),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          style: _inputStyle,
                          obscureText: !_isPasswordVisible,
                          decoration: _buildInputDecoration('PIN', Icons.lock_outline_rounded).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: AppColors.onSurfaceVariant,
                              ),
                              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            ),
                          ),
                        )
                            .animate()
                            .fade(delay: 700.ms)
                            .slideX(begin: 0.2, duration: 450.ms, curve: Curves.easeOut),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              elevation: 0,
                            ),
                            child: Text('Ingresar', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
                          ),
                        )
                            .animate()
                            .fade(delay: 850.ms)
                            .slideY(begin: 0.2, duration: 450.ms, curve: Curves.easeOut),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _navigateToResetPassword,
                          child: Text(
                            '¿Olvidaste tu contraseña?',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _navigateToRegister,
                          child: Text(
                            'Crear cuenta',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
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
      prefixIcon: Icon(prefixIcon, color: AppColors.onSurfaceVariant, size: 22),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.accent, width: 2),
      ),
      labelStyle: GoogleFonts.plusJakartaSans(color: AppColors.onSurfaceVariant),
    );
  }
}
