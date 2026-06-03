import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/utils/categorias_producto.dart';

/// Resumen de pedidos/traspasos pendientes de confirmar en un sector.
class ResumenPedidosPendientes {
  final int cantidadPedidos;
  final Set<String> pedidoIds;
  final int totalUnidades;
  final int totalLineas;
  final String? origenReciente;

  const ResumenPedidosPendientes({
    required this.cantidadPedidos,
    required this.pedidoIds,
    required this.totalUnidades,
    required this.totalLineas,
    this.origenReciente,
  });

  static const vacio = ResumenPedidosPendientes(
    cantidadPedidos: 0,
    pedidoIds: {},
    totalUnidades: 0,
    totalLineas: 0,
  );

  factory ResumenPedidosPendientes.fromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return vacio;

    final ids = <String>{};
    var totalUnidades = 0;
    String? origenReciente;
    Timestamp? fechaReciente;

    for (final doc in docs) {
      final d = doc.data();
      final pedidoId = d['pedidoId']?.toString();
      ids.add(
        (pedidoId != null && pedidoId.isNotEmpty) ? pedidoId : doc.id,
      );
      totalUnidades += _intDesdeFirestore(d['cantidadEnviada']);

      final fecha = d['fecha'];
      if (fecha is Timestamp) {
        if (fechaReciente == null || fecha.compareTo(fechaReciente) > 0) {
          fechaReciente = fecha;
          origenReciente = d['sectorOrigenNombre']?.toString();
        }
      } else {
        origenReciente ??= d['sectorOrigenNombre']?.toString();
      }
    }

    return ResumenPedidosPendientes(
      cantidadPedidos: ids.length,
      pedidoIds: ids,
      totalUnidades: totalUnidades,
      totalLineas: docs.length,
      origenReciente: origenReciente,
    );
  }
}

/// Vibración + sonido del sistema al recibir un pedido nuevo.
Future<void> alertarPedidoRecibido({int cantidadNuevos = 1}) async {
  try {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
    if (cantidadNuevos > 1) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await HapticFeedback.lightImpact();
    }
    SystemSound.play(SystemSoundType.alert);
  } catch (_) {
    // En web o dispositivos sin soporte, ignorar silenciosamente.
  }
}

class _GrupoPedido {
  final String id;
  final String origen;
  final List<DocumentSnapshot<Map<String, dynamic>>> lineas;

  _GrupoPedido({
    required this.id,
    required this.origen,
    required this.lineas,
  });

  int get totalEnviado =>
      lineas.fold(0, (s, d) => s + _intDesdeFirestore(d.data()?['cantidadEnviada']));
}

