// lib/home_admin.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'package:front_appsnack/widgets/dashboard_card.dart';
import 'package:front_appsnack/widgets/graficos_admin.dart';
import 'package:front_appsnack/widgets/inventory_management.dart';
import 'package:front_appsnack/widgets/asignacion_personal.dart';
import 'package:front_appsnack/widgets/eventos_management.dart';
import 'package:front_appsnack/widgets/stock_reports.dart';
import 'package:front_appsnack/widgets/ventas_por_categoria.dart';
import 'package:front_appsnack/widgets/reporte_mermas.dart';
import 'package:front_appsnack/widgets/reporte_diferencias_traspaso.dart';
import 'package:front_appsnack/widgets/incidencias_pendientes.dart';
import 'package:front_appsnack/widgets/agregar_stock.dart';
import 'package:front_appsnack/widgets/gestion_roles_usuarios.dart';
import 'package:front_appsnack/widgets/ranking_vendedores.dart';
import 'package:front_appsnack/widgets/estadio_selection.dart';
import 'package:front_appsnack/widgets/cierres_partidos_activos.dart';
import 'package:front_appsnack/widgets/reporte_bandejeo_admin.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/services/admin_estadisticas_service.dart';
import 'package:front_appsnack/services/incidencias_service.dart';
import 'package:front_appsnack/core/tipografia.dart';
import 'package:front_appsnack/core/margen_inferior.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';

class HomeAdmin extends StatefulWidget {
  const HomeAdmin({super.key, this.cargarResumen, this.contarIncidencias});

  /// Solo para tests: reemplaza la carga de estadísticas desde Firestore.
  @visibleForTesting
  final Future<AdminResumenActivos> Function()? cargarResumen;

  /// Solo para tests: reemplaza el conteo de incidencias pendientes.
  @visibleForTesting
  final Future<int> Function()? contarIncidencias;

  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

/// Una opción del panel: abre una pantalla existente.
class _Opcion {
  const _Opcion({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.abrir,
    this.contador = 0,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final Widget Function() abrir;

  /// Pendientes a destacar (p. ej. incidencias). 0 = sin contador.
  final int contador;
}

/// Sección de la navegación principal del admin.
class _Seccion {
  const _Seccion(this.titulo, this.icono, this.iconoActivo, [String? corta])
    : etiquetaCorta = corta ?? titulo;

  final String titulo;

  /// Nombre en la barra inferior del teléfono (sin cortarse en 4 columnas).
  final String etiquetaCorta;
  final IconData icono;
  final IconData iconoActivo;
}

const _secciones = [
  _Seccion('Inicio', Icons.home_outlined, Icons.home_rounded),
  _Seccion(
    'Evento en curso',
    Icons.stadium_outlined,
    Icons.stadium_rounded,
    'Evento',
  ),
  _Seccion('Reportes', Icons.bar_chart_outlined, Icons.bar_chart_rounded),
  _Seccion(
    'Configuración',
    Icons.settings_outlined,
    Icons.settings_rounded,
    'Ajustes',
  ),
];

class _HomeAdminState extends State<HomeAdmin> {
  AdminResumenActivos? _resumen;
  bool _cargando = true;
  String? _errorCarga;

  /// Sección visible (índice en [_secciones]).
  int _seccion = 0;

  /// Incidencias pendientes de revisar (null mientras carga o si falló).
  int? _incidencias;

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    _cargarIncidencias();
    try {
      final resumen =
          await (widget.cargarResumen ??
              AdminEstadisticasService.cargarResumenActivos)();
      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCarga = e is FirebaseException && e.code == 'permission-denied'
            ? 'Firestore no permitió leer los datos. Si la app se actualizó, '
                  'faltan publicar las reglas nuevas de Firestore.'
            : 'Puede ser la señal. Intente de nuevo.\n($e)';
        _cargando = false;
      });
    }
  }

