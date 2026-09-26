import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/services/firestore_helpers.dart';
import 'package:front_appsnack/widgets/gestion_stock.dart';
import 'package:front_appsnack/widgets/registro_merma.dart';
import 'package:front_appsnack/widgets/resumen_cierre_turno.dart';
import 'package:front_appsnack/widgets/traspaso_stock.dart';
import 'package:front_appsnack/widgets/confirmacion_traspasos.dart';
import 'package:front_appsnack/widgets/bandejeo_flow.dart';
import 'package:front_appsnack/widgets/estadio_selection.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';
import 'package:front_appsnack/core/tipografia.dart';

class HomeVendedor extends StatefulWidget {
  final String eventId;
  final String sectorId;
  final String nombreSector;

  /// Si es true, se muestra botón para volver al panel de administración.
  final bool fromAdmin;

  const HomeVendedor({
    super.key,
    required this.eventId,
    required this.sectorId,
    required this.nombreSector,
    this.fromAdmin = false,
  });

  @override
  State<HomeVendedor> createState() => _HomeVendedorState();
}

class _HomeVendedorState extends State<HomeVendedor> {
  final Color primaryColor = AppColors.primaryLight;
  final Color accentColor = AppColors.accent;
  final Color secondaryColor = AppColors.secondary;
  final Color backgroundColor = AppColors.surface;

  DateTime _currentTime = DateTime.now();
  late final String _currentSectorNombre;
  late final String _currentSectorId;
  bool _stockInicialAgregado = false;
  String? _nombreEvento;

  @override
  void initState() {
    super.initState();
    _currentSectorNombre = widget.nombreSector;
    _currentSectorId = widget.sectorId;
    _startTimer();
    _verificarStockInicial();
    _cargarNombreEvento();
    _verificarSectorNoCerrado();
  }