int _intDesdeFirestore(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

class _LineaConfirmacionPendiente {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final Map<String, dynamic> tData;
  final int cantidadEnviada;
  final int cantidadRecibida;
  final String? comentarioDiferencia;
  final String productoId;
  final String origenId;
  final DocumentReference<Map<String, dynamic>> destinoRef;
  final DocumentSnapshot<Map<String, dynamic>> destinoSnap;
  final DocumentSnapshot<Map<String, dynamic>>? origenSnap;
  final DocumentSnapshot<Map<String, dynamic>>? salienteSnap;

  const _LineaConfirmacionPendiente({
    required this.doc,
    required this.tData,
    required this.cantidadEnviada,
    required this.cantidadRecibida,
    this.comentarioDiferencia,
    required this.productoId,
    required this.origenId,
    required this.destinoRef,
    required this.destinoSnap,
    required this.origenSnap,
    required this.salienteSnap,
  });
}

void _aplicarConfirmacionLineaEnTx(
  Transaction tx, {
  required String eventoId,
  required _LineaConfirmacionPendiente linea,
}) {
  final tData = linea.tData;
  final cantidadRecibida = linea.cantidadRecibida;
  final cantidadEnviada = linea.cantidadEnviada;
  final productoId = linea.productoId;
  final traspasoRef = linea.doc.reference;

  if (cantidadRecibida > 0) {
    if (linea.destinoSnap.exists) {
      final destData = linea.destinoSnap.data()!;
      final actual = _intDesdeFirestore(destData['cantidad']);
      final traspasoActual =
          _intDesdeFirestore(destData['cantidadPorTraspaso']);
      tx.update(linea.destinoRef, {
        'cantidad': actual + cantidadRecibida,
        'cantidadPorTraspaso': traspasoActual + cantidadRecibida,
      });
    } else {
      tx.set(linea.destinoRef, {
        'productoId': productoId,
        'nombre': tData['nombre'],
        'precio': tData['precio'],
        'cantidad': cantidadRecibida,
        'cantidadPorTraspaso': cantidadRecibida,
        'cantidadPropio': 0,
        'categoria': tData['categoria'] ?? categoriaDefault,
      });
    }
  }

  final diferencia = cantidadEnviada - cantidadRecibida;
  if (diferencia > 0 && linea.origenId.isNotEmpty) {
    final origenRef = FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .collection('sectores')
        .doc(linea.origenId)
        .collection('stock')
        .doc(productoId);

    if (linea.origenSnap != null && linea.origenSnap!.exists) {
      final origenData = linea.origenSnap!.data()!;
      final actualOrigen = _intDesdeFirestore(origenData['cantidad']);
      tx.update(origenRef, {'cantidad': actualOrigen + diferencia});
    } else {
      tx.set(origenRef, {
        'productoId': productoId,
        'nombre': tData['nombre'],
        'precio': tData['precio'],
        'cantidad': diferencia,
        'categoria': tData['categoria'] ?? categoriaDefault,
      });
    }
  }

  final confirmacion = <String, dynamic>{
    'estado': 'confirmado',
    'cantidadRecibida': cantidadRecibida,
    'cantidadDiferencia': diferencia,
    'confirmadoAt': FieldValue.serverTimestamp(),
  };

  final comentario = linea.comentarioDiferencia?.trim();
  if (diferencia > 0 && comentario != null && comentario.isNotEmpty) {
    confirmacion['comentarioDiferencia'] = comentario;
  }

  tx.update(traspasoRef, confirmacion);

  if (linea.origenId.isNotEmpty) {
    final salienteRef = FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId)
        .collection('sectores')
        .doc(linea.origenId)
        .collection('traspasos_salientes')
        .doc(linea.doc.id);

    if (linea.salienteSnap != null && linea.salienteSnap!.exists) {
      tx.update(salienteRef, confirmacion);
    } else {
      tx.set(
        salienteRef,
        Map<String, dynamic>.from(tData)..addAll(confirmacion),
      );
    }
  }
}

class _ResultadoConfirmacionRecepcion {
  final Map<String, int> recibidas;
  final Map<String, String> comentariosDiferencia;

  const _ResultadoConfirmacionRecepcion({
    required this.recibidas,
    required this.comentariosDiferencia,
  });
}

class _DialogConfirmarRecepcion extends StatefulWidget {
  final _GrupoPedido grupo;
  final Color primaryColor;
  final Color accentColor;
  final Color secondaryColor;

  const _DialogConfirmarRecepcion({
    required this.grupo,
    required this.primaryColor,
    required this.accentColor,
    required this.secondaryColor,
  });

  @override
  State<_DialogConfirmarRecepcion> createState() =>
      _DialogConfirmarRecepcionState();
}

