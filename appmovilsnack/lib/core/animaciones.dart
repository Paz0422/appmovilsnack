// Movimiento de la interfaz: duraciones, curvas y atajos de flutter_animate.
//
// Reglas:
// - Ninguna animación bloquea un toque ni demora una acción: los elementos
//   se pueden tocar mientras entran.
// - Solo los indicadores de carga se repiten sin fin; el resto termina solo
//   (así los tests con pumpAndSettle no se quedan esperando).
// - Las demoras van en cada efecto (`fadeIn(delay: …)`), nunca en
//   `.animate(delay: …)`: esa usa un Timer que deja los tests de widgets con
//   timers pendientes.
// - Si el teléfono tiene "Quitar animaciones" activado ([Movimiento.reducido]),
//   los atajos devuelven el widget sin animar.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class Movimiento {
  Movimiento._();

  /// Lo fija `MaterialApp.builder` (main.dart) según la accesibilidad del
  /// sistema. En los tests queda en false.
  static bool reducido = false;

  static const Duration rapido = Duration(milliseconds: 220);
  static const Duration normal = Duration(milliseconds: 450);
  static const Duration lento = Duration(milliseconds: 750);

  /// Separación entre elementos de una lista que entran escalonados.
  static const Duration escalon = Duration(milliseconds: 70);

  static const Curve entrada = Curves.easeOutCubic;

  /// Se pasa un poco y vuelve: da vida sin rebotar demasiado.
  static const Curve resorte = Curves.easeOutBack;

  /// Rebote marcado: solo mascota y celebraciones.
  static const Curve rebote = Curves.elasticOut;

  /// Demora del elemento [orden] de una lista. Tope de 8 para que una lista
  /// larga no tarde en aparecer completa.
  static Duration demora(int orden) => escalon * orden.clamp(0, 8);
}

extension AnimacionesApp on Widget {
  /// Aparece subiendo y creciendo un poco. [orden] escalona listas y grillas.
  Widget entrada({int orden = 0, double desde = 0.18}) {
    if (Movimiento.reducido) return this;
    final d = Movimiento.demora(orden);
    return animate()
        .fadeIn(delay: d, duration: Movimiento.normal, curve: Movimiento.entrada)
        .slideY(
          begin: desde,
          end: 0,
          delay: d,
          duration: Movimiento.normal,
          curve: Movimiento.resorte,
        )
        .scaleXY(
          begin: 0.94,
          end: 1,
          delay: d,
          duration: Movimiento.normal,
          curve: Movimiento.resorte,
        );
  }

  /// Para ítems de listas con builder: solo anima los primeros (los que se
  /// ven al abrir). Los que aparecen al hacer scroll no esperan su turno.
  Widget entradaEnLista(int index) =>
      index < 10 ? entrada(orden: index) : this;

  /// Entra deslizándose de lado (pasos de un flujo, paneles).
  Widget entradaLateral({int orden = 0, bool desdeDerecha = true}) {
    if (Movimiento.reducido) return this;
    final d = Movimiento.demora(orden);
    return animate()
        .fadeIn(delay: d, duration: Movimiento.normal, curve: Movimiento.entrada)
        .slideX(
          begin: desdeDerecha ? 0.22 : -0.22,
          end: 0,
          delay: d,
          duration: Movimiento.normal,
          curve: Movimiento.resorte,
        );
  }

  /// Aparece desde abajo (paneles de confirmación, botones fijos).
  Widget entradaDesdeAbajo({Duration demora = Duration.zero}) {
    if (Movimiento.reducido) return this;
    return animate()
        .fadeIn(delay: demora, duration: Movimiento.normal)
        .slideY(
          begin: 0.6,
          end: 0,
          delay: demora,
          duration: Movimiento.lento,
          curve: Movimiento.resorte,
        );
  }

  /// Aparición con rebote: mascota, sellos de éxito.
  Widget aparicionRebote({Duration demora = Duration.zero}) {
    if (Movimiento.reducido) return this;
    return animate()
        .fadeIn(delay: demora, duration: Movimiento.rapido)
        .scaleXY(
          begin: 0.4,
          end: 1,
          delay: demora,
          duration: const Duration(milliseconds: 1100),
          curve: Movimiento.rebote,
        )
        .rotate(
          begin: -0.04,
          end: 0,
          delay: demora,
          duration: Movimiento.lento,
          curve: Movimiento.resorte,
        );
  }

  /// Saludo de la mascota: se inclina a un lado y al otro y vuelve.
  Widget saludo({Duration demora = const Duration(milliseconds: 900)}) {
    if (Movimiento.reducido) return this;
    return animate()
        .rotate(
          begin: 0,
          end: 0.035,
          delay: demora,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          alignment: Alignment.bottomCenter,
        )
        .then()
        .rotate(
          begin: 0,
          end: -0.07,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOut,
          alignment: Alignment.bottomCenter,
        )
        .then()
        .rotate(
          begin: 0,
          end: 0.035,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutBack,
          alignment: Alignment.bottomCenter,
        );
  }

  /// Llama la atención un par de veces (aviso nuevo). Termina sola.
  Widget latido({Duration demora = const Duration(milliseconds: 500)}) {
    if (Movimiento.reducido) return this;
    const subida = Duration(milliseconds: 180);
    const bajada = Duration(milliseconds: 320);
    return animate()
        .scaleXY(begin: 1, end: 1.04, delay: demora, duration: subida)
        .then()
        .scaleXY(begin: 1, end: 1 / 1.04, duration: bajada, curve: Curves.easeOut)
        .then(delay: const Duration(milliseconds: 120))
        .scaleXY(begin: 1, end: 1.04, duration: subida)
        .then()
        .scaleXY(begin: 1, end: 1 / 1.04, duration: bajada, curve: Curves.easeOut);
  }

  /// Sacudida corta para un error. Usar con una `key` que cambie con el
  /// error, así se repite cada vez que aparece uno nuevo.
  Widget temblor() {
    if (Movimiento.reducido) return this;
    return animate()
        .fadeIn(duration: Movimiento.rapido)
        .shakeX(hz: 5, amount: 6, duration: const Duration(milliseconds: 480));
  }

  /// Destello dorado que cruza una vez (tarjetas destacadas).
  Widget destello({Duration demora = const Duration(milliseconds: 600)}) {
    if (Movimiento.reducido) return this;
    return animate().shimmer(
      delay: demora,
      duration: const Duration(milliseconds: 1400),
      color: Colors.white.withValues(alpha: 0.35),
      angle: 0.6,
    );
  }
}

/// Transición entre pantallas: la nueva sube un poco, crece y aparece; la
/// anterior se achica y se oscurece levemente detrás. Se aplica a toda la
/// app desde el tema (no hay que tocar cada `MaterialPageRoute`).
class TransicionFusion extends PageTransitionsBuilder {
  const TransicionFusion();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 320);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Movimiento.reducido) return child;

    final curva = CurveTween(curve: Curves.easeOutCubic);
    Animation<V> entra<V>(Tween<V> t) => animation.drive(t.chain(curva));
    Animation<V> queda<V>(Tween<V> t) =>
        secondaryAnimation.drive(t.chain(curva));

    return ScaleTransition(
      scale: queda(Tween<double>(begin: 1, end: 0.96)),
      child: FadeTransition(
        opacity: queda(Tween<double>(begin: 1, end: 0.55)),
        child: SlideTransition(
          position: entra(
            Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero),
          ),
          child: ScaleTransition(
            scale: entra(Tween<double>(begin: 0.97, end: 1)),
            child: FadeTransition(
              opacity: entra(Tween<double>(begin: 0, end: 1)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
