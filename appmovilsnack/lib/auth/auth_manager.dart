import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/auth_gate.dart';
import 'package:front_appsnack/auth/firebase_auth_messages.dart';
import 'package:front_appsnack/core/app_navigator.dart';
import 'package:front_appsnack/screens/admin/home_admin.dart';
import 'package:front_appsnack/widgets/estadio_selection.dart';

class AuthManager {
  static final AuthManager _instance = AuthManager._internal();
  factory AuthManager() => _instance;
  AuthManager._internal();

  DocumentSnapshot<Map<String, dynamic>>? loggedInVendor;
  DocumentSnapshot<Map<String, dynamic>>? _perfilCache;

  Widget? _pantallaRaiz;

  static String normalizarRol(String? rol) {
    final r = rol?.trim().toLowerCase() ?? '';
    if (r == 'admin' || r == 'administrador') return 'admin';
    return 'vendedor';
  }

  static bool esAdmin(String rol) => rol == 'admin';

  void configurarPantallaRaiz(Widget pantalla) {
    _pantallaRaiz = pantalla;
  }

  DocumentSnapshot<Map<String, dynamic>>? perfilEnCache() {
    return _perfilCache ?? loggedInVendor;
  }

  Widget pantallaDesdeDocumento(DocumentSnapshot<Map<String, dynamic>> doc) {
    final rol = normalizarRol(doc.data()?['rol']?.toString());
    if (esAdmin(rol)) return const HomeAdmin();
    return const EstadioSelection();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> resolverPerfil(
    User user,
  ) async {
    final cache = perfilEnCache();
    if (cache != null) return cache;

    final firestore = FirebaseFirestore.instance;

    final porUid = await firestore
        .collection('usuarios')
        .doc(user.uid)
        .get()
        .timeout(const Duration(seconds: 15));
    if (porUid.exists) {
      _guardarPerfil(porUid);
      return porUid;
    }

    final porAuthUid = await firestore
        .collection('usuarios')
        .where('auth_uid', isEqualTo: user.uid)
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 15));
    if (porAuthUid.docs.isNotEmpty) {
      _guardarPerfil(porAuthUid.docs.first);
      return porAuthUid.docs.first;
    }

    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      final porEmail = await firestore
          .collection('usuarios')
          .where('email', isEqualTo: email)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 15));
      if (porEmail.docs.isNotEmpty) {
        _guardarPerfil(porEmail.docs.first);
        return porEmail.docs.first;
      }
    }

    return null;
  }

  void _guardarPerfil(DocumentSnapshot<Map<String, dynamic>> doc) {
    _perfilCache = doc;
    loggedInVendor = doc;
  }

  Future<void> asegurarSesionLista() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) await user.reload();
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      _limpiarCache();
    }
  }

  Future<String?> iniciarSesion({
    required String username,
    required String password,
  }) async {
    final nombre = username.trim();
    final clave = password.trim();
    if (nombre.isEmpty || clave.isEmpty) {
      return 'Por favor, completa todos los campos.';
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('username', isEqualTo: nombre)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 15));

      if (query.docs.isEmpty) {
        return 'Usuario no encontrado. Revisa el nombre o pide que te den de alta.';
      }

      final userDoc = query.docs.first;
      final userData = userDoc.data();
      final emailRaw = userData['email'];
      final email = emailRaw is String
          ? emailRaw.trim()
          : emailRaw?.toString().trim();
      if (email == null || email.isEmpty) {
        return 'Falta el correo en tu perfil. Pide al administrador que lo agregue.';
      }

      _guardarPerfil(userDoc);

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: clave,
      );

      return null;
    } on FirebaseAuthException catch (e) {
      _limpiarCache();
      return mensajeInicioSesion(e);
    } catch (e) {
      _limpiarCache();
      return mensajeErrorInesperado(e);
    }
  }

  Future<void> cerrarSesion() async {
    _limpiarCache();
    await FirebaseAuth.instance.signOut();

    final navigator = appNavigatorKey.currentState;
    final raiz = _pantallaRaiz ?? const AuthGate();
    if (navigator != null) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => raiz),
        (_) => false,
      );
    }
  }

  void _limpiarCache() {
    loggedInVendor = null;
    _perfilCache = null;
  }
}
