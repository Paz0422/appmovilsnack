/// Avisos de interfaz que se muestran después de cerrar la sesión.
/// Es solo estado visual: no afecta la sesión ni los datos.
class AvisosSesion {
  AvisosSesion._();

  /// Sector cuyo turno se acaba de cerrar. El login lo muestra una vez.
  static String? turnoCerradoEn;

  /// Devuelve el aviso pendiente y lo borra, para mostrarlo una sola vez.
  static String? tomarTurnoCerrado() {
    final sector = turnoCerradoEn;
    turnoCerradoEn = null;
    return sector;
  }
}
