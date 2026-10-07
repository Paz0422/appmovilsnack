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

  FirebaseFirestore? _firestorePrueba;
  FirebaseAuth? _authPrueba;

  FirebaseFirestore get _firestore =>
      _firestorePrueba ?? FirebaseFirestore.instance;
  FirebaseAuth get _firebaseAuth => _authPrueba ?? FirebaseAuth.instance;

  /// Sustituye Firestore y Auth en [iniciarSesion], [resolverPerfil] y
  /// [verificarCuentaVigente]; `null` vuelve a los reales.
  @visibleForTesting
  void usarInstanciasDePrueba({FirebaseFirestore? firestore, FirebaseAuth? auth}) {
    _firestorePrueba = firestore;
    _authPrueba = auth;
  }

  /// Mismo texto si el usuario no existe o la contraseña es incorrecta, para no
  /// revelar qué nombres de usuario existen.
  static const mensajeCredencialesIncorrectas =
      'Usuario o contraseña incorrectos';

  static String normalizarRol(String? rol) {
    final r = rol?.trim().toLowerCase() ?? '';
    if (r == 'admin' || r == 'administrador') return 'admin';
    return 'vendedor';
  }

  static bool esAdmin(String rol) => rol == 'admin';

  /// Id del documento en `usernames/`: minúsculas y sin espacios.
  /// Debe coincidir con `normalizarUsername` en firestore.rules y con
  /// scripts/migrar_usernames.mjs.
  static String normalizarUsername(String username) =>
      username.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  /// Firestore no acepta como id de documento '/', '.', '..' ni '__x__'.
  static bool esIdUsernameValido(String id) =>
      id.isNotEmpty &&
      !id.contains('/') &&
      id != '.' &&
      id != '..' &&
      !(id.startsWith('__') && id.endsWith('__'));

  void configurarPantallaRaiz(Widget pantalla) {
    _pantallaRaiz = pantalla;
  }

  DocumentSnapshot<Map<String, dynamic>>? perfilEnCache() {
    return _perfilCache ?? loggedInVendor;
  }

  /// Si la sesión actual es de un admin, también cuando usa el panel de vendedor.
  bool get sesionEsAdmin =>
      esAdmin(normalizarRol(perfilEnCache()?.data()?['rol']?.toString()));

  Widget pantallaDesdeDocumento(DocumentSnapshot<Map<String, dynamic>> doc) {
    final rol = normalizarRol(doc.data()?['rol']?.toString());
    if (esAdmin(rol)) return const HomeAdmin();
    return const EstadioSelection();
  }

  /// Cuánto se espera al servidor antes de usar la copia local del perfil.
  static const _esperaServidor = Duration(seconds: 6);

  /// Perfil del usuario en `usuarios/` (por id = uid, luego `auth_uid`, luego
  /// email). Pide cada lectura al servidor y, si no responde a tiempo, usa la
  /// copia local de Firestore: con mala señal se entra igual.
  ///
  /// Devuelve null solo si el servidor confirmó que no existe. Si alguna
  /// búsqueda salió de la copia local y no encontró nada, lanza
  /// [PerfilSinConexion]: que no esté en la copia local no prueba que no
  /// exista, y no hay que cerrarle la sesión por eso.
  Future<DocumentSnapshot<Map<String, dynamic>>?> resolverPerfil(
    User user,
  ) async {
    final cache = perfilEnCache();
    if (cache != null) return cache;

    var usoCopiaLocal = false;

    Future<DocumentSnapshot<Map<String, dynamic>>> leerDoc(
      DocumentReference<Map<String, dynamic>> ref,
    ) async {
      try {
        return await ref.get().timeout(_esperaServidor);
      } catch (_) {
        usoCopiaLocal = true;
        // Si tampoco está en la copia local, el error llega a AuthGate.
        return ref.get(const GetOptions(source: Source.cache));
      }
    }

    Future<QuerySnapshot<Map<String, dynamic>>> leerConsulta(
      Query<Map<String, dynamic>> consulta,
    ) async {
      try {
        return await consulta.get().timeout(_esperaServidor);
      } catch (_) {
        usoCopiaLocal = true;
        return consulta.get(const GetOptions(source: Source.cache));
      }
    }

    final usuarios = _firestore.collection('usuarios');

    DocumentSnapshot<Map<String, dynamic>>? porUid;
    try {
      porUid = await leerDoc(usuarios.doc(user.uid));
    } on FirebaseException catch (_) {
      // No está ni en el servidor (sin respuesta) ni en la copia local:
      // se sigue con las otras búsquedas.
      usoCopiaLocal = true;
    }
    if (porUid != null && porUid.exists) {
      _guardarPerfil(porUid);
      return porUid;
    }

    final porAuthUid = await leerConsulta(
      usuarios.where('auth_uid', isEqualTo: user.uid).limit(1),
    );
    if (porAuthUid.docs.isNotEmpty) {
      _guardarPerfil(porAuthUid.docs.first);
      return porAuthUid.docs.first;
    }

    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      final porEmail = await leerConsulta(
        usuarios.where('email', isEqualTo: email).limit(1),
      );
      if (porEmail.docs.isNotEmpty) {
        _guardarPerfil(porEmail.docs.first);
        return porEmail.docs.first;
      }
    }

    if (usoCopiaLocal) throw const PerfilSinConexion();
    return null;
  }

  void _guardarPerfil(DocumentSnapshot<Map<String, dynamic>> doc) {
    _perfilCache = doc;
    loggedInVendor = doc;
  }

  /// Respuestas de Firebase Auth que significan que la cuenta ya no sirve
  /// (borrada, deshabilitada o con la sesión revocada).
  static const codigosCuentaInvalida = {
    'user-not-found',
    'user-disabled',
    'user-token-expired',
    'invalid-user-token',
  };

  /// Comprueba con Firebase que la cuenta de la sesión siga vigente. No
  /// bloquea el arranque (AuthGate la llama en segundo plano) y solo cierra
  /// la sesión si Firebase responde que la cuenta ya no es válida: sin señal
  /// la sesión se mantiene, para que el vendedor pueda seguir trabajando.
  Future<void> verificarCuentaVigente() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    try {
      await user.reload();
    } on FirebaseAuthException catch (e) {
      if (codigosCuentaInvalida.contains(e.code)) await cerrarSesion();
    } catch (_) {
      // Error de red u otro transitorio: se vuelve a comprobar al reabrir.
    }
  }

  Future<String?> iniciarSesion({
    required String username,
    required String password,
  }) async {
    final nombre = username.trim();
    final clave = password.trim();
    if (nombre.isEmpty || clave.isEmpty) {
      return 'Por favor, complete todos los campos.';
    }

    // "Paz", "paz" y " PAZ " apuntan al mismo documento.
    final usernameId = normalizarUsername(nombre);
    if (!esIdUsernameValido(usernameId)) return mensajeCredencialesIncorrectas;

    try {
      // Sin sesión todavía: las reglas solo permiten `get` en usernames/,
      // nunca consultar usuarios/.
      final usernameDoc = await _firestore
          .collection('usernames')
          .doc(usernameId)
          .get()
          .timeout(const Duration(seconds: 15));

      if (!usernameDoc.exists) return mensajeCredencialesIncorrectas;

      final email = usernameDoc.data()?['email']?.toString().trim();
      if (email == null || email.isEmpty) {
        return 'Falta el correo en su perfil. Pida al administrador que lo agregue.';
      }

      // El perfil lo resuelve AuthGate con resolverPerfil al cambiar la sesión.
      await _firebaseAuth.signInWithEmailAndPassword(
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
    await _firebaseAuth.signOut();

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

/// No se pudo saber si el perfil existe: el servidor no respondió y la copia
/// local no lo tiene. La sesión sigue abierta; AuthGate ofrece reintentar.
class PerfilSinConexion implements Exception {
  const PerfilSinConexion();

  @override
  String toString() => 'Perfil no disponible sin conexión';
}
