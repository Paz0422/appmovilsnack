// Panel › Eventos activos: los partidos activos lado a lado; al elegir uno se
// ven sus ventas, el estado de cada sector, sus incidencias y las acciones
// directas (ya filtradas a ese partido).
import 'package:flutter/material.dart';
import 'package:front_appsnack/core/animaciones.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/core/margen_inferior.dart';
import 'package:front_appsnack/core/precio.dart';
import 'package:front_appsnack/core/tipografia.dart';
import 'package:front_appsnack/services/admin_estadisticas_service.dart';
import 'package:front_appsnack/services/incidencias_service.dart';
import 'package:front_appsnack/widgets/agregar_stock.dart';
import 'package:front_appsnack/widgets/cierres_partidos_activos.dart';
import 'package:front_appsnack/widgets/comunes/animados.dart';
import 'package:front_appsnack/widgets/comunes/cargando.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';
import 'package:front_appsnack/widgets/dashboard_card.dart';
import 'package:front_appsnack/widgets/eventos_management.dart';
import 'package:front_appsnack/widgets/graficos_admin.dart';
import 'package:front_appsnack/widgets/incidencias_pendientes.dart';
import 'package:front_appsnack/widgets/reporte_bandejeo_admin.dart';

typedef EventoActivo = ({String id, String nombre});

class EventosActivosAdmin extends StatefulWidget {
  const EventosActivosAdmin({
    super.key,
    required this.abrir,
    this.cargarEventos,
    this.cargarResumen,
  });

  /// Abre una pantalla y termina al volver (refresca los contadores del
  /// panel). Viene de HomeAdmin.
  final Future<void> Function(Widget Function() pantalla) abrir;

  /// Solo para tests: reemplaza la lectura de eventos activos.
  @visibleForTesting
  final Future<List<EventoActivo>> Function()? cargarEventos;

  /// Solo para tests: reemplaza la carga del resumen de un evento.
  @visibleForTesting
  final Future<ResumenEvento> Function(String eventoId)? cargarResumen;

  @override
  State<EventosActivosAdmin> createState() => _EventosActivosAdminState();
}

class _EventosActivosAdminState extends State<EventosActivosAdmin> {
  List<EventoActivo>? _eventos;
  String? _errorEventos;
  String? _elegido;

  /// Resumen cargado por evento (se vuelve a pedir al actualizar o al volver
  /// de una acción).
  final Map<String, Future<ResumenEvento>> _resumenes = {};

  @override
  void initState() {
    super.initState();
    _cargarEventos();
  }

