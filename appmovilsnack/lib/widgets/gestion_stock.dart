import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:front_appsnack/services/firestore_helpers.dart';
import 'package:front_appsnack/utils/categorias_producto.dart';

// Paleta de colores basada en el logo "Fusión"
const Color _primaryColor = Color(0xFF2B2B2B);
const Color _accentColor = Color(0xFFDABF41);
const Color _secondaryColor = Color(0xFF6B4D2F);
const Color _backgroundColor = Color(0xFFFDFBF7);

/// Item de stock en memoria (hasta que se pulse Guardar).
/// [cantidadPropio]: unidades que el sector ya tenía.
/// [cantidadPorTraspaso]: unidades recibidas por traspaso (se suman solas).
/// [cantidad]: total = propio + traspaso.
Map<String, dynamic> _stockItem(
  String productoId,
  String nombre,
  double precio,
  int cantidadPropio, [
  String categoria = 'Otros',
  int cantidadPorTraspaso = 0,
]) {
  final traspaso = cantidadPorTraspaso < 0 ? 0 : cantidadPorTraspaso;
  final propio = cantidadPropio < 0 ? 0 : cantidadPropio;
  return {
    'productoId': productoId,
    'nombre': nombre,
    'precio': precio,
    'cantidadPropio': propio,
    'cantidadPorTraspaso': traspaso,
    'cantidad': propio + traspaso,
    'categoria': categoria,
  };
}

int _cantidadPropioDe(Map<String, dynamic> item) =>
    item['cantidadPropio'] as int? ??
    ((item['cantidad'] as int? ?? 0) - (item['cantidadPorTraspaso'] as int? ?? 0))
        .clamp(0, 1 << 30);

/// Widget reutilizable para gestionar el stock de un sector
/// Los cambios se guardan en Firestore solo al pulsar "Guardar".
/// [soloLectura]: si true, no permite agregar ni editar productos (solo ver)
class GestionStock extends StatefulWidget {
  final String eventoId;
  final String sectorId;
  final String nombreSector;
  final bool soloLectura;
  /// Si true, al guardar muestra advertencia de ingreso único y cierra la pantalla.
  final bool esIngresoInicial;
  /// Si se proporciona, se llama tras guardar con éxito.
  final VoidCallback? onGuardado;

  const GestionStock({
    super.key,
    required this.eventoId,
    required this.sectorId,
    required this.nombreSector,
    this.soloLectura = false,
    this.esIngresoInicial = false,
    this.onGuardado,
  });

  @override
  State<GestionStock> createState() => _GestionStockState();
}

class _GestionStockState extends State<GestionStock> {
  List<Map<String, dynamic>> _items = [];
  final Map<String, TextEditingController> _cantidadControllers = {};
  bool _dirty = false;
  bool _loading = true;
  Timer? _debounceBorrador;
  bool _mostroAvisoBorrador = false;

