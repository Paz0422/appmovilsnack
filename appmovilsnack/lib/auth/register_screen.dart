import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'package:front_appsnack/auth/firebase_auth_messages.dart';
import 'package:front_appsnack/auth/auth_layout.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/widgets/comunes/cargando.dart';
import 'package:front_appsnack/core/tipografia.dart';
// Necessário para ImageFilter.blur

// Paleta de cores baseada no logo "Fusión"
const Color accentColor = AppColors.accent; // Dorado brillante
const Color secondaryColor = AppColors.secondary; // Marrón medio

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<void> _registerUser() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Validações iniciais de campos vazios
    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnackBar('Por favor, complete todos los campos.', isError: true);
      return;
    }

    // --- VALIDAÇÕES DE NOME DE USUÁRIO ---
    final usernameId = AuthManager.normalizarUsername(username);
    if (usernameId.length < 3) {
      _showSnackBar(
        'El nombre de usuario debe tener al menos 3 caracteres.',
        isError: true,
      );
      return;
    }
    if (!AuthManager.esIdUsernameValido(usernameId)) {
      _showSnackBar(
        'El nombre de usuario no puede contener "/".',
        isError: true,
      );
      return;
    }
    // --- FIM DAS VALIDAÇÕES DE NOME DE USUÁRIO ---

    // Validação de correspondência de senhas
    if (password != confirmPassword) {
      _showSnackBar('Las contraseñas no coinciden.', isError: true);
      return;
    }

    // --- VALIDAÇÕES DE SENHA ---
    // 1. Comprimento mínimo de 5 caracteres
    if (password.length < 5) {
      _showSnackBar(
        'La contraseña debe tener al menos 5 caracteres.',
        isError: true,
      );
      return;
    }

    // 2. Pelo menos uma letra (maiúscula ou minúscula)
    bool hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    if (!hasLetter) {
      _showSnackBar(
        'La contraseña debe contener al menos una letra.',
        isError: true,
      );
      return;
    }

    // 3. Pelo menos um número
    bool hasDigit = RegExp(r'[0-9]').hasMatch(password);
    if (!hasDigit) {
      _showSnackBar(
        'La contraseña debe contener al menos un número.',
        isError: true,
      );
      return;
    }
    // --- FIM DAS VALIDAÇÕES DE SENHA ---

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CargandoPuntos()),
    );

    final usernameRef = _firestore.collection('usernames').doc(usernameId);

    try {
      // 1. Verificar que el nombre de usuario esté libre antes de crear la cuenta.
      final usernameSnap = await usernameRef.get();
      if (usernameSnap.exists) {
        if (mounted) Navigator.of(context).pop();
        _showSnackBar(
          'Ese nombre de usuario ya está en uso. Elija otro.',
          isError: true,
        );
        return;
      }

      // 2. Criar usuário no Firebase Authentication com e-mail e senha
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      final nuevoUsuario = userCredential.user!;

      // 3. Perfil + reserva del username en un solo batch. Las reglas rechazan
      // el batch si otro usuario tomó el username entre el paso 1 y este.
      final batch = _firestore.batch();
      batch.set(_firestore.collection('usuarios').doc(nuevoUsuario.uid), {
        'auth_uid': nuevoUsuario.uid,
        'email': email,
        'username': username,
        'rol': 'vendedor', // Função padrão para novos registros
        'fechaRegistro': FieldValue.serverTimestamp(),
        'itemsvendidos': 0,
        'totalvendido': 0,
      });
      // Las reglas exigen el correo tal como lo guarda Firebase Auth.
      batch.set(usernameRef, {'email': nuevoUsuario.email ?? email});
      try {
        await batch.commit();
      } on FirebaseException catch (e) {
        // Sin perfil la cuenta queda inservible: se borra para liberar el correo.
        try {
          await nuevoUsuario.delete();
        } catch (_) {}
        if (e.code == 'permission-denied') {
          if (mounted) Navigator.of(context).pop();
          _showSnackBar(
            'Ese nombre de usuario ya está en uso. Elija otro.',
            isError: true,
          );
          return;
        }
        rethrow;
      }

      if (mounted) Navigator.of(context).pop();
      _showSnackBar('¡Registro exitoso! Ya puede iniciar sesión.');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop();
      });
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showSnackBar(mensajeRegistro(e), isError: true);
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showSnackBar(mensajeErrorInesperado(e), isError: true);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PantallaAcceso(
      titulo: 'Registrar Nuevo Usuario',
      descripcion: 'Crea una nueva cuenta de vendedor.',
      children: [
        TextField(
          controller: _usernameController,
          autofocus: true,
          textInputAction: TextInputAction.next,
          style: estiloCampoAcceso,
          decoration: const InputDecoration(
            labelText: 'Nombre de Usuario',
            prefixIcon: Icon(Icons.person_outline),
            helperText: 'Mín. 3 caracteres.',
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: estiloCampoAcceso,
          decoration: const InputDecoration(
            labelText: 'Correo Electrónico',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          textInputAction: TextInputAction.next,
          style: estiloCampoAcceso,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            helperText: 'Mín. 5 caracteres, incluir letras y números.',
            suffixIcon: IconButton(
              tooltip: _isPasswordVisible ? 'Ocultar' : 'Mostrar',
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _confirmPasswordController,
          obscureText: !_isConfirmPasswordVisible,
          textInputAction: TextInputAction.done,
          style: estiloCampoAcceso,
          decoration: InputDecoration(
            labelText: 'Confirmar Contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _isConfirmPasswordVisible ? 'Ocultar' : 'Mostrar',
              icon: Icon(
                _isConfirmPasswordVisible
                    ? Icons.visibility_off
                    : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: _registerUser,
          icon: const Icon(Icons.person_add),
          label: const Text('Registrarme'),
        ),
      ],
    );
  }
}
