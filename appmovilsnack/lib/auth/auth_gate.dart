import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'package:front_appsnack/auth/login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = AuthManager();
  StreamSubscription<User?>? _authSub;

  User? _user;
  Widget? _pantalla;
  bool _resolviendo = true;
  String? _errorPerfil;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    await _auth.asegurarSesionLista();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChange);
    await _onAuthChange(FirebaseAuth.instance.currentUser);
  }

  Future<void> _onAuthChange(User? user) async {
    if (!mounted) return;

    if (user == null) {
      setState(() {
        _user = null;
        _pantalla = null;
        _resolviendo = false;
        _errorPerfil = null;
      });
      return;
    }

    final cache = _auth.perfilEnCache();
    if (cache != null) {
      setState(() {
        _user = user;
        _pantalla = _auth.pantallaDesdeDocumento(cache);
        _resolviendo = false;
        _errorPerfil = null;
      });
      return;
    }

    setState(() {
      _user = user;
      _resolviendo = true;
      _errorPerfil = null;
    });

    try {
      final perfil = await _auth.resolverPerfil(user);
      if (!mounted) return;

      if (perfil == null) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() {
          _user = null;
          _pantalla = null;
          _resolviendo = false;
          _errorPerfil =
              'No encontramos su perfil. Pida al administrador que verifique su cuenta.';
        });
        return;
      }

      setState(() {
        _pantalla = _auth.pantallaDesdeDocumento(perfil);
        _resolviendo = false;
      });
    } catch (_) {
      if (!mounted) return;
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      setState(() {
        _user = null;
        _pantalla = null;
        _resolviendo = false;
        _errorPerfil =
            'No pudimos cargar su perfil. Revise su conexión e intente de nuevo.';
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return LoginScreen(mensajeInicial: _errorPerfil);
    }

    if (_resolviendo || _pantalla == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _pantalla!;
  }
}