  DocumentReference<Map<String, dynamic>> get _sectorRef =>
      FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId);

  @override
  void initState() {
    super.initState();
    _cargarStock();
  }

  @override
  void dispose() {
    _debounceBorrador?.cancel();
    for (final c in _cantidadControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _aplicarBorradorStock(
    Map<String, dynamic> borrador,
    List<Map<String, dynamic>> items,
  ) {
    final raw = borrador['productos'] as List<dynamic>? ?? const [];
    for (final p in raw.whereType<Map<String, dynamic>>()) {
      final id = p['productoId']?.toString();
      if (id == null || id.isEmpty) continue;

      final traspaso = (p['cantidadPorTraspaso'] as num?)?.toInt() ?? 0;
      final propio = (p['cantidadPropio'] as num?)?.toInt() ??
          ((p['cantidad'] as num?)?.toInt() ?? 0) - traspaso;
      final propioClamped = propio < 0 ? 0 : propio;
      final cat = p['categoria']?.toString() ?? categoriaDefault;

      final idx = items.indexWhere((i) => i['productoId'] == id);
      if (idx >= 0) {
        items[idx]['cantidadPropio'] = propioClamped;
        items[idx]['cantidadPorTraspaso'] = traspaso;
        items[idx]['cantidad'] = propioClamped + traspaso;
      } else {
        items.add(
          _stockItem(
            id,
            p['nombre']?.toString() ?? 'Sin nombre',
            (p['precio'] as num?)?.toDouble() ?? 0.0,
            propioClamped,
            categoriasProducto.contains(cat) ? cat : categoriaDefault,
            traspaso,
          ),
        );
      }
    }
  }

  void _programarGuardadoBorrador() {
    if (widget.soloLectura || !widget.esIngresoInicial) return;
    _debounceBorrador?.cancel();
    _debounceBorrador = Timer(const Duration(milliseconds: 800), () {
      _guardarBorradorStockInicial();
    });
  }

  Future<void> _guardarBorradorStockInicial() async {
    if (widget.soloLectura || !widget.esIngresoInicial) return;
    _leerCantidadesDesdeControllers();
    try {
      if (_items.isEmpty) {
        await _sectorRef.set(
          {'borradorStockInicial': FieldValue.delete()},
          SetOptions(merge: true),
        );
        return;
      }
      await _sectorRef.set(
        {
          'borradorStockInicial': {
            'actualizadoEn': FieldValue.serverTimestamp(),
            'productos': _items
                .map(
                  (item) => {
                    'productoId': item['productoId'],
                    'nombre': item['nombre'],
                    'precio': item['precio'],
                    'categoria': item['categoria'] ?? categoriaDefault,
                    'cantidadPropio': _cantidadPropioDe(item),
                    'cantidadPorTraspaso':
                        item['cantidadPorTraspaso'] as int? ?? 0,
                    'cantidad': item['cantidad'],
                  },
                )
                .toList(),
          },
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> _retrocederPantalla() async {
    if (widget.soloLectura) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (widget.esIngresoInicial) {
      await _guardarBorradorStockInicial();
      if (!mounted) return;
      Navigator.of(context).pop(_items.isEmpty ? 'exit' : 'draft');
      return;
    }
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Sin guardar',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Si sale ahora no se guardará el stock. ¿Salir sin guardar?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: _secondaryColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Salir sin guardar',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (salir == true && mounted) Navigator.of(context).pop();
  }

  void _vincularControllers() {
    final ids = <String>{};
    for (final item in _items) {
      final id = item['productoId'] as String;
      ids.add(id);
      final conTraspaso = widget.esIngresoInicial &&
          (item['cantidadPorTraspaso'] as int? ?? 0) > 0;
      final valor =
          conTraspaso ? _cantidadPropioDe(item) : (item['cantidad'] as int? ?? 0);
      final ctrl = _cantidadControllers.putIfAbsent(
        id,
        () => TextEditingController(text: '$valor'),
      );
      if (ctrl.text != '$valor') {
        ctrl.text = '$valor';
      }
    }
    for (final id in _cantidadControllers.keys.toList()) {
      if (!ids.contains(id)) {
        _cantidadControllers.remove(id)?.dispose();
      }
    }
  }

  void _leerCantidadesDesdeControllers() {
    for (final item in _items) {
      final id = item['productoId'] as String;
      final ctrl = _cantidadControllers[id];
      if (ctrl == null) continue;
      final n = int.tryParse(ctrl.text.trim());
      if (n == null || n < 0) continue;
      final traspaso = item['cantidadPorTraspaso'] as int? ?? 0;
      if (widget.esIngresoInicial && traspaso > 0) {
        item['cantidadPropio'] = n;
        item['cantidad'] = n + traspaso;
      } else {
        item['cantidadPropio'] = n;
        item['cantidadPorTraspaso'] = 0;
        item['cantidad'] = n;
      }
    }
  }

  void _setCantidadItem(String productoId, int valor) {
    final i = _items.indexWhere((e) => e['productoId'] == productoId);
    if (i < 0) return;
    final traspaso = _items[i]['cantidadPorTraspaso'] as int? ?? 0;
    if (widget.esIngresoInicial && traspaso > 0) {
      _actualizarCantidadPropioLocal(productoId, valor);
    } else {
      _actualizarCantidadLocal(productoId, valor);
    }
    final ctrl = _cantidadControllers[productoId];
    final mostrar = widget.esIngresoInicial && traspaso > 0
        ? _cantidadPropioDe(_items[i])
        : _items[i]['cantidad'] as int;
    if (ctrl != null && ctrl.text != '$mostrar') {
      ctrl.text = '$mostrar';
    }
  }

  Future<void> _cargarStock() async {
    try {
      final sectorSnap = await _sectorRef.get();
      final sectorData = sectorSnap.data();
      final borrador = sectorData?['borradorStockInicial'];
      final stockInicialConfirmado =
          sectorData?['stockInicialIngresado'] == true;

      final snap = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId)
          .collection('stock')
          .get();
      if (!mounted) return;

      final items = snap.docs.map((d) {
          final data = d.data();
          final cat = data['categoria']?.toString() ?? categoriaDefault;
          final cantidad = data['cantidad'] as int? ?? 0;
          final cantidadInicialDoc = data['cantidadInicial'];
          final porTraspasoDoc = data['cantidadPorTraspaso'] as int?;
          final propioDoc = data['cantidadPropio'] as int?;
          final recibidoPorTraspaso = widget.esIngresoInicial &&
              cantidad > 0 &&
              cantidadInicialDoc == null;
          final int porTraspaso = (porTraspasoDoc ??
                  (recibidoPorTraspaso
                      ? cantidad
                      : (cantidadInicialDoc != null &&
                              cantidad > cantidadInicialDoc
                          ? cantidad - cantidadInicialDoc
                          : 0)))
              .toInt();
          final int propio = (propioDoc ??
                  (recibidoPorTraspaso
                      ? 0
                      : (cantidad - porTraspaso).clamp(0, cantidad)))
              .toInt();
          return _stockItem(
            d.id,
            data['nombre']?.toString() ?? 'Sin nombre',
            (data['precio'] as num?)?.toDouble() ?? 0.0,
            propio,
            categoriasProducto.contains(cat) ? cat : categoriaDefault,
            porTraspaso,
          );
        }).toList();

      var restauroBorrador = false;
      if (widget.esIngresoInicial && !stockInicialConfirmado) {
        await _fusionarCatalogoEnItems(items);
        if (borrador is Map<String, dynamic>) {
          _aplicarBorradorStock(borrador, items);
          restauroBorrador = true;
        }
      }

      items.sort((a, b) {
        final oa = ordenCategoria(a['categoria'] as String);
        final ob = ordenCategoria(b['categoria'] as String);
        if (oa != ob) return oa.compareTo(ob);
        return (a['nombre'] as String).compareTo(b['nombre'] as String);
      });

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _dirty = restauroBorrador;
      });
      _vincularControllers();

      if (restauroBorrador && mounted && !_mostroAvisoBorrador) {
        _mostroAvisoBorrador = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Se restauró su borrador. Para activar el punto, toque Guardar y salir.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: _accentColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fusionarCatalogoEnItems(
    List<Map<String, dynamic>> items,
  ) async {
    final catalogSnap =
        await FirebaseFirestore.instance.collection('productos').get();
    for (final doc in catalogSnap.docs) {
      final data = doc.data();
      final nombre = data['nombre']?.toString().trim();
      if (nombre == null || nombre.isEmpty) continue;

      final catRaw = data['categoria']?.toString() ?? categoriaDefault;
      final cat =
          categoriasProducto.contains(catRaw) ? catRaw : categoriaDefault;
      final precio = (data['precio'] as num?)?.toDouble() ?? 0.0;

      final idx = items.indexWhere((i) => i['productoId'] == doc.id);
      if (idx >= 0) {
        items[idx]['nombre'] = nombre;
        items[idx]['precio'] = precio;
        items[idx]['categoria'] = cat;
      } else {
        items.add(_stockItem(doc.id, nombre, precio, 0, cat, 0));
      }
    }
  }

  bool get _hayProductosPorTraspaso =>
      widget.esIngresoInicial &&
      _items.any((i) => (i['cantidadPorTraspaso'] as int? ?? 0) > 0);

  String get _subtituloEncabezado {
    if (widget.soloLectura) {
      return 'Consulte las cantidades disponibles en su sector';
    }
    if (widget.esIngresoInicial) {
      if (_hayProductosPorTraspaso) {
        return 'Indique la cantidad propia de cada producto; el traspaso se suma solo.';
      }
      return 'Ingrese la cantidad de cada producto del catálogo. '
          'Al terminar use Guardar y salir.';
    }
    return 'Toque el recuadro de cantidad, escriba el número y pulse Guardar';
  }

  String _textoListaEncabezado() {
    if (widget.soloLectura) return _resumenStockLectura();
    if (widget.esIngresoInicial && _hayProductosPorTraspaso) {
      return 'Revise la cantidad de cada ítem. Los productos recibidos por traspaso '
          'ya están en la lista.';
    }
    if (widget.esIngresoInicial) {
      return 'Inventario inicial — complete la cantidad de cada producto';
    }
    return 'Toque el recuadro de cantidad, escriba el número y pulse Guardar';
  }

  String get _textoBannerTraspaso {
    return 'Hay productos recibidos por traspaso. '
        'Toque el recuadro y escriba la cantidad propia: el traspaso se suma solo.';
  }

  String _textoConfirmacionInicial() {
    final traspasoItems = _items
        .where((i) => (i['cantidadPorTraspaso'] as int? ?? 0) > 0)
        .toList();
    final base =
        'Atención: esta es la ÚNICA vez que podrá ingresar stock manualmente para este sector.\n\n'
        'Si necesita agregar stock después, debe hacerlo mediante TRASPASO entre sectores.\n\n';
    if (traspasoItems.isEmpty) {
      return '$base¿Desea guardar y finalizar?';
    }
    final detalle = traspasoItems
        .map((i) {
          final nombre = i['nombre'] as String;
          final traspaso = i['cantidadPorTraspaso'] as int;
          final propio = _cantidadPropioDe(i);
          final total = i['cantidad'] as int;
          return '• $nombre: $propio + $traspaso traspaso = $total u.';
        })
        .join('\n');
    return '$base'
        'Resumen con traspaso sumado automáticamente:\n'
        '$detalle\n\n'
        '¿Desea guardar y finalizar?';
  }

  String _resumenStockLectura() {
    final totalUnidades = _items.fold<int>(
      0,
      (total, item) => total + (item['cantidad'] as int? ?? 0),
    );
    final n = _items.length;
    return '$n producto${n == 1 ? '' : 's'} · $totalUnidades u. en stock';
  }

  Future<bool> _persistirStock() async {
    _leerCantidadesDesdeControllers();
    try {
      final col = FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId)
          .collection('stock');
      final itemsPersistir = _items;
      final batch = FirebaseFirestore.instance.batch();
      for (final item in itemsPersistir) {
        final ref = col.doc(item['productoId'] as String);
        final porTraspaso = item['cantidadPorTraspaso'] as int? ?? 0;
        final propio = _cantidadPropioDe(item);
        batch.set(ref, {
          'productoId': item['productoId'],
          'nombre': item['nombre'],
          'precio': item['precio'],
          'cantidad': item['cantidad'],
          'cantidadInicial': item['cantidad'],
          'cantidadPropio': propio,
          'cantidadPorTraspaso': porTraspaso,
          'categoria': item['categoria'] ?? categoriaDefault,
        });
      }
      final existing = await col.get();
      for (final doc in existing.docs) {
        if (!itemsPersistir.any((i) => i['productoId'] == doc.id)) {
          batch.delete(doc.reference);
        }
      }
      await batch.commit();
      await _sectorRef.set({
        'stockInicialIngresado': true,
        'borradorStockInicial': FieldValue.delete(),
      }, SetOptions(merge: true));
      if (!mounted) return false;
      setState(() => _dirty = false);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _guardarYSalir() async {
    _leerCantidadesDesdeControllers();
    if (widget.esIngresoInicial) {
      if (_items.isEmpty) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No hay productos en el catálogo. El administrador debe cargarlos primero.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    } else if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Agregue al menos un producto antes de finalizar.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (widget.esIngresoInicial) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Finalizar ingreso de stock inicial',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _primaryColor),
          ),
          content: Text(
            _textoConfirmacionInicial(),
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancelar', style: GoogleFonts.poppins(color: _secondaryColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: _primaryColor,
              ),
              child: Text(
                'Guardar y salir',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    } else if (_dirty) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Guardar cambios', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text(
            '¿Desea guardar los cambios antes de salir?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancelar', style: GoogleFonts.poppins(color: _secondaryColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Guardar y salir', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }

    final ok = await _persistirStock();
    if (!ok || !mounted) return;

    widget.onGuardado?.call();
    if (mounted) Navigator.of(context).pop('saved');
  }

  void _agregarItemLocal(String productoId, String nombre, double precio, int cantidad, [String categoria = 'Otros']) {
    setState(() {
      _items.add(_stockItem(productoId, nombre, precio, cantidad, categoriasProducto.contains(categoria) ? categoria : categoriaDefault));
      _items.sort((a, b) {
        final oa = ordenCategoria(a['categoria'] as String);
        final ob = ordenCategoria(b['categoria'] as String);
        if (oa != ob) return oa.compareTo(ob);
        return (a['nombre'] as String).compareTo(b['nombre'] as String);
      });
      _dirty = true;
    });
    _vincularControllers();
    _programarGuardadoBorrador();
  }

  void _actualizarCantidadPropioLocal(String productoId, int cantidadPropio) {
    if (cantidadPropio < 0) return;
    setState(() {
      final i = _items.indexWhere((e) => e['productoId'] == productoId);
      if (i >= 0) {
        final traspaso = _items[i]['cantidadPorTraspaso'] as int? ?? 0;
        _items[i]['cantidadPropio'] = cantidadPropio;
        _items[i]['cantidad'] = cantidadPropio + traspaso;
        _dirty = true;
      }
    });
    _programarGuardadoBorrador();
  }

  void _actualizarCantidadLocal(String productoId, int cantidad) {
    if (cantidad < 0) return;
    final i = _items.indexWhere((e) => e['productoId'] == productoId);
    if (i < 0) return;
    final traspaso = _items[i]['cantidadPorTraspaso'] as int? ?? 0;
    if (widget.esIngresoInicial && traspaso > 0) {
      _actualizarCantidadPropioLocal(productoId, cantidad);
      return;
    }
    setState(() {
      _items[i]['cantidadPropio'] = cantidad;
      _items[i]['cantidadPorTraspaso'] = 0;
      _items[i]['cantidad'] = cantidad;
      _dirty = true;
    });
    _programarGuardadoBorrador();
  }

  Widget _buildEncabezadoSector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: _accentColor.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sector: ${widget.nombreSector}',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _subtituloEncabezado,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: _secondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerTraspaso() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.swap_horiz_rounded, color: Colors.orange[800], size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _textoBannerTraspaso,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _secondaryColor,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoVacio() {
    return Center(
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
            widget.esIngresoInicial
                ? 'No hay productos en el catálogo'
                : 'No hay productos en stock',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: _secondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          if (!widget.soloLectura)
            Text(
              widget.esIngresoInicial
                  ? 'El administrador debe cargar productos antes del evento.'
                  : 'Apriete "+" abajo para agregar productos al stock',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _secondaryColor.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildProductoCard(Map<String, dynamic> item) {
    final productoId = item['productoId'] as String;
    return _ProductoStockCard(
      productoId: productoId,
      nombre: item['nombre'] as String,
      precio: (item['precio'] as num).toDouble(),
      cantidad: item['cantidad'] as int,
      cantidadPropio: _cantidadPropioDe(item),
      cantidadPorTraspaso: item['cantidadPorTraspaso'] as int? ?? 0,
      soloLectura: widget.soloLectura,
      esIngresoInicial: widget.esIngresoInicial,
      cantidadController: widget.soloLectura
          ? null
          : _cantidadControllers[productoId],
      onCantidadChanged: widget.soloLectura
          ? null
          : (n) => _setCantidadItem(productoId, n),
      onEliminar: widget.esIngresoInicial ||
              (item['cantidadPorTraspaso'] as int? ?? 0) > 0
          ? null
          : () => _eliminarItemLocal(productoId),
    );
  }

  Widget _buildCuerpoLista() {
    if (_items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEncabezadoSector(),
          if (_hayProductosPorTraspaso) _buildBannerTraspaso(),
          Expanded(child: _buildEstadoVacio()),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildEncabezadoSector()),
        if (_hayProductosPorTraspaso)
          SliverToBoxAdapter(child: _buildBannerTraspaso()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              _textoListaEncabezado(),
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _secondaryColor.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            widget.soloLectura ? 16 : 88,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildProductoCard(_items[index]),
              childCount: _items.length,
            ),
          ),
        ),
      ],
    );
  }

  void _eliminarItemLocal(String productoId) {
    setState(() {
      _items.removeWhere((e) => e['productoId'] == productoId);
      _dirty = true;
    });
    _cantidadControllers.remove(productoId)?.dispose();
    _programarGuardadoBorrador();
  }

  @override
  Widget build(BuildContext context) {
    final bool popLibre =
        widget.soloLectura || (!widget.esIngresoInicial && !_dirty);

    return PopScope(
      canPop: popLibre,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _retrocederPantalla();
      },
      child: Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        leading: widget.soloLectura
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _retrocederPantalla,
              ),
        title: Text(
          widget.soloLectura ? 'Ver stock' : 'Stock inicial del punto',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: _accentColor,
          ),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: _accentColor,
      ),
      bottomNavigationBar: widget.soloLectura
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _guardarYSalir,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      'Guardar y salir',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _accentColor))
          : _buildCuerpoLista(),
      floatingActionButton: widget.soloLectura || widget.esIngresoInicial
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _mostrarModalAgregarProducto(context),
              backgroundColor: _accentColor,
              foregroundColor: _primaryColor,
              icon: const Icon(Icons.add),
              label: Text(
                'Agregar Producto',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
    ),
    );
  }

  void _mostrarModalAgregarProducto(BuildContext context) {
    final idsEnStock = _items.map((e) => e['productoId'] as String).toSet();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ModalBuscarProducto(
        eventoId: widget.eventoId,
        sectorId: widget.sectorId,
        productIdsEnStock: idsEnStock,
        onAgregarLocal: _agregarItemLocal,
      ),
    );
  }
}

