import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/services/incidencias_service.dart';
import 'package:front_appsnack/utils/categorias_producto.dart';

/// Error de negocio de un traspaso; [toString] es el mensaje para el usuario.
class TraspasoException implements Exception {
  TraspasoException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Una línea del pedido que se envía.
class LineaEnvio {
  const LineaEnvio({
    required this.productoId,
    required this.nombre,
    required this.precio,
    required this.cantidad,
    this.categoria,
  });

  final String productoId;
  final String nombre;
  final double precio;
  final int cantidad;
  final String? categoria;
}

/// Resultado de confirmar un pedido.
class ResultadoConfirmacion {
  const ResultadoConfirmacion({
    required this.unidadesDevueltas,
    required this.faltanteRegistrado,
  });

  /// Unidades no recibidas que volvieron al stock del origen.
  final int unidadesDevueltas;

  /// Unidades no recibidas cuyo origen ya cerró el turno: no se devolvieron y
  /// quedaron en `eventos/{eventoId}/discrepancias` para el admin.
  final int faltanteRegistrado;
}

/// Envío y confirmación de traspasos entre sectores. Un sector con turno
/// cerrado no puede enviar ni recibir; si un traspaso llega con faltante y su
/// origen ya cerró, el faltante se registra como discrepancia.
class TraspasoService {
  TraspasoService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const mensajeDestinoCerrado = 'El sector destino ya cerró su turno';

  static String mensajeOrigenCerradoEnvio(String origen) =>
      'Su sector ("$origen") ya cerró su turno: no puede enviar traspasos.';

  static String mensajeEnvioADestinoCerrado(String destino) =>
      'No se puede enviar a "$destino": ya cerró su turno.';

  static String mensajeFaltanteRegistrado(int unidades) =>
      'Se registró un faltante de $unidades ${unidades == 1 ? 'unidad' : 'unidades'}. '
      'El administrador lo revisará.';

  CollectionReference<Map<String, dynamic>> _discrepancias(String eventoId) =>
      _db.collection('eventos').doc(eventoId).collection('discrepancias');

  DocumentReference<Map<String, dynamic>> _sector(
    String eventoId,
    String sectorId,
  ) =>
      _db
          .collection('eventos')
          .doc(eventoId)
          .collection('sectores')
          .doc(sectorId);

  static int _int(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static bool _cerrado(DocumentSnapshot<Map<String, dynamic>> snap) =>
      snap.data()?['turnoCerrado'] == true;

  /// Descuenta el stock del origen y deja el pedido pendiente en ambos
  /// sectores. Devuelve el id del pedido.
  Future<String> enviar({
    required String eventoId,
    required String origenId,
    required String origenNombre,
    required String destinoId,
    required String destinoNombre,
    required List<LineaEnvio> lineas,
  }) async {
    if (origenId == destinoId) {
      throw TraspasoException(
        'El sector origen y destino no pueden ser el mismo.',
      );
    }
    final pedidoId = _db.collection('_').doc().id;
    final totalUnidades = lineas.fold<int>(0, (t, l) => t + l.cantidad);
    final origen = _sector(eventoId, origenId);
    final destino = _sector(eventoId, destinoId);

    await _db.runTransaction((tx) async {
      final origenSnap = await tx.get(origen);
      if (!origenSnap.exists) {
        throw TraspasoException('Su sector ya no existe.');
      }
      if (_cerrado(origenSnap)) {
        throw TraspasoException(mensajeOrigenCerradoEnvio(origenNombre));
      }
      final destinoSnap = await tx.get(destino);
      if (!destinoSnap.exists) {
        throw TraspasoException('El sector destino ya no existe.');
      }
      if (_cerrado(destinoSnap)) {
        throw TraspasoException(mensajeEnvioADestinoCerrado(destinoNombre));
      }

      final stocks = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final linea in lineas) {
        final snap = await tx.get(origen.collection('stock').doc(linea.productoId));
        if (!snap.exists) {
          throw TraspasoException('"${linea.nombre}" ya no está en su sector.');
        }
        final stockActual = _int(snap.data()!['cantidad']);
        if (stockActual < linea.cantidad) {
          throw TraspasoException(
            'Stock insuficiente de "${linea.nombre}" (hay $stockActual u.).',
          );
        }
        stocks.add(snap);
      }

      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i];
        final stockSnap = stocks[i];
        tx.update(stockSnap.reference, {
          'cantidad': _int(stockSnap.data()!['cantidad']) - linea.cantidad,
        });

        final traspasoData = {
          'fecha': FieldValue.serverTimestamp(),
          'registradoAt': FieldValue.serverTimestamp(),
          'pedidoId': pedidoId,
          'totalProductosPedido': lineas.length,
          'totalUnidadesPedido': totalUnidades,
          'sectorOrigenId': origenId,
          'sectorOrigenNombre': origenNombre,
          'sectorDestinoId': destinoId,
          'sectorDestinoNombre': destinoNombre,
          'productoId': linea.productoId,
          'nombre': linea.nombre,
          'precio': linea.precio,
          'categoria': linea.categoria ??
              stockSnap.data()!['categoria']?.toString() ??
              categoriaDefault,
          'cantidadEnviada': linea.cantidad,
          'estado': 'pendiente',
        };
        final traspasoId = _db.collection('_').doc().id;
        tx.set(
          destino.collection('traspasos_entrantes').doc(traspasoId),
          traspasoData,
        );
        tx.set(
          origen.collection('traspasos_salientes').doc(traspasoId),
          traspasoData,
        );
      }
    });