  /// Si el sector tiene turno cerrado, volver atrás y mostrar mensaje.
  Future<void> _verificarSectorNoCerrado() async {
    try {
      final sectorDoc = await FirestoreHelpers.getSector(
        widget.eventId,
        widget.sectorId,
      );
      if (!mounted) return;
      final sectorData = sectorDoc.data() as Map<String, dynamic>?;
      if (sectorDoc.exists &&
          sectorData != null &&
          sectorData['turnoCerrado'] == true) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Text(
                'Sector con turno cerrado',
                style: AppFonts.inter(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Este sector tiene el turno cerrado. Un administrador debe reabrirlo desde Gestión de eventos para poder operar aquí.',
                style: AppFonts.inter(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Entendido', style: AppFonts.inter()),
                ),
              ],
            ),
          );
          if (!mounted) return;
          Navigator.of(context).pop();
        });
      }
    } catch (_) {}
  }

  Future<void> _cargarNombreEvento() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _nombreEvento = data?['nombre']?.toString() ?? widget.eventId;
        });
      } else if (mounted) {
        setState(() {
          _nombreEvento = widget.eventId;
        });
      }
    } catch (e) {
      debugPrint("Error cargando nombre del evento: $e");
      if (mounted) {
        setState(() {
          _nombreEvento = widget.eventId;
        });
      }
    }
  }

  Future<void> _verificarStockInicial() async {
    try {
      final sectorDoc = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventId)
          .collection('sectores')
          .doc(_currentSectorId)
          .get();

      if (mounted) {
        setState(() {
          // Solo cuenta como "stock inicial ingresado" si se usó Gestionar Stock.
          // Traspasos no marcan este flag; un sector que solo recibió traspaso
          // puede seguir usando "Gestionar Stock" una vez.
          _stockInicialAgregado =
              sectorDoc.data()?['stockInicialIngresado'] == true;
        });
      }
    } catch (e) {
      debugPrint("Error verificando stock: $e");
    }
  }

  void _startTimer() {
    // Actualizar la hora cada segundo
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
        _startTimer(); // Continuar el timer
      }
    });
  }

  @override
  void dispose() {
    // Limpiar el timer cuando se cierre la pantalla
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: widget.fromAdmin
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Volver al panel de administración',
                onPressed: _volverAlPanelAdmin,
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              "assets/imagenes/logo.png",
              height: 40,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const MarcaFusion(tamano: 22),
                Text(
                  'Panel de Vendedor',
                  style: AppFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: null,
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: _buildBarraAccesoCuenta(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _VendedorPanelLayout.fromWidth(constraints.maxWidth);
          return Padding(
            padding: EdgeInsets.fromLTRB(layout.padding, 12, layout.padding, 8),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: layout.maxContentWidth,
                  minHeight: constraints.maxHeight - 28,
                ),
                child: layout.stockYOperacionesEnFila
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildEncabezadoTurno(compacto: false),
                                SizedBox(height: layout.sectionGap),
                                if (!_stockInicialAgregado) ...[
                                  _buildAvisoStockInicialPendiente(),
                                  SizedBox(height: layout.sectionGap),
                                ],
                                _buildBannerTraspasosPendientes(),
                                SizedBox(height: layout.sectionGap),
                                Expanded(
                                  child: _buildStockPrincipal(
                                    compacto: false,
                                    expandir: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(flex: 6, child: _buildPanelAcciones(layout)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildEncabezadoTurno(compacto: layout.compacto),
                          SizedBox(height: layout.sectionGap),
                          if (!_stockInicialAgregado) ...[
                            _buildAvisoStockInicialPendiente(),
                            SizedBox(height: layout.sectionGap),
                          ],
                          _buildBannerTraspasosPendientes(),
                          SizedBox(height: layout.sectionGap),
                          _buildStockPrincipal(compacto: layout.compacto),
                          SizedBox(height: layout.sectionGap),
                          Expanded(child: _buildPanelAcciones(layout)),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBarraAccesoCuenta() {
    return Material(
      color: AppColors.tarjeta,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _buildBotonBarraInferior(
                  icon: Icons.stadium_outlined,
                  label: 'Cambiar evento',
                  onTap: _cambiarEvento,
                  color: AppColors.tinta,
                  borde: AppColors.separador,
                  fondo: AppColors.tarjetaAlta,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: widget.fromAdmin
                    ? _buildBotonBarraInferior(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Panel admin',
                        onTap: _volverAlPanelAdmin,
                        color: AppColors.tinta,
                        borde: AppColors.separador,
                        fondo: AppColors.tarjetaAlta,
                      )
                    : _buildBotonBarraInferior(
                        icon: Icons.logout_rounded,
                        label: 'Cerrar sesión',
                        onTap: _cerrarSesion,
                        color: AppColors.error,
                        borde: AppColors.error,
                        fondo: AppColors.errorSuave,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBotonBarraInferior({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required Color borde,
    required Color fondo,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borde, width: 1.5),
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: AppTamanos.boton),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarAvisoStockInicial() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Debe ingresar el stock inicial antes de usar esta operación.',
          style: AppFonts.inter(),
        ),
        backgroundColor: AppColors.avisoFuerte,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _ejecutarSiHayStockInicial(VoidCallback accion) {
    if (!_stockInicialAgregado) {
      _mostrarAvisoStockInicial();
      return;
    }
    accion();
  }

  Widget _buildAvisoStockInicialPendiente() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.avisoSuave,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.aviso, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.aviso,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ingrese el stock inicial para habilitar traspasos, mermas y bandejeo. '
              'Puede recibir traspasos de otros sectores antes de cargar su inventario.',
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.avisoTexto,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerTraspasosPendientes() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventId)
          .collection('sectores')
          .doc(_currentSectorId)
          .collection('traspasos_entrantes')
          .where('estado', isEqualTo: 'pendiente')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final resumen = ResumenPedidosPendientes.fromDocs(snapshot.data!.docs);
        if (resumen.cantidadPedidos == 0) return const SizedBox.shrink();
        return BannerTraspasosPendientes(
          eventoId: widget.eventId,
          sectorId: _currentSectorId,
          nombreSector: _currentSectorNombre,
          resumen: resumen,
        );
      },
    );
  }

  Widget _buildEncabezadoTurno({required bool compacto}) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradientes.tarjeta,
        border: Border.all(color: AppColors.separador),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compacto ? 12 : 14,
                  compacto ? 12 : 14,
                  12,
                  compacto ? 12 : 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: compacto ? 40 : 44,
                      height: compacto ? 40 : 44,
                      decoration: BoxDecoration(
                        color: AppColors.dorado,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: AppColors.negro,
                        size: compacto ? 22 : 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_nombreEvento != null)
                            Text(
                              _nombreEvento!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.tintaSecundaria,
                              ),
                            ),
                          Text(
                            _currentSectorNombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.inter(
                              fontSize: compacto ? 20 : 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')}',
                          style: AppFonts.inter(
                            fontSize: compacto ? 20 : 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dorado,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_currentTime.day.toString().padLeft(2, '0')}/${_currentTime.month.toString().padLeft(2, '0')}/${_currentTime.year}',
                          style: AppFonts.inter(
                            fontSize: 14,
                            color: AppColors.tintaSecundaria,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockPrincipal({bool compacto = false, bool expandir = false}) {
    final esFinal = _stockInicialAgregado;
    final contenido = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 14 : 18,
        vertical: compacto ? 14 : 18,
      ),
      child: Row(
        children: [
          Container(
            width: compacto ? 48 : 54,
            height: compacto ? 48 : 54,
            decoration: BoxDecoration(
              color: AppColors.negro,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              esFinal ? Icons.fact_check_outlined : Icons.add_box_outlined,
              size: compacto ? 26 : 30,
              color: AppColors.dorado,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  esFinal ? 'Ingresar stock final' : 'Ingresar stock inicial',
                  style: AppFonts.inter(
                    fontSize: compacto ? 19 : 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.negro,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  esFinal
                      ? 'Cuente lo que queda al cerrar el turno'
                      : 'Registre las cantidades de apertura',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.negro.withValues(alpha: 0.8),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppColors.negro,
            size: 22,
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: esFinal ? _ingresarStockFinal : _agregarStockInicial,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppGradientes.dorado,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.dorado,
          ),
          child: expandir
              ? SizedBox.expand(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [contenido],
                  ),
                )
              : contenido,
        ),
      ),
    );
  }

  Widget _buildPanelAcciones(_VendedorPanelLayout layout) {
    return _buildPanelAccionesBody(_accionesOperativas(), layout);
  }

  List<_AccionItem> _accionesOperativas() {
    return [
      _AccionItem(
        icon: Icons.swap_horiz_rounded,
        label: 'Traspaso',
        descripcion: 'Enviar a otro sector',
        iconBg: AppColors.cian.withValues(alpha: 0.16),
        iconColor: AppColors.cian,
        onTap: () => _ejecutarSiHayStockInicial(() {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TraspasoStock(
                eventoId: widget.eventId,
                nombreEvento: _nombreEvento ?? widget.eventId,
                sectorIdOrigenInicial: _currentSectorId,
                nombreSectorOrigenInicial: _currentSectorNombre,
              ),
            ),
          );
        }),
        requiereStockInicial: true,
      ),
      _AccionItem(
        icon: Icons.remove_circle_outline_rounded,
        label: 'Mermas',
        descripcion: 'Productos perdidos',
        iconBg: AppColors.coral.withValues(alpha: 0.16),
        iconColor: AppColors.coral,
        onTap: () => _ejecutarSiHayStockInicial(() {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RegistroMerma(
                key: ValueKey('mermas-${widget.eventId}-$_currentSectorId'),
                eventoId: widget.eventId,
                sectorId: _currentSectorId,
                nombreSector: _currentSectorNombre,
              ),
            ),
          );
        }),
        requiereStockInicial: true,
      ),
      _AccionItem(
        icon: Icons.restaurant_menu_rounded,
        label: 'Bandejeo',
        descripcion: 'Armar bandejas',
        iconBg: AppColors.dorado.withValues(alpha: 0.16),
        iconColor: AppColors.dorado,
        onTap: () => _ejecutarSiHayStockInicial(() {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BandejeoFlow(
                eventoId: widget.eventId,
                sectorId: _currentSectorId,
                nombreSector: _currentSectorNombre,
              ),
            ),
          );
        }),
        requiereStockInicial: true,
      ),
      _AccionItem(
        icon: Icons.inventory_2_outlined,
        label: 'Ver stock',
        descripcion: 'Ver inventario',
        iconBg: AppColors.violeta.withValues(alpha: 0.16),
        iconColor: AppColors.violeta,
        onTap: _verStock,
        requiereStockInicial: false,
      ),
    ];
  }

  Widget _buildPanelAccionesBody(
    List<_AccionItem> acciones,
    _VendedorPanelLayout layout,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradientes.tarjeta,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.separador),
        boxShadow: AppShadows.card,
      ),
      padding: EdgeInsets.fromLTRB(
        14,
        layout.compacto ? 10 : 14,
        14,
        layout.compacto ? 10 : 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                layout.stockYOperacionesEnFila
                    ? 'Operaciones'
                    : 'Operaciones del turno',
                style: AppFonts.inter(
                  fontSize: layout.tituloSeccion + 2,
                  fontWeight: FontWeight.w800,
                  color: AppColors.tinta,
                ),
              ),
            ],
          ),
          SizedBox(height: layout.compacto ? 8 : 12),
          Expanded(
            child: layout.gridColumns == 4
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < acciones.length; i++) ...[
                        if (i > 0) SizedBox(width: layout.gridSpacing),
                        Expanded(
                          child: _buildActionTile(
                            acciones[i],
                            habilitado:
                                !acciones[i].requiereStockInicial ||
                                _stockInicialAgregado,
                            compacto: layout.compacto,
                          ),
                        ),
                      ],
                    ],
                  )
                : Column(
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildActionTile(
                                acciones[0],
                                habilitado:
                                    !acciones[0].requiereStockInicial ||
                                    _stockInicialAgregado,
                                compacto: layout.compacto,
                              ),
                            ),
                            SizedBox(width: layout.gridSpacing),
                            Expanded(
                              child: _buildActionTile(
                                acciones[1],
                                habilitado:
                                    !acciones[1].requiereStockInicial ||
                                    _stockInicialAgregado,
                                compacto: layout.compacto,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: layout.gridSpacing),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildActionTile(
                                acciones[2],
                                habilitado:
                                    !acciones[2].requiereStockInicial ||
                                    _stockInicialAgregado,
                                compacto: layout.compacto,
                              ),
                            ),
                            SizedBox(width: layout.gridSpacing),
                            Expanded(
                              child: _buildActionTile(
                                acciones[3],
                                habilitado:
                                    !acciones[3].requiereStockInicial ||
                                    _stockInicialAgregado,
                                compacto: layout.compacto,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    _AccionItem accion, {
    bool habilitado = true,
    bool compacto = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: habilitado ? accion.onTap : _mostrarAvisoStockInicial,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: habilitado ? 1 : 0.5,
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.fondo,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.separador, width: 1.5),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final muyApretado = constraints.maxHeight < 98;
                final iconBox = compacto || muyApretado ? 40.0 : 46.0;
                final iconSize = compacto || muyApretado ? 22.0 : 24.0;
                final padV = compacto || muyApretado ? 8.0 : 12.0;
                final padH = compacto || muyApretado ? 8.0 : 10.0;
                final gapIcono = compacto || muyApretado ? 6.0 : 10.0;
                final mostrarDescripcion = !muyApretado;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: padH,
                    vertical: padV,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: iconBox,
                        height: iconBox,
                        decoration: BoxDecoration(
                          color: accion.iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          accion.icon,
                          color: accion.iconColor,
                          size: iconSize,
                        ),
                      ),
                      SizedBox(height: gapIcono),
                      Text(
                        accion.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.inter(
                          fontSize: compacto || muyApretado ? 15 : 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tinta,
                          height: 1.1,
                        ),
                      ),
                      if (mostrarDescripcion) ...[
                        SizedBox(height: compacto ? 2 : 3),
                        Text(
                          accion.descripcion,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.inter(
                            fontSize: 14,
                            color: AppColors.tintaSecundaria,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _agregarStockInicial() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => GestionStock(
          eventoId: widget.eventId,
          nombreSector: _currentSectorNombre,
          sectorId: _currentSectorId,
          soloLectura: false,
          esIngresoInicial: true,
        ),
      ),
    );

    await _verificarStockInicial();
    if (!mounted || result == null) return;

    _mostrarSnackStock(result);
  }

  void _mostrarSnackStock(String result) {
    if (!mounted) return;
    late final String mensaje;
    late final Color color;
    if (result == 'saved') {
      mensaje = 'Stock inicial guardado correctamente.';
      color = AppColors.exitoFuerte;
    } else if (result == 'draft') {
      mensaje =
          'Borrador guardado. Para activar el punto, use Guardar y salir.';
      color = AppColors.avisoFuerte;
    } else if (result == 'exit') {
      mensaje = 'Salió sin finalizar. Complete el stock y use Guardar y salir.';
      color = AppColors.avisoFuerte;
    } else {
      return;
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: AppFonts.inter()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _volverAlPanelAdmin() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _cambiarEvento() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EstadioSelection(fromAdmin: widget.fromAdmin),
      ),
    );
  }

  void _verStock() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GestionStock(
          eventoId: widget.eventId,
          nombreSector: _currentSectorNombre,
          sectorId: _currentSectorId,
          soloLectura: true,
        ),
      ),
    );
  }

  void _ingresarStockFinal() {
    if (!_stockInicialAgregado) {
      _mostrarAvisoStockInicial();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResumenCierreTurno(
          eventoId: widget.eventId,
          sectorId: _currentSectorId,
          nombreSector: _currentSectorNombre,
          nombreEvento: _nombreEvento,
          fromAdmin: widget.fromAdmin,
        ),
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    await AuthManager().cerrarSesion();
  }
}

