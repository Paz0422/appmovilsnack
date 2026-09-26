import 'package:flutter/painting.dart';

/// Tipografías incluidas en la app (assets/fuentes): funcionan sin internet.
///
/// - Inter: todo el texto de trabajo. Cifras tabulares para que cantidades y
///   montos se alineen en columnas.
/// - Lobster: cursiva parecida al logo, SOLO para títulos de marca ("Fusión",
///   saludo del login, "¡Turno cerrado!"). Nunca en datos, botones ni campos.
class AppFonts {
  AppFonts._();

  static const String texto = 'Inter';
  static const String marca = 'Lobster';

  static const List<FontFeature> _cifrasTabulares = [
    FontFeature.tabularFigures(),
  ];

  /// Estilo de texto general (reemplaza a las fuentes que se descargaban de internet).
  static TextStyle inter({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    FontStyle? fontStyle,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: texto,
    fontFeatures: _cifrasTabulares,
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
  );

  /// Títulos de marca en cursiva.
  static TextStyle lobster({
    Color? color,
    double fontSize = 28,
    double? height,
  }) => TextStyle(
    fontFamily: marca,
    color: color,
    fontSize: fontSize,
    height: height,
  );
}
