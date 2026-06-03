import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// Paleta de colores basada en el logo "Fusión"
const Color _primaryColor = Color(0xFF2B2B2B);
const Color _accentColor = Color(0xFFDABF41);
const Color _secondaryColor = Color(0xFF6B4D2F);
const Color _backgroundColor = Color(0xFFFDFBF7);

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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: Text(
            'Registro de Mermas',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: _accentColor,
            ),
          ),
          backgroundColor: _primaryColor,
          foregroundColor: _accentColor,
          bottom: TabBar(
            labelColor: _accentColor,
            unselectedLabelColor: Colors.white70,
            indicatorColor: _accentColor,
            tabs: [
              Tab(
                child: Text(
                  'Nueva Merma',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              Tab(
                child: Text(
                  'Historial',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Encabezado con pérdida total acumulada
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eventos')
          .doc(eventoId)
          .collection('sectores')
          .doc(sectorId)
          .collection('mermas')
          .snapshots(),
      builder: (context, snapshot) {
        double perdidaTotal = 0.0;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
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
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red[700],
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pérdida total acumulada',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _secondaryColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\$${perdidaTotal.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
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
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: esError ? Colors.red : Colors.green,
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
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              producto.nombre,
              style: GoogleFonts.poppins(
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
                style: GoogleFonts.poppins(fontSize: 13, color: _secondaryColor),
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
                style: GoogleFonts.poppins(color: Colors.red),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: Text('Cancelar', style: GoogleFonts.poppins()),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              Navigator.of(dialogContext).pop(v);
            },
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
            label: Text(
              existente != null ? 'Actualizar' : 'Agregar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Carrito de mermas',
                style: GoogleFonts.poppins(
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
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${l.cantidad} u.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
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
                style: GoogleFonts.poppins(
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
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resumen, style: GoogleFonts.poppins(height: 1.45)),
                  const SizedBox(height: 8),
                  Text(
                    'Total: ${lineas.length} productos · $_totalUnidades u.',
                    style: GoogleFonts.poppins(
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
                        borderSide: BorderSide(color: _accentColor, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                    ),
                    style: GoogleFonts.poppins(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text('Cancelar', style: GoogleFonts.poppins()),
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
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId)
          .collection('stock')
          .orderBy('nombre')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _accentColor));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar productos: ${snapshot.error}',
                    style: GoogleFonts.poppins(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
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
                      'Elegí los productos a registrar',
                      style: GoogleFonts.poppins(
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
                  'Tocá cada producto para agregarlo al carrito. Podés registrar uno o varios juntos.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
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
                  tieneCarrito ? 88 : 16,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: _secondaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay productos con stock disponible',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: _secondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'No se pueden registrar mermas sin stock en este sector.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _secondaryColor.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
              color: Colors.red.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 20),
            Text(
              'Registrar merma de productos',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              tieneCarrito
                  ? 'Tenés ${_carrito.length} producto(s) pendientes en el carrito.'
                  : 'Podés cargar una o varias pérdidas en un solo registro.',
              style: GoogleFonts.poppins(
                fontSize: 13,
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
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
      color: Colors.white,
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
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _primaryColor,
                          ),
                        ),
                        Text(
                          '$_totalUnidades u. · Tocá para ver',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
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
                  style: GoogleFonts.poppins(
                    color: Colors.red[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
            ? BorderSide(color: _accentColor.withValues(alpha: 0.7), width: 1.5)
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
                  : Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              enCarrito ? Icons.shopping_cart_rounded : Icons.inventory_2,
              color: enCarrito ? _primaryColor : Colors.orange[700],
              size: 26,
            ),
          ),
          title: Text(
            producto.nombre,
            style: GoogleFonts.poppins(
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
                'Precio: \$${producto.precio.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _secondaryColor,
                ),
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
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Stock: ${producto.cantidad}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
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
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Carrito: $cantidadEnCarrito u.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
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
            color: enCarrito ? _secondaryColor : Colors.red[700],
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
      final stockRef = FirebaseFirestore.instance
          .collection('eventos')
          .doc(eventoId)
          .collection('sectores')
          .doc(sectorId)
          .collection('stock')
          .doc(linea.productoId);

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

      final mermaRef = FirebaseFirestore.instance
          .collection('eventos')
          .doc(eventoId)
          .collection('sectores')
          .doc(sectorId)
          .collection('mermas')
          .doc();

      transaction.set(mermaRef, {
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eventos')
          .doc(eventoId)
          .collection('sectores')
          .doc(sectorId)
          .collection('mermas')
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _accentColor));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar historial: ${snapshot.error}',
                    style: GoogleFonts.poppins(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: _secondaryColor.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay mermas registradas',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: _secondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Las mermas registradas aparecerán aquí',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _secondaryColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        final mermas = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: mermas.length,
          itemBuilder: (context, index) {
            final mermaDoc = mermas[index];
            final data = mermaDoc.data() as Map<String, dynamic>;
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
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Colors.red[700],
                    size: 28,
                  ),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        nombreProducto,
                        style: GoogleFonts.poppins(
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
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-$cantidadPerdida',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
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
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _secondaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      motivo,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
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
                  color: Colors.red[700],
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