class _AccionItem {
  final IconData icon;
  final String label;
  final String descripcion;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;
  final bool requiereStockInicial;

  const _AccionItem({
    required this.icon,
    required this.label,
    required this.descripcion,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
    this.requiereStockInicial = true,
  });
}

/// Breakpoints del panel vendedor: teléfono, tablet y pantalla ancha.
class _VendedorPanelLayout {
  final double maxContentWidth;
  final double padding;
  final double sectionGap;
  final int gridColumns;
  final double gridSpacing;
  final double tituloSeccion;
  final bool compacto;
  final bool stockYOperacionesEnFila;

  const _VendedorPanelLayout({
    required this.maxContentWidth,
    required this.padding,
    required this.sectionGap,
    required this.gridColumns,
    required this.gridSpacing,
    required this.tituloSeccion,
    required this.compacto,
    required this.stockYOperacionesEnFila,
  });

  static _VendedorPanelLayout fromWidth(double width) {
    if (width >= 900) {
      return const _VendedorPanelLayout(
        maxContentWidth: 1040,
        padding: 24,
        sectionGap: 14,
        gridColumns: 2,
        gridSpacing: 12,
        tituloSeccion: 17,
        compacto: false,
        stockYOperacionesEnFila: true,
      );
    }
    if (width >= 600) {
      return const _VendedorPanelLayout(
        maxContentWidth: 820,
        padding: 20,
        sectionGap: 14,
        gridColumns: 4,
        gridSpacing: 12,
        tituloSeccion: 16,
        compacto: false,
        stockYOperacionesEnFila: false,
      );
    }
    return const _VendedorPanelLayout(
      maxContentWidth: double.infinity,
      padding: 16,
      sectionGap: 12,
      gridColumns: 2,
      gridSpacing: 10,
      tituloSeccion: 15,
      compacto: true,
      stockYOperacionesEnFila: false,
    );
  }
}
