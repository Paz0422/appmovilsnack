import 'package:firebase_auth/firebase_auth.dart';

/// Textos breves y claros para el usuario (sin inglés técnico de Firebase).

String mensajeInicioSesion(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-credential':
    case 'wrong-password':
      return 'PIN o contraseña incorrectos. Revisa o recupera la clave abajo.';
    case 'user-not-found':
      return 'No hay cuenta con ese correo. Pide al admin que revise tu perfil.';
    case 'invalid-email':
      return 'El correo en tu perfil no es válido. Avísale al administrador.';
    case 'user-disabled':
      return 'Esta cuenta está deshabilitada. Contacta al administrador.';
    case 'too-many-requests':
      return 'Demasiados intentos. Espera un minuto e intenta de nuevo.';
    case 'network-request-failed':
      return 'Sin conexión. Revisa Wi‑Fi o datos e intenta otra vez.';
    case 'operation-not-allowed':
      return 'El acceso con correo no está habilitado. Revisa Firebase (admin).';
    case 'invalid-verification-code':
    case 'invalid-verification-id':
      return 'Código inválido o vencido. Pide uno nuevo.';
    case 'session-expired':
    case 'user-token-expired':
      return 'Sesión vencida. Cierra la app e inicia sesión de nuevo.';
    case 'requires-recent-login':
      return 'Por seguridad debes volver a iniciar sesión.';
    default:
      return 'No pudimos entrar. Revisa usuario y PIN o pide ayuda al admin.';
  }
}

String mensajeRegistro(FirebaseAuthException e) {
  switch (e.code) {
    case 'weak-password':
      return 'Contraseña muy débil. Al menos 6 caracteres, letras y números.';
    case 'email-already-in-use':
      return 'Ese correo ya está registrado. Inicia sesión u otro correo.';
    case 'invalid-email':
      return 'Correo inválido. Usa un formato como nombre@correo.com';
    case 'operation-not-allowed':
      return 'Registro deshabilitado. Lo debe habilitar un administrador.';
    case 'network-request-failed':
      return 'Sin conexión. Revisa internet.';
    case 'too-many-requests':
      return 'Demasiados intentos. Espera unos minutos.';
    default:
      return 'No se pudo registrar. Revisa los datos e intenta de nuevo.';
  }
}

String mensajeRestablecerClave(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'Correo inválido. Revisa que esté bien escrito.';
    case 'user-not-found':
      return 'No hay cuenta con ese correo.';
    case 'network-request-failed':
      return 'Sin conexión. Revisa internet.';
    case 'too-many-requests':
      return 'Demasiados envíos. Espera unos minutos.';
    default:
      return 'No se pudo enviar el correo. Intenta más tarde.';
  }
}

String mensajeErrorInesperado(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('socketexception') ||
      s.contains('network') ||
      s.contains('failed host lookup') ||
      s.contains('connection reset') ||
      s.contains('connection refused')) {
    return 'Problema de conexión. Revisa la red e intenta de nuevo.';
  }
  if (s.contains('timeout') || s.contains('timed out')) {
    return 'Tardó demasiado. Intenta de nuevo en un momento.';
  }
  if (s.contains('permission-denied')) {
    return 'Sin permiso para esta acción. Consulta al administrador.';
  }
  return 'Algo salió mal. Si pasa otra vez, avisa al administrador.';
}