class _DialogConfirmarRecepcionState extends State<_DialogConfirmarRecepcion> {
  late final Map<String, TextEditingController> _cantidadControllers;
  late final Map<String, TextEditingController> _comentarioControllers;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cantidadControllers = {};
    _comentarioControllers = {};
    for (final doc in widget.grupo.lineas) {
      final enviada = _intDesdeFirestore(doc.data()?['cantidadEnviada']);
      final c = TextEditingController(text: '$enviada');
      c.addListener(_actualizarVista);
      _cantidadControllers[doc.id] = c;
      _comentarioControllers[doc.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _cantidadControllers.values) {
      c.dispose();
    }
    for (final c in _comentarioControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _actualizarVista() => setState(() => _error = null);

  int? _cantidadRecibida(String docId) =>
      int.tryParse(_cantidadControllers[docId]!.text.trim());

  bool _requiereComentario(String docId) {
    final doc = widget.grupo.lineas.firstWhere((d) => d.id == docId);
    final enviada = _intDesdeFirestore(doc.data()?['cantidadEnviada']);
    final recibida = _cantidadRecibida(docId);
    return recibida != null && recibida < enviada;
  }

  bool get _hayAlgunaDiferencia =>
      widget.grupo.lineas.any((doc) => _requiereComentario(doc.id));

  void _confirmar() {
    final recibidas = <String, int>{};
    final comentarios = <String, String>{};

    for (final doc in widget.grupo.lineas) {
      final nombre = doc.data()?['nombre']?.toString() ?? 'Producto';
      final enviada = _intDesdeFirestore(doc.data()?['cantidadEnviada']);
      final recibida = _cantidadRecibida(doc.id);

      if (recibida == null || recibida < 0) {
        setState(() => _error = 'Cantidad inválida en "$nombre".');
        return;
      }
      if (recibida > enviada) {
        setState(
          () => _error =
              'No puede recibir más de lo enviado en "$nombre" ($enviada u.).',
        );
        return;
      }

      recibidas[doc.id] = recibida;

      if (recibida < enviada) {
        final comentario = _comentarioControllers[doc.id]!.text.trim();
        if (comentario.length < 3) {
          setState(
            () => _error =
                'Indique por qué recibió menos en "$nombre" (mín. 3 caracteres).',
          );
          return;
        }
        comentarios[doc.id] = comentario;
      }
    }

    Navigator.of(context).pop(
      _ResultadoConfirmacionRecepcion(
        recibidas: recibidas,
        comentariosDiferencia: comentarios,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.grupo.lineas.length == 1
            ? 'Confirmar recepción'
            : 'Confirmar pedido',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Desde: ${widget.grupo.origen}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: widget.secondaryColor,
                ),
              ),
              if (_hayAlgunaDiferencia) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    'Si recibiste menos de lo enviado, debés indicar el motivo.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: widget.secondaryColor,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ...widget.grupo.lineas.map((doc) {
                final d = doc.data()!;
                final nombre = d['nombre']?.toString() ?? 'Producto';
                final enviada = _intDesdeFirestore(d['cantidadEnviada']);
                final pideComentario = _requiereComentario(doc.id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: widget.primaryColor,
                        ),
                      ),
                      Text(
                        'Enviado: $enviada u.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: widget.secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _cantidadControllers[doc.id],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Recibido',
                          helperText: 'Puede ser menor a lo enviado',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      if (pideComentario) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _comentarioControllers[doc.id],
                          maxLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: '¿Por qué recibiste menos?',
                            hintText: 'Ej: faltaron unidades en la caja',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: AppColors.error.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text('Cancelar', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: _confirmar,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.accentColor,
            foregroundColor: widget.primaryColor,
          ),
          child: Text(
            'Confirmar',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

/// Traspasos enviados a este sector que esperan confirmación de recepción.
class ConfirmacionTraspasos extends StatefulWidget {
  final String eventoId;
  final String sectorId;
  final String nombreSector;

  const ConfirmacionTraspasos({
    super.key,
    required this.eventoId,
    required this.sectorId,
    required this.nombreSector,
  });

  @override
  State<ConfirmacionTraspasos> createState() => _ConfirmacionTraspasosState();
}

class _ConfirmacionTraspasosState extends State<ConfirmacionTraspasos> {
  final Color primaryColor = AppColors.primaryLight;
  final Color accentColor = AppColors.accent;
  final Color secondaryColor = AppColors.secondary;

  List<_GrupoPedido> _agruparPedidos(
    List<DocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final map = <String, _GrupoPedido>{};

    for (final doc in docs) {
      final d = doc.data() ?? {};
      final pedidoId = d['pedidoId']?.toString();
      final key = (pedidoId != null && pedidoId.isNotEmpty) ? pedidoId : doc.id;
      final origen = d['sectorOrigenNombre']?.toString() ?? 'Origen';

      map.putIfAbsent(
        key,
        () => _GrupoPedido(id: key, origen: origen, lineas: []),
      );
      map[key]!.lineas.add(doc);
    }

    final grupos = map.values.toList();
    for (final g in grupos) {
      g.lineas.sort(
        (a, b) => (a.data()?['nombre']?.toString() ?? '').compareTo(
          b.data()?['nombre']?.toString() ?? '',
        ),
      );
    }
    grupos.sort((a, b) {
      final af = a.lineas.first.data()?['fecha'];
      final bf = b.lineas.first.data()?['fecha'];
      if (af is Timestamp && bf is Timestamp) {
        return bf.compareTo(af);
      }
      return 0;
    });
    return grupos;
  }

  Future<void> _confirmarPedido(_GrupoPedido grupo) async {
    final resultado = await showDialog<_ResultadoConfirmacionRecepcion?>(
      context: context,
      builder: (ctx) => _DialogConfirmarRecepcion(
        grupo: grupo,
        primaryColor: primaryColor,
        accentColor: accentColor,
        secondaryColor: secondaryColor,
      ),
    );

    if (resultado == null || !mounted) return;

    final recibidas = resultado.recibidas;
    final comentarios = resultado.comentariosDiferencia;

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final pendientes = <_LineaConfirmacionPendiente>[];

        for (final doc in grupo.lineas) {
          final cantidadRecibida = recibidas[doc.id]!;
          final traspasoRef = doc.reference;
          final traspasoSnap = await tx.get(traspasoRef);

          if (!traspasoSnap.exists) {
            throw Exception('Un ítem del pedido ya no está disponible.');
          }

          final tData = traspasoSnap.data()!;
          if (tData['estado']?.toString() != 'pendiente') {
            throw Exception('Este pedido ya fue procesado.');
          }

          final productoId = tData['productoId']?.toString() ?? '';
          if (productoId.isEmpty) {
            throw Exception('Producto inválido en el pedido.');
          }

          final cantidadEnviada = _intDesdeFirestore(tData['cantidadEnviada']);
          final origenId = tData['sectorOrigenId']?.toString() ?? '';

          final destinoRef = FirebaseFirestore.instance
              .collection('eventos')
              .doc(widget.eventoId)
              .collection('sectores')
              .doc(widget.sectorId)
              .collection('stock')
              .doc(productoId);

          final destinoSnap = await tx.get(destinoRef);

          DocumentSnapshot<Map<String, dynamic>>? origenSnap;
          if (cantidadEnviada - cantidadRecibida > 0 && origenId.isNotEmpty) {
            final origenRef = FirebaseFirestore.instance
                .collection('eventos')
                .doc(widget.eventoId)
                .collection('sectores')
                .doc(origenId)
                .collection('stock')
                .doc(productoId);
            origenSnap = await tx.get(origenRef);
          }

          DocumentSnapshot<Map<String, dynamic>>? salienteSnap;
          if (origenId.isNotEmpty) {
            final salienteRef = FirebaseFirestore.instance
                .collection('eventos')
                .doc(widget.eventoId)
                .collection('sectores')
                .doc(origenId)
                .collection('traspasos_salientes')
                .doc(doc.id);
            salienteSnap = await tx.get(salienteRef);
          }

          pendientes.add(
            _LineaConfirmacionPendiente(
              doc: doc,
              tData: tData,
              cantidadEnviada: cantidadEnviada,
              cantidadRecibida: cantidadRecibida,
              comentarioDiferencia: comentarios[doc.id],
              productoId: productoId,
              origenId: origenId,
              destinoRef: destinoRef,
              destinoSnap: destinoSnap,
              origenSnap: origenSnap,
              salienteSnap: salienteSnap,
            ),
          );
        }

        for (final linea in pendientes) {
          _aplicarConfirmacionLineaEnTx(
            tx,
            eventoId: widget.eventoId,
            linea: linea,
          );
        }
      });

      if (!mounted) return;
      final huboDiferencia = grupo.lineas.any((doc) {
        final enviada = _intDesdeFirestore(doc.data()?['cantidadEnviada']);
        return recibidas[doc.id] != enviada;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            huboDiferencia
                ? (grupo.lineas.length == 1
                    ? 'Recepción confirmada con diferencia. '
                        'Lo no recibido volvió al sector origen.'
                    : 'Pedido confirmado con diferencias. '
                        'Lo no recibido volvió al sector origen.')
                : (grupo.lineas.length == 1
                    ? 'Recepción confirmada.'
                    : 'Pedido confirmado (${grupo.lineas.length} productos).'),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (e) {
      _mostrarError(
        'No se pudo confirmar (${e.code}): ${e.message ?? e.toString()}',
      );
    } catch (e) {
      _mostrarError('No se pudo confirmar: $e');
    }
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Pedidos por confirmar',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: accentColor,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: accentColor.withValues(alpha: 0.12),
            child: Text(
              'Sector: ${widget.nombreSector}\n'
              'Recibiste pedidos de otros sectores. '
              'Confirmá cuánto llegó. Si recibiste menos, indicá el motivo.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: secondaryColor,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('eventos')
                  .doc(widget.eventoId)
                  .collection('sectores')
                  .doc(widget.sectorId)
                  .collection('traspasos_entrantes')
                  .where('estado', isEqualTo: 'pendiente')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: accentColor),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: GoogleFonts.poppins(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 56,
                            color: secondaryColor.withValues(alpha: 0.45),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No hay pedidos pendientes',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final grupos = _agruparPedidos(docs);

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: grupos.length,
                  itemBuilder: (context, index) {
                    final grupo = grupos[index];
                    final esPedidoMulti = grupo.lineas.length > 1;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      accentColor.withValues(alpha: 0.2),
                                  child: Icon(
                                    esPedidoMulti
                                        ? Icons.receipt_long_outlined
                                        : Icons.local_shipping_outlined,
                                    color: secondaryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        esPedidoMulti
                                            ? 'Pedido de ${grupo.origen}'
                                            : grupo.lineas.first
                                                      .data()?['nombre']
                                                      ?.toString() ??
                                                  'Producto',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        esPedidoMulti
                                            ? '${grupo.lineas.length} productos · ${grupo.totalEnviado} u.'
                                            : 'Desde ${grupo.origen} · ${grupo.totalEnviado} u.',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: secondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (esPedidoMulti) ...[
                              const SizedBox(height: 12),
                              ...grupo.lineas.map((doc) {
                                final d = doc.data()!;
                                final nombre =
                                    d['nombre']?.toString() ?? 'Producto';
                                final enviada =
                                    _intDesdeFirestore(d['cantidadEnviada']);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '• $nombre — $enviada u.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: secondaryColor,
                                    ),
                                  ),
                                );
                              }),
                            ],
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () => _confirmarPedido(grupo),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                ),
                                child: Text(
                                  esPedidoMulti
                                      ? 'Confirmar pedido'
                                      : 'Confirmar recepción',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
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
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuenta pedidos pendientes (agrupados por pedidoId).
int contarPedidosPendientes(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) =>
    ResumenPedidosPendientes.fromDocs(docs).cantidadPedidos;

/// Notificación destacada cuando hay pedidos de traspaso por confirmar.
class BannerTraspasosPendientes extends StatefulWidget {
  final String eventoId;
  final String sectorId;
  final String nombreSector;
  final ResumenPedidosPendientes resumen;
  final bool habilitado;
  final VoidCallback? onBloqueado;

  const BannerTraspasosPendientes({
    super.key,
    required this.eventoId,
    required this.sectorId,
    required this.nombreSector,
    required this.resumen,
    this.habilitado = true,
    this.onBloqueado,
  });

  @override
  State<BannerTraspasosPendientes> createState() =>
      _BannerTraspasosPendientesState();
}

class _BannerTraspasosPendientesState extends State<BannerTraspasosPendientes> {
  Set<String> _pedidosConocidos = {};
  bool _listoParaAlertar = false;
  int _pulso = 0;

  @override
  void initState() {
    super.initState();
    _pedidosConocidos = Set<String>.from(widget.resumen.pedidoIds);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _listoParaAlertar = true;
    });
  }

  @override
  void didUpdateWidget(covariant BannerTraspasosPendientes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_listoParaAlertar) {
      _pedidosConocidos = Set<String>.from(widget.resumen.pedidoIds);
      return;
    }

    final actuales = widget.resumen.pedidoIds;
    final nuevos = actuales.difference(_pedidosConocidos);
    if (nuevos.isNotEmpty) {
      alertarPedidoRecibido(cantidadNuevos: nuevos.length);
      setState(() => _pulso++);
    }
    _pedidosConocidos = Set<String>.from(actuales);
  }

  void _abrirConfirmacion() {
    if (!widget.habilitado) {
      widget.onBloqueado?.call();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmacionTraspasos(
          eventoId: widget.eventoId,
          sectorId: widget.sectorId,
          nombreSector: widget.nombreSector,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.resumen.cantidadPedidos;
    final origen = widget.resumen.origenReciente?.trim();
    final unidades = widget.resumen.totalUnidades;

    return Opacity(
      opacity: widget.habilitado ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _abrirConfirmacion,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.55),
              width: 1.2,
            ),
            boxShadow: AppShadows.card,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg - 1),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    color: AppColors.accent,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            key: ValueKey(_pulso),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.notifications_active_rounded,
                              color: AppColors.secondary,
                              size: 22,
                            ),
                          )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scale(
                                begin: const Offset(1, 1),
                                end: const Offset(1.06, 1.06),
                                duration: 900.ms,
                                curve: Curves.easeInOut,
                              ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  n == 1
                                      ? 'Pedido recibido'
                                      : 'Pedidos recibidos',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.primaryLight,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  n == 1
                                      ? 'Confirmá la recepción'
                                      : '$n pedidos por confirmar'
                                      '${unidades > 0 ? ' · $unidades u.' : ''}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                    height: 1.25,
                                  ),
                                ),
                                if (origen != null && origen.isNotEmpty)
                                  Text(
                                    'Desde $origen',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _BadgeContadorPedidos(cantidad: n),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.secondary,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    )
        .animate()
        .fadeIn(duration: 300.ms, curve: Curves.easeOut)
        .slideY(begin: -0.05, end: 0, duration: 350.ms, curve: Curves.easeOut);
  }
}

/// Badge circular para cantidad de pedidos (centrado visual con Poppins).
class _BadgeContadorPedidos extends StatelessWidget {
  final int cantidad;

  const _BadgeContadorPedidos({required this.cantidad});

  static const _tam = 22.0;
  static const _fontSize = 11.0;

  @override
  Widget build(BuildContext context) {
    final texto = '$cantidad';
    final unDigito = cantidad < 10;
    // Poppins: el "1" queda ópticamente arriba/izquierda en círculos chicos.
    final ajusteOptico = cantidad == 1
        ? const Offset(0.5, 1.0)
        : Offset.zero;

    return Container(
      width: unDigito ? _tam : null,
      height: _tam,
      constraints: unDigito ? null : const BoxConstraints(minWidth: _tam),
      padding: unDigito ? null : const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.22),
        shape: unDigito ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: unDigito ? null : BorderRadius.circular(_tam / 2),
      ),
      child: Transform.translate(
        offset: ajusteOptico,
        child: SizedBox(
          height: _fontSize,
          child: Text(
            texto,
            textAlign: TextAlign.center,
            strutStyle: const StrutStyle(
              fontSize: _fontSize,
              height: 1,
              leading: 0,
              forceStrutHeight: true,
            ),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: _fontSize,
              height: 1,
              letterSpacing: 0,
              color: AppColors.secondary,
            ),
          ),
        ),
      ),
    );
  }
}