    return pedidoId;
  }

  /// Confirma la recepción de las líneas [traspasoIds] de
  /// `sectores/{sectorId}/traspasos_entrantes`. [recibidas] y [comentarios]
  /// van por id de línea. Lo no recibido vuelve al stock del origen, salvo que
  /// el origen haya cerrado su turno: entonces se registra una discrepancia
  /// (id = id del traspaso) a nombre de [vendedorUid].
  Future<ResultadoConfirmacion> confirmarRecepcion({
    required String eventoId,
    required String sectorId,
    required List<String> traspasoIds,
    required Map<String, int> recibidas,
    Map<String, String> comentarios = const {},
    required String vendedorUid,
    String? vendedorNombre,
  }) async {
    final destino = _sector(eventoId, sectorId);

    return _db.runTransaction<ResultadoConfirmacion>((tx) async {
      final destinoSnap = await tx.get(destino);
      if (_cerrado(destinoSnap)) {
        throw TraspasoException(mensajeDestinoCerrado);
      }

      final lineas = <_LineaConfirmacion>[];
      final sectoresOrigen = <String, DocumentSnapshot<Map<String, dynamic>>>{};

      for (final id in traspasoIds) {
        final traspasoRef = destino.collection('traspasos_entrantes').doc(id);
        final traspasoSnap = await tx.get(traspasoRef);
        if (!traspasoSnap.exists) {
          throw TraspasoException('Un ítem del pedido ya no está disponible.');
        }
        final tData = traspasoSnap.data()!;
        if (tData['estado']?.toString() != 'pendiente') {
          throw TraspasoException('Este pedido ya fue procesado.');
        }
        final productoId = tData['productoId']?.toString() ?? '';
        if (productoId.isEmpty) {
          throw TraspasoException('Producto inválido en el pedido.');
        }

        final enviada = _int(tData['cantidadEnviada']);
        final recibida = recibidas[id] ?? enviada;
        final diferencia = enviada - recibida;
        final origenId = tData['sectorOrigenId']?.toString() ?? '';

        DocumentSnapshot<Map<String, dynamic>>? origenStockSnap;
        DocumentSnapshot<Map<String, dynamic>>? salienteSnap;
        var registrarDiscrepancia = false;
        if (origenId.isNotEmpty) {
          final origen = _sector(eventoId, origenId);
          if (diferencia > 0) {
            final origenSnap = sectoresOrigen[origenId] ??= await tx.get(origen);
            if (_cerrado(origenSnap)) {
              // El origen ya cerró: su conteo final es definitivo y no se le
              // devuelve nada. El admin decide qué hacer con el faltante.
              registrarDiscrepancia = true;
            } else {
              origenStockSnap =
                  await tx.get(origen.collection('stock').doc(productoId));
            }
          }
          salienteSnap =
              await tx.get(origen.collection('traspasos_salientes').doc(id));
        }

        lineas.add(_LineaConfirmacion(
          traspasoRef: traspasoRef,
          tData: tData,
          productoId: productoId,
          enviada: enviada,
          recibida: recibida,
          comentario: comentarios[id],
          destinoStockSnap:
              await tx.get(destino.collection('stock').doc(productoId)),
          origenStockSnap: origenStockSnap,
          salienteSnap: salienteSnap,
          discrepanciaRef:
              registrarDiscrepancia ? _discrepancias(eventoId).doc(id) : null,
        ));
      }

      var devueltas = 0;
      var faltante = 0;
      for (final linea in lineas) {
        _aplicar(
          tx,
          eventoId,
          linea,
          vendedorUid: vendedorUid,
          vendedorNombre: vendedorNombre,
        );
        final diferencia = linea.enviada - linea.recibida;
        if (linea.discrepanciaRef != null) {
          faltante += diferencia;
        } else if (linea.origenStockSnap != null) {
          devueltas += diferencia;
        }
      }
      return ResultadoConfirmacion(
        unidadesDevueltas: devueltas,
        faltanteRegistrado: faltante,
      );
    });
  }

  void _aplicar(
    Transaction tx,
    String eventoId,
    _LineaConfirmacion l, {
    required String vendedorUid,
    String? vendedorNombre,
  }) {
    final tData = l.tData;
    final categoria = tData['categoria'] ?? categoriaDefault;

    if (l.recibida > 0) {
      final destStock = l.destinoStockSnap;
      if (destStock.exists) {
        final d = destStock.data()!;
        tx.update(destStock.reference, {
          'cantidad': _int(d['cantidad']) + l.recibida,
          'cantidadPorTraspaso': _int(d['cantidadPorTraspaso']) + l.recibida,
        });
      } else {
        tx.set(destStock.reference, {
          'productoId': l.productoId,
          'nombre': tData['nombre'],
          'precio': tData['precio'],
          'cantidad': l.recibida,
          'cantidadPorTraspaso': l.recibida,
          'cantidadPropio': 0,
          'categoria': categoria,
        });
      }
    }

    final diferencia = l.enviada - l.recibida;
    final origenStock = l.origenStockSnap;
    if (diferencia > 0 && origenStock != null) {
      if (origenStock.exists) {
        tx.update(origenStock.reference, {
          'cantidad': _int(origenStock.data()!['cantidad']) + diferencia,
        });
      } else {
        tx.set(origenStock.reference, {
          'productoId': l.productoId,
          'nombre': tData['nombre'],
          'precio': tData['precio'],
          'cantidad': diferencia,
          'categoria': categoria,
        });
      }
    }

    final confirmacion = <String, dynamic>{
      'estado': 'confirmado',
      'cantidadRecibida': l.recibida,
      'cantidadDiferencia': diferencia,
      'confirmadoAt': FieldValue.serverTimestamp(),
    };
    final comentario = l.comentario?.trim();
    if (diferencia > 0 && comentario != null && comentario.isNotEmpty) {
      confirmacion['comentarioDiferencia'] = comentario;
    }

    final discrepancia = l.discrepanciaRef;
    if (discrepancia != null) {
      confirmacion['discrepanciaId'] = discrepancia.id;
      tx.set(discrepancia, {
        'tipo': TipoIncidencia.faltanteTraspaso,
        'eventoId': eventoId,
        'traspasoId': discrepancia.id,
        'pedidoId': tData['pedidoId'],
        'sectorOrigenId': tData['sectorOrigenId'],
        'sectorOrigenNombre': tData['sectorOrigenNombre'],
        'sectorDestinoId': tData['sectorDestinoId'],
        'sectorDestinoNombre': tData['sectorDestinoNombre'],
        'productoId': l.productoId,
        'nombreProducto': tData['nombre'],
        'cantidadEnviada': l.enviada,
        'cantidadRecibida': l.recibida,
        'diferencia': diferencia,
        if (comentario != null && comentario.isNotEmpty) 'comentario': comentario,
        'vendedorUid': vendedorUid,
        'vendedorNombre': vendedorNombre,
        'fecha': FieldValue.serverTimestamp(),
        'estado': 'pendiente',
      });
    }

    tx.update(l.traspasoRef, confirmacion);

    final saliente = l.salienteSnap;
    if (saliente != null) {
      if (saliente.exists) {
        tx.update(saliente.reference, confirmacion);
      } else {
        tx.set(
          saliente.reference,
          Map<String, dynamic>.from(tData)..addAll(confirmacion),
        );
      }
    }
  }
}

class _LineaConfirmacion {
  const _LineaConfirmacion({
    required this.traspasoRef,
    required this.tData,
    required this.productoId,
    required this.enviada,
    required this.recibida,
    required this.comentario,
    required this.destinoStockSnap,
    required this.origenStockSnap,
    required this.salienteSnap,
    required this.discrepanciaRef,
  });

  final DocumentReference<Map<String, dynamic>> traspasoRef;
  final Map<String, dynamic> tData;
  final String productoId;
  final int enviada;
  final int recibida;
  final String? comentario;
  final DocumentSnapshot<Map<String, dynamic>> destinoStockSnap;
  final DocumentSnapshot<Map<String, dynamic>>? origenStockSnap;
  final DocumentSnapshot<Map<String, dynamic>>? salienteSnap;
  /// Solo si el origen está cerrado y hubo faltante.
  final DocumentReference<Map<String, dynamic>>? discrepanciaRef;
}
