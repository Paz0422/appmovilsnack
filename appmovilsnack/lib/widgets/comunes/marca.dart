// Piezas visuales de la marca Fusión reutilizadas en toda la app.
//
// Reglas de la mascota: solo en login, avisos de éxito o error, pantallas
// vacías y errores de carga a pantalla completa. Nunca encima de datos o
// botones, y nunca demora una acción (sin animaciones que bloqueen).
import 'package:flutter/material.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/core/tipografia.dart';

/// Mascota (gatito Fusión). Decorativa: el lector de pantalla la ignora.
/// La imagen es de 338 × 375 px: se ve nítida hasta ~120 dp de alto.
class Mascota extends StatelessWidget {
  const Mascota({super.key, this.alto = 120});

  final double alto;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Image.asset(
        'assets/imagenes/mascota.png',
        height: alto,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      ),
    );
  }
}

/// La palabra "Fusión" en la cursiva de marca (dorado: solo sobre negro).
class MarcaFusion extends StatelessWidget {
  const MarcaFusion({
    super.key,
    this.tamano = 26,
    this.color = AppColors.dorado,
  });

  final double tamano;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Fusión',
      style: AppFonts.lobster(fontSize: tamano, color: color, height: 1.1),
    );
  }
}

/// Pantalla vacía: mascota, título corto y qué va a aparecer ahí.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.titulo,
    this.mensaje,
    this.accion,
    this.dentroDeLista = false,
  });

  final String titulo;
  final String? mensaje;
  final Widget? accion;

  /// true si va dentro de un ListView (p. ej. con "tirar para actualizar"):
  /// no crea su propio scroll.
  final bool dentroDeLista;

  @override
  Widget build(BuildContext context) {
    const relleno = EdgeInsets.fromLTRB(24, 24, 24, 32);
    if (dentroDeLista) {
      return Padding(
        padding: relleno,
        child: Center(child: _contenido()),
      );
    }
    return Center(
      child: SingleChildScrollView(padding: relleno, child: _contenido()),
    );
  }

  Widget _contenido() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Mascota(alto: 120),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: AppFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.tinta,
            ),
          ),
          if (mensaje != null) ...[
            const SizedBox(height: 8),
            Text(
              mensaje!,
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 16,
                color: AppColors.tintaSecundaria,
                height: 1.4,
              ),
            ),
          ],
          if (accion != null) ...[
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: accion),
          ],
        ],
      ),
    );
  }
}

/// Error de carga a pantalla completa, en palabras simples y con Reintentar.
class ErrorAmable extends StatelessWidget {
  const ErrorAmable({
    super.key,
    this.titulo = 'No pudimos cargar la información',
    this.mensaje =
        'Puede ser la señal. Sus datos no se perdieron: intente de nuevo.',
    this.detalle,
    this.onReintentar,
    this.dentroDeLista = false,
  });

  final String titulo;
  final String mensaje;
  final bool dentroDeLista;

  /// Texto técnico opcional, en letra chica (para soporte).
  final String? detalle;

  /// Si es null no se muestra el botón.
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    return EstadoVacio(
      titulo: titulo,
      dentroDeLista: dentroDeLista,
      mensaje: detalle == null ? mensaje : '$mensaje\n\n($detalle)',
      accion: onReintentar == null
          ? null
          : ElevatedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
    );
  }
}

enum TipoAviso { exito, error }

/// Aviso en línea con la mascota pequeña (éxito o error). No bloquea nada.
class AvisoMascota extends StatelessWidget {
  const AvisoMascota({
    super.key,
    required this.tipo,
    required this.titulo,
    this.mensaje,
    this.onCerrar,
  });

  final TipoAviso tipo;
  final String titulo;
  final String? mensaje;
  final VoidCallback? onCerrar;

  @override
  Widget build(BuildContext context) {
    final exito = tipo == TipoAviso.exito;
    final color = exito ? AppColors.exito : AppColors.error;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
        decoration: BoxDecoration(
          color: exito ? AppColors.exitoSuave : AppColors.errorSuave,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          children: [
            const Mascota(alto: 52),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titulo,
                    style: exito
                        ? AppFonts.lobster(fontSize: 22, color: AppColors.tinta)
                        : AppFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.error,
                          ),
                  ),
                  if (mensaje != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      mensaje!,
                      style: AppFonts.inter(
                        fontSize: 14,
                        color: AppColors.tinta,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onCerrar != null)
              IconButton(
                onPressed: onCerrar,
                tooltip: 'Cerrar aviso',
                icon: const Icon(Icons.close_rounded, color: AppColors.tinta),
              ),
          ],
        ),
      ),
    );
  }
}
