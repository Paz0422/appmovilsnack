import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'item_carrito.dart';
import 'realizar_venta.dart';
import 'stock_screen.dart';

class PanelVentas extends StatefulWidget {
  final String eventoId;
  final String nombreSector;
  final String sectorId;
  final String? vendedorNombre;

  const PanelVentas({
    super.key,
    required this.eventoId,
    required this.nombreSector,
    required this.sectorId,
    this.vendedorNombre,
  });

  @override
  State<PanelVentas> createState() => _PanelVentasState();
}

class _PanelVentasState extends State<PanelVentas> {
  final VentasService _ventasService = VentasService();
  String? _sectorActualNombre;
  String? _sectorActualId;
  List<Map<String, String>> _todosLosSectores = [];
  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _productos = [];
  List<DocumentSnapshot> _productosFiltrados = [];

  List<ItemCarrito> _carritoItems = [];
  double _montoTotal = 0.0;
  bool _stockInicialAgregado = false;

  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);
  final Color backgroundColor = const Color(0xFFFDFBF7);

  @override
  void initState() {
    super.initState();
    _sectorActualNombre = widget.nombreSector;
    _sectorActualId = widget.sectorId;
    _cargarDatosIniciales();
    _searchController.addListener(_filtrarProductos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- FUNCIÓN PARA DEVOLVER ESTADO ---
  void _devolverEstadoActual() {
    final resultado = {
      'sectorNombre': _sectorActualNombre,
      'sectorId': _sectorActualId,
    };
    Navigator.of(context).pop(resultado);
  }

  // --- LÓGICA DE DATOS ---

  Future<void> _cargarDatosIniciales() async {
    try {
      if (mounted)
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      await _cargarSectoresDelEvento();
      await _cargarProductosPorSector();
    } on FirebaseException catch (e) {
      if (mounted)
        setState(() => _errorMessage = 'Error de conexión: ${e.message}');
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarSectoresDelEvento() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('sectores')
        .get();
    if (mounted) {
      setState(() {
        _todosLosSectores = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'nombre': data['nombre'] as String? ?? 'Sin Nombre',
          };
        }).toList();
      });
    }
  }

  Future<void> _cargarProductosPorSector() async {
    if (_sectorActualId == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('sectores')
        .doc(_sectorActualId)
        .collection('stockInicial')
        .get();
    if (mounted) {
      setState(() {
        _productos = snapshot.docs;
        _productosFiltrados = _productos;
        _stockInicialAgregado = _productos.isNotEmpty;
      });
    }
  }

  void _filtrarProductos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _productosFiltrados = _productos.where((p) {
        final data = p.data() as Map<String, dynamic>?;
        return data?['nombre']?.toString().toLowerCase().contains(query) ??
            false;
      }).toList();
    });
  }

  // --- LÓGICA DE CARRITO ---

  void _agregarItemAlCarrito(String nombre, double precio, int stock) {
    setState(() {
      final index = _carritoItems.indexWhere((item) => item.nombre == nombre);
      if (index != -1) {
        if (_carritoItems[index].cantidad < stock)
          _carritoItems[index].cantidad++;
        else
          _mostrarSnackBar('No hay más stock para $nombre', esError: true);
      } else {
        _carritoItems.add(
          ItemCarrito(
            nombre: nombre,
            precio: precio,
            cantidad: 1,
            stock: stock,
          ),
        );
      }
      _recalcularTotal();
    });
  }

  void _incrementarCantidad(String nombre) {
    setState(() {
      final index = _carritoItems.indexWhere((item) => item.nombre == nombre);
      if (index != -1 &&
          _carritoItems[index].cantidad < _carritoItems[index].stock) {
        _carritoItems[index].cantidad++;
        _recalcularTotal();
      }
    });
  }

  void _decrementarCantidad(String nombre) {
    setState(() {
      final index = _carritoItems.indexWhere((item) => item.nombre == nombre);
      if (index != -1) {
        if (_carritoItems[index].cantidad > 1)
          _carritoItems[index].cantidad--;
        else
          _carritoItems.removeAt(index);
        _recalcularTotal();
      }
    });
  }

  void _recalcularTotal() {
    double total = _carritoItems.fold(
      0.0,
      (sum, item) => sum + (item.precio * item.cantidad),
    );
    setState(() => _montoTotal = total);
  }

  void _limpiarCarrito() => setState(() {
    _carritoItems.clear();
    _montoTotal = 0.0;
  });

  // --- LÓGICA DE VENTA ---

  Future<void> _realizarVenta(String metodoPago) async {
    if (_carritoItems.isEmpty) {
      _mostrarSnackBar(
        'El carrito está vacío.',
        esError: false,
        color: Colors.orange,
      );
      return;
    }
    try {
      await _ventasService.procesarVenta(
        eventoId: widget.eventoId,
        sectorId: _sectorActualId!,
        vendedorNombre: widget.vendedorNombre,
        carritoItems: _carritoItems,
        montoTotal: _montoTotal,
        metodoPago: metodoPago,
      );
      _limpiarCarrito();
      await _cargarProductosPorSector();
    } catch (e) {
      rethrow;
    }
  }

  // --- NAVEGACIÓN Y ACCIONES ---

  void _agregarStockInicial() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StockScreen(
          eventoId: widget.eventoId,
          nombreSector: _sectorActualNombre ?? widget.nombreSector,
          sectorId: _sectorActualId ?? widget.sectorId,
          esStockInicial: true,
        ),
      ),
    );
    if (result == true) _cargarProductosPorSector();
  }

  void _agregarStockFinal() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StockScreen(
          eventoId: widget.eventoId,
          nombreSector: _sectorActualNombre ?? widget.nombreSector,
          sectorId: _sectorActualId ?? widget.sectorId,
          esStockInicial: false,
        ),
      ),
    );
  }

  void _cerrarTurno() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Cerrar Turno',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            '¿Estás seguro de que quieres cerrar el turno?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(color: secondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _devolverEstadoActual();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: primaryColor,
              ),
              child: Text(
                'Cerrar Turno',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- HELPERS DE UI ---

  void _mostrarSnackBar(String mensaje, {required bool esError, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: GoogleFonts.poppins()),
        backgroundColor: color ?? (esError ? Colors.redAccent : Colors.green),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- MÉTODO BUILD Y WIDGETS DE UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: primaryColor,
      foregroundColor: accentColor,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.3),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: _devolverEstadoActual,
      ),
      title: _isLoading
          ? Text(
              'Cargando...',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 18,
              ),
            )
          : DropdownButton<String>(
              value: _sectorActualNombre,
              isExpanded: true,
              icon: Icon(Icons.expand_more_rounded, color: accentColor),
              style: GoogleFonts.poppins(
                color: accentColor,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
              dropdownColor: primaryColor,
              underline: Container(),
              onChanged: (String? nuevoSectorNombre) async {
                if (nuevoSectorNombre != null) {
                  final nuevoSector = _todosLosSectores.firstWhere(
                    (s) => s['nombre'] == nuevoSectorNombre,
                    orElse: () => {},
                  );
                  if (nuevoSector.isNotEmpty &&
                      nuevoSector['id'] != _sectorActualId) {
                    setState(() {
                      _isLoading = true;
                      _sectorActualNombre = nuevoSectorNombre;
                      _sectorActualId = nuevoSector['id'];
                      _carritoItems.clear();
                      _montoTotal = 0.0;
                    });
                    await _cargarProductosPorSector();
                    setState(() => _isLoading = false);
                  }
                }
              },
              items: _todosLosSectores.map<DropdownMenuItem<String>>((
                Map<String, String> sector,
              ) {
                return DropdownMenuItem<String>(
                  value: sector['nombre'],
                  child: Text(sector['nombre']!),
                );
              }).toList(),
            ),
      centerTitle: true,
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: secondaryColor, fontSize: 16),
          ),
        ),
      );
    }
    return Column(
      children: [
        _buildPanelAcciones(),
        _buildBarraBusqueda(),
        Expanded(child: _buildGridProductos()),
        if (_carritoItems.isNotEmpty) _buildBotonCarrito(),
      ],
    );
  }

  Widget _buildPanelAcciones() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildBotonAccion(
              onPressed: _stockInicialAgregado
                  ? _agregarStockFinal
                  : _agregarStockInicial,
              label: _stockInicialAgregado ? 'Stock Final' : 'Stock Inicial',
              icon: _stockInicialAgregado
                  ? Icons.inventory_2_outlined
                  : Icons.add_box_outlined,
              color: _stockInicialAgregado ? Colors.blueAccent : Colors.green,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildBotonAccion(
              onPressed: _cerrarTurno,
              label: 'Cerrar Turno',
              icon: Icons.logout_rounded,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonAccion({
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    );
  }

  Widget _buildBarraBusqueda() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.poppins(),
        decoration: InputDecoration(
          hintText: 'Buscar productos...',
          hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
          prefixIcon: Icon(Icons.search_rounded, color: secondaryColor),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentColor, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildGridProductos() {
    if (_productosFiltrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No se encontraron productos'
                  : 'No hay productos en este sector',
              style: GoogleFonts.poppins(
                color: secondaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toca "Stock Inicial" para agregar productos',
              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // Cambiado de 3 a 2 para tarjetas más grandes
        childAspectRatio: 0.8, // Más alto para mejor visibilidad
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _productosFiltrados.length,
      itemBuilder: (context, index) {
        final data =
            _productosFiltrados[index].data() as Map<String, dynamic>? ?? {};
        final nombre = data['nombre']?.toString() ?? 'N/A';
        final precio = data['precio'] as num? ?? 0;
        final stock = data['stock'] as int? ?? 0;
        final isAgotado = stock <= 0;
        return GestureDetector(
          onTap: isAgotado
              ? null
              : () => _agregarItemAlCarrito(nombre, precio.toDouble(), stock),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: isAgotado ? Colors.grey[100] : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isAgotado
                    ? Colors.grey[300]!
                    : accentColor.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isAgotado
                      ? Colors.grey.withOpacity(0.1)
                      : accentColor.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isAgotado
                              ? Colors.grey[300]
                              : accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(
                          Icons.fastfood_outlined,
                          size: 30,
                          color: isAgotado ? Colors.grey[500] : accentColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        nombre,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isAgotado ? Colors.grey[600] : primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${precio.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isAgotado ? Colors.grey[600] : accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isAgotado)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$stock',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (isAgotado)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'AGOTADO',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBotonCarrito() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, -6),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: ElevatedButton(
        onPressed: _mostrarPanelPago,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.shopping_cart_checkout,
                color: primaryColor,
                size: 24,
              ),
            ),
            Text(
              'PROCEDER AL PAGO',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                '\$${_montoTotal.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarPanelPago() {
    if (_carritoItems.isEmpty) return;
    bool isProcessingPayment = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Future<void> handlePayment(String metodoPago) async {
              setModalState(() => isProcessingPayment = true);
              try {
                await _realizarVenta(metodoPago);
                if (mounted) Navigator.of(context).pop();
                _mostrarSnackBar(
                  'Venta realizada con éxito',
                  esError: false,
                  color: Colors.green,
                );
              } catch (e) {
                if (mounted) Navigator.of(context).pop();
                _mostrarSnackBar(
                  'Error: ${e.toString().replaceFirst("Exception: ", "")}',
                  esError: true,
                );
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Revisar Venta',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      itemCount: _carritoItems.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = _carritoItems[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: accentColor.withOpacity(0.15),
                            child: Text(
                              '${item.cantidad}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          title: Text(
                            item.nombre,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: secondaryColor,
                                onPressed: () => setModalState(
                                  () => _decrementarCantidad(item.nombre),
                                ),
                              ),
                              Text(
                                '\$${(item.precio * item.cantidad).toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                color: accentColor,
                                onPressed: () => setModalState(
                                  () => _incrementarCantidad(item.nombre),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total a Pagar:',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: secondaryColor,
                              ),
                            ),
                            Text(
                              '\$${_montoTotal.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (isProcessingPayment)
                          const Center(child: CircularProgressIndicator())
                        else
                          Row(
                            children: [
                              Expanded(
                                child: _buildBotonPago(
                                  context,
                                  'Efectivo',
                                  () => handlePayment('Efectivo'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildBotonPago(
                                  context,
                                  'Tarjeta',
                                  () => handlePayment('Tarjeta'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBotonPago(
    BuildContext context,
    String metodoPago,
    VoidCallback onPressed,
  ) {
    bool esEfectivo = metodoPago == 'Efectivo';
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(esEfectivo ? Icons.money_rounded : Icons.credit_card_rounded),
      label: Text(metodoPago),
      style: ElevatedButton.styleFrom(
        backgroundColor: esEfectivo ? secondaryColor : accentColor,
        foregroundColor: esEfectivo ? Colors.white : primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
