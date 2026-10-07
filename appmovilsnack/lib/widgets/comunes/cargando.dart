// Esqueletos de carga: la forma de lo que va a aparecer, con un brillo que
// la recorre. Reemplazan a la rueda giratoria en listas y paneles.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:front_appsnack/core/animaciones.dart';
import 'package:front_appsnack/core/app_theme.dart';

/// Lista de tarjetas "fantasma" mientras cargan los datos.
class CargandoTarjetas extends StatelessWidget {
  const CargandoTarjetas({
    super.key,
    this.cantidad = 5,
    this.alto = 76,
    this.padding = const EdgeInsets.all(16),
    this.dentroDeLista = false,
  });

  final int cantidad;
  final double alto;
  final EdgeInsets padding;

  /// true si ya está dentro de un scroll: no crea el suyo.
  final bool dentroDeLista;

  @override
  Widget build(BuildContext context) {
    final tarjetas = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < cantidad; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _TarjetaFantasma(alto: alto, orden: i),
        ],
      ],
    );
    return Semantics(
      label: 'Cargando',
      liveRegion: true,
      child: ExcludeSemantics(
        child: dentroDeLista
            ? Padding(padding: padding, child: tarjetas)
            : SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: padding,
                child: tarjetas,
              ),
      ),
    );
  }
}

class _TarjetaFantasma extends StatelessWidget {
  const _TarjetaFantasma({required this.alto, required this.orden});

  final double alto;
  final int orden;

  @override
  Widget build(BuildContext context) {
    final tarjeta = Container(
      height: alto,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.separador),
      ),
      child: Row(
        children: [
          _bloque(44, 44, AppRadius.md),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: orden.isEven ? 0.7 : 0.55,
                  child: _bloque(double.infinity, 14, 6),
                ),
                const SizedBox(height: 10),
                FractionallySizedBox(
                  widthFactor: orden.isEven ? 0.4 : 0.5,
                  child: _bloque(double.infinity, 12, 6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (Movimiento.reducido) return tarjeta;
    return tarjeta
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          delay: Movimiento.demora(orden),
          duration: const Duration(milliseconds: 1300),
          color: AppColors.tarjetaAlta,
          angle: 0.4,
        );
  }

  Widget _bloque(double ancho, double alto, double radio) => Container(
    width: ancho,
    height: alto,
    decoration: BoxDecoration(
      color: AppColors.tarjetaAlta,
      borderRadius: BorderRadius.circular(radio),
    ),
  );
}

/// Carga breve en el centro (diálogos, botones, paneles chicos): tres
/// puntos dorados que saltan.
class CargandoPuntos extends StatelessWidget {
  const CargandoPuntos({super.key, this.color = AppColors.dorado});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) _punto(i),
          ],
        ),
      ),
    );
  }

  Widget _punto(int i) {
    final punto = Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (Movimiento.reducido) return punto;
    return punto
        .animate(onPlay: (c) => c.repeat())
        .moveY(
          delay: Duration(milliseconds: 140 * i),
          begin: 0,
          end: -10,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        )
        .then()
        .moveY(
          begin: 0,
          end: 10,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
        )
        .then(delay: Duration(milliseconds: 140 * (2 - i)));
  }
}
