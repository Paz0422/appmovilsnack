import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'package:front_appsnack/auth/register_screen.dart';
import 'package:front_appsnack/auth/reset_password_screen.dart';
import 'package:front_appsnack/core/animaciones.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/core/avisos_sesion.dart';
import 'package:front_appsnack/core/margen_inferior.dart';
import 'package:front_appsnack/core/tipografia.dart';
import 'package:front_appsnack/widgets/comunes/animados.dart';
import 'package:front_appsnack/widgets/comunes/cargando.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';

class LoginScreen extends StatefulWidget {
  final String? mensajeInicial;

  const LoginScreen({super.key, this.mensajeInicial});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _cargando = false;

  /// Error visible junto al formulario (mismo texto que antes en el aviso).
  String? _error;

  /// Sector cuyo turno se acaba de cerrar ("¡Turno cerrado!").
  String? _turnoCerradoEn;

  @override
  void initState() {
    super.initState();
    final mensaje = widget.mensajeInicial;
    if (mensaje != null && mensaje.isNotEmpty) _error = mensaje;
    _turnoCerradoEn = AvisosSesion.tomarTurnoCerrado();
  }

  Future<void> signIn() async {
    if (_cargando) return;

    setState(() {
      _cargando = true;
      _error = null;
      _turnoCerradoEn = null;
    });
    final error = await AuthManager().iniciarSesion(
      username: _usernameController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = error;
    });
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
    return Scaffold(
      backgroundColor: AppColors.negro,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Tablet horizontal: marca a la izquierda, formulario a la derecha.
            if (constraints.maxWidth >= 760) {
              return Row(
                children: [
                  Expanded(child: Center(child: _buildMarca(ancho: true))),
                  SizedBox(
                    width: 480,
                    child: _buildHojaFormulario(
                      redondearArriba: false,
                    ).entradaLateral(),
                  ),
                ],
              );
            }
            return CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      _buildMarca(ancho: false),
                      Expanded(
                        child: _buildHojaFormulario(
                          redondearArriba: true,
                        ).entradaDesdeAbajo(
                          demora: const Duration(milliseconds: 150),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Zona de marca en negro: logo, mascota y saludo en la cursiva de marca.
  Widget _buildMarca({required bool ancho}) {
    final tamanoLogo = ancho ? 200.0 : 112.0;
    final tamanoMascota = ancho ? 170.0 : 104.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, ancho ? 0 : 20, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Semantics(
                label: 'Fusión, Healthy Snacks & Coffee',
                image: true,
                child: Image.asset(
                  'assets/imagenes/logo.png',
                  width: tamanoLogo,
                  excludeFromSemantics: true,
                ).aparicionRebote(),
              ),
              const SizedBox(width: 4),
              Mascota(alto: tamanoMascota)
                  .aparicionRebote(demora: const Duration(milliseconds: 250))
                  .saludo(demora: const Duration(milliseconds: 1200)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '¡Hola de nuevo!',
            textAlign: TextAlign.center,
            style: AppFonts.lobster(
              fontSize: ancho ? 40 : 32,
              color: AppColors.dorado,
            ),
          ).entrada(orden: 4).destello(
                demora: const Duration(milliseconds: 1000),
              ),
        ],
      ),
    );
  }

  /// Formulario sobre fondo claro para que se lea al sol.
  Widget _buildHojaFormulario({required bool redondearArriba}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.fondo,
        borderRadius: redondearArriba
            ? const BorderRadius.vertical(top: Radius.circular(28))
            : null,
      ),
      child: SingleChildScrollView(
        padding: conMargenInferior(
          context,
          const EdgeInsets.fromLTRB(20, 24, 20, 24),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (redondearArriba) ...[
                    const Center(child: FiletMarca(ancho: 56)),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Ingrese a su punto de venta',
                    style: AppFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.tinta,
                    ),
                  ).entrada(orden: 3),
                  const SizedBox(height: 16),
                  Aparece(
                    child: _turnoCerradoEn == null
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: AvisoMascota(
                              tipo: TipoAviso.exito,
                              titulo: '¡Turno cerrado!',
                              mensaje: _turnoCerradoEn!.isEmpty
                                  ? 'Buen trabajo. Ya puede cerrar la app o ingresar de nuevo.'
                                  : 'Buen trabajo en ${_turnoCerradoEn!}. Ya puede cerrar la app o ingresar de nuevo.',
                              onCerrar: () =>
                                  setState(() => _turnoCerradoEn = null),
                            ),
                          ),
                  ),
                  TextField(
                    controller: _usernameController,
                    autofocus: _turnoCerradoEn == null,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    style: _estiloCampo,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ).entrada(orden: 4),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => signIn(),
                    style: _estiloCampo,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _isPasswordVisible
                            ? 'Ocultar PIN'
                            : 'Mostrar PIN',
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                        onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                      ),
                    ),
                  ).entrada(orden: 5),
                  // Se vuelve a crear en cada intento fallido: sacude cada vez.
                  Aparece(
                    child: _error == null
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: AvisoMascota(
                              tipo: TipoAviso.error,
                              titulo: _error!,
                              mensaje:
                                  'Revise sus datos e intente otra vez. ¡Le pasa a cualquiera!',
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  Presionable(
                    child: ElevatedButton(
                      onPressed: _cargando ? null : signIn,
                      child: _cargando
                          ? const SizedBox(height: 24, child: CargandoPuntos())
                          : const Text('Ingresar'),
                    ),
                  ).entrada(orden: 6),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _navigateToResetPassword,
                        child: const Text('¿Olvidó su contraseña?'),
                      ),
                      TextButton(
                        onPressed: _navigateToRegister,
                        child: const Text('Crear cuenta'),
                      ),
                    ],
                  ).entrada(orden: 7),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle get _estiloCampo => AppFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.tinta,
  );
}
