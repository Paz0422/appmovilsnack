// Admin: faltantes de traspasos que no pudieron volver al sector de origen
// porque ya había cerrado su turno (eventos/{id}/discrepancias).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import '../services/firestore_helpers.dart';
import '../services/traspaso_service.dart';

class DiscrepanciasPendientes extends StatefulWidget {
  const DiscrepanciasPendientes({super.key});

  @override
  State<DiscrepanciasPendientes> createState() =>
      _DiscrepanciasPendientesState();
}

class _DiscrepanciasPendientesState extends State<DiscrepanciasPendientes> {
  final _service = TraspasoService();
  bool _isLoading = true;
  String? _errorMessage;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _pendientes = [];
  Map<String, String> _nombresEventos = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final eventos = await FirestoreHelpers.getEventos();
      final pendientes = await _service.discrepanciasPendientes();
      if (!mounted) return;
      setState(() {
        _nombresEventos = {
          for (final e in eventos.docs)
            e.id: (e.data() as Map<String, dynamic>?)?['nombre']?.toString() ??
                e.id,
        };
        _pendientes = pendientes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _resolver(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final notaController = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Marcar como resuelta',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: notaController,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nota (opcional)',
            hintText: 'Ej: se descontó al vendedor, se encontró la caja…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Resuelta'),
          ),
        ],
      ),
    );
    final nota = notaController.text;
    notaController.dispose();
    if (confirmado != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.resolverDiscrepancia(
        eventoId: doc.data()['eventoId']?.toString() ??
            doc.reference.parent.parent!.id,
        discrepanciaId: doc.id,
        adminUid: FirebaseAuth.instance.currentUser?.uid ?? '',
        nota: nota,
      );
      if (!mounted) return;
      setState(() => _pendientes.remove(doc));
      messenger.showSnackBar(
        SnackBar(
          content: Text('Discrepancia resuelta.', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar: $e', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _fecha(dynamic valor) {
    if (valor is! Timestamp) return '';
    final d = valor.toDate();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year} ${dos(d.hour)}:${dos(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Faltantes por resolver',
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
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _cargar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _pendientes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No hay faltantes pendientes.',
                          style: GoogleFonts.poppins(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      color: AppColors.accent,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pendientes.length,
                        itemBuilder: (context, i) => _buildCard(_pendientes[i]),
                      ),
                    ),
    );
  }

  Widget _buildCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final evento = _nombresEventos[d['eventoId']] ?? d['eventoId']?.toString() ?? '';
    final comentario = d['comentario']?.toString();

    TextStyle detalle() =>
        GoogleFonts.poppins(fontSize: 13, color: AppColors.onSurfaceVariant);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    d['nombreProducto']?.toString() ?? 'Producto',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ),
                Text(
                  'Faltan ${d['diferencia'] ?? 0} u.',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(evento, style: detalle()),
            Text(
              '${d['sectorOrigenNombre'] ?? 'Origen'} → '
              '${d['sectorDestinoNombre'] ?? 'Destino'} '
              '(el origen ya había cerrado su turno)',
              style: detalle(),
            ),
            Text(
              'Enviado: ${d['cantidadEnviada'] ?? 0} · '
              'Recibido: ${d['cantidadRecibida'] ?? 0}',
              style: detalle(),
            ),
            Text(
              'Confirmó: ${d['vendedorNombre'] ?? d['vendedorUid'] ?? '—'}'
              '${_fecha(d['fecha']).isEmpty ? '' : ' · ${_fecha(d['fecha'])}'}',
              style: detalle(),
            ),
            if (comentario != null && comentario.isNotEmpty)
              Text('Motivo: $comentario', style: detalle()),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _resolver(doc),
                icon: const Icon(Icons.check),
                label: const Text('Marcar resuelta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
