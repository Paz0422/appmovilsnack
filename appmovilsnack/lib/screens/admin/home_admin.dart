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
import 'package:front_appsnack/widgets/comunes/animados.dart';
import 'package:front_appsnack/widgets/comunes/cargando.dart';
import 'package:front_appsnack/core/animaciones.dart';
import 'package:front_appsnack/core/precio.dart';
import 'package:front_appsnack/screens/admin/panel_funciones.dart';

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

/// Sección de la navegación principal del admin.
class _Seccion {
  const _Seccion(this.titulo, this.icono, this.iconoActivo);

  final String titulo;
  final IconData icono;
  final IconData iconoActivo;
}

/// Solo dos secciones: "Ventas" (la principal, con cifras y gráficos) y
/// "Panel" con todos los módulos a la vista.
const _secciones = [
  _Seccion('Ventas', Icons.insights_outlined, Icons.insights_rounded),
  _Seccion('Panel', Icons.dashboard_outlined, Icons.dashboard_rounded),
];

/// Índices de [_secciones].
const _seccionVentas = 0;
const _seccionPanel = 1;

class _HomeAdminState extends State<HomeAdmin> {
  AdminResumenActivos? _resumen;
  bool _cargando = true;
  String? _errorCarga;

  /// Sección visible (índice en [_secciones]).
  int _seccion = _seccionVentas;

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

