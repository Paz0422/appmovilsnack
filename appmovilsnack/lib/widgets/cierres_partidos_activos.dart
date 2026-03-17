// Lista de cierres de turno por partido (solo eventos activos).
// Muestra qué sectores tienen turnoCerrado y la fecha/hora del cierre.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import '../services/firestore_helpers.dart';
import 'resumen_cierre_turno.dart';

class CierresPartidosActivos extends StatefulWidget {
  const CierresPartidosActivos({super.key});

  @override
  State<CierresPartidosActivos> createState() => _CierresPartidosActivosState();
}

class _CierresPartidosActivosState extends State<CierresPartidosActivos> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _eventosConCierres = [];

  Future<void> _cargar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final eventosSnapshot = await FirestoreHelpers.getEventosActivos();
      final List<Map<String, dynamic>> resultados = [];

      for (var eventoDoc in eventosSnapshot.docs) {
        final eventoId = eventoDoc.id;
        final eventoData = eventoDoc.data() as Map<String, dynamic>?;
        final nombreEvento = eventoData?['nombre']?.toString() ?? eventoId;

        final sectoresSnapshot = await FirestoreHelpers.getSectores(eventoId);
        final List<Map<String, dynamic>> cierres = [];

        for (var sectorDoc in sectoresSnapshot.docs) {
          final data = sectorDoc.data() as Map<String, dynamic>?;
          if (data == null || data['turnoCerrado'] != true) continue;
          final nombreSector = data['nombre']?.toString() ?? sectorDoc.id;
          final ts = data['turnoCerradoAt'];
          String fechaHora = '—';
          if (ts != null && ts is Timestamp) {
            final dt = ts.toDate();
            fechaHora =
                '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          }
          cierres.add({
            'sectorId': sectorDoc.id,
            'nombreSector': nombreSector,
            'cerradoAt': fechaHora,
          });
        }

        if (cierres.isNotEmpty) {
          resultados.add({
            'eventoId': eventoId,
            'nombreEvento': nombreEvento,
            'cierres': cierres,
          });
        }
      }

      if (mounted) {
        setState(() {
          _eventosConCierres = resultados;
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Cierres de partidos activos',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.accent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _cargar,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(
                          'Error al cargar',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
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
              : _eventosConCierres.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No hay sectores cerrados en partidos activos',
                          style: GoogleFonts.poppins(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      color: AppColors.accent,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _eventosConCierres.length,
                        itemBuilder: (context, index) {
                          final evento = _eventosConCierres[index];
                          return _buildCardEvento(evento);
                        },
                      ),
                    ),
    );
  }

  Widget _buildCardEvento(Map<String, dynamic> evento) {
    final eventoId = evento['eventoId'] as String? ?? '';
    final nombreEvento = evento['nombreEvento'] as String? ?? 'Sin nombre';
    final cierres = (evento['cierres'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      color: AppColors.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, color: AppColors.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nombreEvento,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...cierres.map((c) {
              final sectorId = c['sectorId'] as String? ?? '';
              final nombreSector = c['nombreSector'] as String? ?? '—';
              final cerradoAt = c['cerradoAt'] as String? ?? '—';
              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ResumenCierreTurno(
                        eventoId: eventoId,
                        sectorId: sectorId,
                        nombreSector: nombreSector,
                        nombreEvento: nombreEvento,
                        fromAdmin: true,
                        soloVerReporte: true,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, size: 18, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          nombreSector,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        cerradoAt,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.visibility_outlined, size: 18, color: AppColors.accent),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
