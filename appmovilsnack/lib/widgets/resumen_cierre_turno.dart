import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:front_appsnack/utils/categorias_producto.dart';
import 'package:front_appsnack/services/cierre_turno_service.dart';
import 'package:front_appsnack/services/vendedor_ventas_service.dart';
import 'package:front_appsnack/auth/auth_manager.dart';
import 'package:front_appsnack/core/margen_inferior.dart';

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
  /// Stock del sistema al abrir el conteo (inicial + traspasos − mermas, etc.).
  /// Se puede contar más: el exceso es sobrante, no venta.
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

  /// Con sobrante las ventas son 0, nunca negativas: no restan del total ni
  /// del ranking.
  int get cantidadVendida => CierreTurnoService.unidadesVendidas(
        stockSistema: cantidadMaxima,
        contado: cantidadFinal,
      );
  double get subtotal => cantidadVendida > 0 ? cantidadVendida * precio : 0;
  int get sobrante => CierreTurnoService.sobrante(
        stockSistema: cantidadMaxima,
        contado: cantidadFinal,
      );
  bool get tieneSobrante => sobrante > 0;
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

({double monto, int unidades}) _totalesVenta(
  Iterable<_ProductoConciliacion> productos,
) =>
    CierreTurnoService.totalesVenta(productos.map((p) => (
          stockSistema: p.cantidadMaxima,
          contado: p.cantidadFinal,
          precio: p.precio,
        )));

class _ResumenBandejeroEnCierre {
  final String nombre;
  final double totalVendido;
  final double porcentajeComision;
  final double comision;
  final double cajaVuelto;
  final double totalARecibir;

  const _ResumenBandejeroEnCierre({
    required this.nombre,
    required this.totalVendido,
    required this.porcentajeComision,
    required this.comision,
    this.cajaVuelto = 0,
    required this.totalARecibir,
  });

  Map<String, dynamic> toFirestore() => {
        'nombre': nombre,
        'totalVendido': totalVendido,
        'porcentajeComision': porcentajeComision,
        'comision': comision,
        'cajaVuelto': cajaVuelto,
        'totalARecibir': totalARecibir,
      };

  static double _totalARecibirDesdeCierre(Map<String, dynamic> cierre) {
    final directo = (cierre['totalARecibir'] as num?)?.toDouble();
    if (directo != null) return directo;
    final vendido = (cierre['totalVendido'] as num?)?.toDouble() ?? 0;
    final caja = (cierre['cajaVuelto'] as num?)?.toDouble() ?? 0;
    return vendido + caja;
  }

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
      cajaVuelto: (m['cajaVuelto'] as num?)?.toDouble() ?? 0,
      totalARecibir: _totalARecibirDesdeCierre(m),
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

  final _cierreService = CierreTurnoService();
  /// Stock de cada producto al abrir el conteo. El cierre solo se escribe si
  /// sigue igual; se guarda en el borrador para detectar cambios al volver.
  Map<String, int> _stockAlIniciar = {};
  /// Productos cuyo stock cambió durante el conteo: hay que volver a contarlos.
  Set<String> _productosCambiados = {};
  /// Traspasos entrantes sin confirmar y rondas abiertas: bloquean el conteo.
  List<String> _movimientosPendientes = [];
  /// Conteo con sobrante ya confirmado por el vendedor ({productoId: contado}),
  /// para no volver a preguntar si no lo cambia.
  final Map<String, int> _sobrantesConfirmados = {};

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
      p.cantidadFinal = n < 0 ? 0 : n;
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
        p.cantidadFinal = guardado < 0 ? 0 : guardado;
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
    if (widget.soloVerReporte || _productos.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await _guardarBorradorCierre(enResumen: _mostrarResumen);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Borrador guardado. Puede continuar el conteo cuando vuelva a cerrar turno.',
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
            'stockAlIniciar': _stockAlIniciar,
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
    final clamped = value < 0 ? 0 : value;
    p.cantidadFinal = clamped;
    _productosCambiados.remove(p.productoId);
    final ctrl = _cantidadControllers[p.productoId];
    if (ctrl != null && ctrl.text != '$clamped') {
      ctrl.text = '$clamped';
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    }
    setState(() {});
    _programarGuardadoBorrador(enResumen: _mostrarResumen);
  }