  Future<void> _abrir(Widget Function() pantalla) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => pantalla()),
    );
    // Al volver (p. ej. tras resolver incidencias) se actualiza el contador.
    if (mounted) await _cargarIncidencias();
  }

  // --- Funciones del panel ---

  OpcionPanel _op(
    IconData icono,
    String titulo,
    String descripcion,
    Widget Function() pantalla, {
    String? ejemplo,
    int contador = 0,
  }) => OpcionPanel(
    icono: icono,
    titulo: titulo,
    descripcion: descripcion,
    ejemplo: ejemplo,
    contador: contador,
    abrir: () => _abrir(pantalla),
  );

  OpcionPanel get _opIncidencias => _op(
    Icons.report_problem_outlined,
    'Incidencias por resolver',
    'Faltantes en traspasos y sobrantes en conteos',
    () => const IncidenciasPendientes(),
    ejemplo: 'Llegaron 2 bebidas menos de las que se enviaron',
    contador: _incidencias ?? 0,
  );

  /// Los cuatro botones del panel y sus módulos.
  List<CategoriaPanel> get _categorias => [
    CategoriaPanel(
      titulo: 'Entrar como vendedor',
      descripcion: 'Operar un sector como lo hace el vendedor',
      icono: Icons.storefront_rounded,
      color: AppColors.coral,
      abrirDirecto: () => _abrir(() => const EstadioSelection(fromAdmin: true)),
    ),
    CategoriaPanel(
      titulo: 'Configuración de eventos',
      descripcion: 'Partidos, sectores, productos y equipo',
      icono: Icons.tune_rounded,
      color: AppColors.cian,
      opciones: [
        _op(
          Icons.event_rounded,
          'Crear evento',
          'Crear partidos, sectores y reabrir turnos',
          () => const EventosManagement(),
          ejemplo: 'Armar el partido del domingo con Norte, Sur y Pacífico',
        ),
        _op(
          Icons.fastfood_outlined,
          'Crear producto',
          'Catálogo, precios y categorías',
          () => const InventoryManagement(),
          ejemplo: 'Subir el precio del café o agregar un snack nuevo',
        ),
        _op(
          Icons.people_outline_rounded,
          'Listado de personal',
          'Empleados (nombre y RUT) y exportación',
          () => const AsignacionPersonal(),
          ejemplo: 'Registrar a un bandejero nuevo con su RUT',
        ),
        _op(
          Icons.badge_outlined,
          'Usuarios y roles',
          'Ver y cambiar quién es administrador',
          () => const GestionRolesUsuarios(),
          ejemplo: 'Darle permisos de administrador al encargado del día',
        ),
      ],
    ),
    CategoriaPanel(
      titulo: 'Eventos activos',
      descripcion: 'Stock, cierres e incidencias del partido en curso',
      icono: Icons.stadium_rounded,
      color: AppColors.dorado,
      opciones: [
        _op(
          Icons.add_box_outlined,
          'Agregar stock',
          'Sumar unidades a un sector abierto',
          () => const AgregarStock(),
          ejemplo: 'Al puesto Norte se le acabaron las bebidas',
        ),
        _op(
          Icons.lock_clock_outlined,
          'Cierres de turno',
          'Qué sectores cerraron y a qué hora',
          () => const CierresPartidosActivos(),
          ejemplo: 'Saber si Pacífico ya entregó su conteo final',
        ),
        _opIncidencias,
        _op(
          Icons.directions_walk_outlined,
          'Bandejeo por sector',
          'Rondas y ventas de los bandejeros',
          () => const ReporteBandejeoAdmin(),
          ejemplo: 'Cuánto vendió cada bandejero en sus rondas',
        ),
      ],
    ),
    CategoriaPanel(
      titulo: 'Reportes',
      descripcion: 'Categorías, stock, mermas, traspasos y ranking',
      icono: Icons.bar_chart_rounded,
      color: AppColors.violeta,
      opciones: [
        _op(
          Icons.pie_chart_outline,
          'Ventas por categoría',
          'Qué tipo de producto se vende más',
          () => const VentasPorCategoria(),
          ejemplo: '¿Se venden más bebidas o snacks?',
        ),
        _op(
          Icons.inventory_2_outlined,
          'Stock por sector',
          'Cuánto queda de cada producto',
          () => const StockReports(),
          ejemplo: 'Revisar qué sobró para el próximo partido',
        ),
        _op(
          Icons.remove_circle_outline,
          'Mermas',
          'Productos perdidos y su motivo',
          () => const ReporteMermas(),
          ejemplo: 'Ver cuántos productos se botaron y por qué',
        ),
        _op(
          Icons.sync_problem_rounded,
          'Diferencias en traspasos',
          'Traspasos que llegaron con menos unidades',
          () => const ReporteDiferenciasTraspaso(),
          ejemplo: 'Encontrar dónde se perdió mercadería en un envío',
        ),
        _op(
          Icons.leaderboard_outlined,
          'Ranking de vendedores',
          'Ventas acumuladas del año por vendedor',
          () => const RankingVendedores(),
          ejemplo: 'Premiar al vendedor que más vendió en el año',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final conRiel = ancho >= 720;

    final cuerpo = IndexedStack(
      index: _seccion,
      children: [_buildVentas(context), _buildPanel(context)],
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
                    label: _secciones[i].titulo,
                    tooltip: _secciones[i].titulo,
                  ),
              ],
            ),
    );
  }

  /// Ícono de la sección; "Panel" lleva el contador de incidencias.
  Widget _iconoSeccion(int i, {required bool activo}) {
    final icono = Icon(
      activo ? _secciones[i].iconoActivo : _secciones[i].icono,
    );
    final pendientes = _incidencias ?? 0;
    if (i != _seccionPanel || pendientes == 0) return icono;
    return Badge(
      label: Text('$pendientes'),
      backgroundColor: AppColors.error,
      textColor: AppColors.negro,
      child: icono,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final actualizar = [
      IconButton(
        tooltip: 'Actualizar',
        icon: const Icon(Icons.refresh_rounded),
        onPressed: _cargando ? null : _cargarEstadisticas,
      ),
      const SizedBox(width: 4),
    ];
    if (_seccion == _seccionPanel) {
      return AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Panel'),
        actions: actualizar,
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
          ).aparicionRebote(),
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
                    color: AppColors.tinta,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: actualizar,
    );
  }

  /// Un botón del panel: directo a su pantalla o a la lista de sus módulos.
  Future<void> _abrirCategoria(CategoriaPanel categoria) async {
    final directo = categoria.abrirDirecto;
    if (directo != null) return directo();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaCategoria(
          // Se vuelve a pedir para que los contadores estén al día.
          obtener: () =>
              _categorias.firstWhere((c) => c.titulo == categoria.titulo),
        ),
      ),
    );
  }

  /// Lo urgente (incidencias), arriba de Ventas.
  Widget _avisoIncidencias() {
    final pendientes = _incidencias ?? 0;
    return Aparece(
      child: pendientes == 0
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _TarjetaOpcion(
                opcion: _opIncidencias,
                onTap: _opIncidencias.abrir,
                urgente: true,
              ).latido(demora: const Duration(milliseconds: 700)),
            ),
    );
  }

  /// Panel: todos los módulos, agrupados por momento del partido, cada uno
  /// con para qué sirve y un ejemplo.
  Widget _buildPanel(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _cargarEstadisticas,
      child: ListView(
        padding: conMargenInferior(
          context,
          const EdgeInsets.fromLTRB(16, 12, 16, 24),
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¿Qué quiere hacer?',
                              style: AppFonts.inter(
                                color: AppColors.tinta,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const FiletMarca(ancho: 56),
                            const SizedBox(height: 8),
                            Text(
                              'Elija una sección. Cada módulo dice para qué '
                              'sirve y trae un ejemplo.',
                              style: AppFonts.inter(
                                color: AppColors.tintaSecundaria,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const _LiveReloj(),
                    ],
                  ).entrada(),
                  const SizedBox(height: 18),
                  CategoriasPanel(
                    categorias: _categorias,
                    onAbrir: _abrirCategoria,
                    ordenInicial: 1,
                  ),
                  const SizedBox(height: 28),
                  _BotonCerrarSesion(
                    onPressed: () => AuthManager().cerrarSesion(),
                  ).entrada(orden: 5),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sección Ventas: total, métricas y gráficos.
  Widget _buildVentas(BuildContext context) {
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
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const FiletMarca(ancho: 56),
                          const SizedBox(height: 8),
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
                    const _LiveReloj(),
                  ],
                ).entrada(),
                const SizedBox(height: 16),
                _avisoIncidencias(),
                if (_cargando)
                  const CargandoTarjetas(
                    cantidad: 4,
                    alto: 92,
                    padding: EdgeInsets.zero,
                    dentroDeLista: true,
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
                    value: formatearPesos(_resumen!.totalVendido),
                    cifra: _resumen!.totalVendido.toDouble(),
                    formatearCifra: formatearPesos,
                    subtitle:
                        '${_resumen!.eventosConVentas} partido${_resumen!.eventosConVentas == 1 ? '' : 's'} con ventas · '
                        '${_resumen!.cantidadEventosActivos} activo${_resumen!.cantidadEventosActivos == 1 ? '' : 's'} ahora',
                    icon: Icons.payments_outlined,
                  ).entrada(orden: 4).destello(
                        demora: const Duration(milliseconds: 1300),
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
              value: separarMiles(r.cantidadCierres),
              cifra: r.cantidadCierres.toDouble(),
              formatearCifra: separarMiles,
              icon: Icons.receipt_long_outlined,
              acento: AppColors.dorado,
            ),
            DashboardCard.stat(
              title: 'Promedio por cierre',
              value: formatearPesos(r.promedioPorCierre.round()),
              cifra: r.promedioPorCierre,
              formatearCifra: formatearPesos,
              icon: Icons.trending_up_rounded,
              acento: AppColors.cian,
            ),
            DashboardCard.stat(
              title: 'Rondas bandejeo',
              value: separarMiles(r.transaccionesBandejeo),
              cifra: r.transaccionesBandejeo.toDouble(),
              formatearCifra: separarMiles,
              icon: Icons.shopping_basket_outlined,
              acento: AppColors.coral,
            ),
            DashboardCard.stat(
              title: 'Partidos activos',
              value: '${r.cantidadEventosActivos}',
              icon: Icons.event_available_outlined,
              acento: AppColors.cafe,
            ),
          ].indexed.map((e) => e.$2.entrada(orden: e.$1 + 5)).toList(),
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
        formatear: formatearPesos,
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
    final serie = r.ventasEnElTiempo;
    final evolucion = TarjetaGrafico(
      titulo: 'Ventas en el tiempo',
      subtitulo: serie.porHora
          ? 'Por hora, según la hora de cada cierre y rendición'
          : 'Por día, según la fecha de cada cierre y rendición',
      child: serie.tramos.isEmpty
          ? const _SinDatos('Aún no hay ventas con fecha registrada')
          : GraficoEvolucion(
              tramos: serie.tramos,
              porHora: serie.porHora,
              formatear: formatearPesos,
            ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 760) {
          return Column(
            children: [
              evolucion.entrada(orden: 8),
              const SizedBox(height: 16),
              origen.entrada(orden: 9),
              const SizedBox(height: 16),
              porPartido.entrada(orden: 10),
              const SizedBox(height: 16),
              porSector.entrada(orden: 11),
            ],
          );
        }
        return Column(
          children: [
            evolucion.entrada(orden: 8),
            const SizedBox(height: 16),
            // Sin IntrinsicHeight: los gráficos usan LayoutBuilder.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: origen.entrada(orden: 9)),
                const SizedBox(width: 16),
                Expanded(child: porPartido.entrada(orden: 10)),
              ],
            ),
            const SizedBox(height: 16),
            porSector.entrada(orden: 11),
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
              const Mascota(alto: 110).aparicionRebote(),
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

}

class _LiveReloj extends StatefulWidget {
  const _LiveReloj();

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
    const color = AppColors.tinta;
    const sub = AppColors.tintaSecundaria;
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
    return RankingBarras(items: top.toList(), formatear: formatearPesos);
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
      formatear: formatearPesos,
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

  final OpcionPanel opcion;
  final VoidCallback onTap;

  /// Resaltada como "requiere atención" (fondo de aviso).
  final bool urgente;

  @override
  Widget build(BuildContext context) {
    final contador = opcion.contador;
    return Presionable(
      child: Semantics(
      button: true,
      onTap: onTap,
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
                AnilloMarca(
                  grosor: 2,
                  padding: const EdgeInsets.all(9),
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
                        color: AppColors.negro,
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
