// Reporte de mermas para que el admin vea todas las mermas y el motivo

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/services/firestore_helpers.dart';
import 'package:google_fonts/google_fonts.dart';

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
  String? _eventoSeleccionadoId;
  String? _sectorSeleccionadoId;

  Future<void> _cargar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final QuerySnapshot eventosSnapshot = _soloActivos
          ? await FirestoreHelpers.getEventosActivos()
          : await FirestoreHelpers.getEventos();

      final List<Map<String, dynamic>> list = [];

      for (var eventoDoc in eventosSnapshot.docs) {
        final eventoId = eventoDoc.id;
        final eventoNombre =
            (eventoDoc.data() as Map<String, dynamic>)['nombre']?.toString() ??
            'Sin nombre';

        final sectoresSnapshot = await FirestoreHelpers.getSectores(eventoId);

        for (var sectorDoc in sectoresSnapshot.docs) {
          final sectorId = sectorDoc.id;
          final sectorNombre =
              (sectorDoc.data() as Map<String, dynamic>?)?['nombre']
                  ?.toString() ??
              'Sin sector';

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

      final Set<String> eventosIds = {};
      for (var m in list) {
        final eid = m['eventoId'] as String? ?? '';
        if (eid.isNotEmpty) eventosIds.add(eid);
      }
      if (_eventoSeleccionadoId != null &&
          !eventosIds.contains(_eventoSeleccionadoId)) {
        _eventoSeleccionadoId = null;
        _sectorSeleccionadoId = null;
      }

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

  List<Map<String, dynamic>> get _mermasFiltradas {
    return _mermas.where((m) {
      if (_eventoSeleccionadoId != null &&
          m['eventoId'] != _eventoSeleccionadoId) {
        return false;
      }
      if (_sectorSeleccionadoId == null) return true;
      if (_sectorSeleccionadoId!.contains('|')) {
        final parts = _sectorSeleccionadoId!.split('|');
        return m['eventoId'] == parts[0] && m['sectorId'] == parts[1];
      }
      return m['sectorId'] == _sectorSeleccionadoId;
    }).toList();
  }

  List<Map<String, String>> get _eventosOpciones {
    final Set<String> ids = {};
    final List<Map<String, String>> op = [];
    for (var m in _mermas) {
      final eid = m['eventoId'] as String? ?? '';
      final enom = m['eventoNombre'] as String? ?? 'Sin nombre';
      if (eid.isNotEmpty && !ids.contains(eid)) {
        ids.add(eid);
        op.add({'id': eid, 'nombre': enom});
      }
    }
    op.sort((a, b) => (a['nombre'] ?? '').compareTo(b['nombre'] ?? ''));
    return op;
  }

  List<Map<String, String>> get _sectoresOpciones {
    final List<Map<String, String>> op = [];
    final String? eidSel = _eventoSeleccionadoId;
    if (eidSel != null) {
      final Set<String> sidSet = {};
      for (var m in _mermas) {
        if (m['eventoId'] != eidSel) continue;
        final sid = m['sectorId'] as String? ?? '';
        final snom = m['sectorNombre'] as String? ?? 'Sector';
        if (sid.isNotEmpty && !sidSet.contains(sid)) {
          sidSet.add(sid);
          op.add({'id': sid, 'nombre': snom});
        }
      }
      op.sort((a, b) => (a['nombre'] ?? '').compareTo(b['nombre'] ?? ''));
    } else {
      final Set<String> compSet = {};
      for (var m in _mermas) {
        final eid = m['eventoId'] as String? ?? '';
        final enom = m['eventoNombre'] as String? ?? '';
        final sid = m['sectorId'] as String? ?? '';
        final snom = m['sectorNombre'] as String? ?? 'Sector';
        if (eid.isEmpty || sid.isEmpty) continue;
        final comp = '$eid|$sid';
        if (!compSet.contains(comp)) {
          compSet.add(comp);
          op.add({'id': comp, 'nombre': '$snom ($enom)'});
        }
      }
      op.sort((a, b) => (a['nombre'] ?? '').compareTo(b['nombre'] ?? ''));
    }
    return op;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Reporte de mermas',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.accent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Solo activos',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 6),
                Switch(
                  value: _soloActivos,
                  onChanged: (v) {
                    setState(() => _soloActivos = v);
                    _cargar();
                  },
                  activeThumbColor: AppColors.accent,
                ),
              ],
            ),
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
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
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
          : _mermas.isEmpty
          ? Center(
              child: Text(
                _soloActivos
                    ? 'No hay mermas en eventos activos'
                    : 'No hay mermas registradas',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : RefreshIndicator(
              onRefresh: _cargar,
              color: AppColors.accent,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFiltros(),
                  const SizedBox(height: 16),
                  _buildCardPerdidaTotal(),
                  const SizedBox(height: 16),
                  Text(
                    'Detalle de mermas',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_mermasFiltradas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No hay mermas con los filtros seleccionados',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ..._mermasFiltradas.map((m) => _buildCardMerma(m)),
                ],
              ),
            ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Filtrar por',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue:
                _eventosOpciones.any((e) => e['id'] == _eventoSeleccionadoId)
                ? _eventoSeleccionadoId
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Partido',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text('Todos', style: GoogleFonts.poppins(fontSize: 13)),
              ),
              ..._eventosOpciones.map(
                (e) => DropdownMenuItem<String>(
                  value: e['id'],
                  child: Text(
                    e['nombre'] ?? '',
                    style: GoogleFonts.poppins(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (v) {
              setState(() {
                _eventoSeleccionadoId = v;
                _sectorSeleccionadoId = null;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue:
                _sectoresOpciones.any((s) => s['id'] == _sectorSeleccionadoId)
                ? _sectorSeleccionadoId
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Sector',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text('Todos', style: GoogleFonts.poppins(fontSize: 13)),
              ),
              ..._sectoresOpciones.map(
                (s) => DropdownMenuItem<String>(
                  value: s['id'],
                  child: Text(
                    s['nombre'] ?? '',
                    style: GoogleFonts.poppins(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (v) {
              setState(() {
                _sectorSeleccionadoId = v;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardPerdidaTotal() {
    int totalUnidades = 0;
    double totalValor = 0.0;
    for (var m in _mermasFiltradas) {
      final cant = m['cantidadPerdida'] as int? ?? 0;
      final precio = (m['precio'] as num?)?.toDouble();
      totalUnidades += cant;
      if (precio != null) totalValor += cant * precio;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[700]!, Colors.red[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_down, color: Colors.white70, size: 22),
              const SizedBox(width: 8),
              Text(
                'Pérdida total',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$totalUnidades unidades',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (totalValor > 0) ...[
            const SizedBox(height: 4),
            Text(
              '\$${totalValor.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardMerma(Map<String, dynamic> m) {
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
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red[700],
                    size: 26,
                  ),
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
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$eventoNombre · $sectorNombre',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '-$cantidad',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Motivo',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    motivo,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.primaryLight,
                    ),
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
  }
}
