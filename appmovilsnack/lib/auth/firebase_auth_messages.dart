import 'package:firebase_auth/firebase_auth.dart';

/// Textos breves y claros para el usuario (sin inglés técnico de Firebase).

String mensajeInicioSesion(FirebaseAuthException e) {
  switch (e.code) {
    // Mismo texto que AuthManager.mensajeCredencialesIncorrectas (usuario inexistente).
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'Usuario o contraseña incorrectos';
    case 'invalid-email':
      return 'El correo en su perfil no es válido. Avise al administrador.';
    case 'user-disabled':
      return 'Esta cuenta está deshabilitada. Contacte al administrador.';
    case 'too-many-requests':
      return 'Demasiados intentos. Espere un minuto e intente de nuevo.';
    case 'network-request-failed':
      return 'Sin conexión. Revise Wi‑Fi o datos e intente otra vez.';
    case 'operation-not-allowed':
      return 'El acceso con correo no está habilitado. Revise Firebase (admin).';
    case 'invalid-verification-code':
    case 'invalid-verification-id':
      return 'Código inválido o vencido. Pida uno nuevo.';
    case 'session-expired':
    case 'user-token-expired':
      return 'Sesión vencida. Cierre la app e inicie sesión de nuevo.';
    case 'requires-recent-login':
      return 'Por seguridad debe volver a iniciar sesión.';
    default:
      return 'No pudimos entrar. Revise usuario y PIN o pida ayuda al admin.';
  }
}

String mensajeRegistro(FirebaseAuthException e) {
  switch (e.code) {
    case 'weak-password':
      return 'Contraseña muy débil. Al menos 6 caracteres, letras y números.';
    case 'email-already-in-use':
      return 'Ese correo ya está registrado. Inicie sesión o use otro correo.';
    case 'invalid-email':
      return 'Correo inválido. Use un formato como nombre@correo.com';
    case 'operation-not-allowed':
      return 'Registro deshabilitado. Lo debe habilitar un administrador.';
    case 'network-request-failed':
      return 'Sin conexión. Revise internet.';
    case 'too-many-requests':
      return 'Demasiados intentos. Espere unos minutos.';
    default:
      return 'No se pudo registrar. Revise los datos e intente de nuevo.';
  }
}

String mensajeRestablecerClave(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'Correo inválido. Revise que esté bien escrito.';
    case 'user-not-found':
      return 'No hay cuenta con ese correo.';
    case 'network-request-failed':
      return 'Sin conexión. Revise internet.';
    case 'too-many-requests':
      return 'Demasiados envíos. Espere unos minutos.';
    default:
      return 'No se pudo enviar el correo. Intente más tarde.';
  }
}

String mensajeErrorInesperado(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('socketexception') ||
      s.contains('network') ||
      s.contains('failed host lookup') ||
      s.contains('connection reset') ||
      s.contains('connection refused')) {
    return 'Problema de conexión. Revise la red e intente de nuevo.';
  }
  if (s.contains('timeout') || s.contains('timed out')) {
    return 'Tardó demasiado. Intente de nuevo en un momento.';
  }
  if (s.contains('permission-denied')) {
    return 'Sin permiso para esta acción. Consulte al administrador.';
  }
  return 'Algo salió mal. Si pasa otra vez, avise al administrador.';
}
