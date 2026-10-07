import 'package:cloud_firestore/cloud_firestore.dart';

class RolException implements Exception {
  RolException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Cambio de rol (vendedor ↔ administrador) desde "Usuarios y roles".
///
/// Las reglas solo permiten que un administrador cambie `rol` de otro
/// perfil. Además, nadie puede cambiar su propio rol desde la app: así un
/// administrador no se deja sin acceso por error.
class RolesService {
  RolesService([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const rolAdmin = 'admin';
  static const rolVendedor = 'vendedor';

  /// Si el perfil es del usuario con sesión: por id del documento o, en
  /// perfiles antiguos, por el campo `auth_uid`.
  static bool esPropio(String perfilId, Map<String, dynamic>? data, String? miUid) =>
      miUid != null && (perfilId == miUid || data?['auth_uid'] == miUid);

  Future<void> cambiarRol({
    required String perfilId,
    required bool aAdmin,
    required String? miUid,
  }) async {
    final ref = _db.collection('usuarios').doc(perfilId);
    final snap = await ref.get();
    if (!snap.exists) throw RolException('El usuario ya no existe.');
    if (esPropio(perfilId, snap.data(), miUid)) {
      throw RolException('No puede cambiar su propio rol.');
    }
    // Solo `rol`: el resto del perfil no se toca.
    await ref.update({'rol': aAdmin ? rolAdmin : rolVendedor});
  }
}
