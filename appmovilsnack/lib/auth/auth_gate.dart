import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'package:front_appsnack/auth/login_screen.dart';
import 'package:front_appsnack/core/animaciones.dart';
import 'package:front_appsnack/widgets/comunes/cargando.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';

typedef PerfilUsuario = DocumentSnapshot<Map<String, dynamic>>;

/// Elige la pantalla inicial según la sesión de Firebase Auth y el rol del
/// perfil.
///
/// Hasta que Firebase entrega el primer estado de la sesión (la restaurada
/// del teléfono, o ninguna) y se carga el perfil, se muestra la pantalla de
/// carga: el login solo aparece cuando de verdad no hay sesión.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.cambiosDeSesion,
    this.cargarPerfil,
    this.pantallaPara,
    this.verificarCuenta,
    this.cerrarSesion,
  });

  /// Solo para tests: reemplaza `FirebaseAuth.instance.authStateChanges()`.
  @visibleForTesting
  final Stream<User?>? cambiosDeSesion;

  /// Solo para tests: reemplaza [AuthManager.resolverPerfil].
  @visibleForTesting
  final Future<PerfilUsuario?> Function(User user)? cargarPerfil;

  /// Solo para tests: reemplaza [AuthManager.pantallaDesdeDocumento].
  @visibleForTesting
  final Widget Function(PerfilUsuario perfil)? pantallaPara;

  /// Solo para tests: reemplaza [AuthManager.verificarCuentaVigente].
  @visibleForTesting
  final Future<void> Function()? verificarCuenta;

  /// Solo para tests: reemplaza `FirebaseAuth.instance.signOut()`.
  @visibleForTesting
  final Future<void> Function()? cerrarSesion;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

enum _Estado { resolviendo, sinSesion, conSesion, errorPerfil }

class _AuthGateState extends State<AuthGate> {
  final _auth = AuthManager();
  StreamSubscription<User?>? _authSub;

  _Estado _estado = _Estado.resolviendo;
  User? _user;
  Widget? _pantalla;

  /// Mensaje para el login (p. ej. perfil inexistente). Se mantiene cuando
  /// la sesión pasa a null, para que el login lo muestre.
  String? _mensajeLogin;

  /// Sube con cada cambio de sesión: descarta perfiles que llegan tarde de
  /// una sesión anterior.
  int _intento = 0;

  bool _cuentaVerificada = false;

  @override
  void initState() {
    super.initState();
    // authStateChanges emite primero la sesión restaurada (o null). Hasta
    // ese primer evento se ve la pantalla de carga, no el login.
    final cambios =
        widget.cambiosDeSesion ?? FirebaseAuth.instance.authStateChanges();
    _authSub = cambios.listen(_onAuthChange);
  }

  Future<void> _onAuthChange(User? user) async {
    if (!mounted) return;
    final intento = ++_intento;

    if (user == null) {
      setState(() {
        _estado = _Estado.sinSesion;
        _user = null;
        _pantalla = null;
      });
      return;
    }

    _user = user;
    _verificarCuentaUnaVez();

    final cache = _auth.perfilEnCache();
    if (cache != null) {
      setState(() => _mostrar(cache));
      return;
    }
    await _cargarPerfil(user, intento);
  }

  /// Comprueba en segundo plano que la cuenta siga vigente; no demora la
  /// entrada y no cierra la sesión por falta de señal.
  void _verificarCuentaUnaVez() {
    if (_cuentaVerificada) return;
    _cuentaVerificada = true;
    unawaited((widget.verificarCuenta ?? _auth.verificarCuentaVigente)());
  }

  Future<void> _cargarPerfil(User user, int intento) async {
    if (_estado != _Estado.resolviendo) {
      setState(() => _estado = _Estado.resolviendo);
    }
    try {
      final perfil =
          await (widget.cargarPerfil ?? _auth.resolverPerfil)(user);
      if (!mounted || intento != _intento) return;

      if (perfil == null) {
        // El servidor confirmó que no hay perfil: no puede usar la app.
        _mensajeLogin =
            'No encontramos su perfil. Pida al administrador que verifique su cuenta.';
        await (widget.cerrarSesion ?? FirebaseAuth.instance.signOut)();
        return;
      }
      setState(() => _mostrar(perfil));
    } catch (_) {
      // Sin señal o error transitorio: la sesión sigue abierta.
      if (!mounted || intento != _intento) return;
      setState(() => _estado = _Estado.errorPerfil);
    }
  }

  void _mostrar(PerfilUsuario perfil) {
    _estado = _Estado.conSesion;
    _mensajeLogin = null;
    _pantalla = (widget.pantallaPara ?? _auth.pantallaDesdeDocumento)(perfil);
  }

  void _reintentar() {
    final user = _user;
    if (user == null) return;
    _cargarPerfil(user, ++_intento);
  }

  Future<void> _cerrarSesion() async {
    if (widget.cerrarSesion != null) {
      await widget.cerrarSesion!();
    } else {
      await _auth.cerrarSesion();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_estado) {
      _Estado.resolviendo => const PantallaCargaInicial(),
      _Estado.sinSesion => LoginScreen(mensajeInicial: _mensajeLogin),
      _Estado.conSesion => _pantalla!,
      _Estado.errorPerfil => Scaffold(
        body: SafeArea(
          child: EstadoVacio(
            titulo: 'No pudimos cargar su perfil',
            mensaje:
                'Puede ser la señal. Su sesión sigue abierta: intente de nuevo.',
            accion: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: _reintentar,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _cerrarSesion,
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    };
  }
}

/// Pantalla de carga al abrir la app: logo y puntos dorados mientras se
/// restaura la sesión y se carga el perfil.
class PantallaCargaInicial extends StatelessWidget {
  const PantallaCargaInicial({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Semantics(
        label: 'Abriendo Fusión',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/imagenes/logo.png',
                height: 120,
                excludeFromSemantics: true,
              ).aparicionRebote(),
              const SizedBox(height: 24),
              const CargandoPuntos(),
            ],
          ),
        ),
      ),
    );
  }
}
