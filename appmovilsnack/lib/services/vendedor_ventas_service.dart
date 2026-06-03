import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/auth/auth_manager.dart';

/// Acumula ventas por usuario (cierres de turno del punto) para ranking anual.
class VendedorVentasService {
  VendedorVentasService._();

  static final _db = FirebaseFirestore.instance;

  /// Firestore devuelve `Map<dynamic, dynamic>`, no `Map<String, dynamic>`.
  static Map<String, dynamic>? _mapFirestore(dynamic raw) {
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  static VentasAnioResumen _leerVentasAnio(
    Map<String, dynamic> data,
    int anioConsulta,
  ) {
    final ventas = _mapFirestore(data['ventasAcumuladas']);
    if (ventas == null) {
      return const VentasAnioResumen(
        monto: 0,
        unidades: 0,
        cierres: 0,
        anioDatos: 0,
      );
    }
    final anioDatos = (ventas['anio'] as num?)?.toInt() ?? 0;
    if (anioDatos != anioConsulta) {
      return VentasAnioResumen(
        monto: 0,
        unidades: 0,
        cierres: 0,
        anioDatos: anioDatos,
      );
    }
    return VentasAnioResumen(
      monto: (ventas['monto'] as num?)?.toDouble() ?? 0,
      unidades: (ventas['unidades'] as num?)?.toInt() ?? 0,
      cierres: (ventas['cierres'] as num?)?.toInt() ?? 0,
      anioDatos: anioDatos,
    );
  }

  /// Registra un cierre de turno en el perfil del vendedor (idempotente por [cierreId]).
  static Future<void> registrarCierreTurno({
    required String vendedorUid,
    required String cierreId,
    required double monto,
    required int unidades,
    String? eventoId,
    String? sectorId,
    String? vendedorNombre,
  }) async {
    if (vendedorUid.isEmpty || cierreId.isEmpty) return;
    if (monto < 0 || unidades < 0) return;

    final anio = DateTime.now().year;
    final usuarioRef = _db.collection('usuarios').doc(vendedorUid);
    final contabRef =
        usuarioRef.collection('cierres_contabilizados').doc(cierreId);

    await _db.runTransaction((tx) async {
      final contabSnap = await tx.get(contabRef);
      if (contabSnap.exists) return;

      final userSnap = await tx.get(usuarioRef);
      final data = userSnap.data() ?? <String, dynamic>{};

      final ventasPrev = _mapFirestore(data['ventasAcumuladas']) ?? {};

      final anioGuardado = (ventasPrev['anio'] as num?)?.toInt() ?? anio;
      var montoAnio = (ventasPrev['monto'] as num?)?.toDouble() ?? 0.0;
      var unidadesAnio = (ventasPrev['unidades'] as num?)?.toInt() ?? 0;
      var cierresAnio = (ventasPrev['cierres'] as num?)?.toInt() ?? 0;

      if (anioGuardado != anio) {
        montoAnio = 0;
        unidadesAnio = 0;
        cierresAnio = 0;
      }

      montoAnio += monto;
      unidadesAnio += unidades;
      cierresAnio += 1;

      final totalVida = (data['totalvendido'] as num?)?.toDouble() ?? 0.0;
      final itemsVida = (data['itemsvendidos'] as num?)?.toInt() ?? 0;

      tx.set(contabRef, {
        'cierreId': cierreId,
        'monto': monto,
        'unidades': unidades,
        'anio': anio,
        'fecha': FieldValue.serverTimestamp(),
        if (eventoId != null) 'eventoId': eventoId,
        if (sectorId != null) 'sectorId': sectorId,
        if (vendedorNombre != null) 'vendedorNombre': vendedorNombre,
        'tipo': 'cierre_turno',
      });

      tx.set(
        usuarioRef,
        {
          'ventasAcumuladas': {
            'anio': anio,
            'monto': montoAnio,
            'unidades': unidadesAnio,
            'cierres': cierresAnio,
            'actualizadoEn': FieldValue.serverTimestamp(),
          },
          'totalvendido': totalVida + monto,
          'itemsvendidos': itemsVida + unidades,
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Ranking de vendedores (rol distinto de admin) por monto del año indicado.
  static Future<List<RankingVendedor>> cargarRanking({int? anio}) async {
    final anioConsulta = anio ?? DateTime.now().year;
    final snap = await _db.collection('usuarios').get();
    final lista = <RankingVendedor>[];

    for (final doc in snap.docs) {
      final data = doc.data();
      final rol = AuthManager.normalizarRol(data['rol']?.toString());

      final nombre = data['username']?.toString().trim().isNotEmpty == true
          ? data['username'].toString()
          : data['email']?.toString() ?? doc.id;

      final resumenAnio = _leerVentasAnio(data, anioConsulta);
      final monto = resumenAnio.monto;
      final unidades = resumenAnio.unidades;
      final cierres = resumenAnio.cierres;

      // No listar admins sin ventas en el año; sí si tienen cierres registrados.
      if (AuthManager.esAdmin(rol) && monto <= 0 && cierres <= 0) continue;

      final totalHistorico = (data['totalvendido'] as num?)?.toDouble() ?? 0;

      lista.add(
        RankingVendedor(
          uid: doc.id,
          nombre: nombre,
          montoAnio: monto,
          unidadesAnio: unidades,
          cierresAnio: cierres,
          totalHistorico: totalHistorico,
          anio: anioConsulta,
        ),
      );
    }

    lista.sort((a, b) {
      final cmp = b.montoAnio.compareTo(a.montoAnio);
      if (cmp != 0) return cmp;
      return b.unidadesAnio.compareTo(a.unidadesAnio);
    });
    return lista;
  }
}

class VentasAnioResumen {
  final double monto;
  final int unidades;
  final int cierres;
  final int anioDatos;

  const VentasAnioResumen({
    required this.monto,
    required this.unidades,
    required this.cierres,
    required this.anioDatos,
  });
}

class RankingVendedor {
  final String uid;
  final String nombre;
  final double montoAnio;
  final int unidadesAnio;
  final int cierresAnio;
  final double totalHistorico;
  final int anio;

  const RankingVendedor({
    required this.uid,
    required this.nombre,
    required this.montoAnio,
    required this.unidadesAnio,
    required this.cierresAnio,
    required this.totalHistorico,
    required this.anio,
  });
}
