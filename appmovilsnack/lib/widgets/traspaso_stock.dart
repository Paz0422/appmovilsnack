import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/utils/categorias_producto.dart';

class _LineaPedido {
  final String productoId;
  final String nombre;
  final double precio;
  final int stockMax;
  String? categoria;
  int cantidad;

  _LineaPedido({
    required this.productoId,
    required this.nombre,
    required this.precio,
    required this.stockMax,
    required this.cantidad,
    this.categoria,
  });
}

class _LineaEnvioTraspaso {
  final _LineaPedido linea;
  final DocumentReference<Map<String, dynamic>> origenRef;
  final Map<String, dynamic> origenData;
  final int stockActual;
  final String traspasoId;
  final String categoria;

  const _LineaEnvioTraspaso({
    required this.linea,
    required this.origenRef,
    required this.origenData,
    required this.stockActual,
    required this.traspasoId,
    required this.categoria,
  });
}

int _intDesdeFirestore(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

class TraspasoStock extends StatefulWidget {
  final String eventoId;
  final String nombreEvento;
  final String? sectorIdOrigenInicial;
  final String? nombreSectorOrigenInicial;

  const TraspasoStock({
    super.key,
    required this.eventoId,
    required this.nombreEvento,
    this.sectorIdOrigenInicial,
    this.nombreSectorOrigenInicial,
  });

  @override
  State<TraspasoStock> createState() => _TraspasoStockState();
}

class _TraspasoStockState extends State<TraspasoStock> {
  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);
  final Color backgroundColor = const Color(0xFFFDFBF7);

  bool _isLoading = true;
  bool _enviando = false;
  String? _error;

  List<Map<String, dynamic>> _sectores = [];
  String? _sectorOrigenId;
  String? _sectorDestinoId;
  final Map<String, _LineaPedido> _pedido = {};

  bool _sectorEstaCerrado(String? id) {
    if (id == null) return false;
    for (final s in _sectores) {
      if (s['id'] == id) return s['turnoCerrado'] == true;
    }
    return false;
  }

  List<Map<String, dynamic>> _destinosDisponibles() {
    return _sectores
        .where(
          (s) => s['id'] != _sectorOrigenId && s['turnoCerrado'] != true,
        )
        .toList();
  }

  void _syncSectorDestino() {
    final disponibles = _destinosDisponibles();
    if (_sectorDestinoId != null &&
        disponibles.any((s) => s['id'] == _sectorDestinoId)) {
      return;
    }
    _sectorDestinoId = disponibles.firstOrNull?['id'] as String?;
  }

  int get _totalUnidadesPedido =>
      _pedido.values.fold(0, (total, l) => total + l.cantidad);

  @override
  void initState() {
    super.initState();
    _cargarSectores();
  }

  Future<void> _cargarSectores() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .get();

      final sectores = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'nombre': (data['nombre'] as String?) ?? 'Sin Nombre',
          'turnoCerrado': data['turnoCerrado'] == true,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _sectores = sectores;
          _sectorOrigenId = widget.sectorIdOrigenInicial ??
              sectores.firstOrNull?['id'] as String?;
          _syncSectorDestino();
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error cargando sectores: $e';
        });
      }
    }
  }

  void _limpiarPedido() {
    setState(_pedido.clear);
  }

  Future<void> _agregarAlPedido({
    required String productoId,
    required String nombre,
    required double precio,
    required int stockDisponible,
    String? categoria,
  }) async {
    final existente = _pedido[productoId];
    final controller = TextEditingController(
      text: existente != null ? '${existente.cantidad}' : '',
    );

    final cantidad = await showDialog<int?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existente != null ? 'Actualizar cantidad' : 'Agregar al pedido',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nombre,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Disponible: $stockDisponible u.',
                style: GoogleFonts.poppins(fontSize: 13, color: secondaryColor),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Cantidad',
                hintText: 'Ej: 10',
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
                style: GoogleFonts.poppins(color: AppColors.error),
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
              backgroundColor: accentColor,
              foregroundColor: primaryColor,
            ),
          ),
        ],
      ),
    );

    if (cantidad == null || !mounted) return;

    if (cantidad == -1) {
      setState(() => _pedido.remove(productoId));
      _mostrarMensaje('"$nombre" quitado del pedido.');
      return;
    }

    if (cantidad <= 0 || cantidad > stockDisponible) {
      _mostrarMensaje('Cantidad inválida.', esError: true);
      return;
    }

    setState(() {
      _pedido[productoId] = _LineaPedido(
        productoId: productoId,
        nombre: nombre,
        precio: precio,
        stockMax: stockDisponible,
        cantidad: cantidad,
        categoria: categoria,
      );
    });
  }

  Future<void> _mostrarResumenPedido() async {
    if (_pedido.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final lineas = _pedido.values.toList()
          ..sort((a, b) => a.nombre.compareTo(b.nombre));
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
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tu pedido',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: primaryColor,
                ),
              ),
              Text(
                'Hacia: ${_nombreSector(_sectorDestinoId)}',
                style: GoogleFonts.poppins(fontSize: 13, color: secondaryColor),
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
                          color: secondaryColor,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _agregarAlPedido(
                            productoId: l.productoId,
                            nombre: l.nombre,
                            precio: l.precio,
                            stockDisponible: l.stockMax,
                            categoria: l.categoria,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${lineas.length} productos · $_totalUnidadesPedido unidades',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _enviarPedido() async {
    if (_pedido.isEmpty || _enviando) return;

    final origenId = _sectorOrigenId;
    final destinoId = _sectorDestinoId;
    if (origenId == null || destinoId == null) return;
    if (origenId == destinoId) {
      _mostrarMensaje(
        'El sector origen y destino no pueden ser el mismo.',
        esError: true,
      );
      return;
    }

    if (_sectorEstaCerrado(destinoId)) {
      _mostrarMensaje(
        'No podés enviar productos a un sector con turno cerrado. '
        'Un administrador debe reabrirlo desde Gestión de eventos.',
        esError: true,
      );
      return;
    }

    final destinoNombre = _nombreSector(destinoId);
    final origenNombre = _nombreSector(origenId);
    final lineas = _pedido.values.toList();
    final resumen = lineas.map((l) => '• ${l.nombre}: ${l.cantidad} u.').join('\n');

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Enviar pedido?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hacia: $destinoNombre',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: secondaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(resumen, style: GoogleFonts.poppins(height: 1.45)),
              const SizedBox(height: 8),
              Text(
                'Total: ${lineas.length} productos · $_totalUnidadesPedido u.',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: GoogleFonts.poppins()),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(
              'Enviar pedido',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: primaryColor,
            ),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    setState(() => _enviando = true);

    try {
      final pedidoId = FirebaseFirestore.instance.collection('_').doc().id;

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final origenNombreTx = origenNombre;
        final destinoNombreTx = destinoNombre;
        final pendientes = <_LineaEnvioTraspaso>[];

        final destinoSectorRef = FirebaseFirestore.instance
            .collection('eventos')
            .doc(widget.eventoId)
            .collection('sectores')
            .doc(destinoId);
        final destinoSectorSnap = await tx.get(destinoSectorRef);
        if (!destinoSectorSnap.exists) {
          throw Exception('El sector destino ya no existe.');
        }
        if (destinoSectorSnap.data()?['turnoCerrado'] == true) {
          throw Exception(
            'No se puede enviar a "$destinoNombreTx": el turno está cerrado.',
          );
        }

        for (final linea in lineas) {
          final origenRef = FirebaseFirestore.instance
              .collection('eventos')
              .doc(widget.eventoId)
              .collection('sectores')
              .doc(origenId)
              .collection('stock')
              .doc(linea.productoId);

          final origenSnap = await tx.get(origenRef);
          if (!origenSnap.exists) {
            throw Exception('"${linea.nombre}" ya no está en tu sector.');
          }

          final origenData = origenSnap.data()!;
          final stockActual = _intDesdeFirestore(origenData['cantidad']);
          if (stockActual < linea.cantidad) {
            throw Exception(
              'Stock insuficiente de "${linea.nombre}" (hay $stockActual u.).',
            );
          }

          pendientes.add(
            _LineaEnvioTraspaso(
              linea: linea,
              origenRef: origenRef,
              origenData: origenData,
              stockActual: stockActual,
              traspasoId: FirebaseFirestore.instance.collection('_').doc().id,
              categoria:
                  linea.categoria ??
                  origenData['categoria']?.toString() ??
                  categoriaDefault,
            ),
          );
        }

        for (final item in pendientes) {
          final linea = item.linea;
          tx.update(item.origenRef, {
            'cantidad': item.stockActual - linea.cantidad,
          });

          final traspasoData = {
            'fecha': FieldValue.serverTimestamp(),
            'registradoAt': FieldValue.serverTimestamp(),
            'pedidoId': pedidoId,
            'totalProductosPedido': lineas.length,
            'totalUnidadesPedido': _totalUnidadesPedido,
            'sectorOrigenId': origenId,
            'sectorOrigenNombre': origenNombreTx,
            'sectorDestinoId': destinoId,
            'sectorDestinoNombre': destinoNombreTx,
            'productoId': linea.productoId,
            'nombre': linea.nombre,
            'precio': linea.precio,
            'categoria': item.categoria,
            'cantidadEnviada': linea.cantidad,
            'estado': 'pendiente',
          };

          final entranteRef = FirebaseFirestore.instance
              .collection('eventos')
              .doc(widget.eventoId)
              .collection('sectores')
              .doc(destinoId)
              .collection('traspasos_entrantes')
              .doc(item.traspasoId);

          final salienteRef = FirebaseFirestore.instance
              .collection('eventos')
              .doc(widget.eventoId)
              .collection('sectores')
              .doc(origenId)
              .collection('traspasos_salientes')
              .doc(item.traspasoId);

          tx.set(entranteRef, traspasoData);
          tx.set(salienteRef, traspasoData);
        }
      });

      if (!mounted) return;
      setState(() {
        _pedido.clear();
        _enviando = false;
      });
      _mostrarMensaje(
        'Pedido enviado a $destinoNombre (${lineas.length} productos). '
        'Esperá su confirmación.',
      );
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() => _enviando = false);
        _mostrarMensaje(
          'Error al enviar (${e.code}): ${e.message ?? e.toString()}',
          esError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enviando = false);
        _mostrarMensaje('Error al enviar: $e', esError: true);
      }
    }
  }

  void _mostrarMensaje(String msg, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: esError ? Colors.red : AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: esError ? 3 : 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tienePedido = _pedido.isNotEmpty;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Traspaso',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: accentColor,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
        actions: [
          if (tienePedido)
            TextButton(
              onPressed: _limpiarPedido,
              child: Text(
                'Vaciar',
                style: GoogleFonts.poppins(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: GoogleFonts.poppins(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                _buildSelector(),
                Expanded(
                  child: _sectorOrigenId == null
                      ? Center(
                          child: Text(
                            'No hay sector origen disponible.',
                            style: GoogleFonts.poppins(color: secondaryColor),
                          ),
                        )
                      : _ListaStockTraspaso(
                          key: ValueKey(_sectorOrigenId),
                          eventoId: widget.eventoId,
                          sectorOrigenId: _sectorOrigenId!,
                          sectorDestinoNombre: _nombreSector(_sectorDestinoId),
                          pedido: Map.from(_pedido),
                          accentColor: accentColor,
                          primaryColor: primaryColor,
                          secondaryColor: secondaryColor,
                          bottomPadding: tienePedido ? 88 : 16,
                          onAgregar: _agregarAlPedido,
                        ),
                ),
                if (tienePedido) _buildBarraPedido(),
              ],
            ),
    );
  }

  Widget _buildBarraPedido() {
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
                  onTap: _mostrarResumenPedido,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_pedido.length} productos en el pedido',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: primaryColor,
                          ),
                        ),
                        Text(
                          '$_totalUnidadesPedido u. · Tocá para ver',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: (_enviando ||
                        _sectorDestinoId == null ||
                        _sectorEstaCerrado(_sectorDestinoId))
                    ? null
                    : _enviarPedido,
                icon: _enviando
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryColor,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  'Enviar',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: primaryColor,
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

  String _nombreSector(String? id) {
    if (id == null) return '';
    if (id == widget.sectorIdOrigenInicial &&
        (widget.nombreSectorOrigenInicial?.isNotEmpty ?? false)) {
      return widget.nombreSectorOrigenInicial!;
    }
    for (final s in _sectores) {
      if (s['id'] == id) return s['nombre']?.toString() ?? '';
    }
    return '';
  }

  Widget _buildSectorDropdown({
    required String label,
    required String? value,
    required List<Map<String, dynamic>> options,
    required ValueChanged<String?> onChanged,
    bool bloqueado = false,
    bool marcarCerrados = false,
  }) {
    final valorValido = value != null &&
        options.any(
          (s) => s['id'] == value && (!marcarCerrados || s['turnoCerrado'] != true),
        );
    String etiquetaSector(Map<String, dynamic> s) {
      final nombre = s['nombre']?.toString() ?? 'Sin nombre';
      if (marcarCerrados && s['turnoCerrado'] == true) {
        return '$nombre (Turno cerrado)';
      }
      return nombre;
    }

    return DropdownButtonFormField<String>(
      initialValue: valorValido ? value : null,
      isExpanded: true,
      isDense: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: options
          .map(
            (s) => DropdownMenuItem<String>(
              value: s['id']?.toString(),
              enabled: !marcarCerrados || s['turnoCerrado'] != true,
              child: Text(
                etiquetaSector(s),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: marcarCerrados && s['turnoCerrado'] == true
                      ? Colors.grey
                      : null,
                ),
              ),
            ),
          )
          .toList(),
      selectedItemBuilder: (context) => options
          .map(
            (s) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                etiquetaSector(s),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: marcarCerrados && s['turnoCerrado'] == true
                      ? Colors.grey
                      : primaryColor,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: bloqueado ? null : onChanged,
    );
  }

  Widget _buildSelector() {
    final origenNombre = _nombreSector(_sectorOrigenId).isNotEmpty
        ? _nombreSector(_sectorOrigenId)
        : (widget.nombreSectorOrigenInicial ?? 'Tu sector');

    final origenOptions =
        _sectores.where((s) => s['id'] != _sectorDestinoId).toList();
    final destinoOptions =
        _sectores.where((s) => s['id'] != _sectorOrigenId).toList();
    final hayDestinoDisponible = _destinosDisponibles().isNotEmpty;
    final origenFijo = widget.sectorIdOrigenInicial != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.nombreEvento,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: secondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.upload_outlined, size: 20, color: secondaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sector origen (envías desde)',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: secondaryColor,
                        ),
                      ),
                      Text(
                        origenNombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!origenFijo) ...[
            _buildSectorDropdown(
              label: 'Sector origen',
              value: _sectorOrigenId,
              options: origenOptions,
              onChanged: (v) => setState(() {
                _sectorOrigenId = v;
                _pedido.clear();
                _syncSectorDestino();
              }),
            ),
            const SizedBox(height: 10),
          ],
          _buildSectorDropdown(
            label: 'Sector destino (recibe y confirma)',
            value: _sectorDestinoId,
            options: destinoOptions,
            marcarCerrados: true,
            bloqueado: !hayDestinoDisponible,
            onChanged: (v) {
              if (v == null || v == _sectorDestinoId) return;
              if (_sectorEstaCerrado(v)) return;
              setState(() {
                _sectorDestinoId = v;
                _pedido.clear();
              });
            },
          ),
          if (!hayDestinoDisponible) ...[
            const SizedBox(height: 8),
            Text(
              'No hay sectores destino disponibles: todos tienen el turno cerrado.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.error,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Tocá los productos para armar el pedido. '
            'Cuando termines, envialo todo junto.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: secondaryColor.withValues(alpha: 0.9),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

typedef _AgregarPedidoCallback = Future<void> Function({
  required String productoId,
  required String nombre,
  required double precio,
  required int stockDisponible,
  String? categoria,
});

class _ListaStockTraspaso extends StatefulWidget {
  final String eventoId;
  final String sectorOrigenId;
  final String sectorDestinoNombre;
  final Map<String, _LineaPedido> pedido;
  final double bottomPadding;
  final Color accentColor;
  final Color primaryColor;
  final Color secondaryColor;
  final _AgregarPedidoCallback onAgregar;

  const _ListaStockTraspaso({
    super.key,
    required this.eventoId,
    required this.sectorOrigenId,
    required this.sectorDestinoNombre,
    required this.pedido,
    required this.bottomPadding,
    required this.accentColor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onAgregar,
  });

  @override
  State<_ListaStockTraspaso> createState() => _ListaStockTraspasoState();
}

class _ListaStockTraspasoState extends State<_ListaStockTraspaso> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stockStream;

  @override
  void initState() {
    super.initState();
    _stockStream = _crearStream(widget.sectorOrigenId);
  }

  @override
  void didUpdateWidget(covariant _ListaStockTraspaso oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sectorOrigenId != widget.sectorOrigenId) {
      _stockStream = _crearStream(widget.sectorOrigenId);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _crearStream(String sectorId) {
    return FirebaseFirestore.instance
        .collection('eventos')
        .doc(widget.eventoId)
        .collection('sectores')
        .doc(sectorId)
        .collection('stock')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stockStream,
      builder: (context, snapshot) {
        final cargando = snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        if (cargando) {
          return Center(
            child: CircularProgressIndicator(color: widget.accentColor),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error cargando stock: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          );
        }

        final docs = List<DocumentSnapshot<Map<String, dynamic>>>.from(
          snapshot.data?.docs ?? [],
        )..sort((a, b) {
            final an = a.data()?['nombre']?.toString() ?? '';
            final bn = b.data()?['nombre']?.toString() ?? '';
            return an.compareTo(bn);
          });

        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No hay stock en tu sector para traspasar.',
              style: GoogleFonts.poppins(color: widget.secondaryColor),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(16, 16, 16, widget.bottomPadding),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() ?? {};
            final nombre = data['nombre'] as String? ?? 'Sin nombre';
            final precio = (data['precio'] as num?)?.toDouble() ?? 0.0;
            final cantidad = data['cantidad'] as int? ?? 0;
            final categoria = data['categoria']?.toString();
            final enPedido = widget.pedido[doc.id];
            final habilitado = cantidad > 0;
            final destino = widget.sectorDestinoNombre.trim();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: habilitado
                      ? () => widget.onAgregar(
                          productoId: doc.id,
                          nombre: nombre,
                          precio: precio,
                          stockDisponible: cantidad,
                          categoria: categoria,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: enPedido != null
                          ? widget.accentColor.withValues(alpha: 0.08)
                          : AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: enPedido != null
                            ? widget.accentColor.withValues(alpha: 0.55)
                            : habilitado
                            ? AppColors.outline
                            : AppColors.outline.withValues(alpha: 0.6),
                        width: enPedido != null ? 1.5 : 1,
                      ),
                      boxShadow: habilitado ? AppShadows.card : null,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: enPedido != null
                                ? widget.accentColor.withValues(alpha: 0.28)
                                : habilitado
                                ? widget.accentColor.withValues(alpha: 0.16)
                                : AppColors.outline.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            enPedido != null
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            color: habilitado
                                ? widget.secondaryColor
                                : AppColors.onSurfaceVariant,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombre,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: habilitado
                                      ? widget.primaryColor
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Stock: $cantidad  ·  \$${precio.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: widget.secondaryColor,
                                ),
                              ),
                              if (enPedido != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'En pedido: ${enPedido.cantidad} u.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: widget.secondaryColor,
                                  ),
                                ),
                              ] else if (habilitado && destino.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Tocá para agregar al pedido',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: widget.accentColor.withValues(
                                      alpha: 0.95,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          enPedido != null
                              ? Icons.edit_outlined
                              : Icons.chevron_right_rounded,
                          color: habilitado
                              ? widget.secondaryColor
                              : AppColors.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