  /// [cambiadosAlCerrar]: productos que el cierre detectó modificados.
  Future<void> _cargarDatos({Set<String> cambiadosAlCerrar = const {}}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _movimientosPendientes = [];
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

      if (!widget.soloVerReporte) {
        final pendientes = await _cierreService.movimientosPendientes(
          widget.eventoId,
          widget.sectorId,
        );
        if (!mounted) return;
        if (pendientes.isNotEmpty) {
          setState(() {
            _movimientosPendientes = pendientes;
            _productos = [];
            _mostrarResumen = false;
            _isLoading = false;
          });
          return;
        }
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

      // Sector reabierto: el turno empezó con el conteo del cierre anterior,
      // no con el stock inicial original. Las ventas siempre salen del stock
      // actual (cantidad) menos lo contado; esto solo corrige el "Inicial".
      final inicioTurno = CierreTurnoService.inicioDelTurno(sectorData);
      final productos = stockSnapshot.docs.map((doc) {
        final d = doc.data();
        final inicial = inicioTurno != null
            ? (inicioTurno[doc.id] ?? 0)
            : (d['cantidadInicial'] as int?) ?? (d['cantidad'] as int?) ?? 0;
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

      final stockActual = {
        for (final doc in stockSnapshot.docs)
          doc.id: CierreTurnoService.cantidadDe(doc.data()),
      };
      final cambiados = {...cambiadosAlCerrar};

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
        // Stock movido desde que se empezó este conteo (p. ej. salió y volvió).
        final previo = borrador['stockAlIniciar'];
        if (previo is Map) {
          cambiados.addAll(CierreTurnoService.productosCambiados(
            {
              for (final e in previo.entries)
                if (e.value is num) e.key.toString(): (e.value as num).toInt(),
            },
            stockActual,
          ));
        }
        if (borrador['enResumen'] == true && cambiados.isEmpty) {
          final totales = _totalesVenta(productos);
          total = totales.monto;
          unidades = totales.unidades;
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
        _stockAlIniciar = stockActual;
        _productosCambiados = cambiados.intersection(stockActual.keys.toSet());
        _isLoading = false;
      });
      _vincularControllers();

      if (cambiados.isNotEmpty && mounted) {
        _mostroAvisoBorrador = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              CierreTurnoService.mensajeStockCambio,
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange[800],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
          ),
        );
      } else if (restauroBorrador && mounted && !_mostroAvisoBorrador) {
        _mostroAvisoBorrador = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Se restauró el conteo guardado anteriormente.',
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
    return 'Antes de cerrar el turno del sector, complete el cierre de bandejeo:\n'
        '• ${pendientes.join('\n• ')}';
  }

  /// Revisa de nuevo antes de pasar al resumen y antes de cerrar: pudo llegar
  /// un traspaso o abrirse una ronda después de empezar el conteo.
  Future<bool> _verificarSinPendientes() async {
    final movimientos = await _cierreService.movimientosPendientes(
      widget.eventoId,
      widget.sectorId,
    );
    if (!mounted) return false;
    if (movimientos.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'No se puede cerrar todavía',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Hay movimientos pendientes que cambian el stock del sector:\n'
            '• ${movimientos.join('\n• ')}\n\n'
            'Resuélvalos y vuelva a revisar el conteo.',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return false;
    }

    final msgBandejeros = await _mensajeBandejerosPendientes();
    if (!mounted) return false;
    if (msgBandejeros != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msgBandejeros, style: GoogleFonts.poppins()),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 6),
        ),
      );
      return false;
    }
    return true;
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
        cajaVuelto: (cierre['cajaVuelto'] as num?)?.toDouble() ?? 0,
        totalARecibir: _ResumenBandejeroEnCierre._totalARecibirDesdeCierre(cierre),
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
    }
    for (final p in _productos) {
      if (!p.tieneSobrante ||
          _sobrantesConfirmados[p.productoId] == p.cantidadFinal) {
        continue;
      }
      if (!await _confirmarSobrante(p)) return;
      _sobrantesConfirmados[p.productoId] = p.cantidadFinal;
    }
    await _calcularResumen();
  }

  Future<bool> _confirmarSobrante(_ProductoConciliacion p) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          p.nombre,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Está contando ${p.sobrante} más de lo registrado. ¿Confirma?\n\n'
          'Sistema: ${p.cantidadMaxima} · Contado: ${p.cantidadFinal}. '
          'El sobrante se registrará para que el administrador lo revise.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Corregir'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return confirmado == true;
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
    }

    final totales = _totalesVenta(_productos);
    final total = totales.monto;
    final unidades = totales.unidades;

    if (!await _verificarSinPendientes()) return;

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
          'Caja vuelto: \$${b.cajaVuelto.toStringAsFixed(0)} | '
          'A recibir: \$${b.totalARecibir.toStringAsFixed(0)} | '
          'Comisión al cierre $pct%: \$${b.comision.toStringAsFixed(0)}',
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
        'Vendido: ${p.cantidadVendida} | Subtotal: \$${p.subtotal.toStringAsFixed(0)}'
        '${p.tieneSobrante ? ' | Sobrante: ${p.sobrante}' : ''}',
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
    if (!await _verificarSinPendientes()) return;

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
                if (p.tieneSobrante) 'sobrante': p.sobrante,
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

      // El conteo físico reemplaza el stock solo si nadie lo movió mientras
      // se contaba; si cambió, no se escribe nada y se vuelve a contar.
      final cambiados = await _cierreService.cerrarTurno(
        eventoId: widget.eventoId,
        sectorId: widget.sectorId,
        stockAlIniciar: _stockAlIniciar,
        conteoFinal: {for (final p in _productos) p.productoId: p.cantidadFinal},
        cierreData: cierreData,
        totalEstimado: _totalEstimado,
        // Las incidencias de sobrante van a nombre del uid de Auth (reglas).
        vendedorUid: user?.uid ?? '',
        vendedorNombre: vendedorNombre,
        sectorNombre: widget.nombreSector,
        nombresProductos: {for (final p in _productos) p.productoId: p.nombre},
      );
      if (cambiados.isNotEmpty) {
        if (!mounted) return;
        _mostrarResumen = false;
        await _guardarBorradorCierre();
        if (!mounted) return;
        await _cargarDatos(cambiadosAlCerrar: cambiados);
        return;
      }

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

      await AuthManager().cerrarSesion();
    } on TurnoYaCerradoException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
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
              : _movimientosPendientes.isNotEmpty
                  ? _buildMovimientosPendientes()
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

  Widget _buildMovimientosPendientes() {
    return SingleChildScrollView(
      padding: conMargenInferior(context, const EdgeInsets.all(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.pending_actions, size: 48, color: Colors.orange[800]),
          const SizedBox(height: 12),
          Text(
            'Antes de contar, resuelva estos movimientos',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cambian el stock del sector, así que el conteo quedaría '
            'desactualizado. Confirme los traspasos desde el aviso de pedidos '
            'pendientes en el inicio y rinda las rondas en Bandejeo.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.secondary),
          ),
          const SizedBox(height: 16),
          ..._movimientosPendientes.map(
            (m) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.warning_amber, color: Colors.orange[800]),
                title: Text(m, style: GoogleFonts.poppins(fontSize: 14)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh),
            label: const Text('Revisar de nuevo'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Volver'),
          ),
        ],
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
                'Ingrese cuántas unidades quedan. Si cuenta más que el stock del '
                'sistema, se registrará como sobrante para el administrador.',
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
              final cambio = _productosCambiados.contains(p.productoId);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: cambio
                      ? BorderSide(color: Colors.orange[800]!, width: 2)
                      : BorderSide.none,
                ),
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
                      if (cambio) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.sync_problem,
                              size: 16,
                              color: Colors.orange[800],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'El stock cambió: vuelva a contar',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Inicial: ${p.cantidadInicial} · Sistema: ${p.cantidadMaxima}'
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
                                      _setCantidadFinal(p, n);
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
                                  onPressed: () => _setCantidadFinal(
                                    p,
                                    p.cantidadFinal + 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (p.tieneSobrante)
                            Text(
                              'Sobrante: +${p.sobrante}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[800],
                              ),
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
          padding: conMargenInferior(context, const EdgeInsets.all(16)),
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
    final hayDiscrepancias = _productos.any((p) => p.tieneSobrante);
    return SingleChildScrollView(
      padding: conMargenInferior(context, const EdgeInsets.all(16)),
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
                      'Hay productos con sobrante (se contó más que el stock del '
                      'sistema). Sus ventas quedan en 0 y el sobrante se registrará '
                      'para que el administrador lo revise.',
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
            'Ventas y comisión registrada al cerrar cada bandejero.',
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
                      'Caja para vuelto: \$${b.cajaVuelto.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.secondary,
                      ),
                    ),
                    Text(
                      'Comisión al cierre: \$${b.comision.toStringAsFixed(0)} ($pct%)',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total a recibir: \$${b.totalARecibir.toStringAsFixed(0)}',
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
                            'Inicial: ${p.cantidadInicial} → Final: ${p.cantidadFinal}'
                            '${p.tieneSobrante ? ' (sobrante +${p.sobrante})' : ''}',
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
                            color: p.tieneSobrante ? Colors.orange[800] : AppColors.success,
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
