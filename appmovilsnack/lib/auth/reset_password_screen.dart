import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/firebase_auth_messages.dart';
import 'package:front_appsnack/auth/auth_layout.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/core/tipografia.dart';

// Paleta de cores baseada no logo "Fusión"
const Color primaryColor = AppColors.primaryLight; // Preto/marrón oscuro
const Color accentColor = AppColors.accent; // Dorado brillante
const Color secondaryColor = AppColors.secondary; // Marrón medio

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
        content: Text(message, style: AppFonts.inter()),
        backgroundColor: isError ? AppColors.errorFuerte : AppColors.exitoFuerte,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 6 : 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showSnackBar('Por favor, ingrese su correo electrónico.', isError: true);
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
      _showSnackBar(mensajeRestablecerClave(e), isError: true);
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showSnackBar(mensajeErrorInesperado(e), isError: true);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PantallaAcceso(
      titulo: 'Restablecer Contraseña',
      descripcion:
          'Ingrese su correo electrónico para restablecer su contraseña.',
      children: [
        TextField(
          controller: _emailController,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _resetPassword(),
          style: estiloCampoAcceso,
          decoration: const InputDecoration(
            labelText: 'Correo Electrónico',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: _resetPassword,
          icon: const Icon(Icons.send),
          label: const Text('Enviar Correo de Restablecimiento'),
        ),
      ],
    );
  }
}
