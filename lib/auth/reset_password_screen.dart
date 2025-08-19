import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Paleta de cores baseada no logo "Fusión"
const Color primaryColor = Color(0xFF2B2B2B); // Preto/marrón oscuro
const Color accentColor = Color(0xFFDABF41); // Dorado brillante
const Color secondaryColor = Color(0xFF6B4D2F); // Marrón medio
const Color backgroundColorStart = Color(
  0xFFFDFBF7,
); // Fundo claro elegante (anteriormente backgroundColorEnd)
const Color backgroundColorEnd = Color(
  0xFFFDFBF7,
); // Usamos o mesmo para um fundo uniforme se só quiser uma cor

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lato()),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showSnackBar('Por favor, ingresa tu correo electrónico.', isError: true);
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
      await _auth.sendPasswordResetEmail(email: email);
      if (mounted) Navigator.of(context).pop();
      _showSnackBar('Se ha enviado un correo de restablecimiento a $email.');
      // Opcional: Volver a la pantalla de login después de un breve retraso
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop();
      });
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.of(context).pop();
      String errorMessage;
      if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo electrónico es inválido.';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'No hay usuario registrado con ese correo electrónico.';
      } else {
        errorMessage =
            'Error al enviar correo de restablecimiento: ${e.message}';
      }
      _showSnackBar(errorMessage, isError: true);
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showSnackBar(
        'Ocurrió un error inesperado: ${e.toString()}',
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Restablecer Contraseña',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ), // Color del icono de retroceso
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [backgroundColorStart, backgroundColorEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ingresa tu correo electrónico para restablecer tu contraseña.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.lato(fontStyle: FontStyle.italic),
                  decoration: _buildInputDecoration(
                    'Correo Electrónico',
                    Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: _resetPassword,
                  icon: const Icon(Icons.send),
                  label: Text(
                    'Enviar Correo de Restablecimiento',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    elevation: 8,
                    shadowColor: Colors.black.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        borderSide: BorderSide(
          color: primaryColor.withOpacity(0.5),
          width: 1.0,
        ), // Borde por defecto
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: primaryColor, width: 2.5),
      ),
      labelStyle: GoogleFonts.lato(fontStyle: FontStyle.italic),
    );
  }
}