/// Card individual para cada producto en stock
class _ProductoStockCard extends StatelessWidget {
  final String productoId;
  final String nombre;
  final double precio;
  final int cantidad;
  final int cantidadPropio;
  final int cantidadPorTraspaso;
  final bool soloLectura;
  final bool esIngresoInicial;
  final TextEditingController? cantidadController;
  final void Function(int nuevaCantidad)? onCantidadChanged;
  final VoidCallback? onEliminar;

  const _ProductoStockCard({
    required this.productoId,
    required this.nombre,
    required this.precio,
    required this.cantidad,
    required this.cantidadPropio,
    this.cantidadPorTraspaso = 0,
    this.soloLectura = false,
    this.esIngresoInicial = false,
    this.cantidadController,
    this.onCantidadChanged,
    this.onEliminar,
  });

  bool get _sumaTraspaso =>
      esIngresoInicial && cantidadPorTraspaso > 0 && !soloLectura;

  int get _valorEditable =>
      _sumaTraspaso ? cantidadPropio : cantidad;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.fastfood, color: _secondaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _primaryColor,
                        ),
                      ),
                      Text(
                        'Precio: \$${precio.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onEliminar != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onPressed: () => _eliminarProducto(context),
                  ),
              ],
            ),
            if (soloLectura) ...[
              const SizedBox(height: 8),
              Text(
                'Stock: $cantidad u.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cantidad > 0 ? Colors.green[700] : Colors.red[700],
                ),
              ),
              if (esIngresoInicial && cantidadPorTraspaso > 0)
                Text(
                  'Incluye $cantidadPorTraspaso u. por traspaso',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: _secondaryColor,
                  ),
                ),
            ] else ...[
              const SizedBox(height: 10),
              if (_sumaTraspaso)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Traspaso: $cantidadPorTraspaso u. (se suma solo). '
                    'Ingrese la cantidad propia del sector:',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.orange[900],
                      height: 1.3,
                    ),
                  ),
                ),
              Row(
                children: [
                  Text(
                    'Cantidad:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    iconSize: 22,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: _primaryColor,
                    onPressed: _valorEditable > 0
                        ? () => onCantidadChanged?.call(_valorEditable - 1)
                        : null,
                  ),
                  SizedBox(
                    width: 56,
                    child: _CampoCantidadEditable(
                      controller: cantidadController!,
                      onCantidadChanged: onCantidadChanged!,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    iconSize: 22,
                    icon: const Icon(Icons.add_circle_outline),
                    color: _accentColor,
                    onPressed: () =>
                        onCantidadChanged?.call(_valorEditable + 1),
                  ),
                ],
              ),
              if (_sumaTraspaso) ...[
                const SizedBox(height: 6),
                Text(
                  'Total inicial: $cantidad u. '
                  '($_valorEditable + $cantidadPorTraspaso traspaso)',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[800],
                  ),
                ),
              ] else
                Text(
                  'Stock inicial: $cantidad u.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cantidad > 0
                        ? Colors.green[700]
                        : (esIngresoInicial
                            ? _secondaryColor
                            : Colors.red[700]),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _eliminarProducto(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Eliminar Producto',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar "$nombre" del stock?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: _secondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onEliminar?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Eliminar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampoCantidadEditable extends StatefulWidget {
  final TextEditingController controller;
  final void Function(int nuevaCantidad) onCantidadChanged;

  const _CampoCantidadEditable({
    required this.controller,
    required this.onCantidadChanged,
  });

  @override
  State<_CampoCantidadEditable> createState() => _CampoCantidadEditableState();
}

class _CampoCantidadEditableState extends State<_CampoCantidadEditable> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_focusNode.hasFocus || !mounted) return;
        widget.controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.controller.text.length,
        );
      });
      return;
    }
    if (widget.controller.text.trim().isEmpty) {
      widget.controller.text = '0';
      widget.onCantidadChanged(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: _primaryColor,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 8,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onTap: () {
        widget.controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.controller.text.length,
        );
      },
      onChanged: (v) {
        if (v.trim().isEmpty) return;
        final n = int.tryParse(v.trim());
        if (n != null && n >= 0) {
          widget.onCantidadChanged(n);
        }
      },
    );
  }
}