  Future<void> _cargarEventos() async {
    setState(() {
      _eventos = null;
      _errorEventos = null;
      _resumenes.clear();
    });
    try {
      final eventos = await (widget.cargarEventos ??
          AdminEstadisticasService.listarEventosActivos)();
      if (!mounted) return;
      setState(() {
        _eventos = eventos;
        if (!eventos.any((e) => e.id == _elegido)) {
          _elegido = eventos.isEmpty ? null : eventos.first.id;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _errorEventos = '$e');
    }
  }

  Future<ResumenEvento> _resumen(String eventoId) => _resumenes.putIfAbsent(
    eventoId,
    () => (widget.cargarResumen ??
        AdminEstadisticasService.cargarResumenEvento)(eventoId),
  );

  /// Abre una acción y, al volver, recarga el resumen del evento.
  Future<void> _accion(Widget Function() pantalla) async {
    await widget.abrir(pantalla);
    if (!mounted) return;
    setState(() => _resumenes.remove(_elegido));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos activos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargarEventos,
          ),
        ],
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_errorEventos != null) {
      return ErrorAmable(
        titulo: 'No pudimos cargar los eventos',
        detalle: _errorEventos,
        onReintentar: _cargarEventos,
      );
    }
    final eventos = _eventos;
    if (eventos == null) return const CargandoTarjetas(cantidad: 4, alto: 96);
    if (eventos.isEmpty) {
      return EstadoVacio(
        titulo: 'No hay eventos activos',
        mensaje:
            'Cree el partido del día y déjelo activo para que los vendedores '
            'lo vean.',
        accion: ElevatedButton.icon(
          onPressed: () async {
            await widget.abrir(() => const EventosManagement());
            if (mounted) _cargarEventos();
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Crear evento'),
        ),
      );
    }

    final elegido = eventos.firstWhere((e) => e.id == _elegido);
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _resumenes.remove(elegido.id));
        await _resumen(elegido.id);
      },
      child: ListView(
        padding: conMargenInferior(
          context,
          const EdgeInsets.fromLTRB(16, 8, 16, 24),
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    eventos.length == 1
                        ? 'Partido activo'
                        : 'Elija un partido (${eventos.length} activos)',
                    style: AppFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.tintaSecundaria,
                    ),
                  ).entrada(),
                  const SizedBox(height: 10),
                  _SelectorEventos(
                    eventos: eventos,
                    elegido: elegido.id,
                    onElegir: (id) => setState(() => _elegido = id),
                  ).entrada(orden: 1),
                  const SizedBox(height: 18),
                  // Al cambiar de partido, el contenido entra de lado.
                  AnimatedSwitcher(
                    duration: Movimiento.reducido
                        ? Duration.zero
                        : Movimiento.normal,
                    switchInCurve: Movimiento.resorte,
                    transitionBuilder: (hijo, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.06, 0),
                          end: Offset.zero,
                        ).animate(a),
                        child: hijo,
                      ),
                    ),
                    layoutBuilder: (actual, anteriores) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...anteriores, ?actual],
                    ),
                    child: FutureBuilder<ResumenEvento>(
                      key: ValueKey(elegido.id),
                      future: _resumen(elegido.id),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return ErrorAmable(
                            titulo: 'No pudimos cargar el partido',
                            detalle: '${snap.error}',
                            dentroDeLista: true,
                            onReintentar: () =>
                                setState(() => _resumenes.remove(elegido.id)),
                          );
                        }
                        if (!snap.hasData) {
                          return const CargandoTarjetas(
                            cantidad: 4,
                            alto: 110,
                            padding: EdgeInsets.zero,
                            dentroDeLista: true,
                          );
                        }
                        return _DetalleEvento(
                          evento: elegido,
                          resumen: snap.data!,
                          onAccion: _accion,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjetas de los partidos activos, lado a lado (con scroll si no caben).
class _SelectorEventos extends StatelessWidget {
  const _SelectorEventos({
    required this.eventos,
    required this.elegido,
    required this.onElegir,
  });

  final List<EventoActivo> eventos;
  final String elegido;
  final void Function(String id) onElegir;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final (i, e) in eventos.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            _TarjetaEvento(
              nombre: e.nombre,
              elegido: e.id == elegido,
              onTap: () => onElegir(e.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaEvento extends StatelessWidget {
  const _TarjetaEvento({
    required this.nombre,
    required this.elegido,
    required this.onTap,
  });

  final String nombre;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Presionable(
      child: Semantics(
        button: true,
        selected: elegido,
        label: 'Partido $nombre',
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: Movimiento.reducido ? Duration.zero : Movimiento.rapido,
          constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
          decoration: BoxDecoration(
            gradient: elegido ? AppGradientes.dorado : null,
            color: elegido ? null : AppColors.tarjeta,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: elegido ? AppColors.dorado : AppColors.separador,
              width: 2,
            ),
            boxShadow: elegido ? AppShadows.dorado : AppShadows.card,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stadium_rounded,
                      color: elegido ? AppColors.negro : AppColors.dorado,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: elegido ? AppColors.negro : AppColors.tinta,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: elegido
                                      ? AppColors.negro
                                      : AppColors.exito,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Activo',
                                style: AppFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: elegido
                                      ? AppColors.negro
                                      : AppColors.exito,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

/// Ventas, sectores, incidencias y acciones del partido elegido.
class _DetalleEvento extends StatelessWidget {
  const _DetalleEvento({
    required this.evento,
    required this.resumen,
    required this.onAccion,
  });

  final EventoActivo evento;
  final ResumenEvento resumen;
  final Future<void> Function(Widget Function() pantalla) onAccion;

  @override
  Widget build(BuildContext context) {
    final ventas = _Ventas(resumen: resumen);
    final sectores = _Sectores(resumen: resumen);
    final incidencias = _Incidencias(
      incidencias: resumen.incidencias,
      onResolver: () => onAccion(() => const IncidenciasPendientes()),
    );
    final acciones = _Acciones(eventoId: evento.id, onAccion: onAccion);

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    ventas.entrada(),
                    const SizedBox(height: 16),
                    sectores.entrada(orden: 2),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    acciones.entrada(orden: 1),
                    const SizedBox(height: 16),
                    incidencias.entrada(orden: 3),
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            ventas.entrada(),
            const SizedBox(height: 16),
            acciones.entrada(orden: 1),
            const SizedBox(height: 16),
            incidencias.entrada(orden: 2),
            const SizedBox(height: 16),
            sectores.entrada(orden: 3),
          ],
        );
      },
    );
  }
}

class _Ventas extends StatelessWidget {
  const _Ventas({required this.resumen});

  final ResumenEvento resumen;

  @override
  Widget build(BuildContext context) {
    final v = resumen.ventas;
    final conVentas = resumen.sectores.where((s) => s.vendido > 0).toList()
      ..sort((a, b) => b.vendido.compareTo(a.vendido));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardCard.kpi(
          title: 'Vendido en este partido',
          value: formatearPesos(v.totalVendido),
          cifra: v.totalVendido.toDouble(),
          formatearCifra: formatearPesos,
          subtitle:
              '${v.cantidadCierres} cierre${v.cantidadCierres == 1 ? '' : 's'} · '
              '${formatearPesos(v.montoBandejeoTurnosAbiertos)} en bandejeo',
          icon: Icons.payments_outlined,
        ),
        if (conVentas.isNotEmpty) ...[
          const SizedBox(height: 16),
          TarjetaGrafico(
            titulo: 'Ventas por sector',
            subtitulo: 'Cierres de turno y bandejeo en turnos abiertos',
            child: RankingBarras(
              formatear: formatearPesos,
              items: [
                for (final s in conVentas)
                  (nombre: s.nombre, detalle: null, monto: s.vendido),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Sectores extends StatelessWidget {
  const _Sectores({required this.resumen});

  final ResumenEvento resumen;

  @override
  Widget build(BuildContext context) {
    final total = resumen.sectores.length;
    final cerrados = resumen.cuantos(EstadoTurno.cerrado);
    return TarjetaGrafico(
      titulo: 'Estado de los sectores',
      subtitulo: total == 0
          ? 'Este partido no tiene sectores'
          : '${resumen.cuantos(EstadoTurno.enCurso)} en curso · '
                '$cerrados cerrado${cerrados == 1 ? '' : 's'} · '
                '${resumen.cuantos(EstadoTurno.sinAbrir)} sin abrir',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (total > 0) ...[
            // Avance de cierres: cuántos puestos ya entregaron su conteo.
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: ProgresoEntrada(
                      curva: Curves.easeOutCubic,
                      builder: (t) => LinearProgressIndicator(
                        value: cerrados / total * t,
                        minHeight: 10,
                        backgroundColor: AppColors.tarjetaAlta,
                        color: AppColors.cafe,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$cerrados de $total cerrados',
                  style: AppFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tintaSecundaria,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          for (final (i, s) in resumen.sectores.indexed) ...[
            if (i > 0) const Divider(height: 18),
            _FilaSector(sector: s),
          ],
        ],
      ),
    );
  }
}

class _FilaSector extends StatelessWidget {
  const _FilaSector({required this.sector});

  final SectorDelEvento sector;

  static String _dos(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final (texto, color, fondo, icono) = switch (sector.estado) {
      EstadoTurno.sinAbrir => (
        'Sin abrir',
        AppColors.avisoTexto,
        AppColors.avisoSuave,
        Icons.hourglass_empty_rounded,
      ),
      EstadoTurno.enCurso => (
        'En curso',
        AppColors.exito,
        AppColors.exitoSuave,
        Icons.play_circle_outline_rounded,
      ),
      EstadoTurno.cerrado => (
        sector.cerradoA == null
            ? 'Cerrado'
            : 'Cerrado ${_dos(sector.cerradoA!.hour)}:${_dos(sector.cerradoA!.minute)}',
        AppColors.cafeClaro,
        AppColors.cafeSuave,
        Icons.lock_rounded,
      ),
    };
    return Semantics(
      label: '${sector.nombre}: $texto, vendido ${formatearPesos(sector.vendido)}',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sector.nombre,
                  style: AppFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tinta,
                  ),
                ),
                Text(
                  sector.vendido > 0
                      ? 'Vendido: ${formatearPesos(sector.vendido)}'
                      : 'Sin ventas registradas',
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: AppColors.tintaSecundaria,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icono, size: 15, color: color),
                const SizedBox(width: 5),
                Text(
                  texto,
                  style: AppFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Incidencias extends StatelessWidget {
  const _Incidencias({required this.incidencias, required this.onResolver});

  final List<Map<String, dynamic>> incidencias;
  final VoidCallback onResolver;

  @override
  Widget build(BuildContext context) {
    if (incidencias.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.exitoSuave,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.exito.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppColors.exito, size: 28)
                .aparicionRebote(),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sin incidencias en este partido',
                style: AppFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.tinta,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final n = incidencias.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.avisoSuave,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.aviso, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.report_problem_rounded, color: AppColors.aviso),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$n incidencia${n == 1 ? '' : 's'} por resolver',
                  style: AppFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.tinta,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final d in incidencias.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• ${TipoIncidencia.etiqueta(TipoIncidencia.de(d))}: '
                '${d['nombreProducto'] ?? 'producto'}'
                '${d['diferencia'] != null ? ' (${d['diferencia']} u.)' : ''}'
                ' · ${d['sectorNombre'] ?? d['sectorDestinoNombre'] ?? ''}',
                style: AppFonts.inter(
                  fontSize: 14,
                  color: AppColors.avisoTexto,
                  height: 1.3,
                ),
              ),
            ),
          if (n > 3)
            Text(
              'y ${n - 3} más…',
              style: AppFonts.inter(fontSize: 14, color: AppColors.avisoTexto),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Presionable(
              child: ElevatedButton.icon(
                onPressed: onResolver,
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text('Resolver incidencias'),
              ),
            ),
          ),
        ],
      ),
    ).latido(demora: const Duration(milliseconds: 800));
  }
}

class _Acciones extends StatelessWidget {
  const _Acciones({required this.eventoId, required this.onAccion});

  final String eventoId;
  final Future<void> Function(Widget Function() pantalla) onAccion;

  @override
  Widget build(BuildContext context) {
    final acciones = [
      (
        Icons.add_box_outlined,
        'Agregar stock',
        'Sumar unidades a un sector',
        AppColors.dorado,
        () => onAccion(() => AgregarStock(eventoIdInicial: eventoId)),
      ),
      (
        Icons.directions_walk_rounded,
        'Bandejeo',
        'Rondas y dinero en la calle',
        AppColors.coral,
        () => onAccion(() => ReporteBandejeoAdmin(eventoIdInicial: eventoId)),
      ),
      (
        Icons.lock_clock_outlined,
        'Cierres de turno',
        'Qué sectores cerraron',
        AppColors.cafe,
        () => onAccion(() => const CierresPartidosActivos()),
      ),
    ];
    return TarjetaGrafico(
      titulo: 'Acciones',
      subtitulo: 'Ya elegidas para este partido',
      child: Column(
        children: [
          for (final (i, (icono, titulo, desc, color, abrir)) in acciones.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            Presionable(
              child: Material(
                color: AppColors.fondo,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  onTap: abrir,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 60),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icono, color: color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titulo,
                                style: AppFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.tinta,
                                ),
                              ),
                              Text(
                                desc,
                                style: AppFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.tintaSecundaria,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded, color: color),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
