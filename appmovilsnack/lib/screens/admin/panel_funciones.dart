// Piezas del panel del administrador: cuatro botones grandes (entrar como
// vendedor, configuración de eventos, eventos activos y reportes) que abren
// sus módulos, cada uno con para qué sirve y un ejemplo de cuándo usarlo.
import 'package:flutter/material.dart';
import 'package:front_appsnack/core/animaciones.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/core/margen_inferior.dart';
import 'package:front_appsnack/core/tipografia.dart';
import 'package:front_appsnack/widgets/comunes/animados.dart';

/// Un módulo del panel: abre una pantalla.
class OpcionPanel {
  const OpcionPanel({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.abrir,
    this.ejemplo,
    this.contador = 0,
  });

  final IconData icono;
  final String titulo;

  /// Para qué sirve, en una línea.
  final String descripcion;

  /// Situación concreta en la que se usa ("Al puesto Norte le faltan
  /// bebidas"): hace el panel más fácil de entender que una lista de nombres.
  final String? ejemplo;

  /// Termina al volver de la pantalla (para refrescar contadores).
  final Future<void> Function() abrir;

  /// Pendientes a destacar (p. ej. incidencias). 0 = sin contador.
  final int contador;
}

/// Botón grande del panel. Con [opciones] abre una pantalla con esos
/// módulos; sin opciones, [abrirDirecto] lleva directo a una pantalla.
class CategoriaPanel {
  const CategoriaPanel({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.color,
    this.opciones = const [],
    this.abrirDirecto,
  });

  final String titulo;
  final String descripcion;
  final IconData icono;
  final Color color;
  final List<OpcionPanel> opciones;
  final Future<void> Function()? abrirDirecto;

  /// Suma de pendientes de sus módulos (se muestra en el botón).
  int get pendientes => opciones.fold(0, (t, o) => t + o.contador);
}

/// Los cuatro botones: 2 × 2 en teléfono y tablet vertical, en una fila en
/// tablet horizontal o pantalla ancha.
class CategoriasPanel extends StatelessWidget {
  const CategoriasPanel({
    super.key,
    required this.categorias,
    required this.onAbrir,
    this.ordenInicial = 0,
  });

  final List<CategoriaPanel> categorias;
  final void Function(CategoriaPanel) onAbrir;
  final int ordenInicial;

