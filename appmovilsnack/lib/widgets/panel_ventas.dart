import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:front_appsnack/utils/categorias_producto.dart';

class PanelVentas extends StatefulWidget {
  final String eventoId;
  final String nombreSector;
  final String sectorId;
  final String? vendedorNombre; // NUEVO: Nombre del vendedor

  const PanelVentas({
    super.key,
    required this.eventoId,
    required this.nombreSector,
    required this.sectorId,
    this.vendedorNombre, // NUEVO parámetro opcional
  });

  @override
  State<PanelVentas> createState() => _PanelVentasState();
}

class _PanelVentasState extends State<PanelVentas> {
  String? _sectorActualNombre;
  String? _sectorActualId;
  List<Map<String, String>> _todosLosSectores = [];
  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  // Stream fijo para no recrearlo en cada setState y evitar parpadeo al añadir al carrito.
  Stream<QuerySnapshot>? _stockStream;

  List<Map<String, dynamic>> _carritoItems = [];
  double _montoTotal = 0.0;

  /// Categoría por productoId (desde colección productos) para stock que no tenga categoría
  Map<String, String> _categoriasPorProductoId = {};
  /// Nombres de categorías (desde Firestore) para orden de secciones
  List<String> _nombresCategorias = [];
  /// Historial: username desde colección usuarios por vendedorUid
  Map<String, String> _usernameCache = {};
  Set<String> _lastFetchedUids = {};

  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);
  final Color backgroundColor = const Color(0xFFFDFBF7);

  @override
  void initState() {
    super.initState();
    _sectorActualNombre = widget.nombreSector;
    _sectorActualId = widget.sectorId;
    if (_sectorActualId != null) {
      _stockStream = FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(_sectorActualId)
          .collection('stock')
          .snapshots();
    }
    _cargarDatosIniciales();
    _cargarCategoriasProductos();
    _cargarListaCategorias();
    _searchController.addListener(_filtrarProductos);
  }

  Future<void> _cargarListaCategorias() async {
    try {
      final list = await cargarNombresCategorias();
      if (mounted) setState(() => _nombresCategorias = list);
    } catch (_) {}
  }

  Future<void> _cargarCategoriasProductos() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('productos').get();
      if (!mounted) return;
      final map = <String, String>{};
      for (final d in snap.docs) {
        final cat = d.data()['categoria']?.toString();
        if (cat != null && cat.isNotEmpty) map[d.id] = cat;
      }
      setState(() => _categoriasPorProductoId = map);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
      await _cargarSectoresDelEvento();
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión: ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error inesperado: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cargarSectoresDelEvento() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .get();

      setState(() {
        _todosLosSectores = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'nombre': (data['nombre'] as String?) ?? 'Sin Nombre',
          };
        }).toList();
      });
    } catch (e) {
      rethrow;
    }
  }

  void _filtrarProductos() {
    // Con StreamBuilder, basta con repintar al escribir.
    if (mounted) setState(() {});
  }

  void _agregarItemAlCarrito(String nombre, double precio, int stock, [String categoria = categoriaDefault]) {
    setState(() {
      bool itemEncontrado = false;
      for (var item in _carritoItems) {
        if (item['nombre'] == nombre) {
          if (item['cantidad'] < stock) {
            item['cantidad']++;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No hay más stock disponible para $nombre',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          itemEncontrado = true;
          break;
        }
      }
      if (!itemEncontrado) {
        _carritoItems.add({
          'nombre': nombre,
          'precio': precio,
          'cantidad': 1,
          'stock': stock,
          'categoria': categoriasProducto.contains(categoria) ? categoria : categoriaDefault,
        });
      }
      _recalcularTotal();
    });
  }

  void _quitarItemDelCarrito(String nombre) {
    setState(() {
      _carritoItems.removeWhere((item) => item['nombre'] == nombre);
      _recalcularTotal();
    });
  }

  void _incrementarCantidad(String nombre) {
    setState(() {
      for (var item in _carritoItems) {
        if (item['nombre'] == nombre) {
          int stock = item['stock'] ?? 0;
          if (item['cantidad'] < stock) {
            item['cantidad']++;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No hay más stock disponible para $nombre',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          break;
        }
      }
      _recalcularTotal();
    });
  }

  void _decrementarCantidad(String nombre) {
    setState(() {
      for (var item in _carritoItems) {
        if (item['nombre'] == nombre) {
          if (item['cantidad'] > 1) {
            item['cantidad']--;
          } else {
            _quitarItemDelCarrito(nombre);
            return;
          }
          break;
        }
      }
      _recalcularTotal();
    });
  }

  Future<void> _editarCantidadPorTeclado(String nombre) async {
    final idx = _carritoItems.indexWhere((e) => e['nombre'] == nombre);
    if (idx == -1) return;
    final item = _carritoItems[idx];
    final stockMax = item['stock'] as int? ?? 0;
    final cantidadActual = item['cantidad'] as int? ?? 1;
    final controller = TextEditingController(text: cantidadActual.toString());

    final nuevaCantidad = await showDialog<int?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          item['nombre'] as String,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stock disponible: $stockMax',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: secondaryColor,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Cantidad',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSubmitted: (_) => Navigator.of(dialogContext).pop(
                int.tryParse(controller.text.trim()),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: Text('Cancelar', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              int.tryParse(controller.text.trim()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: primaryColor,
            ),
            child: Text('Aceptar', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (nuevaCantidad == null || !mounted) return;
    if (nuevaCantidad <= 0) {
      _quitarItemDelCarrito(nombre);
      return;
    }
    if (nuevaCantidad > stockMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Máximo disponible: $stockMax',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      for (var i in _carritoItems) {
        if (i['nombre'] == nombre) {
          i['cantidad'] = nuevaCantidad;
          break;
        }
      }
      _recalcularTotal();
    });
  }

  void _recalcularTotal() {
    _montoTotal = 0.0;
    for (var item in _carritoItems) {
      _montoTotal += (item['precio'] as num) * (item['cantidad'] as num);
    }
  }

  /// Solo lee el sector y devuelve el mapa para update. Las transacciones exigen: primero todas las lecturas, después todas las escrituras.
  Future<Map<String, dynamic>?> _leerSectorYPrepararUpdateVendedor(Transaction transaction) async {
    if (widget.vendedorNombre == null) return null;

    final sectorRef = FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('sectores')
        .doc(_sectorActualId);
    final sectorSnapshot = await transaction.get(sectorRef);
    if (!sectorSnapshot.exists) return null;

    final sectorData = sectorSnapshot.data() as Map<String, dynamic>;
    List<dynamic> vendedoresAsignados = List.from(
      sectorData['vendedoresasignados'] ?? [],
    );
    bool vendedorEncontrado = false;
    for (int i = 0; i < vendedoresAsignados.length; i++) {
      if (vendedoresAsignados[i]['nombre'] == widget.vendedorNombre) {
        double totalActual = (vendedoresAsignados[i]['totalVendido'] ?? 0).toDouble();
        vendedoresAsignados[i]['totalVendido'] = totalActual + _montoTotal;
        vendedorEncontrado = true;
        break;
      }
    }
    if (!vendedorEncontrado) {
      vendedoresAsignados.add({
        'nombre': widget.vendedorNombre,
        'totalVendido': _montoTotal,
      });
    }
    return {
      'vendedoresasignados': vendedoresAsignados,
      'totalVendido': FieldValue.increment(_montoTotal),
    };
  }

  Future<void> _realizarVenta(String metodoPago, {double? montoEfectivo, double? montoTarjeta}) async {
    if (_carritoItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El carrito está vacío.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // Referencias de stock por producto (Transaction.get solo acepta DocumentReference en Flutter)
      final stockRefs = <String, DocumentReference<Map<String, dynamic>>>{};
      for (var item in _carritoItems) {
        final nombre = item['nombre'] as String;
        if (stockRefs.containsKey(nombre)) continue;
        final q = await FirebaseFirestore.instance
            .collection('eventos')
            .doc(widget.eventoId)
            .collection('sectores')
            .doc(_sectorActualId)
            .collection('stock')
            .where('nombre', isEqualTo: nombre)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) stockRefs[nombre] = q.docs.first.reference;
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final sectorRef = FirebaseFirestore.instance
            .collection('eventos')
            .doc(widget.eventoId)
            .collection('sectores')
            .doc(_sectorActualId);
        final ventaRef = FirebaseFirestore.instance.collection('transacciones').doc();

        // ——— FASE 1: Todas las LECTURAS (Firestore lo exige) ———
        final stockActualPorRef = <DocumentReference<Map<String, dynamic>>, int>{};
        for (var item in _carritoItems) {
          final productoNombre = item['nombre'] as String;
          final cantidadVendida = item['cantidad'] as int;
          final productoRef = stockRefs[productoNombre];
          if (productoRef == null) continue;
          final productoDoc = await transaction.get(productoRef);
          if (!productoDoc.exists) continue;
          final currentStock = productoDoc.data()?['cantidad'] as int? ?? 0;
          if (currentStock < cantidadVendida) {
            throw Exception('Stock insuficiente para $productoNombre');
          }
          stockActualPorRef[productoRef] = currentStock - cantidadVendida;
        }
        final sectorUpdate = await _leerSectorYPrepararUpdateVendedor(transaction);

        // ——— FASE 2: Todas las ESCRITURAS ———
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final itemsGuardar = _carritoItems.map<Map<String, dynamic>>((item) => {
          'nombre': item['nombre'],
          'precio': item['precio'],
          'cantidad': item['cantidad'],
          'categoria': item['categoria'] ?? categoriaDefault,
        }).toList();
        final data = <String, dynamic>{
          'eventoId': widget.eventoId,
          'sectorId': _sectorActualId,
          'vendedorNombre': widget.vendedorNombre,
          'fecha': FieldValue.serverTimestamp(),
          'montoTotal': _montoTotal,
          'metodoPago': metodoPago,
          'items': itemsGuardar,
        };
        if (uid != null) data['vendedorUid'] = uid;
        if (metodoPago == 'Mixto' && montoEfectivo != null && montoTarjeta != null) {
          data['montoEfectivo'] = montoEfectivo;
          data['montoTarjeta'] = montoTarjeta;
        }
        transaction.set(ventaRef, data);
        for (var e in stockActualPorRef.entries) {
          transaction.update(e.key, {'cantidad': e.value});
        }
        if (sectorUpdate != null) {
          transaction.update(sectorRef, sectorUpdate);
        }
      });

      // Si la transacción fue exitosa
      _limpiarCarrito();
      // El stock se actualiza automáticamente (StreamBuilder).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Venta realizada con éxito',
            style: GoogleFonts.poppins(color: primaryColor),
          ),
          backgroundColor: accentColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al realizar la venta: ${e.message}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _limpiarCarrito() {
    setState(() {
      _carritoItems = [];
      _montoTotal = 0.0;
    });
  }

  Future<void> _mostrarPagoMixto() async {
    if (_carritoItems.isEmpty) return;
    final efectivoController = TextEditingController();
    final total = _montoTotal;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final ef = double.tryParse(efectivoController.text.replaceAll(',', '.')) ?? 0;
            final tarjeta = (total - ef).clamp(0.0, double.infinity);
            return AlertDialog(
              title: Text(
                'Pago mixto',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryColor),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total: \$${total.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: accentColor),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: efectivoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Monto en efectivo',
                        hintText: '0',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: accentColor, width: 2),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Resto en tarjeta: \$${tarjeta.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor,
                      ),
                    ),
                    if (ef > total)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'El efectivo no puede ser mayor al total.',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('Cancelar', style: GoogleFonts.poppins(color: secondaryColor)),
                ),
                ElevatedButton(
                  onPressed: (ef >= 0 && ef <= total)
                      ? () {
                          Navigator.of(ctx).pop(true);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: primaryColor,
                  ),
                  child: Text('Cobrar', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmar != true || !mounted) {
      _disposeEfectivoControllerAfterDialog(efectivoController);
      return;
    }
    final ef = double.tryParse(efectivoController.text.replaceAll(',', '.')) ?? 0;
    _disposeEfectivoControllerAfterDialog(efectivoController);
    final efClamp = ef.clamp(0.0, total);
    final tarjeta = total - efClamp;
    await _realizarVenta('Mixto', montoEfectivo: efClamp, montoTarjeta: tarjeta);
  }

  /// Evita "used after disposed": el diálogo puede seguir en el árbol un frame más.
  void _disposeEfectivoControllerAfterDialog(TextEditingController c) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      c.dispose();
    });
  }

  /// Obtiene usernames de la colección usuarios para los uids de las transacciones.
  Future<Map<String, String>> _fetchUsernamesForUids(List<String> uids) async {
    if (uids.isEmpty) return {};
    final snaps = await Future.wait(
      uids.map((uid) => FirebaseFirestore.instance.collection('usuarios').doc(uid).get()),
    );
    final map = <String, String>{};
    for (var i = 0; i < uids.length; i++) {
      final un = snaps[i].data()?['username']?.toString();
      if (un != null && un.isNotEmpty) map[uids[i]] = un;
    }
    return map;
  }

  String _usuarioEnHistorial(Map<String, dynamic> d) {
    final uid = d['vendedorUid']?.toString();
    if (uid != null && _usernameCache.containsKey(uid)) return _usernameCache[uid]!;
    final nom = d['vendedorNombre']?.toString();
    return (nom != null && nom.isNotEmpty) ? nom.trim() : 'Sin usuario';
  }

  void _mostrarHistorialVentas() {
    if (_sectorActualId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Historial de ventas',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('transacciones')
                      .where('eventoId', isEqualTo: widget.eventoId)
                      .where('sectorId', isEqualTo: _sectorActualId)
                      .orderBy('fecha', descending: true)
                      .limit(100)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: accentColor));
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: GoogleFonts.poppins(color: Colors.red),
                        ),
                      );
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No hay ventas en este sector',
                          style: GoogleFonts.poppins(color: secondaryColor),
                        ),
                      );
                    }
                    final uids = docs
                        .map((doc) => (doc.data() as Map<String, dynamic>)['vendedorUid']?.toString())
                        .whereType<String>()
                        .toSet();
                    if (!setEquals(uids, _lastFetchedUids)) {
                      _lastFetchedUids = uids;
                      _fetchUsernamesForUids(uids.toList()).then((map) {
                        if (mounted) setState(() => _usernameCache = map);
                      });
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final d = doc.data() as Map<String, dynamic>;
                        final monto = (d['montoTotal'] as num?)?.toDouble() ?? 0.0;
                        final usuario = _usuarioEnHistorial(d);
                        final fecha = d['fecha'] as dynamic;
                        String fechaStr = '';
                        if (fecha != null && fecha is Timestamp) {
                          final dt = fecha.toDate();
                          fechaStr = '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                        }
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: accentColor.withOpacity(0.2),
                              child: Icon(Icons.receipt_long, color: accentColor),
                            ),
                            title: Text(
                              '\$${monto.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: primaryColor,
                              ),
                            ),
                            subtitle: Text(
                              usuario,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: secondaryColor,
                              ),
                            ),
                            trailing: fechaStr.isNotEmpty
                                ? Text(
                                    fechaStr,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: secondaryColor,
                                    ),
                                  )
                                : null,
                            onTap: () => _mostrarDetalleTransaccion(d),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarDetalleTransaccion(Map<String, dynamic> d) async {
    final uid = d['vendedorUid']?.toString();
    if (uid != null && !_usernameCache.containsKey(uid)) {
      try {
        final snap = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
        final un = snap.data()?['username']?.toString();
        if (un != null && un.isNotEmpty && mounted) {
          setState(() => _usernameCache[uid] = un);
        }
      } catch (_) {}
    }
    final monto = (d['montoTotal'] as num?)?.toDouble() ?? 0.0;
    final metodoPago = d['metodoPago']?.toString() ?? '—';
    final usuario = _usuarioEnHistorial(d);
    final items = d['items'] as List<dynamic>?;
    final fecha = d['fecha'] as dynamic;
    String fechaStr = '';
    if (fecha != null && fecha is Timestamp) {
      final dt = fecha.toDate();
      fechaStr = '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Detalle de la venta',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Usuario: $usuario', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              if (fechaStr.isNotEmpty) Text('Fecha: $fechaStr', style: GoogleFonts.poppins(fontSize: 13, color: secondaryColor)),
              const SizedBox(height: 8),
              Text(
                'Método de pago: $metodoPago',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: metodoPago == 'Efectivo' ? Colors.green : (metodoPago == 'Tarjeta' ? accentColor : primaryColor),
                ),
              ),
              if (metodoPago == 'Mixto') ...[
                const SizedBox(height: 6),
                Text(
                  'Efectivo: \$${((d['montoEfectivo'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} · Tarjeta: \$${((d['montoTarjeta'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontSize: 13, color: secondaryColor),
                ),
              ],
              const SizedBox(height: 12),
              Text('Total: \$${monto.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: accentColor)),
              const SizedBox(height: 12),
              Text('Productos', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 6),
              if (items != null && items.isNotEmpty)
                ...items.map<Widget>((e) {
                  final map = e as Map<String, dynamic>;
                  final nombre = map['nombre']?.toString() ?? '—';
                  final cant = map['cantidad'] as num? ?? 0;
                  final precio = (map['precio'] as num?)?.toDouble() ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $nombre x$cant — \$${(precio * cant).toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(fontSize: 13, color: secondaryColor),
                    ),
                  );
                })
              else
                Text('Sin detalle de productos', style: GoogleFonts.poppins(fontSize: 13, color: secondaryColor)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cerrar', style: GoogleFonts.poppins(color: secondaryColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // NUEVA FUNCIONALIDAD: Devolver información actualizada
            final resultado = {
              'sectorNombre': _sectorActualNombre,
              'sectorId': _sectorActualId,
              'actualizado': true,
            };
            Navigator.pop(context, resultado);
          },
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/imagenes/logo.png", height: 30),
            const SizedBox(width: 10),
            _isLoading
                ? Text(
                    'Cargando...',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                      fontSize: 16,
                    ),
                  )
                : Expanded(
                    child: DropdownButton<String>(
                      value: _sectorActualNombre,
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down, color: accentColor),
                      style: GoogleFonts.poppins(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                      dropdownColor: primaryColor,
                      underline: Container(),
                      onChanged: (String? nuevoSectorNombre) async {
                        if (nuevoSectorNombre != null) {
                          final nuevoSector = _todosLosSectores.firstWhere(
                            (sector) => sector['nombre'] == nuevoSectorNombre,
                          );
                          if (nuevoSector['id'] != _sectorActualId) {
                            setState(() {
                              _sectorActualNombre = nuevoSectorNombre;
                              _sectorActualId = nuevoSector['id'];
                              _carritoItems.clear();
                              _montoTotal = 0.0;
                              // Actualizar el stream al nuevo sector para que el grid muestre su stock.
                              _stockStream = FirebaseFirestore.instance
                                  .collection('eventos')
                                  .doc(widget.eventoId)
                                  .collection('sectores')
                                  .doc(_sectorActualId)
                                  .collection('stock')
                                  .snapshots();
                            });
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
                  ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial de ventas',
            onPressed: _sectorActualId == null ? null : _mostrarHistorialVentas,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: secondaryColor,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar productos...',
                      prefixIcon: Icon(Icons.search, color: secondaryColor),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Sección del carrito visible
                  if (_carritoItems.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Carrito de ventas',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              Text(
                                'Total: ${_montoTotal.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Divider(color: secondaryColor.withOpacity(0.3)),
                          const SizedBox(height: 8),
                          // Lista de items del carrito con altura fija y scroll
                          SizedBox(
                            height: 200, // Altura fija para el área de items
                            child: ListView.builder(
                              itemCount: _carritoItems.length,
                              itemBuilder: (context, index) {
                                final item = _carritoItems[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      // Cantidad
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: accentColor,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            item['cantidad'].toString(),
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Nombre del producto
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['nombre'],
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: primaryColor,
                                              ),
                                            ),
                                            Text(
                                              'Stock: ${item['stock'] ?? 0}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: secondaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Controles de cantidad
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                            ),
                                            color: secondaryColor,
                                            iconSize: 22,
                                            onPressed: () =>
                                                _decrementarCantidad(
                                                  item['nombre'],
                                                ),
                                          ),
                                          GestureDetector(
                                            onTap: () =>
                                                _editarCantidadPorTeclado(
                                                  item['nombre'] as String,
                                                ),
                                            child: Tooltip(
                                              message: 'Toca para editar cantidad',
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: accentColor.withOpacity(0.5),
                                                  ),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '${item['cantidad']}',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: primaryColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                            ),
                                            color: accentColor,
                                            iconSize: 22,
                                            onPressed: () =>
                                                _incrementarCantidad(
                                                  item['nombre'],
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      // Precio unitario
                                      Text(
                                        (item['precio'] as num).toStringAsFixed(
                                          0,
                                        ),
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: accentColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Botón eliminar
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        color: Colors.red,
                                        iconSize: 20,
                                        onPressed: () => _quitarItemDelCarrito(
                                          item['nombre'],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Botones de pago
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _realizarVenta('Efectivo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: secondaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.money, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Efectivo',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _realizarVenta('Tarjeta'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: primaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.credit_card, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Tarjeta',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _mostrarPagoMixto,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: accentColor,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.account_balance_wallet_outlined, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Mixto',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Grid de productos (stream en tiempo real para que el stock
                  // se actualice al instante después de cada venta)
                  Expanded(
                    child: _sectorActualId == null
                        ? Center(
                            child: Text(
                              'Selecciona un sector',
                              style: GoogleFonts.poppins(color: secondaryColor),
                            ),
                          )
                        : _stockStream == null
                            ? Center(
                                child: Text(
                                  'Selecciona un sector',
                                  style: GoogleFonts.poppins(color: secondaryColor),
                                ),
                              )
                            : StreamBuilder<QuerySnapshot>(
                                stream: _stockStream,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Center(
                                      child: CircularProgressIndicator(
                                        color: accentColor,
                                      ),
                                    );
                                  }

                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Error al cargar productos: ${snapshot.error}',
                                    style: GoogleFonts.poppins(
                                      color: Colors.red,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }

                              final docs = snapshot.data?.docs ?? [];
                              final query = _searchController.text
                                  .toLowerCase()
                                  .trim();

                              final filtrados = query.isEmpty
                                  ? docs
                                  : docs.where((d) {
                                      final data =
                                          d.data() as Map<String, dynamic>?;
                                      final nombre = data?['nombre']
                                              ?.toString()
                                              .toLowerCase() ??
                                          '';
                                      return nombre.contains(query);
                                    }).toList();

                              if (filtrados.isEmpty && query.isNotEmpty) {
                                return Center(
                                  child: Text(
                                    'No se encontraron productos.',
                                    style: GoogleFonts.poppins(
                                      color: secondaryColor,
                                    ),
                                  ),
                                );
                              }

                              if (filtrados.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No hay productos en stock.',
                                    style: GoogleFonts.poppins(
                                      color: secondaryColor,
                                    ),
                                  ),
                                );
                              }

                              // Agrupar por categoría; si el stock no tiene categoría, usar la del producto
                              final Map<String, List<DocumentSnapshot>> porCategoria = {};
                              for (final d in filtrados) {
                                final data = d.data() as Map<String, dynamic>?;
                                final catStock = data?['categoria']?.toString();
                                final cat = catStock ?? _categoriasPorProductoId[d.id] ?? categoriaDefault;
                                final key = (_nombresCategorias.contains(cat) || categoriasProducto.contains(cat)) ? cat : categoriaDefault;
                                porCategoria.putIfAbsent(key, () => []).add(d);
                              }
                              final listaOrden = _nombresCategorias.isNotEmpty ? _nombresCategorias : categoriasProducto;
                              final categoriasOrdenadas = List<String>.from(listaOrden)
                                ..retainWhere((c) => (porCategoria[c]?.length ?? 0) > 0);
                              for (final k in porCategoria.keys) {
                                if (!categoriasOrdenadas.contains(k)) categoriasOrdenadas.add(k);
                              }
                              categoriasOrdenadas.sort((a, b) => ordenCategoria(a, listaOrden).compareTo(ordenCategoria(b, listaOrden)));

                              const double cardWidth = 150;
                              const double rowHeight = 200;

                              return ListView.builder(
                                itemCount: categoriasOrdenadas.length,
                                itemBuilder: (context, idxCat) {
                                  final cat = categoriasOrdenadas[idxCat];
                                  final productos = porCategoria[cat] ?? [];
                                  if (productos.isEmpty) return const SizedBox.shrink();
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
                                        child: Row(
                                          children: [
                                            Icon(iconoCategoria(cat), size: 22, color: secondaryColor),
                                            const SizedBox(width: 8),
                                            Text(
                                              cat,
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        height: rowHeight,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          padding: const EdgeInsets.only(left: 4, right: 12),
                                          itemCount: productos.length,
                                          itemBuilder: (context, index) {
                                            final producto = productos[index];
                                            final data = producto.data() as Map<String, dynamic>?;
                                            if (data == null) return const SizedBox.shrink();
                                            final String nombreProducto = data['nombre']?.toString() ?? 'Sin nombre';
                                            final num precioProducto = data['precio'] as num? ?? 0;
                                            final int stockProducto = data['cantidad'] as int? ?? 0;
                                            final categoriaProducto = data['categoria']?.toString() ?? _categoriasPorProductoId[producto.id] ?? categoriaDefault;
                                            final iconData = iconoCategoria(categoriaProducto);
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 10),
                                              child: SizedBox(
                                                width: cardWidth,
                                                child: Card(
                                                  elevation: stockProducto > 0 ? 4 : 2,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(15),
                                                  ),
                                                  color: stockProducto > 0
                                                      ? Colors.white
                                                      : Colors.grey.withOpacity(0.1),
                                                  child: InkWell(
                                                    onTap: () {
                                                      if (stockProducto > 0) {
                                                        _agregarItemAlCarrito(
                                                          nombreProducto,
                                                          precioProducto.toDouble(),
                                                          stockProducto,
                                                          categoriaProducto,
                                                        );
                                                      } else {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'No hay stock disponible para $nombreProducto',
                                                              style: GoogleFonts.poppins(),
                                                            ),
                                                            backgroundColor: Colors.red,
                                                            behavior: SnackBarBehavior.floating,
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    borderRadius: BorderRadius.circular(15),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(10.0),
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        crossAxisAlignment: CrossAxisAlignment.center,
                                                        children: [
                                                          Icon(
                                                            iconData,
                                                            size: 36,
                                                            color: stockProducto > 0
                                                                ? secondaryColor
                                                                : Colors.grey,
                                                          ),
                                                          const SizedBox(height: 8),
                                                          Text(
                                                            nombreProducto,
                                                            textAlign: TextAlign.center,
                                                            maxLines: 3,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w600,
                                                              color: primaryColor,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 6),
                                                          Text(
                                                            '\$${precioProducto.toStringAsFixed(0)}',
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.bold,
                                                              color: accentColor,
                                                            ),
                                                          ),
                                                          Text(
                                                            'Stock: $stockProducto',
                                                            style: GoogleFonts.poppins(
                                                              fontSize: 10,
                                                              color: stockProducto > 0
                                                                  ? secondaryColor
                                                                  : Colors.grey,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
