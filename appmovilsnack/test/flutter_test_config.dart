import 'dart:async';

import 'package:front_appsnack/core/animaciones.dart';

/// Configuración común de todos los tests (flutter_test la carga sola).
///
/// Los tests corren como un teléfono con "Quitar animaciones": prueban la
/// pantalla en su estado final. flutter_animate crea un Timer de 0 ms por
/// cada widget animado y flutter_test falla si un test termina con timers
/// pendientes. Las animaciones se prueban aparte en
/// test/widgets/animaciones_test.dart, activándolas y esperando que terminen.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Movimiento.reducido = true;
  await testMain();
}
