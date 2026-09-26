import 'package:flutter/services.dart';

/// Carga las fuentes reales de la app (Inter, Lobster e íconos) en los tests.
/// Sin esto, flutter_test dibuja cada letra como un cuadrado y los textos
/// quedan mucho más anchos que en el teléfono.
Future<void> cargarFuentesApp() async {
  final inter = FontLoader('Inter');
  for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    inter.addFont(rootBundle.load('assets/fuentes/Inter-$peso.ttf'));
  }
  await inter.load();
  await (FontLoader('Lobster')
        ..addFont(rootBundle.load('assets/fuentes/Lobster-Regular.ttf')))
      .load();
  await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
      .load();
}
