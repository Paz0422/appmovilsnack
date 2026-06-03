import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:front_appsnack/utils/categorias_producto.dart';
import 'package:front_appsnack/services/vendedor_ventas_service.dart';
import 'package:front_appsnack/auth/auth_manager.dart';

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

bool _bandejeroBandejeoCerrado(Map<String, dynamic> data) {
  if (data['bandejeoCerrado'] == true) return true;
  if (data['bandejeoCerradoEn'] != null) return true;
  return data['activo'] == false;
}

class _ResumenBandejeroEnCierre {
  final String nombre;
  final double totalVendido;
  final double porcentajeComision;
  final double comision;
  final double totalAPagar;

  const _ResumenBandejeroEnCierre({
    required this.nombre,
    required this.totalVendido,
    required this.porcentajeComision,
    required this.comision,
    required this.totalAPagar,
  });

  Map<String, dynamic> toFirestore() => {
        'nombre': nombre,
        'totalVendido': totalVendido,
        'porcentajeComision': porcentajeComision,
        'comision': comision,
        'totalAPagar': totalAPagar,
      };

  static _ResumenBandejeroEnCierre? desdeMap(Map<String, dynamic> m) {
    final nombre = m['nombre']?.toString() ??
        m['bandejeroNombre']?.toString();
    if (nombre == null || nombre.isEmpty) return null;
    return _ResumenBandejeroEnCierre(
      nombre: nombre,
      totalVendido: (m['totalVendido'] as num?)?.toDouble() ?? 0,
      porcentajeComision:
          (m['porcentajeComision'] as num?)?.toDouble() ?? 0,
      comision: (m['comision'] as num?)?.toDouble() ?? 0,
      totalAPagar: (m['totalAPagar'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _ResumenCierreTurnoState extends State<ResumenCierreTurno> {
  List<_ProductoConciliacion> _productos = [];
  List<_ResumenBandejeroEnCierre> _bandejerosCierre = [];
  final Map<String, TextEditingController> _cantidadControllers = {};
  double _totalEstimado = 0.0;
  int _totalUnidadesVendidas = 0;
  bool _isLoading = true;
  bool _mostrarResumen = false;
  String? _nombreEvento;
  String? _error;
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
    _nombreEvento = widget.nombreEvento ?? widget.eventoId;
    _cargarDatos();
  }

  @override
  void dispose() {
    _debounceBorrador?.cancel();
    if (!widget.soloVerReporte && _productos.isNotEmpty) {
      _guardarBorradorCierre(enResumen: _mostrarResumen);
    }
    for (final c in _cantidadControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _leerCantidadesDesdeControllers() {
    for (final p in _productos) {
      final ctrl = _cantidadControllers[p.productoId];
      if (ctrl == null) continue;
      final n = int.tryParse(ctrl.text.trim());
      if (n == null) continue;
      p.cantidadFinal = n.clamp(0, p.cantidadMaxima);
    }
  }

  void _aplicarBorradorInventario(
    Map<String, dynamic> borrador,
    List<_ProductoConciliacion> productos,
  ) {
    final items = borrador['productos'] as List<dynamic>? ?? const [];
    final map = <String, int>{};
    for (final item in items.whereType<Map<String, dynamic>>()) {
      final id = item['productoId']?.toString();
      if (id == null || id.isEmpty) continue;
      final cf = item['cantidadFinal'];
      if (cf is num) map[id] = cf.toInt();
    }
    for (final p in productos) {
      final guardado = map[p.productoId];
      if (guardado != null) {
        p.cantidadFinal = guardado.clamp(0, p.cantidadMaxima);
      }
    }
  }

  void _programarGuardadoBorrador({bool enResumen = false}) {
    if (widget.soloVerReporte) return;
    _debounceBorrador?.cancel();
    _debounceBorrador = Timer(const Duration(milliseconds: 700), () {
      _guardarBorradorCierre(enResumen: enResumen);
    });
  }

  Future<void> _retrocederConBorrador() async {
    if (widget.soloVerReporte) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await _guardarBorradorCierre(enResumen: _mostrarResumen);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Borrador guardado. Podés continuar el conteo cuando vuelvas a cerrar turno.',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _guardarBorradorCierre({bool enResumen = false}) async {
    if (widget.soloVerReporte || _productos.isEmpty) return;
    _leerCantidadesDesdeControllers();
    try {
      await _sectorRef.set(
        {
          'borradorCierreTurno': {
            'actualizadoEn': FieldValue.serverTimestamp(),
            'enResumen': enResumen,
            'productos': _productos
                .map(
                  (p) => {
                    'productoId': p.productoId,
                    'cantidadFinal': p.cantidadFinal,
                  },
                )
                .toList(),
          },
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
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
    _programarGuardadoBorrador(enResumen: _mostrarResumen);
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

      var mostrarResumen = widget.soloVerReporte;
      var bandejeros = <_ResumenBandejeroEnCierre>[];
      var total = 0.0;
      var unidades = 0;
      var restauroBorrador = false;

      final borrador = sectorData?['borradorCierreTurno'];
      if (!widget.soloVerReporte &&
          sectorData?['turnoCerrado'] != true &&
          borrador is Map<String, dynamic>) {
        _aplicarBorradorInventario(borrador, productos);
        restauroBorrador = true;
        if (borrador['enResumen'] == true) {
          for (final p in productos) {
            if (p.cantidadVendida > 0) {
              total += p.subtotal;
              unidades += p.cantidadVendida;
            }
          }
          bandejeros = await _cargarBandejerosCerrados();
          mostrarResumen = true;
        }
      }

      if (!mounted) return;
      setState(() {
        _productos = productos;
        _bandejerosCierre = bandejeros;
        _totalEstimado = total;
        _totalUnidadesVendidas = unidades;
        _mostrarResumen = mostrarResumen;
        _isLoading = false;
      });
      _vincularControllers();

      if (restauroBorrador && mounted && !_mostroAvisoBorrador) {
        _mostroAvisoBorrador = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Se restauró el conteo que habías guardado.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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

    final bandejerosRaw = (cierre['bandejeros'] as List<dynamic>?) ?? const [];
    final bandejeros = bandejerosRaw
        .whereType<Map<String, dynamic>>()
        .map(_ResumenBandejeroEnCierre.desdeMap)
        .whereType<_ResumenBandejeroEnCierre>()
        .toList();

    setState(() {
      _productos = productos;
      _bandejerosCierre = bandejeros;
      _totalEstimado = (cierre['totalEstimado'] as num?)?.toDouble() ?? 0.0;
      _totalUnidadesVendidas = (cierre['totalUnidadesVendidas'] as int?) ?? 0;
      _mostrarResumen = true;
      _isLoading = false;
    });
    _vincularControllers();
  }

  CollectionReference<Map<String, dynamic>> get _bandejerosCol =>
      FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId)
          .collection('bandejeros');

  /// Bandejeros que deben cerrar bandejeo antes del cierre de turno del sector.
  Future<String?> _mensajeBandejerosPendientes() async {
    final snap = await _bandejerosCol.get();
    final pendientes = <String>[];

    for (final doc in snap.docs) {
      final data = doc.data();
      if (_bandejeroBandejeoCerrado(data)) continue;

      final nombre = data['nombre']?.toString() ?? 'Bandejero';

      final enCurso = await doc.reference
          .collection('rondas')
          .where('estado', isEqualTo: 'en_curso')
          .limit(1)
          .get();
      if (enCurso.docs.isNotEmpty) {
        pendientes.add('$nombre (ronda en curso)');
        continue;
      }

      if (data['ultimaRondaRendida'] == true) {
        pendientes.add('$nombre (cerrar bandejeo pendiente)');
        continue;
      }

      final rendidas = await doc.reference
          .collection('rondas')
          .where('estado', isEqualTo: 'rendida')
          .limit(1)
          .get();
      if (rendidas.docs.isNotEmpty) {
        pendientes.add('$nombre (cerrar bandejeo pendiente)');
      }
    }

    if (pendientes.isEmpty) return null;
    return 'Antes de cerrar el turno del sector, completá el cierre de bandejeo:\n'
        '• ${pendientes.join('\n• ')}';
  }

  Future<List<_ResumenBandejeroEnCierre>> _cargarBandejerosCerrados() async {
    final snap = await _bandejerosCol.get();
    final lista = <_ResumenBandejeroEnCierre>[];

    for (final doc in snap.docs) {
      final data = doc.data();
      if (!_bandejeroBandejeoCerrado(data)) continue;

      final cierre = data['cierreResumen'];
      if (cierre is! Map<String, dynamic>) continue;

      final nombre = data['nombre']?.toString() ??
          cierre['bandejeroNombre']?.toString() ??
          'Bandejero';
      final item = _ResumenBandejeroEnCierre(
        nombre: nombre,
        totalVendido: (cierre['totalVendido'] as num?)?.toDouble() ?? 0,
        porcentajeComision:
            (cierre['porcentajeComision'] as num?)?.toDouble() ?? 0,
        comision: (cierre['comision'] as num?)?.toDouble() ?? 0,
        totalAPagar: (cierre['totalAPagar'] as num?)?.toDouble() ?? 0,
      );
      lista.add(item);
    }

    lista.sort((a, b) => a.nombre.compareTo(b.nombre));
    return lista;
  }

  Future<void> _guardarYSalirInventarioFinal() async {
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
    await _calcularResumen();
  }

  Future<void> _calcularResumen() async {
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

    final msgBandejeros = await _mensajeBandejerosPendientes();
    if (!mounted) return;
    if (msgBandejeros != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msgBandejeros, style: GoogleFonts.poppins()),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    final bandejeros = await _cargarBandejerosCerrados();
    if (!mounted) return;

    setState(() {
      _totalEstimado = total;
      _totalUnidadesVendidas = unidades;
      _bandejerosCierre = bandejeros;
      _mostrarResumen = true;
    });
    await _guardarBorradorCierre(enResumen: true);
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
    if (_bandejerosCierre.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('───────────────────────────────────────');
      buffer.writeln('BANDEJEROS (CIERRE BANDEJEO)');
      buffer.writeln('───────────────────────────────────────');
      for (final b in _bandejerosCierre) {
        final pct = b.porcentajeComision == b.porcentajeComision.roundToDouble()
            ? b.porcentajeComision.toInt().toString()
            : b.porcentajeComision.toStringAsFixed(1);
        buffer.writeln('• ${b.nombre}');
        buffer.writeln(
          '  Vendido: \$${b.totalVendido.toStringAsFixed(0)} | '
          'Comisión $pct%: \$${b.comision.toStringAsFixed(0)} | '
          'A pagar: \$${b.totalAPagar.toStringAsFixed(0)}',
        );
      }
    }
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
    final msgBandejeros = await _mensajeBandejerosPendientes();
    if (!mounted) return;
    if (msgBandejeros != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msgBandejeros, style: GoogleFonts.poppins()),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_bandejerosCierre.isEmpty) {
        _bandejerosCierre = await _cargarBandejerosCerrados();
      }

      final user = FirebaseAuth.instance.currentUser;
      String? vendedorNombre;
      String? vendedorUid;
      if (user != null) {
        vendedorUid = AuthManager().loggedInVendor?.id ?? user.uid;
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

      final cierreId =
          '${widget.eventoId}_${widget.sectorId}_${DateTime.now().millisecondsSinceEpoch}';

      final cierreData = {
        'cierreId': cierreId,
        'fecha': FieldValue.serverTimestamp(),
        'vendedorNombre': vendedorNombre,
        'vendedorUid': vendedorUid,
        'totalEstimado': _totalEstimado,
        'totalUnidadesVendidas': _totalUnidadesVendidas,
        'productos': productosData,
        'bandejeros': _bandejerosCierre.map((b) => b.toFirestore()).toList(),
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
        'borradorCierreTurno': FieldValue.delete(),
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

      if (vendedorUid != null && vendedorUid.isNotEmpty) {
        try {
          await VendedorVentasService.registrarCierreTurno(
            vendedorUid: vendedorUid,
            cierreId: cierreId,
            monto: _totalEstimado,
            unidades: _totalUnidadesVendidas,
            eventoId: widget.eventoId,
            sectorId: widget.sectorId,
            vendedorNombre: vendedorNombre,
          );
        } catch (_) {
          // El cierre del sector ya quedó guardado; el acumulado se puede reintentar manualmente si falla red.
        }
      }

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
      canPop: widget.soloVerReporte || _bloquearRetrocesoEnResumen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || widget.soloVerReporte || _bloquearRetrocesoEnResumen) {
          return;
        }
        _retrocederConBorrador();
      },
      child: Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _mostrarBotonAtras
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _retrocederConBorrador,
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
          if (_bandejerosCierre.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildBandejerosCard(),
          ],
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

  Widget _buildBandejerosCard() {
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
            'Bandejeros — cierre de bandejeo',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ventas y comisión acordada al cerrar cada bandejero.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 12),
          ..._bandejerosCierre.map((b) {
            final pct =
                b.porcentajeComision == b.porcentajeComision.roundToDouble()
                    ? '${b.porcentajeComision.toInt()}'
                    : b.porcentajeComision.toStringAsFixed(1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.nombre,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Vendido: \$${b.totalVendido.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.secondary,
                      ),
                    ),
                    Text(
                      'Comisión ($pct%): \$${b.comision.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total a pagar: \$${b.totalAPagar.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
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