  /// Ancho desde el que los botones van todos en una fila.
  static const anchoFila = 900.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = c.maxWidth >= anchoFila ? categorias.length : 2;
        final filas = [
          for (var i = 0; i < categorias.length; i += columnas)
            categorias.sublist(i, (i + columnas).clamp(0, categorias.length)),
        ];
        return Column(
          children: [
            for (final (f, fila) in filas.indexed) ...[
              if (f > 0) const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < columnas; j++) ...[
                      if (j > 0) const SizedBox(width: 12),
                      Expanded(
                        child: j < fila.length
                            ? BotonCategoria(
                                categoria: fila[j],
                                onTap: () => onAbrir(fila[j]),
                              ).entrada(orden: ordenInicial + f * columnas + j)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Botón grande de una categoría: fondo con su color, ícono que rebota,
/// nombre, para qué sirve y cuántos módulos trae.
class BotonCategoria extends StatelessWidget {
  const BotonCategoria({super.key, required this.categoria, required this.onTap});

  final CategoriaPanel categoria;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = categoria;
    final pendientes = c.pendientes;
    final contenido = c.opciones.isEmpty
        ? null
        : c.opciones.map((o) => o.titulo).join(', ');
    return Presionable(
      child: Semantics(
        button: true,
        onTap: onTap,
        label:
            '${c.titulo}. ${c.descripcion}'
            '${contenido == null ? '' : '. Incluye: $contenido'}'
            '${pendientes > 0 ? '. $pendientes pendientes' : ''}',
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            splashColor: c.color.withValues(alpha: 0.2),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.color.withValues(alpha: 0.24), AppColors.tarjeta],
                  stops: const [0, 0.7],
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: pendientes > 0
                      ? AppColors.aviso
                      : c.color.withValues(alpha: 0.6),
                  width: pendientes > 0 ? 2 : 1.5,
                ),
                boxShadow: AppShadows.card,
              ),
              child: Container(
                constraints: const BoxConstraints(minHeight: 168),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: c.color,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            boxShadow: [
                              BoxShadow(
                                color: c.color.withValues(alpha: 0.4),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(c.icono, color: AppColors.negro, size: 30),
                        ).aparicionRebote(
                          demora: const Duration(milliseconds: 200),
                        ),
                        const Spacer(),
                        if (pendientes > 0)
                          Container(
                            constraints: const BoxConstraints(minWidth: 30),
                            height: 30,
                            padding: const EdgeInsets.symmetric(horizontal: 9),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$pendientes',
                              style: AppFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.negro,
                              ),
                            ),
                          ).latido()
                        else
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: c.color,
                            size: 24,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      c.titulo,
                      style: AppFonts.inter(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.tinta,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.descripcion,
                      style: AppFonts.inter(
                        fontSize: 14,
                        color: AppColors.tintaSecundaria,
                        height: 1.3,
                      ),
                    ),
                    if (c.opciones.isNotEmpty) ...[
                      const Spacer(),
                      const SizedBox(height: 10),
                      // Cuántos módulos trae, para no tener que adivinar.
                      Text(
                        '${c.opciones.length} módulos',
                        style: AppFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: c.color,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla de una categoría: qué es y sus módulos en grilla. Se rearma al
/// volver de cada módulo para mostrar los contadores al día.
class PantallaCategoria extends StatefulWidget {
  const PantallaCategoria({super.key, required this.obtener});

  /// Devuelve la categoría actualizada (contadores incluidos).
  final CategoriaPanel Function() obtener;

  @override
  State<PantallaCategoria> createState() => _PantallaCategoriaState();
}

class _PantallaCategoriaState extends State<PantallaCategoria> {
  @override
  Widget build(BuildContext context) {
    final c = widget.obtener();
    // Al volver de un módulo, se rearma con los contadores nuevos.
    final opciones = [
      for (final o in c.opciones)
        OpcionPanel(
          icono: o.icono,
          titulo: o.titulo,
          descripcion: o.descripcion,
          ejemplo: o.ejemplo,
          contador: o.contador,
          abrir: () async {
            await o.abrir();
            if (mounted) setState(() {});
          },
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(c.titulo)),
      body: ListView(
        padding: conMargenInferior(
          context,
          const EdgeInsets.fromLTRB(16, 8, 16, 24),
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: c.color,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(c.icono, color: AppColors.negro, size: 28),
                      ).aparicionRebote(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          c.descripcion,
                          style: AppFonts.inter(
                            fontSize: 16,
                            color: AppColors.tintaSecundaria,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ).entrada(),
                  const SizedBox(height: 18),
                  GrillaModulos(opciones: opciones, color: c.color),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Módulos en filas: 2 por fila en teléfono, 3 en tablet vertical y 4 en
/// pantalla ancha. Filas con IntrinsicHeight (no alto fijo): con la letra
/// del sistema agrandada los módulos crecen en vez de cortarse.
class GrillaModulos extends StatelessWidget {
  const GrillaModulos({super.key, required this.opciones, required this.color});

  final List<OpcionPanel> opciones;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = c.maxWidth < 600 ? 2 : (c.maxWidth < 900 ? 3 : 4);
        final filas = [
          for (var i = 0; i < opciones.length; i += columnas)
            opciones.sublist(i, (i + columnas).clamp(0, opciones.length)),
        ];
        return Column(
          children: [
            for (final (f, fila) in filas.indexed) ...[
              if (f > 0) const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < columnas; j++) ...[
                      if (j > 0) const SizedBox(width: 10),
                      Expanded(
                        child: j < fila.length
                            ? MosaicoOpcion(
                                opcion: fila[j],
                                color: color,
                                orden: f * columnas + j,
                              ).entrada(orden: f * columnas + j + 1)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Módulo: ícono de color que rebota al aparecer, nombre, para qué sirve y
/// un ejemplo. Todo el módulo es tocable y se hunde al presionarlo.
class MosaicoOpcion extends StatelessWidget {
  const MosaicoOpcion({
    super.key,
    required this.opcion,
    required this.color,
    this.orden = 0,
  });

  final OpcionPanel opcion;
  final Color color;

  /// Posición en su bloque: los íconos rebotan uno tras otro.
  final int orden;

  @override
  Widget build(BuildContext context) {
    final contador = opcion.contador;
    final ejemplo = opcion.ejemplo;
    return Presionable(
      child: Semantics(
        button: true,
        onTap: opcion.abrir,
        label:
            '${opcion.titulo}. ${opcion.descripcion}'
            '${ejemplo == null ? '' : '. Por ejemplo: $ejemplo'}'
            '${contador > 0 ? '. $contador pendientes' : ''}',
        excludeSemantics: true,
        child: Material(
          color: AppColors.fondo,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            onTap: opcion.abrir,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            splashColor: color.withValues(alpha: 0.18),
            child: Container(
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: contador > 0
                      ? AppColors.aviso
                      : color.withValues(alpha: 0.35),
                  width: contador > 0 ? 2 : 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(opcion.icono, color: color, size: 26),
                      ).aparicionRebote(demora: Movimiento.demora(orden + 2)),
                      const Spacer(),
                      if (contador > 0)
                        Container(
                          constraints: const BoxConstraints(minWidth: 28),
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$contador',
                            style: AppFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.negro,
                            ),
                          ),
                        ).latido()
                      else
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: color.withValues(alpha: 0.8),
                          size: 22,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    opcion.titulo,
                    style: AppFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.tinta,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    opcion.descripcion,
                    style: AppFonts.inter(
                      fontSize: 13,
                      color: AppColors.tintaSecundaria,
                      height: 1.3,
                    ),
                  ),
                  if (ejemplo != null) ...[
                    const Spacer(),
                    const SizedBox(height: 8),
                    // Ejemplo: una situación real en la que se usa.
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                      decoration: BoxDecoration(
                        color: AppColors.cafeSuave,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 16,
                            color: AppColors.cafeClaro,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              ejemplo,
                              style: AppFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.cafeClaro,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