  /// Solo lectura: cuenta las incidencias pendientes para destacarlas.
  Future<void> _cargarIncidencias() async {
    try {
      final total =
          await (widget.contarIncidencias ??
              () async => (await IncidenciasService().pendientes()).length)();
      if (mounted) setState(() => _incidencias = total);
    } catch (_) {
      if (mounted) setState(() => _incidencias = null);
    }
  }

  Future<void> _abrir(_Opcion opcion) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => opcion.abrir()),
    );
    // Al volver (p. ej. tras resolver incidencias) se actualiza el contador.
    if (mounted) _cargarIncidencias();
  }

  // --- Opciones de cada sección ---

  _Opcion get _opIncidencias => _Opcion(
    icono: Icons.report_problem_outlined,
    titulo: 'Incidencias por resolver',
    descripcion: 'Faltantes en traspasos y sobrantes en conteos',
    contador: _incidencias ?? 0,
    abrir: () => const IncidenciasPendientes(),
  );

  _Opcion get _opAgregarStock => _Opcion(
    icono: Icons.add_box_outlined,
    titulo: 'Agregar stock',
    descripcion: 'Sumar unidades a un sector abierto',
    abrir: () => const AgregarStock(),
  );

  _Opcion get _opCierres => _Opcion(
    icono: Icons.lock_clock_outlined,
    titulo: 'Cierres de turno',
    descripcion: 'Qué sectores cerraron y a qué hora',
    abrir: () => const CierresPartidosActivos(),
  );

  _Opcion get _opVendedor => _Opcion(
    icono: Icons.storefront_outlined,
    titulo: 'Entrar como vendedor',
    descripcion: 'Operar un sector desde el panel de vendedor',
    abrir: () => const EstadioSelection(fromAdmin: true),
  );

  List<_Opcion> get _opcionesEvento => [
    _opCierres,
    _opAgregarStock,
    _opIncidencias,
    _Opcion(
      icono: Icons.directions_walk_outlined,
      titulo: 'Bandejeo por sector',
      descripcion: 'Rondas y ventas de los bandejeros',
      abrir: () => const ReporteBandejeoAdmin(),
    ),
    _opVendedor,
  ];

  List<_Opcion> get _opcionesReportes => [
    _Opcion(
      icono: Icons.pie_chart_outline,
      titulo: 'Ventas por categoría',
      descripcion: 'Qué tipo de producto se vende más',
      abrir: () => const VentasPorCategoria(),
    ),
    _Opcion(
      icono: Icons.inventory_2_outlined,
      titulo: 'Stock por sector',
      descripcion: 'Cuánto queda de cada producto',
      abrir: () => const StockReports(),
    ),
    _Opcion(
      icono: Icons.remove_circle_outline,
      titulo: 'Mermas',
      descripcion: 'Productos perdidos y su motivo',
      abrir: () => const ReporteMermas(),
    ),
    _Opcion(
      icono: Icons.sync_problem_rounded,
      titulo: 'Diferencias en traspasos',
      descripcion: 'Traspasos que llegaron con menos unidades',
      abrir: () => const ReporteDiferenciasTraspaso(),
    ),
    _Opcion(
      icono: Icons.leaderboard_outlined,
      titulo: 'Ranking de vendedores',
      descripcion: 'Ventas acumuladas del año por vendedor',
      abrir: () => const RankingVendedores(),
    ),
  ];

  List<_Opcion> get _opcionesConfiguracion => [
    _Opcion(
      icono: Icons.event_rounded,
      titulo: 'Eventos y sectores',
      descripcion: 'Crear partidos, sectores y reabrir turnos',
      abrir: () => const EventosManagement(),
    ),
    _Opcion(
      icono: Icons.fastfood_outlined,
      titulo: 'Productos y categorías',
      descripcion: 'Catálogo, precios y categorías',
      abrir: () => const InventoryManagement(),
    ),
    _Opcion(
      icono: Icons.people_outline_rounded,
      titulo: 'Personal',
      descripcion: 'Empleados (nombre y RUT) y exportación',
      abrir: () => const AsignacionPersonal(),
    ),
    _Opcion(
      icono: Icons.badge_outlined,
      titulo: 'Usuarios y roles',
      descripcion: 'Quién es administrador y quién vendedor',
      abrir: () => const GestionRolesUsuarios(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final conRiel = ancho >= 720;

    final cuerpo = IndexedStack(
      index: _seccion,
      children: [
        _buildInicio(context),
        _ListaOpciones(
          descripcion: 'Lo que se hace mientras se juega el partido.',
          opciones: _opcionesEvento,
          onAbrir: _abrir,
        ),
        _ListaOpciones(
          descripcion: 'Para analizar ventas, stock y pérdidas.',
          opciones: _opcionesReportes,
          onAbrir: _abrir,
        ),
        _ListaOpciones(
          descripcion: 'Para preparar todo antes del evento.',
          opciones: _opcionesConfiguracion,
          onAbrir: _abrir,
          alFinal: _BotonCerrarSesion(
            onPressed: () => AuthManager().cerrarSesion(),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: _buildAppBar(),
      body: conRiel
          ? Row(
              children: [
                SafeArea(
                  right: false,
                  child: NavigationRail(
                    selectedIndex: _seccion,
                    onDestinationSelected: (i) => setState(() => _seccion = i),
                    destinations: [
                      for (var i = 0; i < _secciones.length; i++)
                        NavigationRailDestination(
                          icon: _iconoSeccion(i, activo: false),
                          selectedIcon: _iconoSeccion(i, activo: true),
                          label: Text(_secciones[i].titulo),
                        ),
                    ],
                  ),
                ),
                Expanded(child: cuerpo),
              ],
            )
          : cuerpo,
      bottomNavigationBar: conRiel
          ? null
          : NavigationBar(
              selectedIndex: _seccion,
              onDestinationSelected: (i) => setState(() => _seccion = i),
              destinations: [
                for (var i = 0; i < _secciones.length; i++)
                  NavigationDestination(
                    icon: _iconoSeccion(i, activo: false),
                    selectedIcon: _iconoSeccion(i, activo: true),
                    label: _secciones[i].etiquetaCorta,
                    tooltip: _secciones[i].titulo,
                  ),
              ],
            ),
    );
  }

  /// Ícono de la sección; "Evento en curso" lleva el contador de incidencias.
  Widget _iconoSeccion(int i, {required bool activo}) {
    final icono = Icon(
      activo ? _secciones[i].iconoActivo : _secciones[i].icono,
    );
    final pendientes = _incidencias ?? 0;
    if (i != 1 || pendientes == 0) return icono;
    return Badge(
      label: Text('$pendientes'),
      backgroundColor: AppColors.error,
      textColor: Colors.white,
      child: icono,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_seccion != 0) {
      return AppBar(
        automaticallyImplyLeading: false,
        title: Text(_secciones[_seccion].titulo),
      );
    }
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/imagenes/logo.png',
            height: 40,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const MarcaFusion(tamano: 22),
                Text(
                  'Panel de Administración',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Actualizar estadísticas',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _cargando ? null : _cargarEstadisticas,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  /// Lo urgente y lo más usado, antes del resumen de ventas.
  List<Widget> _buildAtencionYAccesos() {
    final pendientes = _incidencias ?? 0;
    return [
      if (pendientes > 0) ...[
        _TarjetaOpcion(
          opcion: _opIncidencias,
          onTap: () => _abrir(_opIncidencias),
          urgente: true,
        ),
        const SizedBox(height: 16),
      ],
      const _TituloSeccion(
        icono: Icons.bolt_rounded,
        titulo: 'Accesos rápidos',
      ),
      const SizedBox(height: 10),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, o) in [_opAgregarStock, _opCierres, _opVendedor].indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _AccesoRapido(
                  opcion: o,
                  color: AppColors.grafico[i],
                  onTap: () => _abrir(o),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  /// Sección Inicio: lo urgente, accesos rápidos y el resumen de ventas.
  Widget _buildInicio(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _cargarEstadisticas,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: conMargenInferior(
          context,
          const EdgeInsets.fromLTRB(16, 16, 16, 24),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resumen de ventas',
                            style: AppFonts.inter(
                              color: AppColors.tinta,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cierres de turno en sectores y ventas de bandejeo',
                            style: AppFonts.inter(
                              color: AppColors.tintaSecundaria,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const _LiveReloj(darkText: true),
                  ],
                ),
                const SizedBox(height: 16),
                ..._buildAtencionYAccesos(),
                if (_cargando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_errorCarga != null)
                  _buildErrorCarga()
                else ...[
                  if (_resumen!.sinVentasRegistradas) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.avisoSuave,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.aviso, width: 1.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.aviso,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Todavía no hay ventas cargadas. Aparecen cuando un sector '
                              'cierra turno (inventario final) o cuando se rinde una ronda de bandejeo.',
                              style: AppFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.avisoTexto,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  DashboardCard.kpi(
                    title: 'Total vendido',
                    value: '\$${_fmtMiles(_resumen!.totalVendido)}',
                    subtitle:
                        '${_resumen!.eventosConVentas} partido${_resumen!.eventosConVentas == 1 ? '' : 's'} con ventas · '
                        '${_resumen!.cantidadEventosActivos} activo${_resumen!.cantidadEventosActivos == 1 ? '' : 's'} ahora',
                    icon: Icons.payments_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildMetricas(),
                  const SizedBox(height: 16),
                  _buildGraficos(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Cuatro métricas en grilla de 2 (3 en pantallas anchas).
  Widget _buildMetricas() {
    final r = _resumen!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final cross = ancho < 340 ? 1 : (ancho < 760 ? 2 : 4);
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 92,
          ),
          children: [
            DashboardCard.stat(
              title: 'Cierres de turno',
              value: _fmtMiles(r.cantidadCierres),
              icon: Icons.receipt_long_outlined,
              acento: AppColors.dorado,
            ),
            DashboardCard.stat(
              title: 'Promedio por cierre',
              value: '\$${_fmtMiles(r.promedioPorCierre.round())}',
              icon: Icons.trending_up_rounded,
              acento: AppColors.cian,
            ),
            DashboardCard.stat(
              title: 'Rondas bandejeo',
              value: _fmtMiles(r.transaccionesBandejeo),
              icon: Icons.shopping_basket_outlined,
              acento: AppColors.coral,
            ),
            DashboardCard.stat(
              title: 'Partidos activos',
              value: '${r.cantidadEventosActivos}',
              icon: Icons.event_available_outlined,
              acento: AppColors.violeta,
            ),
          ],
        );
      },
    );
  }

  /// Origen de las ventas, por partido y por sector. En pantallas anchas van
  /// de a dos por fila.
  Widget _buildGraficos() {
    final r = _resumen!;
    final bandejeo = r.montoBandejeoTurnosAbiertos.toDouble();
    final cierres = (r.totalVendido - bandejeo).clamp(0, double.infinity);

    final origen = TarjetaGrafico(
      titulo: '¿De dónde vienen las ventas?',
      subtitulo: 'Cierres de turno y bandejeo en turnos abiertos',
      child: GraficoDona(
        formatear: _formatearMonto,
        textoCentro: abreviarMonto(r.totalVendido.toDouble()),
        partes: [
          (
            etiqueta: 'Cierres de turno',
            monto: cierres.toDouble(),
            color: AppColors.dorado,
          ),
          (
            etiqueta: 'Bandejeo en turno abierto',
            monto: bandejeo,
            color: AppColors.cian,
          ),
        ],
      ),
    );
    final porPartido = TarjetaGrafico(
      titulo: 'Por partido',
      subtitulo: 'Partidos con ventas registradas',
      child: _EventosIngresosWidget(ingresos: r.ingresosPorEvento),
    );
    final porSector = TarjetaGrafico(
      titulo: 'Por sector',
      subtitulo: 'Puestos con más venta (cierre o bandejeo)',
      child: _AnalisisSectoresWidget(sectores: r.ingresosPorSector),
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 760) {
          return Column(
            children: [
              origen,
              const SizedBox(height: 16),
              porPartido,
              const SizedBox(height: 16),
              porSector,
            ],
          );
        }
        return Column(
          children: [
            // Sin IntrinsicHeight: los gráficos usan LayoutBuilder.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: origen),
                const SizedBox(width: 16),
                Expanded(child: porPartido),
              ],
            ),
            const SizedBox(height: 16),
            porSector,
          ],
        );
      },
    );
  }

  /// Error dentro del panel (no a pantalla completa: está dentro del scroll).
  Widget _buildErrorCarga() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              const Mascota(alto: 110),
              const SizedBox(height: 12),
              Text(
                'No pudimos cargar las estadísticas',
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.tinta,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorCarga!,
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                  fontSize: 15,
                  color: AppColors.tintaSecundaria,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _cargarEstadisticas,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtMiles(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final posFromEnd = s.length - i - 1;
      if (posFromEnd > 0 && posFromEnd % 3 == 0) buf.write('.');
    }
    return buf.toString();
  }
}

class _LiveReloj extends StatefulWidget {
  final bool darkText;
  const _LiveReloj({this.darkText = false});

  @override
  State<_LiveReloj> createState() => _LiveRelojState();
}

class _LiveRelojState extends State<_LiveReloj> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final hora = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    final fecha = '${two(now.day)}/${two(now.month)}/${now.year}';
    final color = widget.darkText ? AppColors.tinta : Colors.white;
    final sub = widget.darkText
        ? AppColors.tintaSecundaria
        : const Color(0xFFD8D2C4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          hora,
          style: AppFonts.inter(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(fecha, style: AppFonts.inter(color: sub, fontSize: 14)),
      ],
    );
  }
}

/// Título de sección del panel.
class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion({
    required this.icono,
    required this.titulo,
  });

  final IconData icono;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.dorado.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icono, color: AppColors.dorado, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: AppFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.tinta,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatearMonto(double monto) {
  return '\$${monto.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
}

class _SinDatos extends StatelessWidget {
  const _SinDatos(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        texto,
        style: AppFonts.inter(color: AppColors.tintaSecundaria, fontSize: 15),
      ),
    );
  }
}

// Ingresos por sector (datos reales desde AdminEstadisticasService).
class _AnalisisSectoresWidget extends StatelessWidget {
  final List<Map<String, dynamic>> sectores;

  const _AnalisisSectoresWidget({required this.sectores});

  @override
  Widget build(BuildContext context) {
    if (sectores.isEmpty) {
      return const _SinDatos('Aún no hay ventas por sector');
    }
    final top = sectores
        .take(12)
        .map(
          (e) => (
            nombre: e['nombreSector'] as String? ?? 'Sector',
            detalle: e['nombreEvento'] as String?,
            monto: (e['total'] as num?)?.toDouble() ?? 0,
          ),
        );
    return RankingBarras(items: top.toList(), formatear: _formatearMonto);
  }
}

// Ingresos por evento (datos reales desde AdminEstadisticasService).
class _EventosIngresosWidget extends StatelessWidget {
  final List<Map<String, dynamic>> ingresos;

  const _EventosIngresosWidget({required this.ingresos});

  @override
  Widget build(BuildContext context) {
    final conDatos = ingresos
        .where((e) => (e['ingresos'] as double? ?? 0) > 0)
        .toList();
    if (conDatos.isEmpty) {
      return const _SinDatos('Aún no hay ventas por partido');
    }
    final items = conDatos.map(
      (e) => (
        nombre: e['nombre'] as String? ?? 'Partido',
        detalle: null,
        monto: (e['ingresos'] as num?)?.toDouble() ?? 0,
      ),
    );
    return GraficoBarras(
      items: [for (final i in items.take(6)) (nombre: i.nombre, monto: i.monto)],
      formatear: _formatearMonto,
    );
  }
}

/// Lista de opciones de una sección, como tarjetas grandes.
class _ListaOpciones extends StatelessWidget {
  const _ListaOpciones({
    required this.descripcion,
    required this.opciones,
    required this.onAbrir,
    this.alFinal,
  });

  final String descripcion;
  final List<_Opcion> opciones;
  final void Function(_Opcion) onAbrir;
  final Widget? alFinal;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: conMargenInferior(
        context,
        const EdgeInsets.fromLTRB(16, 16, 16, 24),
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  descripcion,
                  style: AppFonts.inter(
                    fontSize: 16,
                    color: AppColors.tintaSecundaria,
                  ),
                ),
                const SizedBox(height: 12),
                for (final o in opciones) ...[
                  _TarjetaOpcion(opcion: o, onTap: () => onAbrir(o)),
                  const SizedBox(height: 10),
                ],
                if (alFinal != null) ...[const SizedBox(height: 24), alFinal!],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de una opción: ícono, nombre, para qué sirve y contador si hay
/// pendientes. Toda la tarjeta es tocable (mínimo 76 dp de alto).
class _TarjetaOpcion extends StatelessWidget {
  const _TarjetaOpcion({
    required this.opcion,
    required this.onTap,
    this.urgente = false,
  });

  final _Opcion opcion;
  final VoidCallback onTap;

  /// Resaltada como "requiere atención" (fondo de aviso).
  final bool urgente;

  @override
  Widget build(BuildContext context) {
    final contador = opcion.contador;
    return Semantics(
      button: true,
      label:
          '${opcion.titulo}. ${opcion.descripcion}'
          '${contador > 0 ? '. $contador pendientes' : ''}',
      excludeSemantics: true,
      child: Material(
        color: urgente ? AppColors.avisoSuave : AppColors.tarjeta,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: urgente ? AppColors.aviso : AppColors.separador,
                width: urgente ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.negro,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(opcion.icono, color: AppColors.dorado, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        urgente ? 'Requiere atención' : opcion.titulo,
                        style: AppFonts.inter(
                          fontSize: urgente ? 14 : 17,
                          fontWeight: urgente
                              ? FontWeight.w700
                              : FontWeight.w800,
                          color: urgente
                              ? AppColors.avisoTexto
                              : AppColors.tinta,
                        ),
                      ),
                      if (urgente)
                        Text(
                          '$contador ${contador == 1 ? 'incidencia' : 'incidencias'} por resolver',
                          style: AppFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.tinta,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        opcion.descripcion,
                        style: AppFonts.inter(
                          fontSize: 14,
                          color: urgente
                              ? AppColors.avisoTexto
                              : AppColors.tintaSecundaria,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (contador > 0 && !urgente)
                  Container(
                    constraints: const BoxConstraints(minWidth: 30),
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$contador',
                      style: AppFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.tinta,
                    size: 28,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Acceso rápido del inicio: mosaico con ícono de color y el nombre debajo.
class _AccesoRapido extends StatelessWidget {
  const _AccesoRapido({
    required this.opcion,
    required this.color,
    required this.onTap,
  });

  final _Opcion opcion;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tarjeta,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.separador),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(opcion.icono, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                opcion.titulo,
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.tinta,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cerrar sesión: separado del resto y en rojo, para no tocarlo por error.
class _BotonCerrarSesion extends StatelessWidget {
  const _BotonCerrarSesion({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Cerrar sesión'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: const BorderSide(color: AppColors.error, width: 2),
        backgroundColor: AppColors.errorSuave,
      ),
    );
  }
}
