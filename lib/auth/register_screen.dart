import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// Necessário para ImageFilter.blur

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
        content: Text(message, style: GoogleFonts.lato()),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
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
      _showSnackBar('Por favor, completa todos los campos.', isError: true);
      return;
    }

    // --- VALIDAÇÕES DE NOME DE USUÁRIO ---
    if (username.length < 3) {
      _showSnackBar(
        'El nombre de usuario debe tener al menos 3 caracteres.',
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
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: primaryColor, strokeWidth: 5),
      ),
    );

    try {
      // 1. Criar usuário no Firebase Authentication com e-mail e senha
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // 2. Salvar dados adicionais no Firestore
      await _firestore.collection('usuarios').doc(userCredential.user!.uid).set(
        {
          'auth_uid': userCredential.user!.uid,
          'email': email,
          'username': username,
          'rol': 'vendedor', // Função padrão para novos registros
          'fechaRegistro': FieldValue.serverTimestamp(),
          'itemsvendidos': 0,
          'totalvendido': 0,
        },
      );

      if (mounted) Navigator.of(context).pop();
      _showSnackBar('¡Registro exitoso! Ya puedes iniciar sesión.');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop();
      });
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.of(context).pop();
      String errorMessage;
      if (e.code == 'weak-password') {
        errorMessage =
            'La contraseña es demasiado débil según Firebase (mínimo 6 caracteres).';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'El correo electrónico ya está en uso.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo electrónico es inválido.';
      } else {
        errorMessage = 'Error de registro: ${e.message}';
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
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Registrar Nuevo Usuario',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
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
                  'Crea una nueva cuenta de vendedor.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _usernameController,
                  style: GoogleFonts.lato(fontStyle: FontStyle.italic),
                  decoration:
                      _buildInputDecoration(
                        'Nombre de Usuario',
                        Icons.person_outline,
                      ).copyWith(
                        helperText: 'Mín. 3 caracteres.',
                        helperStyle: GoogleFonts.lato(color: Colors.black54),
                      ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.lato(fontStyle: FontStyle.italic),
                  decoration: _buildInputDecoration(
                    'Correo Electrónico',
                    Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  style: GoogleFonts.lato(fontStyle: FontStyle.italic),
                  obscureText: !_isPasswordVisible,
                  decoration:
                      _buildInputDecoration(
                        'Contraseña',
                        Icons.lock_outline,
                      ).copyWith(
                        helperText:
                            'Mín. 5 caracteres, incluir letras y números.',
                        helperStyle: GoogleFonts.lato(color: Colors.black54),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.black54,
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
                  style: GoogleFonts.lato(fontStyle: FontStyle.italic),
                  obscureText: !_isConfirmPasswordVisible,
                  decoration:
                      _buildInputDecoration(
                        'Confirmar Contraseña',
                        Icons.lock_outline,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.black54,
                          ),
                          onPressed: () {
                            setState(() {
                              _isConfirmPasswordVisible =
                                  !_isConfirmPasswordVisible;
                            });
                          },
                        ),
                      ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: _registerUser,
                  icon: const Icon(Icons.person_add),
                  label: Text(
                    'Registrarme',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    elevation: 8,
                    shadowColor: Colors.black.withValues(alpha: 0.5),
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
      fillColor: Colors.white.withValues(alpha: 0.8),
      // --- MODIFICACIÓN AQUÍ: AÑADIDO UN BORDE POR DEFECTO ---
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: primaryColor.withValues(alpha: 0.5),
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