/// Modal para buscar y agregar productos desde la colección global
class _ModalBuscarProducto extends StatefulWidget {
  final String eventoId;
  final String sectorId;
  final Set<String> productIdsEnStock;
  final void Function(String productoId, String nombre, double precio, int cantidad, [String categoria]) onAgregarLocal;

  const _ModalBuscarProducto({
    required this.eventoId,
    required this.sectorId,
    required this.productIdsEnStock,
    required this.onAgregarLocal,
  });

  @override
  State<_ModalBuscarProducto> createState() => _ModalBuscarProductoState();
}

class _ModalBuscarProductoState extends State<_ModalBuscarProducto> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _idsAgregadosEnSesion = {};

  Set<String> get _idsExcluidos => {
        ...widget.productIdsEnStock,
        ..._idsAgregadosEnSesion,
      };

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtrarYOrdenar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final lista = docs.where((doc) {
      if (_idsExcluidos.contains(doc.id)) return false;
      final data = doc.data();
      final nombre = data['nombre']?.toString();
      if (nombre == null || nombre.isEmpty) return false;
      if (query.isEmpty) return true;
      return nombre.toLowerCase().contains(query);
    }).toList();

    lista.sort((a, b) {
      final na = a.data()['nombre']?.toString().toLowerCase() ?? '';
      final nb = b.data()['nombre']?.toString().toLowerCase() ?? '';
      return na.compareTo(nb);
    });
    return lista;
  }

  void _agregarProductoAlStock(
    QueryDocumentSnapshot<Map<String, dynamic>> productoDoc,
  ) {
    final data = productoDoc.data();
    final nombre = data['nombre'] as String? ?? 'Sin nombre';
    final precio = (data['precio'] as num?)?.toDouble() ?? 0.0;
    final categoria = data['categoria']?.toString() ?? categoriaDefault;

    _idsAgregadosEnSesion.add(productoDoc.id);
    widget.onAgregarLocal(productoDoc.id, nombre, precio, 0, categoria);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Buscar Producto',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'La lista se actualiza sola si el admin agrega un producto nuevo.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: _secondaryColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar productos...',
              prefixIcon: Icon(Icons.search, color: _secondaryColor),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreHelpers.streamProductosCatalogo(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error al cargar productos: ${snapshot.error}',
                        style: GoogleFonts.poppins(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: _accentColor),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final filtrados = _filtrarYOrdenar(docs);

                if (filtrados.isEmpty) {
                  return Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? 'No hay productos disponibles para agregar'
                          : 'No se encontraron productos',
                      style: GoogleFonts.poppins(color: _secondaryColor),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtrados.length,
                  itemBuilder: (context, index) {
                    final producto = filtrados[index];
                    final data = producto.data();
                    final nombre = data['nombre'] as String? ?? 'Sin nombre';
                    final precio =
                        (data['precio'] as num?)?.toDouble() ?? 0.0;

                    return ListTile(
                      leading: Icon(Icons.fastfood, color: _secondaryColor),
                      title: Text(
                        nombre,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Precio: \$${precio.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(color: _secondaryColor),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.add_circle, color: _accentColor),
                        onPressed: () => _agregarProductoAlStock(producto),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
