import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/services/firestore_helpers.dart';
import 'package:front_appsnack/core/tipografia.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'package:front_appsnack/core/margen_inferior.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';
import 'package:front_appsnack/core/precio.dart';

// Paleta de colores basada en el logo "Fusión"
const Color _primaryColor = AppColors.primaryLight;
const Color _accentColor = AppColors.accent;
const Color _secondaryColor = AppColors.secondary;
const Color _backgroundColor = AppColors.surface;

/// Widget para registrar mermas (pérdidas) de productos en stock
class RegistroMerma extends StatelessWidget {
  final String eventoId;
  final String sectorId;
  final String nombreSector;

  const RegistroMerma({
    super.key,
    required this.eventoId,
    required this.sectorId,
    required this.nombreSector,
  });

  String get _scopeKey => '$eventoId|$sectorId';

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey('registro-merma-$_scopeKey'),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registro de Mermas',
                  style: AppFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                    fontSize: 18,
                  ),
                ),
                Text(
                  nombreSector,
                  style: AppFonts.inter(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
            bottom: TabBar(
              labelColor: _accentColor,
              unselectedLabelColor: Colors.white70,
              indicatorColor: _accentColor,
              tabs: [
                Tab(
                  child: Text(
                    'Nueva Merma',
                    style: AppFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
                Tab(
                  child: Text(
                    'Historial',
                    style: AppFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              // Pérdida total acumulada: solo para el admin.
              if (AuthManager().sesionEsAdmin)
                _PerdidaTotalAcumulada(eventoId: eventoId, sectorId: sectorId),
              // Tabs content
              Expanded(
                child: TabBarView(
                  children: [
                    _TabNuevaMerma(eventoId: eventoId, sectorId: sectorId),
                    _TabHistorial(eventoId: eventoId, sectorId: sectorId),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget que muestra la pérdida total acumulada
class _PerdidaTotalAcumulada extends StatelessWidget {
  final String eventoId;
  final String sectorId;

  const _PerdidaTotalAcumulada({
    required this.eventoId,
    required this.sectorId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: ValueKey('mermas-total-$eventoId-$sectorId'),
      stream: FirestoreHelpers.streamMermasSector(eventoId, sectorId),
      builder: (context, snapshot) {
        double perdidaTotal = 0.0;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data();
            final docEvento = data['eventoId']?.toString();
            final docSector = data['sectorId']?.toString();
            if (docEvento != null &&
                docEvento.isNotEmpty &&
                docEvento != eventoId) {
              continue;
            }
            if (docSector != null &&
                docSector.isNotEmpty &&
                docSector != sectorId) {
              continue;
            }
            final cantidadPerdida = data['cantidadPerdida'] as int? ?? 0;
            final precio = (data['precio'] as num?)?.toDouble() ?? 0.0;
            perdidaTotal += cantidadPerdida * precio;
          }
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pérdida total acumulada',
                  style: AppFonts.inter(fontSize: 14, color: _secondaryColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\$${perdidaTotal.toStringAsFixed(0)}',
                style: AppFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tab 1: Nueva Merma (carrito de productos)
class _TabNuevaMerma extends StatefulWidget {
  final String eventoId;
  final String sectorId;

  const _TabNuevaMerma({required this.eventoId, required this.sectorId});

  @override
  State<_TabNuevaMerma> createState() => _TabNuevaMermaState();
}

class _LineaMermaCarrito {
  final String productoId;
  final String nombre;
  final double precio;
  final int stockMax;
  int cantidad;

  _LineaMermaCarrito({
    required this.productoId,
    required this.nombre,
    required this.precio,
    required this.stockMax,
    required this.cantidad,
  });
}

class _TabNuevaMermaState extends State<_TabNuevaMerma> {
  final Map<String, _LineaMermaCarrito> _carrito = {};
  bool _registrando = false;
  bool _mostrandoListado = false;

  int get _totalUnidades =>
      _carrito.values.fold(0, (total, linea) => total + linea.cantidad);

  List<_ProductoStock> _productosConStock(QuerySnapshot snapshot) {
    return snapshot.docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _ProductoStock(
            id: doc.id,
            nombre: data['nombre'] as String? ?? 'Sin nombre',
            precio: (data['precio'] as num?)?.toDouble() ?? 0.0,
            cantidad: data['cantidad'] as int? ?? 0,
          );
        })
        .where((p) => p.cantidad > 0)
        .toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
  }

  void _limpiarCarrito() => setState(_carrito.clear);

  void _mostrarMensaje(String msg, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppFonts.inter()),
        backgroundColor: esError ? AppColors.errorFuerte : AppColors.exitoFuerte,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _agregarAlCarrito(_ProductoStock producto) async {
    final existente = _carrito[producto.id];
    final controller = TextEditingController(
      text: existente != null ? '${existente.cantidad}' : '',
    );

    final cantidad = await showDialog<int?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existente != null ? 'Actualizar en el carrito' : 'Agregar al carrito',
          style: AppFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              producto.nombre,
              style: AppFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Disponible: ${producto.cantidad} u.',
                style: AppFonts.inter(fontSize: 14, color: _secondaryColor),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Cantidad perdida',
                hintText: 'Ej: 3',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSubmitted: (v) {
                final n = int.tryParse(v.trim());
                if (n != null) Navigator.of(dialogContext).pop(n);
              },
            ),
          ],
        ),
        actions: [
          if (existente != null)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(-1),
              child: Text(
                'Quitar',
                style: AppFonts.inter(color: AppColors.error),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: Text('Cancelar', style: AppFonts.inter()),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              Navigator.of(dialogContext).pop(v);
            },
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
            label: Text(
              existente != null ? 'Actualizar' : 'Agregar',
              style: AppFonts.inter(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: _primaryColor,
            ),
          ),
        ],
      ),
    );

    if (cantidad == null || !mounted) return;

    if (cantidad == -1) {
      setState(() => _carrito.remove(producto.id));
      _mostrarMensaje('"${producto.nombre}" quitado del carrito.');
      return;
    }

    if (cantidad <= 0 || cantidad > producto.cantidad) {
      _mostrarMensaje('Cantidad inválida.', esError: true);
      return;
    }

    setState(() {
      _carrito[producto.id] = _LineaMermaCarrito(
        productoId: producto.id,
        nombre: producto.nombre,
        precio: producto.precio,
        stockMax: producto.cantidad,
        cantidad: cantidad,
      );
    });
  }

  Future<void> _mostrarResumenCarrito() async {
    if (_carrito.isEmpty) return;

    final lineas = _carrito.values.toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));

    await showModalBottomSheet<void>(
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.tintaSecundaria,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Carrito de mermas',
                style: AppFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: lineas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final l = lineas[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l.nombre,
                        style: AppFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${l.cantidad} u.',
                        style: AppFonts.inter(
                          fontSize: 14,
                          color: _secondaryColor,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _agregarAlCarrito(
                            _ProductoStock(
                              id: l.productoId,
                              nombre: l.nombre,
                              precio: l.precio,
                              cantidad: l.stockMax,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${lineas.length} productos · $_totalUnidades unidades',
                style: AppFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _registrarCarrito() async {
    if (_carrito.isEmpty || _registrando) return;

    final lineas = _carrito.values.toList();
    final motivoController = TextEditingController();
    final resumen = lineas
        .map((l) => '• ${l.nombre}: ${l.cantidad} u.')
        .join('\n');

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? errorMotivo;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Registrar mermas',
              style: AppFonts.inter(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resumen, style: AppFonts.inter(height: 1.45)),
                  const SizedBox(height: 8),
                  Text(
                    'Total: ${lineas.length} productos · $_totalUnidades u.',
                    style: AppFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: motivoController,
                    maxLines: 3,
                    onChanged: (_) {
                      if (errorMotivo != null) {
                        setDialogState(() => errorMotivo = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Motivo de la pérdida',
                      hintText: 'Ej: Se cayó, Vencido, Dañado...',
                      errorText: errorMotivo,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppColors.dorado,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                    ),
                    style: AppFonts.inter(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text('Cancelar', style: AppFonts.inter()),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (motivoController.text.trim().isEmpty) {
                    setDialogState(
                      () => errorMotivo = 'Debes ingresar un motivo',
                    );
                    return;
                  }
                  Navigator.of(dialogContext).pop(true);
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  'Confirmar',
                  style: AppFonts.inter(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: _primaryColor,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmado != true || !mounted) return;

    final motivo = motivoController.text.trim();
    final totalProductos = lineas.length;
    final totalUnidades = _totalUnidades;
    setState(() => _registrando = true);

    try {
      await _registrarMermasEnLote(
        eventoId: widget.eventoId,
        sectorId: widget.sectorId,
        lineas: lineas,
        motivo: motivo,
      );

      if (!mounted) return;
      setState(() {
        _carrito.clear();
        _registrando = false;
        _mostrandoListado = false;
      });
      _mostrarMensaje(
        'Mermas registradas ($totalProductos productos, $totalUnidades u.)',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _registrando = false);
        _mostrarMensaje('Error al registrar: $e', esError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tieneCarrito = _carrito.isNotEmpty;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: ValueKey('mermas-stock-${widget.eventoId}-${widget.sectorId}'),
      stream: FirestoreHelpers.refStockSector(
        widget.eventoId,
        widget.sectorId,
      ).orderBy('nombre').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ErrorAmable(
            titulo: 'No pudimos cargar los productos',
            detalle: '${snapshot.error}',
            onReintentar: () => setState(() {}),
          );
        }

        final productos = snapshot.hasData
            ? _productosConStock(snapshot.data!)
            : <_ProductoStock>[];

        if (productos.isEmpty) {
          return _buildSinStock();
        }

        if (!_mostrandoListado) {
          return _buildPantallaInicial(productos);
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _registrando
                        ? null
                        : () => setState(() => _mostrandoListado = false),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: _primaryColor,
                    tooltip: 'Volver',
                  ),
                  Expanded(
                    child: Text(
                      'Seleccione los productos a registrar',
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Toque cada producto para agregarlo al carrito. Puede registrar uno o varios juntos.',
                  style: AppFonts.inter(
                    fontSize: 14,
                    color: _secondaryColor.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  tieneCarrito ? 88 : 16 + margenSistemaInferior(context),
                ),
                itemCount: productos.length,
                itemBuilder: (context, index) {
                  final producto = productos[index];
                  final enCarrito = _carrito[producto.id];
                  return _ProductoMermaCard(
                    producto: producto,
                    cantidadEnCarrito: enCarrito?.cantidad,
                    onTap: () => _agregarAlCarrito(producto),
                  );
                },
              ),
            ),
            if (tieneCarrito) _buildBarraCarrito(),
          ],
        );
      },
    );
  }

  Widget _buildSinStock() {
    return const EstadoVacio(
      titulo: 'No hay productos con stock disponible',
      mensaje: 'No se pueden registrar mermas sin stock en este sector.',
    );
  }

  Widget _buildPantallaInicial(List<_ProductoStock> productos) {
    final tieneCarrito = _carrito.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.remove_circle_outline,
              size: 64,
              color: AppColors.error.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 20),
            Text(
              'Registrar merma de productos',
              style: AppFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              tieneCarrito
                  ? 'Tiene ${_carrito.length} producto(s) pendientes en el carrito.'
                  : 'Puede cargar una o varias pérdidas en un solo registro.',
              style: AppFonts.inter(
                fontSize: 14,
                color: _secondaryColor.withValues(alpha: 0.85),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => setState(() => _mostrandoListado = true),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                tieneCarrito ? 'Continuar merma' : 'Agregar merma',
                style: AppFonts.inter(fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: _primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraCarrito() {
    return Material(
      elevation: 8,
      color: AppColors.tarjeta,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _mostrarResumenCarrito,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_carrito.length} productos en el carrito',
                          style: AppFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _primaryColor,
                          ),
                        ),
                        Text(
                          '$_totalUnidades u. · Toque para ver',
                          style: AppFonts.inter(
                            fontSize: 14,
                            color: _secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: _registrando ? null : _limpiarCarrito,
                child: Text(
                  'Vaciar',
                  style: AppFonts.inter(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: _registrando ? null : _registrarCarrito,
                icon: _registrando
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primaryColor,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  'Registrar',
                  style: AppFonts.inter(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductoStock {
  final String id;
  final String nombre;
  final double precio;
  final int cantidad;

  const _ProductoStock({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.cantidad,
  });
}

class _ProductoMermaCard extends StatelessWidget {
  final _ProductoStock producto;
  final int? cantidadEnCarrito;
  final VoidCallback onTap;

  const _ProductoMermaCard({
    required this.producto,
    required this.onTap,
    this.cantidadEnCarrito,
  });

  @override
  Widget build(BuildContext context) {
    final enCarrito = cantidadEnCarrito != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: enCarrito ? 3 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: enCarrito
            ? BorderSide(
                color: AppColors.dorado.withValues(alpha: 0.7),
                width: 1.5,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: enCarrito
                  ? _accentColor.withValues(alpha: 0.25)
                  : AppColors.aviso.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              enCarrito ? Icons.shopping_cart_rounded : Icons.inventory_2,
              color: enCarrito ? _primaryColor : AppColors.aviso,
              size: 26,
            ),
          ),
          title: Text(
            producto.nombre,
            style: AppFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _primaryColor,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                etiquetaPrecio(producto.precio),
                style: AppFonts.inter(fontSize: 14, color: _secondaryColor),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.exito.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Stock: ${producto.cantidad}',
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.exito,
                      ),
                    ),
                  ),
                  if (enCarrito) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Carrito: $cantidadEnCarrito u.',
                        style: AppFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          trailing: Icon(
            enCarrito ? Icons.edit_outlined : Icons.add_circle_outline,
            color: enCarrito ? _secondaryColor : AppColors.error,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Registra varias mermas en una sola transacción atómica.
Future<void> _registrarMermasEnLote({
  required String eventoId,
  required String sectorId,
  required List<_LineaMermaCarrito> lineas,
  required String motivo,
}) async {
  final loteId = FirebaseFirestore.instance.collection('_').doc().id;

  await FirebaseFirestore.instance.runTransaction((transaction) async {
    for (final linea in lineas) {
      final stockRef = FirestoreHelpers.refStockSector(
        eventoId,
        sectorId,
      ).doc(linea.productoId);

      final stockDoc = await transaction.get(stockRef);

      if (!stockDoc.exists) {
        throw Exception('"${linea.nombre}" ya no está en el stock.');
      }

      final stockData = stockDoc.data() as Map<String, dynamic>;
      final cantidadActual = stockData['cantidad'] as int? ?? 0;

      if (cantidadActual < linea.cantidad) {
        throw Exception(
          'Stock insuficiente de "${linea.nombre}" (hay $cantidadActual u.).',
        );
      }

      transaction.update(stockRef, {
        'cantidad': cantidadActual - linea.cantidad,
      });

      final mermaRef = FirestoreHelpers.refMermasSector(
        eventoId,
        sectorId,
      ).doc();

      transaction.set(mermaRef, {
        'eventoId': eventoId,
        'sectorId': sectorId,
        'fecha': FieldValue.serverTimestamp(),
        'loteId': loteId,
        'totalProductosLote': lineas.length,
        'totalUnidadesLote': lineas.fold(0, (t, l) => t + l.cantidad),
        'productoId': linea.productoId,
        'nombreProducto': linea.nombre,
        'cantidadPerdida': linea.cantidad,
        'motivo': motivo,
        'precio': linea.precio,
      });
    }
  });
}

/// Tab 2: Historial de Mermas
class _TabHistorial extends StatelessWidget {
  final String eventoId;
  final String sectorId;

  const _TabHistorial({required this.eventoId, required this.sectorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: ValueKey('mermas-historial-$eventoId-$sectorId'),
      stream: FirestoreHelpers.streamMermasSector(
        eventoId,
        sectorId,
        ordenarPorFecha: true,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ErrorAmable(
            titulo: 'No pudimos cargar el historial',
            detalle: '${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final mermas = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final docEvento = data['eventoId']?.toString();
          final docSector = data['sectorId']?.toString();
          if (docEvento != null &&
              docEvento.isNotEmpty &&
              docEvento != eventoId) {
            return false;
          }
          if (docSector != null &&
              docSector.isNotEmpty &&
              docSector != sectorId) {
            return false;
          }
          return true;
        }).toList();

        if (mermas.isEmpty) {
          return const EstadoVacio(
            titulo: 'No hay mermas registradas',
            mensaje: 'Las mermas de este sector aparecerán aquí. ¡Así se hace!',
          );
        }

        return ListView.builder(
          padding: conMargenInferior(context, const EdgeInsets.all(16)),
          itemCount: mermas.length,
          itemBuilder: (context, index) {
            final mermaDoc = mermas[index];
            final data = mermaDoc.data();
            final nombreProducto =
                data['nombreProducto'] as String? ?? 'Sin nombre';
            final cantidadPerdida = data['cantidadPerdida'] as int? ?? 0;
            final motivo = data['motivo'] as String? ?? 'Sin motivo';
            final fecha = data['fecha'] as Timestamp?;

            String horaFormato = '--:--';
            if (fecha != null) {
              final fechaDateTime = fecha.toDate();
              horaFormato =
                  '${fechaDateTime.hour.toString().padLeft(2, '0')}:${fechaDateTime.minute.toString().padLeft(2, '0')}';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                    size: 28,
                  ),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        nombreProducto,
                        style: AppFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-$cantidadPerdida',
                        style: AppFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: _secondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          horaFormato,
                          style: AppFonts.inter(
                            fontSize: 14,
                            color: _secondaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      motivo,
                      style: AppFonts.inter(
                        fontSize: 14,
                        color: _secondaryColor.withValues(alpha: 0.8),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                trailing: Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
