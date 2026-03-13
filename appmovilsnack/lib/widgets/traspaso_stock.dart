import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TraspasoStock extends StatefulWidget {
  final String eventoId;
  final String nombreEvento;
  final String? sectorIdDestinoInicial;
  final String? nombreSectorDestinoInicial;

  const TraspasoStock({
    super.key,
    required this.eventoId,
    required this.nombreEvento,
    this.sectorIdDestinoInicial,
    this.nombreSectorDestinoInicial,
  });

  @override
  State<TraspasoStock> createState() => _TraspasoStockState();
}

class _TraspasoStockState extends State<TraspasoStock> {
  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);
  final Color backgroundColor = const Color(0xFFFDFBF7);

  bool _isLoading = true;
  String? _error;

  List<Map<String, String>> _sectores = [];
  String? _sectorOrigenId;
  String? _sectorDestinoId;

  @override
  void initState() {
    super.initState();
    _cargarSectores();
  }

  Future<void> _cargarSectores() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .get();

      final sectores = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'nombre': (data['nombre'] as String?) ?? 'Sin Nombre',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _sectores = sectores;
          _sectorDestinoId =
              widget.sectorIdDestinoInicial ?? sectores.firstOrNull?['id'];

          // por defecto: primer sector distinto al destino
          _sectorOrigenId = sectores
              .where((s) => s['id'] != null && s['id'] != _sectorDestinoId)
              .firstOrNull?['id'];
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error cargando sectores: $e';
        });
      }
    }
  }

  Future<void> _pedirYTransferirProducto({
    required String productoId,
    required String nombre,
    required double precio,
    required int stockDisponible,
  }) async {
    final controller = TextEditingController();
    final cantidad = await showDialog<int?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Traspasar producto',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nombre,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Disponible en origen: $stockDisponible',
              style: GoogleFonts.poppins(color: secondaryColor),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cantidad a traspasar',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: Text('Cancelar', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              Navigator.of(dialogContext).pop(v);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: primaryColor,
            ),
            child: Text(
              'Traspasar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (cantidad == null) return;
    if (cantidad <= 0 || cantidad > stockDisponible) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cantidad inválida', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final origenId = _sectorOrigenId;
    final destinoId = _sectorDestinoId;
    if (origenId == null || destinoId == null) return;
    if (origenId == destinoId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El sector origen y destino no pueden ser el mismo.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final origenRef = FirebaseFirestore.instance
            .collection('eventos')
            .doc(widget.eventoId)
            .collection('sectores')
            .doc(origenId)
            .collection('stock')
            .doc(productoId);

        final destinoRef = FirebaseFirestore.instance
            .collection('eventos')
            .doc(widget.eventoId)
            .collection('sectores')
            .doc(destinoId)
            .collection('stock')
            .doc(productoId);

        // 1. --- TODAS LAS LECTURAS PRIMERO ---
        final origenSnap = await tx.get(origenRef);
        final destinoSnap = await tx.get(destinoRef);

        // 2. --- VALIDACIONES ---
        if (!origenSnap.exists) {
          throw Exception('El producto ya no existe en el sector origen.');
        }

        final origenData = origenSnap.data() as Map<String, dynamic>;
        final origenCantidad = origenData['cantidad'] as int? ?? 0;
        if (origenCantidad < cantidad) {
          throw Exception('Stock insuficiente en el sector origen.');
        }

        // 3. --- TODAS LAS ESCRITURAS AL FINAL ---
        // Descontamos del origen
        tx.update(origenRef, {'cantidad': origenCantidad - cantidad});

        // Sumamos al destino o lo creamos si no existe
        if (destinoSnap.exists) {
          final destData = destinoSnap.data() as Map<String, dynamic>;
          final destCantidad = destData['cantidad'] as int? ?? 0;
          tx.update(destinoRef, {'cantidad': destCantidad + cantidad});
        } else {
          tx.set(destinoRef, {
            'productoId': productoId,
            'nombre': nombre,
            'precio': precio,
            'cantidad': cantidad,
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Traspaso realizado', style: GoogleFonts.poppins()),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error en traspaso (${e.code}): ${e.message ?? e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error en traspaso: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Traspaso entre sectores',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: accentColor,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: GoogleFonts.poppins(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                _buildSelector(),
                Expanded(
                  child: _sectorOrigenId == null
                      ? Center(
                          child: Text(
                            'No hay sector origen disponible.',
                            style: GoogleFonts.poppins(color: secondaryColor),
                          ),
                        )
                      : _buildListaStockOrigen(),
                ),
              ],
            ),
    );
  }

  Widget _buildSelector() {
    final destinoNombre =
        _sectores.firstWhere(
          (s) => s['id'] == _sectorDestinoId,
          orElse: () => {'nombre': widget.nombreSectorDestinoInicial ?? ''},
        )['nombre'] ??
        widget.nombreSectorDestinoInicial ??
        '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Destino: ${destinoNombre.isEmpty ? 'Selecciona un sector' : destinoNombre}',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: primaryColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _sectorOrigenId,
                  decoration: InputDecoration(
                    labelText: 'Sector origen',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: _sectores
                      .where((s) => s['id'] != _sectorDestinoId)
                      .map(
                        (s) => DropdownMenuItem<String>(
                          value: s['id'],
                          child: Text(
                            s['nombre'] ?? 'Sin nombre',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _sectorOrigenId = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _sectorDestinoId,
                  decoration: InputDecoration(
                    labelText: 'Sector destino',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: _sectores
                      .where((s) => s['id'] != _sectorOrigenId)
                      .map(
                        (s) => DropdownMenuItem<String>(
                          value: s['id'],
                          child: Text(
                            s['nombre'] ?? 'Sin nombre',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _sectorDestinoId = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Toca un producto para traspasar cantidad al destino.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: secondaryColor.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaStockOrigen() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(_sectorOrigenId)
          .collection('stock')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: accentColor));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error cargando stock: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        docs.sort((a, b) {
          final ad = a.data() as Map<String, dynamic>;
          final bd = b.data() as Map<String, dynamic>;
          final an = ad['nombre']?.toString() ?? '';
          final bn = bd['nombre']?.toString() ?? '';
          return an.compareTo(bn);
        });
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No hay stock en el sector origen.',
              style: GoogleFonts.poppins(color: secondaryColor),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final nombre = data['nombre'] as String? ?? 'Sin nombre';
            final precio = (data['precio'] as num?)?.toDouble() ?? 0.0;
            final cantidad = data['cantidad'] as int? ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(Icons.fastfood, color: secondaryColor),
                title: Text(
                  nombre,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Stock: $cantidad  •  \$${precio.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: secondaryColor,
                  ),
                ),
                trailing: Icon(Icons.swap_horiz, color: accentColor),
                onTap: cantidad <= 0
                    ? null
                    : () => _pedirYTransferirProducto(
                        productoId: doc.id,
                        nombre: nombre,
                        precio: precio,
                        stockDisponible: cantidad,
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
