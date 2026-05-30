// Reporte de traspasos recibidos con menos unidades de las enviadas.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/services/firestore_helpers.dart';
import 'package:google_fonts/google_fonts.dart';

int _intDesdeFirestore(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

class ReporteDiferenciasTraspaso extends StatefulWidget {
  const ReporteDiferenciasTraspaso({super.key});

  @override
  State<ReporteDiferenciasTraspaso> createState() =>
      _ReporteDiferenciasTraspasoState();
}

class _ReporteDiferenciasTraspasoState
    extends State<ReporteDiferenciasTraspaso> {
  bool _soloActivos = true;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _registros = [];
  String? _eventoSeleccionadoId;
  String? _sectorSeleccionadoId;

  Future<void> _cargar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final eventosSnapshot = _soloActivos
          ? await FirestoreHelpers.getEventosActivos()
          : await FirestoreHelpers.getEventos();

      final list = <Map<String, dynamic>>[];

      for (final eventoDoc in eventosSnapshot.docs) {
        final eventoId = eventoDoc.id;
        final eventoData = eventoDoc.data() as Map<String, dynamic>;
        final eventoNombre =
            eventoData['nombre']?.toString() ?? 'Sin nombre';

        final sectoresSnapshot = await FirestoreHelpers.getSectores(eventoId);

        for (final sectorDoc in sectoresSnapshot.docs) {
          final sectorDestinoId = sectorDoc.id;
          final sectorDestinoNombre =
              (sectorDoc.data() as Map<String, dynamic>?)?['nombre']
                      ?.toString() ??
                  'Sin sector';

          final traspasosSnapshot = await FirebaseFirestore.instance
              .collection('eventos')
              .doc(eventoId)
              .collection('sectores')
              .doc(sectorDestinoId)
              .collection('traspasos_entrantes')
              .where('estado', isEqualTo: 'confirmado')
              .get();

          for (final traspasoDoc in traspasosSnapshot.docs) {
            final d = traspasoDoc.data();
            final enviada = _intDesdeFirestore(d['cantidadEnviada']);
            final recibida = _intDesdeFirestore(d['cantidadRecibida']);
            final diferencia = d.containsKey('cantidadDiferencia')
                ? _intDesdeFirestore(d['cantidadDiferencia'])
                : enviada - recibida;

            if (diferencia <= 0) continue;

            list.add({
              'eventoId': eventoId,
              'eventoNombre': eventoNombre,
              'sectorDestinoId': sectorDestinoId,
              'sectorDestinoNombre': d['sectorDestinoNombre']?.toString() ??
                  sectorDestinoNombre,
              'sectorOrigenId': d['sectorOrigenId']?.toString() ?? '',
              'sectorOrigenNombre':
                  d['sectorOrigenNombre']?.toString() ?? 'Origen desconocido',
              'productoId': d['productoId']?.toString() ?? '',
              'nombreProducto': d['nombre']?.toString() ?? 'Sin nombre',
              'cantidadEnviada': enviada,
              'cantidadRecibida': recibida,
              'cantidadDiferencia': diferencia,
              'comentarioDiferencia':
                  d['comentarioDiferencia']?.toString() ?? '',
              'precio': (d['precio'] as num?)?.toDouble(),
              'pedidoId': d['pedidoId']?.toString() ?? '',
              'fecha': d['confirmadoAt'] ?? d['fecha'],
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

      final eventosIds = list.map((r) => r['eventoId'] as String).toSet();
      if (_eventoSeleccionadoId != null &&
          !eventosIds.contains(_eventoSeleccionadoId)) {
        _eventoSeleccionadoId = null;
        _sectorSeleccionadoId = null;
      }

      if (mounted) {
        setState(() {
          _registros = list;
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

  List<Map<String, dynamic>> get _registrosFiltrados {
    return _registros.where((r) {
      if (_eventoSeleccionadoId != null &&
          r['eventoId'] != _eventoSeleccionadoId) {
        return false;
      }
      if (_sectorSeleccionadoId == null) return true;
      if (_sectorSeleccionadoId!.contains('|')) {
        final parts = _sectorSeleccionadoId!.split('|');
        return r['eventoId'] == parts[0] &&
            r['sectorDestinoId'] == parts[1];
      }
      return r['sectorDestinoId'] == _sectorSeleccionadoId;
    }).toList();
  }

  List<Map<String, String>> get _eventosOpciones {
    final ids = <String>{};
    final op = <Map<String, String>>[];
    for (final r in _registros) {
      final eid = r['eventoId'] as String? ?? '';
      final enom = r['eventoNombre'] as String? ?? 'Sin nombre';
      if (eid.isNotEmpty && ids.add(eid)) {
        op.add({'id': eid, 'nombre': enom});
      }
    }
    op.sort((a, b) => (a['nombre'] ?? '').compareTo(b['nombre'] ?? ''));
    return op;
  }

  List<Map<String, String>> get _sectoresOpciones {
    final op = <Map<String, String>>[];
    final eidSel = _eventoSeleccionadoId;
    if (eidSel != null) {
      final sidSet = <String>{};
      for (final r in _registros) {
        if (r['eventoId'] != eidSel) continue;
        final sid = r['sectorDestinoId'] as String? ?? '';
        final snom = r['sectorDestinoNombre'] as String? ?? 'Sector';
        if (sid.isNotEmpty && sidSet.add(sid)) {
          op.add({'id': sid, 'nombre': snom});
        }
      }
      op.sort((a, b) => (a['nombre'] ?? '').compareTo(b['nombre'] ?? ''));
    } else {
      final compSet = <String>{};
      for (final r in _registros) {
        final eid = r['eventoId'] as String? ?? '';
        final enom = r['eventoNombre'] as String? ?? '';
        final sid = r['sectorDestinoId'] as String? ?? '';
        final snom = r['sectorDestinoNombre'] as String? ?? 'Sector';
        if (eid.isEmpty || sid.isEmpty) continue;
        final comp = '$eid|$sid';
        if (compSet.add(comp)) {
          op.add({'id': comp, 'nombre': '$snom ($enom)'});
        }
      }
      op.sort((a, b) => (a['nombre'] ?? '').compareTo(b['nombre'] ?? ''));
    }
    return op;
  }

  String _formatearFecha(dynamic fecha) {
    if (fecha is! Timestamp) return '--/--/-- --:--';
    final dt = fecha.toDate();
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Diferencias en traspasos',
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_errorMessage != null) {
      return Center(
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
      );
    }
    if (_registros.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _soloActivos
                ? 'No hay traspasos con diferencia en eventos activos'
                : 'No hay traspasos recibidos con menos unidades',
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFiltros(),
          const SizedBox(height: 16),
          _buildResumenTotal(),
          const SizedBox(height: 16),
          Text(
            'Detalle de diferencias',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: 12),
          if (_registrosFiltrados.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No hay registros con los filtros seleccionados',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ..._registrosFiltrados.map(_buildCardRegistro),
        ],
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
            initialValue: _eventosOpciones.any(
              (e) => e['id'] == _eventoSeleccionadoId,
            )
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
            initialValue: _sectoresOpciones.any(
              (s) => s['id'] == _sectorSeleccionadoId,
            )
                ? _sectorSeleccionadoId
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Sector destino',
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
            onChanged: (v) => setState(() => _sectorSeleccionadoId = v),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenTotal() {
    var totalUnidades = 0;
    var totalValor = 0.0;
    final pedidos = <String>{};

    for (final r in _registrosFiltrados) {
      final diff = r['cantidadDiferencia'] as int? ?? 0;
      final precio = (r['precio'] as num?)?.toDouble();
      totalUnidades += diff;
      if (precio != null) totalValor += diff * precio;
      final pedidoId = r['pedidoId'] as String? ?? '';
      if (pedidoId.isNotEmpty) pedidos.add(pedidoId);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.secondary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_problem_rounded, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                'Unidades no recibidas',
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
            '$totalUnidades u. en ${_registrosFiltrados.length} línea'
            '${_registrosFiltrados.length == 1 ? '' : 's'}',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (pedidos.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${pedidos.length} pedido${pedidos.length == 1 ? '' : 's'} afectado'
              '${pedidos.length == 1 ? '' : 's'}',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
            ),
          ],
          if (totalValor > 0) ...[
            const SizedBox(height: 4),
            Text(
              '\$${totalValor.toStringAsFixed(0)} estimado',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardRegistro(Map<String, dynamic> r) {
    final nombre = r['nombreProducto'] as String? ?? 'Sin nombre';
    final enviada = r['cantidadEnviada'] as int? ?? 0;
    final recibida = r['cantidadRecibida'] as int? ?? 0;
    final diferencia = r['cantidadDiferencia'] as int? ?? 0;
    final comentario = (r['comentarioDiferencia'] as String? ?? '').trim();
    final origen = r['sectorOrigenNombre'] as String? ?? '';
    final destino = r['sectorDestinoNombre'] as String? ?? '';
    final evento = r['eventoNombre'] as String? ?? '';
    final fechaStr = _formatearFecha(r['fecha']);

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    color: AppColors.secondary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$evento · $origen → $destino',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
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
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '-$diferencia',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _chipCantidad('Enviado', enviada, AppColors.primaryLight),
                const SizedBox(width: 8),
                _chipCantidad('Recibido', recibida, AppColors.success),
                const SizedBox(width: 8),
                _chipCantidad('Faltante', diferencia, Colors.orange[800]!),
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
                    'Comentario del receptor',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comentario.isNotEmpty
                        ? comentario
                        : 'Sin comentario registrado',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: comentario.isNotEmpty
                          ? AppColors.primaryLight
                          : Colors.grey[500],
                      fontStyle: comentario.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Confirmado: $fechaStr',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipCantidad(String label, int valor, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
            ),
            const SizedBox(height: 2),
            Text(
              '$valor',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
