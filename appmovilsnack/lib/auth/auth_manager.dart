import 'package:cloud_firestore/cloud_firestore.dart';

class AuthManager {
  static final AuthManager _instance = AuthManager._internal();
  factory AuthManager() => _instance;
  AuthManager._internal();

  DocumentSnapshot? loggedInVendor;

  /// Solo existen los roles `admin` y `vendedor`.
  /// Usuarios legacy con `encargado` se tratan como vendedor.
  static String normalizarRol(String? rol) {
    final r = (rol ?? 'vendedor').toString().trim().toLowerCase();
    if (r == 'admin') return 'admin';
    return 'vendedor';
  }

  static bool esAdmin(String? rol) => normalizarRol(rol) == 'admin';
}
