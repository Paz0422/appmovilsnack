import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de incidencia en `eventos/{eventoId}/discrepancias`.
class TipoIncidencia {
  TipoIncidencia._();

  /// Traspaso recibido con menos unidades cuando el origen ya había cerrado:
  /// la diferencia no pudo volver a su stock (TraspasoService).
  static const faltanteTraspaso = 'faltante_traspaso';

  /// Conteo del cierre de turno mayor al stock del sistema (CierreTurnoService).
  static const sobranteConteo = 'sobrante_conteo';

  static const todos = [faltanteTraspaso, sobranteConteo];

  /// Las incidencias sin `tipo` son faltantes de traspaso (las primeras que hubo).
  static String de(Map<String, dynamic> data) =>
      data['tipo']?.toString() ?? faltanteTraspaso;

  static String etiqueta(String tipo) => switch (tipo) {
        sobranteConteo => 'Sobrante en conteo',
        _ => 'Faltante en traspaso',
      };
}

/// Incidencias que el admin revisa y marca como resueltas.
class IncidenciasService {
  IncidenciasService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String eventoId) =>
      _db.collection('eventos').doc(eventoId).collection('discrepancias');

  /// Pendientes de todos los eventos, más recientes primero. [tipo] filtra por
  /// [TipoIncidencia]; `null` trae todas.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> pendientes({
    String? tipo,
  }) async {
    final eventos = await _db.collection('eventos').get();
    // Una consulta por evento, en paralelo.
    final snaps = await Future.wait(
      eventos.docs.map(
        (e) => _col(e.id).where('estado', isEqualTo: 'pendiente').get(),
      ),
    );
    // Filtro en el cliente: evita un índice compuesto estado + tipo.
    final lista = [
      for (final snap in snaps)
        ...snap.docs.where(
          (d) => tipo == null || TipoIncidencia.de(d.data()) == tipo,
        ),
    ];
    lista.sort((a, b) {
      final fa = a.data()['fecha'];
      final fb = b.data()['fecha'];
      if (fa is Timestamp && fb is Timestamp) return fb.compareTo(fa);
      return 0;
    });
    return lista;
  }

  Future<void> resolver({
    required String eventoId,
    required String incidenciaId,
    required String adminUid,
    String? nota,
  }) =>
      _col(eventoId).doc(incidenciaId).update({
        'estado': 'resuelta',
        'resueltaAt': FieldValue.serverTimestamp(),
        'resueltaPor': adminUid,
        if (nota != null && nota.trim().isNotEmpty) 'notaResolucion': nota.trim(),
      });
}
