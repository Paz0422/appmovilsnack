// Reporte de mermas para que el admin vea todas las mermas y el motivo

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

final Color _primaryColor = const Color(0xFF2B2B2B);
final Color _accentColor = const Color(0xFFDABF41);
final Color _backgroundColor = const Color(0xFFFDFBF7);

class ReporteMermas extends StatefulWidget {
  const ReporteMermas({super.key});

  @override
  State<ReporteMermas> createState() => _ReporteMermasState();
}

class _ReporteMermasState extends State<ReporteMermas> {
  bool _soloActivos = true;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _mermas = [];

  Future<void> _cargar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      QuerySnapshot eventosSnapshot;
      if (_soloActivos) {
        eventosSnapshot = await FirebaseFirestore.instance
            .collection('eventos')
            .where('activo', isEqualTo: true)
            .get();
      } else {
        eventosSnapshot = await FirebaseFirestore.instance.collection('eventos').get();
      }

      final List<Map<String, dynamic>> list = [];

      for (var eventoDoc in eventosSnapshot.docs) {
        final eventoId = eventoDoc.id;
        final eventoNombre = (eventoDoc.data() as Map<String, dynamic>)['nombre']?.toString() ?? 'Sin nombre';

        final sectoresSnapshot = await FirebaseFirestore.instance
            .collection('eventos')
            .doc(eventoId)
            .collection('sectores')
            .get();

        for (var sectorDoc in sectoresSnapshot.docs) {
          final sectorId = sectorDoc.id;
          final sectorNombre = sectorDoc.data()['nombre']?.toString() ?? 'Sin sector';

          final mermasSnapshot = await FirebaseFirestore.instance
              .collection('eventos')
              .doc(eventoId)
              .collection('sectores')
              .doc(sectorId)
              .collection('mermas')
              .orderBy('fecha', descending: true)
              .get();

          for (var mermaDoc in mermasSnapshot.docs) {
            final d = mermaDoc.data();
            list.add({
              'eventoId': eventoId,
              'eventoNombre': eventoNombre,
              'sectorId': sectorId,
              'sectorNombre': sectorNombre,
              'nombreProducto': d['nombreProducto']?.toString() ?? 'Sin nombre',
              'cantidadPerdida': d['cantidadPerdida'] as int? ?? 0,
              'motivo': d['motivo']?.toString() ?? 'Sin motivo',
              'precio': (d['precio'] as num?)?.toDouble(),
              'fecha': d['fecha'],
            });
          }
        }
      }

      list.sort((a, b) {
        final fa = a['fecha'] as Timestamp?;
        final fb = b['fecha'] as Timestamp?;
        if (fa == null && fb == null) return 0;
        if (fa == null) return 1;
        if (fb == null) return -1;
        return fb.compareTo(fa);
      });

      if (mounted) {
        setState(() {
          _mermas = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          'Reporte de mermas',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _accentColor, fontSize: 18),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: _accentColor,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Solo activos', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
                const SizedBox(width: 6),
                Switch(
                  value: _soloActivos,
                  onChanged: (v) {
                    setState(() => _soloActivos = v);
                    _cargar();
                  },
                  activeColor: _accentColor,
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accentColor))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Error al cargar',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _primaryColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _cargar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _mermas.isEmpty
                  ? Center(
                      child: Text(
                        _soloActivos
                            ? 'No hay mermas en eventos activos'
                            : 'No hay mermas registradas',
                        style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      color: _accentColor,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _mermas.length,
                        itemBuilder: (context, index) {
                          final m = _mermas[index];
                          final nombreProducto = m['nombreProducto'] as String? ?? 'Sin nombre';
                          final cantidad = m['cantidadPerdida'] as int? ?? 0;
                          final motivo = m['motivo'] as String? ?? 'Sin motivo';
                          final eventoNombre = m['eventoNombre'] as String? ?? '';
                          final sectorNombre = m['sectorNombre'] as String? ?? '';
                          final fecha = m['fecha'] as Timestamp?;
                          String fechaStr = '--/--/-- --:--';
                          if (fecha != null) {
                            final dt = fecha.toDate();
                            fechaStr =
                                '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.remove_circle_outline, color: Colors.red[700], size: 26),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nombreProducto,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: _primaryColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$eventoNombre · $sectorNombre',
                                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '-$cantidad',
                                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red[700]),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Motivo',
                                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          motivo,
                                          style: GoogleFonts.poppins(fontSize: 14, color: _primaryColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    fechaStr,
                                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
