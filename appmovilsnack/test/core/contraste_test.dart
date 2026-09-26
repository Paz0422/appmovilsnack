import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_appsnack/core/app_theme.dart';

/// Relación de contraste WCAG 2.x entre dos colores opacos.
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  // Texto normal: 4,5:1 (AA); texto principal 7:1 (AAA). Bordes: 3:1.
  final casos = <String, (Color, Color, double)>{
    'texto principal sobre tarjeta': (AppColors.tinta, AppColors.tarjeta, 7),
    'texto principal sobre fondo': (AppColors.tinta, AppColors.fondo, 7),
    'texto principal sobre campo': (AppColors.tinta, AppColors.tarjetaAlta, 7),
    'texto secundario sobre tarjeta': (AppColors.tintaSecundaria, AppColors.tarjeta, 4.5),
    'texto secundario sobre fondo': (AppColors.tintaSecundaria, AppColors.fondo, 4.5),
    'texto secundario sobre campo': (AppColors.tintaSecundaria, AppColors.tarjetaAlta, 4.5),
    'dorado sobre tarjeta (cifras, íconos)': (AppColors.dorado, AppColors.tarjeta, 7),
    'dorado sobre fondo': (AppColors.dorado, AppColors.fondo, 7),
    'azul noche sobre dorado (botón principal)': (AppColors.negro, AppColors.dorado, 7),
    'azul noche sobre dorado oscuro (degradado)': (AppColors.negro, AppColors.doradoOscuro, 7),
    'texto sobre dorado suave': (AppColors.tinta, AppColors.doradoSuave, 7),
    'borde de campo sobre tarjeta': (AppColors.bordeCampo, AppColors.tarjeta, 3),
    'éxito sobre tarjeta': (AppColors.exito, AppColors.tarjeta, 4.5),
    'error sobre tarjeta': (AppColors.error, AppColors.tarjeta, 4.5),
    'aviso sobre tarjeta': (AppColors.aviso, AppColors.tarjeta, 4.5),
    'azul noche sobre éxito (botón)': (AppColors.negro, AppColors.exito, 4.5),
    'azul noche sobre error (botón)': (AppColors.negro, AppColors.error, 4.5),
    'texto de aviso sobre aviso suave': (AppColors.avisoTexto, AppColors.avisoSuave, 4.5),
    'error sobre error suave': (AppColors.error, AppColors.errorSuave, 4.5),
    'éxito sobre éxito suave': (AppColors.exito, AppColors.exitoSuave, 4.5),
    'texto en mensaje de éxito': (AppColors.tinta, AppColors.exitoFuerte, 4.5),
    'texto en mensaje de error': (AppColors.tinta, AppColors.errorFuerte, 4.5),
    'texto en mensaje de aviso': (AppColors.tinta, AppColors.avisoFuerte, 4.5),
    'texto en mensaje neutro': (AppColors.tinta, AppColors.grafito, 7),
    'cian sobre tarjeta (gráficos)': (AppColors.cian, AppColors.tarjeta, 4.5),
    'coral sobre tarjeta (gráficos)': (AppColors.coral, AppColors.tarjeta, 4.5),
    'violeta sobre tarjeta (gráficos)': (AppColors.violeta, AppColors.tarjeta, 4.5),
  };

  for (final caso in casos.entries) {
    test('${caso.key} ≥ ${caso.value.$3}:1', () {
      final (texto, fondo, minimo) = caso.value;
      expect(contraste(texto, fondo), greaterThanOrEqualTo(minimo));
    });
  }

}
