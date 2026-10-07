// Piezas de interfaz con movimiento, reutilizadas en toda la app.
import 'package:flutter/material.dart';
import 'package:front_appsnack/core/animaciones.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/core/tipografia.dart';

/// Cifra que cuenta desde 0 hasta [valor] al aparecer, y desde el valor
/// anterior cuando cambia. El lector de pantalla oye siempre el valor final.
class CifraAnimada extends StatelessWidget {
  const CifraAnimada({
    super.key,
    required this.valor,
    required this.formatear,
    this.style,
    this.duracion = const Duration(milliseconds: 1100),
    this.textAlign,
  });

  final double valor;
  final String Function(double) formatear;
  final TextStyle? style;
  final Duration duracion;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final texto = formatear(valor);
    if (Movimiento.reducido) {
      return Text(texto, style: style, textAlign: textAlign);
    }
    return Semantics(
      label: texto,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: valor),
        duration: duracion,
        curve: Curves.easeOutExpo,
        builder: (_, v, _) => Text(
          // Al final muestra exactamente el valor (sin redondeos del tween).
          v == valor ? texto : formatear(v),
          style: style,
          textAlign: textAlign,
        ),
      ),
    );
  }
}

/// Progreso de entrada (0 → 1) para dibujar algo de a poco: gráficos que
/// crecen, barras que se llenan, filetes que se estiran. Con "Quitar
/// animaciones" arranca en 1. (fl_chart solo anima cuando cambian los datos;
/// esto da la animación de la primera vez.)
class ProgresoEntrada extends StatelessWidget {
  const ProgresoEntrada({
    super.key,
    required this.builder,
    this.duracion = const Duration(milliseconds: 1100),
    this.curva = Curves.linear,
  });

  final Widget Function(double t) builder;
  final Duration duracion;
  final Curve curva;

  @override
  Widget build(BuildContext context) {
    if (Movimiento.reducido) return builder(1);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duracion,
      curve: curva,
      builder: (_, t, _) => builder(t),
    );
  }
}

/// Título de sección: ícono en recuadro dorado, título y un filete dorado →
/// café debajo (el anillo del logo).
class TituloSeccion extends StatelessWidget {
  const TituloSeccion({
    super.key,
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.dorado.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppColors.cafe.withValues(alpha: 0.45),
              ),
            ),
            child: Icon(icono, color: AppColors.dorado, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  style: AppFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.tinta,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                const FiletMarca(),
                if (subtitulo != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitulo!,
                    style: AppFonts.inter(
                      fontSize: 14,
                      color: AppColors.tintaSecundaria,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?accion,
        ],
      ),
    );
  }
}

/// Línea corta dorado → café bajo un título. Crece al aparecer.
class FiletMarca extends StatelessWidget {
  const FiletMarca({super.key, this.ancho = 44});

  final double ancho;

  @override
  Widget build(BuildContext context) {
    final linea = Container(
      width: ancho,
      height: 3,
      decoration: BoxDecoration(
        gradient: AppGradientes.marca,
        borderRadius: BorderRadius.circular(999),
      ),
    );
    return ProgresoEntrada(
      duracion: Movimiento.lento,
      curva: Movimiento.resorte,
      builder: (t) => Transform.scale(
        scaleX: t,
        alignment: Alignment.centerLeft,
        child: linea,
      ),
    );
  }
}

/// Se hunde un poco mientras se presiona y rebota al soltar. Envuelve
/// tarjetas y botones grandes; no cambia qué pasa al tocar.
class Presionable extends StatefulWidget {
  const Presionable({super.key, required this.child, this.escala = 0.96});

  final Widget child;
  final double escala;

  @override
  State<Presionable> createState() => _PresionableState();
}

class _PresionableState extends State<Presionable> {
  bool _presionado = false;

  void _cambiar(bool v) {
    if (_presionado != v && mounted) setState(() => _presionado = v);
  }

  @override
  Widget build(BuildContext context) {
    if (Movimiento.reducido) return widget.child;
    return Listener(
      onPointerDown: (_) => _cambiar(true),
      onPointerUp: (_) => _cambiar(false),
      onPointerCancel: (_) => _cambiar(false),
      child: AnimatedScale(
        scale: _presionado ? widget.escala : 1,
        duration: Duration(milliseconds: _presionado ? 110 : 380),
        curve: _presionado ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

/// Anillo dorado → café alrededor de [child], como el borde del logo.
class AnilloMarca extends StatelessWidget {
  const AnilloMarca({
    super.key,
    required this.child,
    this.grosor = 3,
    this.relleno = AppColors.negro,
    this.padding = const EdgeInsets.all(10),
  });

  final Widget child;
  final double grosor;
  final Color relleno;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(grosor),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            AppColors.dorado,
            AppColors.cafe,
            AppColors.doradoOscuro,
            AppColors.cafe,
            AppColors.dorado,
          ],
        ),
        boxShadow: AppShadows.dorado,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(color: relleno, shape: BoxShape.circle),
        child: child,
      ),
    );
  }
}

/// Etiqueta redonda café (estado, fecha, detalle secundario).
class EtiquetaCafe extends StatelessWidget {
  const EtiquetaCafe({super.key, required this.texto, this.icono});

  final String texto;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cafeSuave,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.cafe.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 16, color: AppColors.cafeClaro),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.cafeClaro,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloque que aparece y desaparece (avisos, errores) sin mover de lugar a
/// sus hermanos en el árbol: siempre ocupa un solo hueco. Con un `if` suelto
/// en un Column, los widgets de abajo cambian de posición, Flutter les asigna
/// el estado equivocado y repiten su animación de entrada. Además, el alto se
/// abre y se cierra suavemente.
class Aparece extends StatelessWidget {
  const Aparece({super.key, this.child});

  /// null = oculto.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final contenido = child ?? const SizedBox(width: double.infinity);
    // AnimatedSize con Duration.zero falla ("mutated in its own
    // performLayout"): sin animaciones va el contenido tal cual. Aparece
    // sigue ocupando el mismo hueco, que es lo que importa.
    if (Movimiento.reducido) return contenido;
    return AnimatedSize(
      duration: Movimiento.normal,
      curve: Movimiento.resorte,
      alignment: Alignment.topCenter,
      child: contenido,
    );
  }
}

/// Texto que cambia con una animación (cantidades que suben o bajan): el
/// valor nuevo entra desde abajo y el anterior sale hacia arriba.
class TextoCambiante extends StatelessWidget {
  const TextoCambiante(this.texto, {super.key, this.style, this.textAlign});

  final String texto;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final hijo = Text(
      texto,
      key: ValueKey(texto),
      style: style,
      textAlign: textAlign,
    );
    if (Movimiento.reducido) return hijo;
    return Semantics(
      label: texto,
      excludeSemantics: true,
      child: AnimatedSwitcher(
      duration: Movimiento.rapido,
      switchInCurve: Movimiento.resorte,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animacion) {
        final entra = child.key == ValueKey(texto);
        return FadeTransition(
          opacity: animacion,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, entra ? 0.6 : -0.6),
              end: Offset.zero,
            ).animate(animacion),
            child: child,
          ),
        );
      },
      layoutBuilder: (actual, anteriores) => Stack(
        alignment: Alignment.center,
        children: [...anteriores, ?actual],
      ),
      child: hijo,
      ),
    );
  }
}
