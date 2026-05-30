import 'package:flutter/material.dart';
import 'package:front_appsnack/auth/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:google_fonts/google_fonts.dart';

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
  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);
  final Color backgroundColor = const Color(0xFFFDFBF7);

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
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Este sector tiene el turno cerrado. Un administrador debe reabrirlo desde Gestión de eventos para poder operar aquí.',
                style: GoogleFonts.poppins(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Entendido', style: GoogleFonts.poppins()),
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
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset("assets/imagenes/logo.png", height: 32),
            const SizedBox(width: 10),
            Text(
              'Panel de Vendedor',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: accentColor,
                fontSize: 17,
              ),
            ),
          ],
        ),
        actions: null,
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: _buildBarraAccesoCuenta(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _VendedorPanelLayout.fromWidth(constraints.maxWidth);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              layout.padding,
              12,
              layout.padding,
              8,
            ),
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
                          Expanded(
                            flex: 6,
                            child: _buildPanelAcciones(layout),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildEncabezadoTurno(compacto: layout.compacto),
                          SizedBox(height: layout.sectionGap),
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
      color: Colors.white,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.08),
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
                  color: secondaryColor,
                  borde: accentColor.withValues(alpha: 0.75),
                  fondo: accentColor.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: widget.fromAdmin
                    ? _buildBotonBarraInferior(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Panel admin',
                        onTap: () => Navigator.of(context).pop(),
                        color: primaryColor,
                        borde: primaryColor.withValues(alpha: 0.25),
                        fondo: primaryColor.withValues(alpha: 0.06),
                      )
                    : _buildBotonBarraInferior(
                        icon: Icons.logout_rounded,
                        label: 'Cerrar sesión',
                        onTap: _cerrarSesion,
                        color: AppColors.error,
                        borde: AppColors.error.withValues(alpha: 0.35),
                        fondo: AppColors.error.withValues(alpha: 0.08),
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
            border: Border.all(color: borde, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accentColor),
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
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: secondaryColor,
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
                              style: GoogleFonts.poppins(
                                fontSize: compacto ? 11 : 12,
                                fontWeight: FontWeight.w500,
                                color: secondaryColor,
                              ),
                            ),
                          Text(
                            _currentSectorNombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: compacto ? 15 : 16,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
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
                          style: GoogleFonts.poppins(
                            fontSize: compacto ? 18 : 20,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_currentTime.day.toString().padLeft(2, '0')}/${_currentTime.month.toString().padLeft(2, '0')}/${_currentTime.year}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: secondaryColor,
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
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              esFinal ? Icons.fact_check_outlined : Icons.add_box_outlined,
              size: compacto ? 26 : 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  esFinal
                      ? 'Ingresar stock final'
                      : 'Ingresar stock inicial',
                  style: GoogleFonts.poppins(
                    fontSize: compacto ? 16 : 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white.withValues(alpha: 0.92),
            size: 18,
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: esFinal ? _ingresarStockFinal : _agregarStockInicial,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentColor, secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
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
        iconBg: AppColors.accent.withValues(alpha: 0.18),
        iconColor: secondaryColor,
        onTap: () {
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
        },
      ),
      _AccionItem(
        icon: Icons.remove_circle_outline_rounded,
        label: 'Mermas',
        descripcion: 'Productos perdidos',
        iconBg: AppColors.error.withValues(alpha: 0.12),
        iconColor: AppColors.error,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RegistroMerma(
                eventoId: widget.eventId,
                sectorId: _currentSectorId,
                nombreSector: _currentSectorNombre,
              ),
            ),
          );
        },
      ),
      _AccionItem(
        icon: Icons.restaurant_menu_rounded,
        label: 'Bandejeo',
        descripcion: 'Armar bandejas',
        iconBg: secondaryColor.withValues(alpha: 0.14),
        iconColor: secondaryColor,
        onTap: () {
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
        },
      ),
      _AccionItem(
        icon: Icons.inventory_2_outlined,
        label: 'Ver stock',
        descripcion: 'Ver inventario',
        iconBg: AppColors.success.withValues(alpha: 0.14),
        iconColor: AppColors.success,
        onTap: _verStock,
      ),
    ];
  }

  Widget _buildPanelAccionesBody(
    List<_AccionItem> acciones,
    _VendedorPanelLayout layout,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.55)),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                layout.stockYOperacionesEnFila
                    ? 'Operaciones'
                    : 'Operaciones del turno',
                style: GoogleFonts.poppins(
                  fontSize: layout.tituloSeccion,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: layout.gridColumns == 4
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < acciones.length; i++) ...[
                        if (i > 0) SizedBox(width: layout.gridSpacing),
                        Expanded(
                          child: _buildActionTile(acciones[i]),
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
                            Expanded(child: _buildActionTile(acciones[0])),
                            SizedBox(width: layout.gridSpacing),
                            Expanded(child: _buildActionTile(acciones[1])),
                          ],
                        ),
                      ),
                      SizedBox(height: layout.gridSpacing),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _buildActionTile(acciones[2])),
                            SizedBox(width: layout.gridSpacing),
                            Expanded(child: _buildActionTile(acciones[3])),
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

  Widget _buildActionTile(_AccionItem accion) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: accion.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: accion.iconBg.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accion.iconColor.withValues(alpha: 0.14),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: accion.iconColor.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    accion.icon,
                    color: accion.iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  accion.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  accion.descripcion,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: secondaryColor.withValues(alpha: 0.88),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _agregarStockInicial() async {
    await Navigator.push(
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock actualizado', style: GoogleFonts.poppins()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _cambiarEvento() {
    Navigator.pushReplacement(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Debe ingresar el stock inicial antes del stock final.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
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
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }
}

class _AccionItem {
  final IconData icon;
  final String label;
  final String descripcion;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  const _AccionItem({
    required this.icon,
    required this.label,
    required this.descripcion,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
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
