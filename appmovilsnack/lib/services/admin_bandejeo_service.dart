import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBandejeroResumen {
  final String id;
  final String nombre;
  final bool cerrado;
  final int rondasRendidas;
  final bool tieneRondaEnCurso;
  final double totalVendido;
  final double valorEnBandeja;
  final double cajaVuelto;
  final double? totalARecibirCierre;
  final double? porcentajeComision;
  final double? comisionAlCierre;

  const AdminBandejeroResumen({
    required this.id,
    required this.nombre,
    required this.cerrado,
    required this.rondasRendidas,
    required this.tieneRondaEnCurso,
    required this.totalVendido,
    required this.valorEnBandeja,
    required this.cajaVuelto,
    this.totalARecibirCierre,
    this.porcentajeComision,
    this.comisionAlCierre,
  });

  double get efectivoEstimadoEnCalles =>
      valorEnBandeja + (cerrado ? 0 : cajaVuelto);
}

class AdminBandejeoSectorResumen {
  final String eventoId;
  final String eventoNombre;
  final String sectorId;
  final String sectorNombre;
  final List<AdminBandejeroResumen> bandejeros;

  const AdminBandejeoSectorResumen({
    required this.eventoId,
    required this.eventoNombre,
    required this.sectorId,
    required this.sectorNombre,
    required this.bandejeros,
  });

  int get totalBandejeros => bandejeros.length;

  int get bandejerosEnTurno => bandejeros.where((b) => !b.cerrado).length;

  int get bandejerosCerrados => bandejeros.where((b) => b.cerrado).length;

  int get rondasRendidas =>
      bandejeros.fold(0, (total, b) => total + b.rondasRendidas);

  int get rondasEnCurso =>
      bandejeros.where((b) => b.tieneRondaEnCurso).length;

  double get totalVendido =>
      bandejeros.fold(0.0, (total, b) => total + b.totalVendido);

  double get valorEnBandeja =>
      bandejeros.fold(0.0, (total, b) => total + b.valorEnBandeja);

  double get cajaVueltoActiva => bandejeros
      .where((b) => !b.cerrado)
      .fold(0.0, (total, b) => total + b.cajaVuelto);

  double get efectivoEstimadoSector => bandejeros.fold(
        0.0,
        (total, b) => total + b.efectivoEstimadoEnCalles,
      );
}

class AdminBandejeoService {
  AdminBandejeoService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static bool _bandejeroCerrado(Map<String, dynamic> data) {
    if (data['bandejeoCerrado'] == true) return true;
    if (data['bandejeoCerradoEn'] != null) return true;
    return false;
  }

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _double(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _valorProductosEnBandeja(List<dynamic>? productos) {
    if (productos == null) return 0;
    var total = 0.0;
    for (final raw in productos) {
      if (raw is! Map<String, dynamic>) continue;
      final qty = _int(raw['cantidadInicial']);
      final precio = _double(raw['precio']);
      total += qty * precio;
    }
    return total;
  }

  static double _totalARecibirDesdeCierre(Map<String, dynamic>? cierre) {
    if (cierre == null) return 0;
    final directo = (cierre['totalARecibir'] as num?)?.toDouble();
    if (directo != null) return directo;
    final vendido = _double(cierre['totalVendido']);
    final caja = _double(cierre['cajaVuelto']);
    return vendido + caja;
  }

  static Future<AdminBandejeroResumen> _cargarBandejero(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data() ?? {};
    final rondasSnap = await doc.reference.collection('rondas').get();

    var rondasRendidas = 0;
    var totalVendido = 0.0;
    var valorEnBandeja = 0.0;
    var tieneRondaEnCurso = false;

    for (final ronda in rondasSnap.docs) {
      final rd = ronda.data();
      final estado = rd['estado']?.toString();
      if (estado == 'rendida') {
        rondasRendidas++;
        totalVendido += _double(rd['totalVendido']);
      } else if (estado == 'en_curso') {
        tieneRondaEnCurso = true;
        valorEnBandeja += _valorProductosEnBandeja(
          rd['productos'] as List<dynamic>?,
        );
      }
    }

    final cierre = data['cierreResumen'];
    final cerrado = _bandejeroCerrado(data);

    return AdminBandejeroResumen(
      id: doc.id,
      nombre: data['nombre']?.toString() ?? 'Sin nombre',
      cerrado: cerrado,
      rondasRendidas: rondasRendidas,
      tieneRondaEnCurso: tieneRondaEnCurso,
      totalVendido: cerrado && cierre is Map<String, dynamic>
          ? _double(cierre['totalVendido'])
          : totalVendido,
      valorEnBandeja: valorEnBandeja,
      cajaVuelto: _double(data['cajaVuelto']),
      totalARecibirCierre: cerrado && cierre is Map<String, dynamic>
          ? _totalARecibirDesdeCierre(cierre)
          : null,
      porcentajeComision: cerrado && cierre is Map<String, dynamic>
          ? _double(cierre['porcentajeComision'])
          : null,
      comisionAlCierre: cerrado && cierre is Map<String, dynamic>
          ? _double(cierre['comision'])
          : null,
    );
  }

  static Future<List<AdminBandejeoSectorResumen>> cargarPorEvento(
    String? eventoId, {
    bool soloActivos = true,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection('eventos');
    if (eventoId != null) {
      q = q.where(FieldPath.documentId, isEqualTo: eventoId);
    } else if (soloActivos) {
      q = q.where('activo', isEqualTo: true);
    }

    final eventosSnap = await q.get();
    final sectores = <AdminBandejeoSectorResumen>[];

    for (final eventoDoc in eventosSnap.docs) {
      final eventoData = eventoDoc.data();
      final eventoNombre =
          eventoData['nombre']?.toString() ?? 'Evento sin nombre';

      final sectoresSnap = await eventoDoc.reference.collection('sectores').get();

      for (final sectorDoc in sectoresSnap.docs) {
        final sectorData = sectorDoc.data();
        final sectorNombre =
            sectorData['nombre']?.toString() ?? 'Sector sin nombre';

        final bandejerosSnap =
            await sectorDoc.reference.collection('bandejeros').get();

        if (bandejerosSnap.docs.isEmpty) continue;

        final bandejeros = await Future.wait(
          bandejerosSnap.docs.map(_cargarBandejero),
        );
        bandejeros.sort(
          (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
        );

        sectores.add(
          AdminBandejeoSectorResumen(
            eventoId: eventoDoc.id,
            eventoNombre: eventoNombre,
            sectorId: sectorDoc.id,
            sectorNombre: sectorNombre,
            bandejeros: bandejeros,
          ),
        );
      }
    }

    sectores.sort((a, b) {
      final ea = a.eventoNombre.toLowerCase();
      final eb = b.eventoNombre.toLowerCase();
      if (ea != eb) return ea.compareTo(eb);
      return a.sectorNombre.toLowerCase().compareTo(b.sectorNombre.toLowerCase());
    });

    return sectores;
  }

  static Future<List<MapEntry<String, String>>> listarEventos({
    bool soloActivos = true,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection('eventos');
    if (soloActivos) {
      q = q.where('activo', isEqualTo: true);
    }
    final snap = await q.get();
    final lista = snap.docs
        .map(
          (d) => MapEntry(
            d.id,
            d.data()['nombre']?.toString() ?? 'Sin nombre',
          ),
        )
        .toList();
    lista.sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return lista;
  }
}
