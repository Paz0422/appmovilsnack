// Helpers centralizados para Firestore — evita duplicar consultas en toda la app.
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreHelpers {
  FirestoreHelpers._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Eventos activos (activo == true).
  static Future<QuerySnapshot> getEventosActivos() {
    return _firestore
        .collection('eventos')
        .where('activo', isEqualTo: true)
        .get();
  }

  /// Todos los eventos (sin filtrar por activo).
  static Future<QuerySnapshot> getEventos() {
    return _firestore.collection('eventos').get();
  }

  /// Stream de eventos activos (para UI reactiva).
  static Stream<QuerySnapshot> streamEventosActivos() {
    return _firestore
        .collection('eventos')
        .where('activo', isEqualTo: true)
        .snapshots();
  }

  /// Sectores de un evento (una sola lectura).
  static Future<QuerySnapshot> getSectores(String eventoId) {
    return _firestore
        .collection('eventos')
        .doc(eventoId)
        .collection('sectores')
        .get();
  }

  /// Stream de sectores de un evento.
  static Stream<QuerySnapshot> streamSectores(String eventoId) {
    return _firestore
        .collection('eventos')
        .doc(eventoId)
        .collection('sectores')
        .snapshots();
  }

  /// Catálogo global de productos (tiempo real para stock inicial, etc.).
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamProductosCatalogo() {
    return _firestore.collection('productos').snapshots();
  }

  /// Documento de un sector (para leer turnoCerrado, nombre, etc.).
  static Future<DocumentSnapshot> getSector(String eventoId, String sectorId) {
    return _firestore
        .collection('eventos')
        .doc(eventoId)
        .collection('sectores')
        .doc(sectorId)
        .get();
  }
}
