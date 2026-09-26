import 'package:flutter/widgets.dart';

// Con targetSdk 35+ (Android 15+) la app se dibuja de borde a borde: la barra
// de navegación del sistema (atrás, inicio, recientes) queda ENCIMA del
// contenido. Flutter reserva ese espacio solo en listas sin `padding`; cuando
// una lista, un botón fijo abajo o una hoja inferior tiene padding propio, hay
// que sumarlo a mano con estas funciones (o envolver en SafeArea).

/// Espacio extra para que el último elemento de una lista no quede bajo un
/// FloatingActionButton.
const double espacioBotonFlotante = 88;

/// Alto de la barra de navegación del sistema. Es 0 dentro de un Scaffold con
/// `bottomNavigationBar` (el Scaffold ya lo descuenta).
double margenSistemaInferior(BuildContext context) =>
    MediaQuery.viewPaddingOf(context).bottom;

/// [base] con el alto de la barra de navegación sumado abajo, más [extra].
EdgeInsets conMargenInferior(
  BuildContext context,
  EdgeInsets base, {
  double extra = 0,
}) =>
    base.copyWith(bottom: base.bottom + extra + margenSistemaInferior(context));
