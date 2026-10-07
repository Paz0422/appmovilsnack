// Reporte de mermas para que el admin vea todas las mermas y el motivo

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/services/firestore_helpers.dart';
import 'package:front_appsnack/core/tipografia.dart';
import 'package:front_appsnack/core/margen_inferior.dart';
import 'package:front_appsnack/widgets/comunes/cargando.dart';
import 'package:front_appsnack/core/animaciones.dart';
import 'package:front_appsnack/widgets/comunes/animados.dart';
import 'package:front_appsnack/widgets/graficos_admin.dart';
import 'package:front_appsnack/core/precio.dart';

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
  List<Map<String, String>> _sectoresCatalogo = [];
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
      final List<Map<String, String>> sectoresCatalogo = [];

      // Sectores de todos los eventos en paralelo.
      final sectoresPorEvento = await Future.wait(
        eventosSnapshot.docs.map((e) => FirestoreHelpers.getSectores(e.id)),
      );

      for (final (i, eventoDoc) in eventosSnapshot.docs.indexed) {
        final eventoId = eventoDoc.id;
        final eventoNombre =
            (eventoDoc.data() as Map<String, dynamic>)['nombre']?.toString() ??
            'Sin nombre';

        final sectoresSnapshot = sectoresPorEvento[i];
        final mermasPorSector = await Future.wait(
          sectoresSnapshot.docs.map(
            (s) => FirestoreHelpers.refMermasSector(
              eventoId,
              s.id,
            ).orderBy('fecha', descending: true).get(),
          ),
        );

        for (final (j, sectorDoc) in sectoresSnapshot.docs.indexed) {
          final sectorId = sectorDoc.id;
          final sectorNombre =
              (sectorDoc.data() as Map<String, dynamic>?)?['nombre']
                  ?.toString() ??
              'Sin sector';

          sectoresCatalogo.add({
            'id': '$eventoId|$sectorId',
            'eventoId': eventoId,
            'sectorId': sectorId,
            'nombre': sectorNombre,
            'eventoNombre': eventoNombre,
          });

          final mermasSnapshot = mermasPorSector[j];

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

      if (_sectorSeleccionadoId != null &&
          !_sectoresCatalogo.any((s) => s['id'] == _sectorSeleccionadoId)) {
        _sectorSeleccionadoId = null;
      }

      if (mounted) {
        setState(() {
          _mermas = list;
          _sectoresCatalogo = sectoresCatalogo;
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

      final parts = _sectorSeleccionadoId!.split('|');
      if (parts.length == 2) {
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
    final fuente = eidSel == null
        ? _sectoresCatalogo
        : _sectoresCatalogo.where((s) => s['eventoId'] == eidSel);

    for (final sector in fuente) {
      final id = sector['id'] ?? '';
      if (id.isEmpty) continue;
      final nombre = sector['nombre'] ?? 'Sector';
      final eventoNombre = sector['eventoNombre'] ?? '';
      op.add({
        'id': id,
        'nombre': eidSel == null ? '$nombre ($eventoNombre)' : nombre,
      });
    }

    op.sort((a, b) => (a['nombre'] ?? '').compareTo(b['nombre'] ?? ''));
    return op;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Mermas',
          style: AppFonts.inter(
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Solo activos',
                  style: AppFonts.inter(fontSize: 14, color: AppColors.tintaSecundaria),
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
          ? const CargandoTarjetas()
          : _errorMessage != null
          ? ErrorAmable(
              titulo: 'No pudimos cargar las mermas',
              detalle: _errorMessage,
              onReintentar: _cargar,
            )
          : _mermas.isEmpty
          ? EstadoVacio(
              titulo: _soloActivos
                  ? 'No hay mermas en eventos activos'
                  : 'No hay mermas registradas',
            )
          : RefreshIndicator(
              onRefresh: _cargar,
              color: AppColors.dorado,
              child: ListView(
                padding: conMargenInferior(context, const EdgeInsets.all(16)),
                children: [
                  _buildFiltros().entrada(),
                  const SizedBox(height: 16),
                  _buildCardPerdidaTotal().entrada(orden: 1),
                  Aparece(
                    child: _perdidaPorProducto().isEmpty
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _buildGraficoPerdida().entrada(orden: 2),
                          ),
                  ),
                  const SizedBox(height: 20),
                  const TituloSeccion(
                    icono: Icons.receipt_long_rounded,
                    titulo: 'Detalle de mermas',
                  ).entrada(orden: 3),
                  const SizedBox(height: 12),
                  if (_mermasFiltradas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: EstadoVacio(
                        titulo: 'No hay mermas con los filtros seleccionados',
                      ),
                    )
                  else
                    for (final (i, m) in _mermasFiltradas.indexed)
                      _buildCardMerma(m).entradaEnLista(i + 4),
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
            style: AppFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.tintaSecundaria,
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
                child: Text('Todos', style: AppFonts.inter(fontSize: 14)),
              ),
              ..._eventosOpciones.map(
                (e) => DropdownMenuItem<String>(
                  value: e['id'],
                  child: Text(
                    e['nombre'] ?? '',
                    style: AppFonts.inter(fontSize: 14),
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
                child: Text('Todos', style: AppFonts.inter(fontSize: 14)),
              ),
              ..._sectoresOpciones.map(
                (s) => DropdownMenuItem<String>(
                  value: s['id'],
                  child: Text(
                    s['nombre'] ?? '',
                    style: AppFonts.inter(fontSize: 14),
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
        gradient: AppGradientes.perdida,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.3),
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
              Icon(Icons.trending_down, color: AppColors.tinta, size: 22),
              const SizedBox(width: 8),
              Text(
                'Pérdida total',
                style: AppFonts.inter(
                  fontSize: 14,
                  color: AppColors.tinta,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CifraAnimada(
            valor: totalUnidades.toDouble(),
            formatear: (v) => '${v.round()} unidades',
            style: AppFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.tinta,
            ),
          ),
          if (totalValor > 0) ...[
            const SizedBox(height: 4),
            CifraAnimada(
              valor: totalValor,
              formatear: formatearPesos,
              style: AppFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.tinta,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Pérdida de las mermas filtradas, sumada por producto y ordenada de
  /// mayor a menor. En dinero si hay precios; si no, en unidades.
  List<({String nombre, String? detalle, double monto})> _perdidaPorProducto() {
    final unidades = <String, int>{};
    final dinero = <String, double>{};
    for (final m in _mermasFiltradas) {
      final nombre = m['nombreProducto'] as String? ?? 'Sin nombre';
      final cant = m['cantidadPerdida'] as int? ?? 0;
      final precio = (m['precio'] as num?)?.toDouble() ?? 0;
      unidades[nombre] = (unidades[nombre] ?? 0) + cant;
      dinero[nombre] = (dinero[nombre] ?? 0) + cant * precio;
    }
    final porDinero = dinero.values.any((v) => v > 0);
    final items = [
      for (final nombre in unidades.keys)
        if ((unidades[nombre] ?? 0) > 0)
          (
            nombre: nombre,
            detalle: porDinero ? '${unidades[nombre]} unidades' : null,
            monto: porDinero
                ? dinero[nombre]!
                : unidades[nombre]!.toDouble(),
          ),
    ]..sort((a, b) => b.monto.compareTo(a.monto));
    return items;
  }

  Widget _buildGraficoPerdida() {
    final items = _perdidaPorProducto();
    final porDinero = items.any((i) => i.detalle != null);
    return TarjetaGrafico(
      titulo: 'Productos con más pérdida',
      subtitulo: porDinero
          ? 'Valor perdido según el precio de cada producto'
          : 'Unidades perdidas',
      child: RankingBarras(
        // Un key por filtro: al cambiarlo, las barras vuelven a crecer.
        key: ValueKey('$_eventoSeleccionadoId|$_sectorSeleccionadoId'),
        formatear: porDinero
            ? formatearPesos
            : (v) => '${v.round()} u.',
        items: items.take(6).toList(),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.separador),
      ),
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
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.remove_circle_outline,
                    color: AppColors.error,
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
                        style: AppFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$eventoNombre · $sectorNombre',
                        style: AppFonts.inter(
                          fontSize: 14,
                          color: AppColors.tintaSecundaria,
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
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '-$cantidad',
                    style: AppFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
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
                border: Border.all(color: AppColors.tintaSecundaria.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Motivo',
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.tintaSecundaria,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    motivo,
                    style: AppFonts.inter(
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
              style: AppFonts.inter(
                fontSize: 14,
                color: AppColors.tintaSecundaria,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
