// Admin: reposición de stock durante el evento. Suma unidades a un producto de
// un sector abierto (StockService.agregarStock) y deja registro del movimiento.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/auth_manager.dart';
import '../core/app_theme.dart';
import '../services/firestore_helpers.dart';
import '../services/stock_service.dart';
import 'package:front_appsnack/core/margen_inferior.dart';

class AgregarStock extends StatefulWidget {
  const AgregarStock({super.key});

  @override
  State<AgregarStock> createState() => _AgregarStockState();
}

class _AgregarStockState extends State<AgregarStock> {
  final _service = StockService();
  bool _cargandoEventos = true;
  List<QueryDocumentSnapshot> _eventos = [];
  String? _eventoId;
  String? _sectorId;

  @override
  void initState() {
    super.initState();
    _cargarEventos();
  }

  Future<void> _cargarEventos() async {
    try {
      final snap = await FirestoreHelpers.getEventosActivos();
      if (!mounted) return;
      setState(() {
        _eventos = snap.docs;
        _eventoId = snap.docs.length == 1 ? snap.docs.first.id : null;
        _cargandoEventos = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoEventos = false);
    }
  }

  String _nombre(DocumentSnapshot doc) =>
      (doc.data() as Map<String, dynamic>?)?['nombre']?.toString() ?? doc.id;

  Future<void> _agregar({
    required String productoId,
    required String nombreProducto,
    required String nombreSector,
    required int stockActual,
  }) async {
    final cantidadController = TextEditingController();
    final motivoController = TextEditingController();
    String? error;

    final resultado = await showDialog<({int cantidad, String motivo})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'Agregar stock',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$nombreProducto · $nombreSector\nStock actual: $stockActual u.',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cantidadController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Unidades a sumar',
                  errorText: error,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: motivoController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Motivo (opcional)',
                  hintText: 'Ej: compra durante el evento',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final n = int.tryParse(cantidadController.text.trim());
                if (n == null || n <= 0) {
                  setDialogState(() => error = 'Ingrese un número mayor que 0');
                  return;
                }
                Navigator.of(ctx).pop((cantidad: n, motivo: motivoController.text));
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
    cantidadController.dispose();
    motivoController.dispose();
    if (resultado == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.agregarStock(
        eventoId: _eventoId!,
        sectorId: _sectorId!,
        productoId: productoId,
        cantidad: resultado.cantidad,
        motivo: resultado.motivo,
        adminUid: FirebaseAuth.instance.currentUser?.uid ?? '',
        adminNombre:
            AuthManager().loggedInVendor?.data()?['username']?.toString(),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Se agregaron ${resultado.cantidad} u. de $nombreProducto a $nombreSector.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on StockException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.mensaje, style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo agregar: $e', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Agregar stock',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.accent,
      ),
      body: _cargandoEventos
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _eventos.isEmpty
              ? Center(
                  child: Text(
                    'No hay eventos activos.',
                    style: GoogleFonts.poppins(color: AppColors.onSurfaceVariant),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: DropdownButtonFormField<String>(
                        initialValue: _eventoId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Evento'),
                        items: [
                          for (final e in _eventos)
                            DropdownMenuItem(value: e.id, child: Text(_nombre(e))),
                        ],
                        onChanged: (v) => setState(() {
                          _eventoId = v;
                          _sectorId = null;
                        }),
                      ),
                    ),
                    if (_eventoId != null) _buildSelectorSector(),
                    Expanded(
                      child: _eventoId == null || _sectorId == null
                          ? Center(
                              child: Text(
                                'Elija un evento y un sector abierto.',
                                style: GoogleFonts.poppins(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            )
                          : _buildProductos(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSelectorSector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreHelpers.streamSectores(_eventoId!),
      builder: (context, snap) {
        final sectores = snap.data?.docs ?? const [];
        bool cerrado(DocumentSnapshot s) =>
            (s.data() as Map<String, dynamic>?)?['turnoCerrado'] == true;
        final seleccionValida = sectores.any(
          (s) => s.id == _sectorId && !cerrado(s),
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: DropdownButtonFormField<String>(
            key: ValueKey(_eventoId),
            initialValue: seleccionValida ? _sectorId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Sector'),
            items: [
              for (final s in sectores)
                DropdownMenuItem(
                  value: s.id,
                  enabled: !cerrado(s),
                  child: Text(
                    cerrado(s) ? '${_nombre(s)} (Turno cerrado)' : _nombre(s),
                    style: cerrado(s) ? const TextStyle(color: Colors.grey) : null,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _sectorId = v),
          ),
        );
      },
    );
  }

  Widget _buildProductos() {
    final sectorRef = FirebaseFirestore.instance
        .collection('eventos')
        .doc(_eventoId)
        .collection('sectores')
        .doc(_sectorId);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: sectorRef.snapshots(),
      builder: (context, sectorSnap) {
        final nombreSector = sectorSnap.data?.data()?['nombre']?.toString() ?? '';
        if (sectorSnap.data?.data()?['turnoCerrado'] == true) {
          return Center(
            child: Text(
              'Este sector cerró su turno: no se puede agregar stock.',
              style: GoogleFonts.poppins(color: AppColors.onSurfaceVariant),
            ),
          );
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: sectorRef.collection('stock').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              );
            }
            final docs = [...snap.data!.docs]..sort(
                (a, b) => (a.data()['nombre']?.toString() ?? '')
                    .compareTo(b.data()['nombre']?.toString() ?? ''),
              );
            if (docs.isEmpty) {
              return Center(
                child: Text(
                  'El sector no tiene stock cargado.',
                  style: GoogleFonts.poppins(color: AppColors.onSurfaceVariant),
                ),
              );
            }
            return ListView.separated(
              padding: conMargenInferior(context, const EdgeInsets.fromLTRB(16, 8, 16, 16)),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = docs[i].data();
                final nombre = d['nombre']?.toString() ?? docs[i].id;
                final cantidad = (d['cantidad'] as num?)?.toInt() ?? 0;
                return ListTile(
                  title: Text(nombre, style: GoogleFonts.poppins()),
                  subtitle: Text(
                    'Stock: $cantidad u.',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.add_circle, color: AppColors.accent),
                    tooltip: 'Agregar stock',
                    onPressed: () => _agregar(
                      productoId: docs[i].id,
                      nombreProducto: nombre,
                      nombreSector: nombreSector,
                      stockActual: cantidad,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
