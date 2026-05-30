import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:front_appsnack/utils/categorias_producto.dart';

/// Cierre de turno por conciliación de inventario:
/// stock inicial − inventario final = unidades vendidas → dinero estimado.
class ResumenCierreTurno extends StatefulWidget {
  final String eventoId;
  final String sectorId;
  final String nombreSector;
  final String? nombreEvento;
  final bool fromAdmin;
  final bool soloVerReporte;

  const ResumenCierreTurno({
    super.key,
    required this.eventoId,
    required this.sectorId,
    required this.nombreSector,
    this.nombreEvento,
    this.fromAdmin = false,
    this.soloVerReporte = false,
  });

  @override
  State<ResumenCierreTurno> createState() => _ResumenCierreTurnoState();
}

class _ProductoConciliacion {
  final String productoId;
  final String nombre;
  final double precio;
  final String categoria;
  final int cantidadInicial;
  /// Stock disponible al cerrar (inicial + traspasos − mermas, etc.).
  final int cantidadMaxima;
  int cantidadFinal;

  _ProductoConciliacion({
    required this.productoId,
    required this.nombre,
    required this.precio,
    required this.categoria,
    required this.cantidadInicial,
    required this.cantidadMaxima,
    required this.cantidadFinal,
  });

  int get cantidadVendida => cantidadMaxima - cantidadFinal;
  double get subtotal => cantidadVendida > 0 ? cantidadVendida * precio : 0;
  bool get tieneDiscrepancia => cantidadFinal > cantidadMaxima;
  bool get recibioTraspaso => cantidadMaxima > cantidadInicial;
}

String _normalizarCategoria(String? cat) {
  final c = cat?.trim();
  if (c == null || c.isEmpty) return categoriaDefault;
  return categoriasProducto.contains(c) ? c : categoriaDefault;
}

