// Admin: incidencias pendientes de todos los eventos (eventos/{id}/discrepancias):
// faltantes de traspasos cuyo origen ya había cerrado y sobrantes del conteo
// de cierre de turno.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';
import 'package:front_appsnack/core/tipografia.dart';
import '../core/app_theme.dart';
import '../services/firestore_helpers.dart';
import '../services/incidencias_service.dart';
import 'package:front_appsnack/core/margen_inferior.dart';
import 'package:front_appsnack/widgets/comunes/cargando.dart';
import 'package:front_appsnack/core/animaciones.dart';

class IncidenciasPendientes extends StatefulWidget {
  const IncidenciasPendientes({super.key});

  @override
  State<IncidenciasPendientes> createState() => _IncidenciasPendientesState();
}

class _IncidenciasPendientesState extends State<IncidenciasPendientes> {
  final _service = IncidenciasService();
  bool _isLoading = true;
  String? _errorMessage;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _pendientes = [];
  Map<String, String> _nombresEventos = {};

  /// `null` = todos los tipos.
  String? _filtroTipo;

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
      final lecturas = await Future.wait<Object>([
        FirestoreHelpers.getEventos(),
        _service.pendientes(),
      ]);
      final eventos = lecturas[0] as QuerySnapshot;
      final pendientes =
          lecturas[1] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
      if (!mounted) return;
      setState(() {
        _nombresEventos = {
          for (final e in eventos.docs)
            e.id:
                (e.data() as Map<String, dynamic>?)?['nombre']?.toString() ??
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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _visibles =>
      _filtroTipo == null
      ? _pendientes
      : _pendientes
            .where((d) => TipoIncidencia.de(d.data()) == _filtroTipo)
            .toList();

  int _cantidadDeTipo(String tipo) =>
      _pendientes.where((d) => TipoIncidencia.de(d.data()) == tipo).length;

  Future<void> _resolver(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final notaController = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Marcar como resuelta',
          style: AppFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: notaController,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nota (opcional)',
            hintText: 'Ej: se ajustó el stock, se descontó al vendedor…',
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
      await _service.resolver(
        eventoId:
            doc.data()['eventoId']?.toString() ??
            doc.reference.parent.parent!.id,
        incidenciaId: doc.id,
        adminUid: FirebaseAuth.instance.currentUser?.uid ?? '',
        nota: nota,
      );
      if (!mounted) return;
      setState(() => _pendientes.remove(doc));
      messenger.showSnackBar(
        SnackBar(
          content: Text('Incidencia resuelta.', style: AppFonts.inter()),
          backgroundColor: AppColors.exitoFuerte,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar: $e', style: AppFonts.inter()),
          backgroundColor: AppColors.errorFuerte,
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
          'Incidencias por resolver',
          style: AppFonts.inter(
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _cargar,
          ),
        ],
      ),
      body: _isLoading
          ? const CargandoTarjetas()
          : _errorMessage != null
          ? _buildError()
          : Column(
              children: [
                _buildFiltros(),
                Expanded(
                  child: _visibles.isEmpty
                      ? EstadoVacio(
                          titulo: _filtroTipo == null
                              ? 'No hay incidencias pendientes.'
                              : 'No hay incidencias pendientes de este tipo.',
                        )
                      : RefreshIndicator(
                          onRefresh: _cargar,
                          color: AppColors.dorado,
                          child: ListView.builder(
                            padding: conMargenInferior(
                              context,
                              const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            ),
                            itemCount: _visibles.length,
                            itemBuilder: (context, i) =>
                                _buildCard(_visibles[i]).entradaEnLista(i),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: AppFonts.inter(fontSize: 14),
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
    );
  }

  Widget _buildFiltros() {
    Widget chip(String? tipo, String texto) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto, style: AppFonts.inter(fontSize: 14)),
        selected: _filtroTipo == tipo,
        onSelected: (_) => setState(() => _filtroTipo = tipo),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          chip(null, 'Todas (${_pendientes.length})'),
          for (final tipo in TipoIncidencia.todos)
            chip(
              tipo,
              '${TipoIncidencia.etiqueta(tipo)} (${_cantidadDeTipo(tipo)})',
            ),
        ],
      ),
    );
  }

  Widget _buildCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final tipo = TipoIncidencia.de(d);
    final esSobrante = tipo == TipoIncidencia.sobranteConteo;
    final evento =
        _nombresEventos[d['eventoId']] ?? d['eventoId']?.toString() ?? '';
    final comentario = d['comentario']?.toString();
    final color = esSobrante ? AppColors.cian : AppColors.aviso;

    TextStyle detalle() =>
        AppFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant);

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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                TipoIncidencia.etiqueta(tipo),
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    d['nombreProducto']?.toString() ?? 'Producto',
                    style: AppFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ),
                Text(
                  esSobrante
                      ? 'Sobran ${d['diferencia'] ?? 0} u.'
                      : 'Faltan ${d['diferencia'] ?? 0} u.',
                  style: AppFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(evento, style: detalle()),
            if (esSobrante) ...[
              Text(
                'Sector: ${d['sectorNombre'] ?? d['sectorId'] ?? '—'} '
                '(conteo del cierre de turno)',
                style: detalle(),
              ),
              Text(
                'Stock del sistema: ${d['stockSistema'] ?? 0} · '
                'Contado: ${d['cantidadContada'] ?? 0}',
                style: detalle(),
              ),
            ] else ...[
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
            ],
            Text(
              '${esSobrante ? 'Contó' : 'Confirmó'}: '
              '${d['vendedorNombre'] ?? d['vendedorUid'] ?? '—'}'
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