class _ResumenCierreTurnoState extends State<ResumenCierreTurno> {
  List<_ProductoConciliacion> _productos = [];
  final Map<String, TextEditingController> _cantidadControllers = {};
  double _totalEstimado = 0.0;
  int _totalUnidadesVendidas = 0;
  bool _isLoading = true;
  bool _mostrarResumen = false;
  String? _nombreEvento;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombreEvento = widget.nombreEvento ?? widget.eventoId;
    _cargarDatos();
  }

  @override
  void dispose() {
    for (final c in _cantidadControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _vincularControllers() {
    for (final p in _productos) {
      final ctrl = _cantidadControllers.putIfAbsent(
        p.productoId,
        () => TextEditingController(text: '${p.cantidadFinal}'),
      );
      if (ctrl.text != '${p.cantidadFinal}') {
        ctrl.text = '${p.cantidadFinal}';
      }
    }
  }

  void _setCantidadFinal(_ProductoConciliacion p, int value) {
    final clamped = value.clamp(0, p.cantidadMaxima);
    p.cantidadFinal = clamped;
    final ctrl = _cantidadControllers[p.productoId];
    if (ctrl != null && ctrl.text != '$clamped') {
      ctrl.text = '$clamped';
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    }
    setState(() {});
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final sectorSnap = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId)
          .get();

      final sectorData = sectorSnap.data();
      if (widget.soloVerReporte && sectorData?['ultimoCierre'] != null) {
        _cargarDesdeCierreGuardado(sectorData!['ultimoCierre'] as Map<String, dynamic>);
        return;
      }

      final stockSnapshot = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId)
          .collection('stock')
          .get();

      if (!mounted) return;
      if (stockSnapshot.docs.isEmpty) {
        setState(() {
          _error = 'No hay stock inicial cargado en este sector.';
          _isLoading = false;
        });
        return;
      }

      final productos = stockSnapshot.docs.map((doc) {
        final d = doc.data();
        final inicial = (d['cantidadInicial'] as int?) ??
            (d['cantidad'] as int?) ??
            0;
        final maxima = (d['cantidad'] as int?) ?? inicial;
        return _ProductoConciliacion(
          productoId: doc.id,
          nombre: d['nombre']?.toString() ?? 'Sin nombre',
          precio: (d['precio'] as num?)?.toDouble() ?? 0.0,
          categoria: _normalizarCategoria(d['categoria']?.toString()),
          cantidadInicial: inicial,
          cantidadMaxima: maxima,
          cantidadFinal: maxima,
        );
      }).toList()
        ..sort((a, b) => a.nombre.compareTo(b.nombre));

      setState(() {
        _productos = productos;
        _mostrarResumen = widget.soloVerReporte;
        _isLoading = false;
      });
      _vincularControllers();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _cargarDesdeCierreGuardado(Map<String, dynamic> cierre) {
    final items = (cierre['productos'] as List<dynamic>?) ?? [];
    final productos = items.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      return _ProductoConciliacion(
        productoId: m['productoId']?.toString() ?? '',
        nombre: m['nombre']?.toString() ?? 'Sin nombre',
        precio: (m['precio'] as num?)?.toDouble() ?? 0.0,
        categoria: _normalizarCategoria(m['categoria']?.toString()),
        cantidadInicial: (m['cantidadInicial'] as int?) ?? 0,
        cantidadMaxima: (m['cantidadMaxima'] as int?) ??
            (m['cantidadInicial'] as int?) ??
            (m['cantidadFinal'] as int?) ??
            0,
        cantidadFinal: (m['cantidadFinal'] as int?) ?? 0,
      );
    }).toList();

    setState(() {
      _productos = productos;
      _totalEstimado = (cierre['totalEstimado'] as num?)?.toDouble() ?? 0.0;
      _totalUnidadesVendidas = (cierre['totalUnidadesVendidas'] as int?) ?? 0;
      _mostrarResumen = true;
      _isLoading = false;
    });
    _vincularControllers();
  }

  void _guardarYSalirInventarioFinal() {
    for (final p in _productos) {
      if (p.cantidadFinal < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La cantidad final de "${p.nombre}" no puede ser negativa.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (p.cantidadFinal > p.cantidadMaxima) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${p.nombre}": no puede quedar más de ${p.cantidadMaxima} u. '
              '(inicial ${p.cantidadInicial}${p.recibioTraspaso ? ', incluye traspasos' : ''}).',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    _calcularResumen();
  }

  void _calcularResumen() {
    for (final p in _productos) {
      if (p.cantidadFinal < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La cantidad final de "${p.nombre}" no puede ser negativa.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (p.cantidadFinal > p.cantidadMaxima) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${p.nombre}": la cantidad final no puede superar ${p.cantidadMaxima}.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    double total = 0;
    int unidades = 0;
    for (final p in _productos) {
      if (p.cantidadVendida > 0) {
        total += p.subtotal;
        unidades += p.cantidadVendida;
      }
    }

    setState(() {
      _totalEstimado = total;
      _totalUnidadesVendidas = unidades;
      _mostrarResumen = true;
    });
  }

  String _generarTextoExportable() {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('  CIERRE DE TURNO — CONCILIACIÓN INVENTARIO');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('Evento: $_nombreEvento');
    buffer.writeln('Sector: ${widget.nombreSector}');
    buffer.writeln(
      'Fecha: ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
    );
    buffer.writeln(
      'Hora: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    );
    buffer.writeln();
    buffer.writeln('───────────────────────────────────────');
    buffer.writeln('RESUMEN');
    buffer.writeln('───────────────────────────────────────');
    buffer.writeln('Unidades vendidas (estimadas): $_totalUnidadesVendidas');
    buffer.writeln('Dinero estimado del punto: \$${_totalEstimado.toStringAsFixed(0)}');
    buffer.writeln();
    buffer.writeln('───────────────────────────────────────');
    buffer.writeln('DETALLE POR PRODUCTO');
    buffer.writeln('───────────────────────────────────────');
    for (final p in _productos) {
      buffer.writeln('• ${p.nombre}');
      buffer.writeln(
        '  Inicial: ${p.cantidadInicial} | Final: ${p.cantidadFinal} | '
        'Vendido: ${p.cantidadVendida} | Subtotal: \$${p.subtotal.toStringAsFixed(0)}',
      );
    }
    buffer.writeln();
    buffer.writeln('═══════════════════════════════════════');
    return buffer.toString();
  }

  Future<void> _exportarTexto() async {
    try {
      await Share.share(
        _generarTextoExportable(),
        subject: 'Cierre Turno - ${widget.nombreSector}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmarCierre() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? vendedorNombre;
      String? vendedorUid;
      if (user != null) {
        vendedorUid = user.uid;
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .get();
          vendedorNombre = userDoc.data()?['username']?.toString();
        } catch (_) {}
        vendedorNombre ??= user.displayName ?? user.email;
      }

      final productosData = _productos
          .map((p) => {
                'productoId': p.productoId,
                'nombre': p.nombre,
                'precio': p.precio,
                'categoria': p.categoria,
                'cantidadInicial': p.cantidadInicial,
                'cantidadMaxima': p.cantidadMaxima,
                'cantidadFinal': p.cantidadFinal,
                'cantidadVendida': p.cantidadVendida,
                'subtotal': p.subtotal,
              })
          .toList();

      final cierreData = {
        'fecha': FieldValue.serverTimestamp(),
        'vendedorNombre': vendedorNombre,
        'vendedorUid': vendedorUid,
        'totalEstimado': _totalEstimado,
        'totalUnidadesVendidas': _totalUnidadesVendidas,
        'productos': productosData,
      };

      final sectorRef = FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId);

      final sectorSnap = await sectorRef.get();
      final batch = FirebaseFirestore.instance.batch();

      // Actualizar cantidad final en stock
      final stockCol = sectorRef.collection('stock');
      for (final p in _productos) {
        batch.set(
          stockCol.doc(p.productoId),
          {'cantidad': p.cantidadFinal, 'cantidadFinal': p.cantidadFinal},
          SetOptions(merge: true),
        );
      }

      Map<String, dynamic> sectorUpdate = {
        'ultimoCierre': cierreData,
        'turnoCerrado': true,
        'turnoCerradoAt': FieldValue.serverTimestamp(),
        'totalVendido': FieldValue.increment(_totalEstimado),
      };

      if (sectorSnap.exists && sectorSnap.data() != null) {
        final data = sectorSnap.data()!;
        List<dynamic> vendedores = List.from(data['vendedoresasignados'] ?? []);
        if (vendedorNombre != null && vendedorNombre.isNotEmpty) {
          vendedores.removeWhere((v) {
            final n = v is Map ? v['nombre']?.toString() : null;
            return n == vendedorNombre;
          });
        }
        sectorUpdate['vendedoresasignados'] = vendedores;
      }

      batch.set(sectorRef, sectorUpdate, SetOptions(merge: true));
      await batch.commit();

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar turno: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool get _bloquearRetrocesoEnResumen =>
      _mostrarResumen && !widget.soloVerReporte;

  bool get _mostrarBotonAtras =>
      widget.soloVerReporte ||
      (!_mostrarResumen && widget.fromAdmin);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_bloquearRetrocesoEnResumen,
      child: Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _mostrarBotonAtras
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          widget.soloVerReporte
              ? 'Reporte de cierre'
              : _mostrarResumen
                  ? 'Resumen de cierre'
                  : 'Inventario final',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.accent,
        actions: [
          if (widget.fromAdmin && !widget.soloVerReporte && !_mostrarResumen)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          if (_mostrarResumen)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _isLoading ? null : _exportarTexto,
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? _buildError()
              : _mostrarResumen
                  ? _buildResumenView()
                  : _buildInventarioFinalView(),
    ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: GoogleFonts.poppins(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _cargarDatos, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  Widget _buildInventarioFinalView() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppColors.accent.withValues(alpha: 0.15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventario final — ${widget.nombreSector}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ingrese cuántas unidades quedan. No puede superar el stock disponible '
                '(inicial + traspasos − mermas).',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _productos.length,
            itemBuilder: (context, index) {
              final p = _productos[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nombre,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Inicial: ${p.cantidadInicial} · Máximo: ${p.cantidadMaxima}'
                        '${p.recibioTraspaso ? ' (incl. traspaso)' : ''} · '
                        'Precio: \$${p.precio.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'Quedan:',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 34,
                                    minHeight: 34,
                                  ),
                                  iconSize: 22,
                                  icon: const Icon(Icons.remove_circle_outline),
                                  color: AppColors.primaryLight,
                                  onPressed: p.cantidadFinal > 0
                                      ? () => _setCantidadFinal(
                                            p,
                                            p.cantidadFinal - 1,
                                          )
                                      : null,
                                ),
                                SizedBox(
                                  width: 52,
                                  child: TextField(
                                    controller:
                                        _cantidadControllers[p.productoId],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryLight,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onChanged: (v) {
                                      final n = int.tryParse(v.trim());
                                      if (n == null) return;
                                      if (n > p.cantidadMaxima) {
                                        _setCantidadFinal(
                                          p,
                                          p.cantidadMaxima,
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Máximo ${p.cantidadMaxima} u. para "${p.nombre}"',
                                              style: GoogleFonts.poppins(),
                                            ),
                                            backgroundColor: Colors.orange,
                                            duration:
                                                const Duration(seconds: 2),
                                          ),
                                        );
                                      } else {
                                        _setCantidadFinal(p, n);
                                      }
                                    },
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
                                  color: AppColors.primaryLight,
                                  onPressed: p.cantidadFinal < p.cantidadMaxima
                                      ? () => _setCantidadFinal(
                                            p,
                                            p.cantidadFinal + 1,
                                          )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (p.tieneDiscrepancia)
                            Icon(
                              Icons.warning_amber,
                              color: Colors.orange[700],
                              size: 20,
                            )
                          else
                            Text(
                              'Vendido: ${p.cantidadVendida}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _guardarYSalirInventarioFinal,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                'Guardar y salir',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.primaryLight,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResumenView() {
    final hayDiscrepancias = _productos.any((p) => p.tieneDiscrepancia);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 20),
          _buildTotalCard(),
          if (hayDiscrepancias) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[800]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hay productos con inventario final mayor al disponible. '
                      'Revise los conteos antes de confirmar.',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildDetalleCard(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exportarTexto,
              icon: const Icon(Icons.share),
              label: Text(
                'Exportar resumen',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.primaryLight,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (!widget.soloVerReporte) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirmarCierre,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  'Confirmar cierre y volver al inicio',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evento: $_nombreEvento',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sector: ${widget.nombreSector}',
            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.secondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dinero estimado del punto',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${_totalEstimado.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$_totalUnidadesVendidas unidades vendidas (inicial − final)',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detalle por producto',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: 12),
          ..._productos.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.nombre,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              color: AppColors.primaryLight,
                            ),
                          ),
                          Text(
                            'Inicial: ${p.cantidadInicial} → Final: ${p.cantidadFinal}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Vendido: ${p.cantidadVendida}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: p.tieneDiscrepancia ? Colors.orange[800] : AppColors.success,
                          ),
                        ),
                        Text(
                          '\$${p.subtotal.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
