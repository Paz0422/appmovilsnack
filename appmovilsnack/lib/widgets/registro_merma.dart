import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// Paleta de colores basada en el logo "Fusión"
const Color _primaryColor = Color(0xFF2B2B2B);
const Color _accentColor = Color(0xFFDABF41);
const Color _secondaryColor = Color(0xFF6B4D2F);
const Color _backgroundColor = Color(0xFFFDFBF7);

/// Widget para registrar mermas (pérdidas) de productos en stock
class RegistroMerma extends StatelessWidget {
  final String eventoId;
  final String sectorId;
  final String nombreSector;

  const RegistroMerma({
    super.key,
    required this.eventoId,
    required this.sectorId,
    required this.nombreSector,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: Text(
            'Registro de Mermas',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: _accentColor,
            ),
          ),
          backgroundColor: _primaryColor,
          foregroundColor: _accentColor,
          bottom: TabBar(
            labelColor: _accentColor,
            unselectedLabelColor: Colors.white70,
            indicatorColor: _accentColor,
            tabs: [
              Tab(
                child: Text(
                  'Nueva Merma',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              Tab(
                child: Text(
                  'Historial',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Encabezado con pérdida total acumulada
            _PerdidaTotalAcumulada(eventoId: eventoId, sectorId: sectorId),
            // Tabs content
            Expanded(
              child: TabBarView(
                children: [
                  _TabNuevaMerma(eventoId: eventoId, sectorId: sectorId),
                  _TabHistorial(eventoId: eventoId, sectorId: sectorId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget que muestra la pérdida total acumulada
class _PerdidaTotalAcumulada extends StatelessWidget {
  final String eventoId;
  final String sectorId;

  const _PerdidaTotalAcumulada({
    required this.eventoId,
    required this.sectorId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eventos')
          .doc(eventoId)
          .collection('sectores')
          .doc(sectorId)
          .collection('mermas')
          .snapshots(),
      builder: (context, snapshot) {
        double perdidaTotal = 0.0;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final cantidadPerdida = data['cantidadPerdida'] as int? ?? 0;
            final precio = (data['precio'] as num?)?.toDouble() ?? 0.0;
            perdidaTotal += cantidadPerdida * precio;
          }
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red[700],
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pérdida Total Acumulada:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: _secondaryColor,
                    ),
                  ),
                ],
              ),
              Text(
                '\$${perdidaTotal.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tab 1: Nueva Merma
class _TabNuevaMerma extends StatelessWidget {
  final String eventoId;
  final String sectorId;

  const _TabNuevaMerma({required this.eventoId, required this.sectorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eventos')
          .doc(eventoId)
          .collection('sectores')
          .doc(sectorId)
          .collection('stock')
          .orderBy('nombre')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _accentColor));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar productos: ${snapshot.error}',
                    style: GoogleFonts.poppins(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: _secondaryColor.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay productos con stock disponible',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: _secondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No se pueden registrar mermas sin stock',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _secondaryColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        final productos = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final cantidad = data['cantidad'] as int? ?? 0;
          return cantidad > 0;
        }).toList();

        if (productos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: _secondaryColor.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay productos con stock disponible',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: _secondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No se pueden registrar mermas sin stock',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _secondaryColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: productos.length,
          itemBuilder: (context, index) {
            final productoDoc = productos[index];
            final data = productoDoc.data() as Map<String, dynamic>;
            final nombre = data['nombre'] as String? ?? 'Sin nombre';
            final precio = (data['precio'] as num?)?.toDouble() ?? 0.0;
            final cantidad = data['cantidad'] as int? ?? 0;

            return _ProductoMermaCard(
              productoId: productoDoc.id,
              nombre: nombre,
              precio: precio,
              cantidad: cantidad,
              eventoId: eventoId,
              sectorId: sectorId,
            );
          },
        );
      },
    );
  }
}

/// Tab 2: Historial de Mermas
class _TabHistorial extends StatelessWidget {
  final String eventoId;
  final String sectorId;

  const _TabHistorial({required this.eventoId, required this.sectorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eventos')
          .doc(eventoId)
          .collection('sectores')
          .doc(sectorId)
          .collection('mermas')
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _accentColor));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar historial: ${snapshot.error}',
                    style: GoogleFonts.poppins(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: _secondaryColor.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay mermas registradas',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: _secondaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Las mermas registradas aparecerán aquí',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _secondaryColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        final mermas = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: mermas.length,
          itemBuilder: (context, index) {
            final mermaDoc = mermas[index];
            final data = mermaDoc.data() as Map<String, dynamic>;
            final nombreProducto =
                data['nombreProducto'] as String? ?? 'Sin nombre';
            final cantidadPerdida = data['cantidadPerdida'] as int? ?? 0;
            final motivo = data['motivo'] as String? ?? 'Sin motivo';
            final fecha = data['fecha'] as Timestamp?;

            String horaFormato = '--:--';
            if (fecha != null) {
              final fechaDateTime = fecha.toDate();
              horaFormato =
                  '${fechaDateTime.hour.toString().padLeft(2, '0')}:${fechaDateTime.minute.toString().padLeft(2, '0')}';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Colors.red[700],
                    size: 28,
                  ),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        nombreProducto,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-$cantidadPerdida',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: _secondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          horaFormato,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _secondaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      motivo,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _secondaryColor.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                trailing: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red[700],
                  size: 20,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Card individual para cada producto en stock
class _ProductoMermaCard extends StatelessWidget {
  final String productoId;
  final String nombre;
  final double precio;
  final int cantidad;
  final String eventoId;
  final String sectorId;

  const _ProductoMermaCard({
    required this.productoId,
    required this.nombre,
    required this.precio,
    required this.cantidad,
    required this.eventoId,
    required this.sectorId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _mostrarFormularioMerma(context),
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.inventory_2, color: Colors.orange[700], size: 28),
          ),
          title: Text(
            nombre,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _primaryColor,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'Precio: \$${precio.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _secondaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Stock: $cantidad',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: _accentColor,
            size: 18,
          ),
        ),
      ),
    );
  }

  void _mostrarFormularioMerma(BuildContext context) {
    final cantidadController = TextEditingController();
    final motivoController = TextEditingController();
    bool isGuardando = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Registrar Merma',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Información del producto
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stock disponible: $cantidad',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Campo de cantidad
                TextField(
                  controller: cantidadController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Cantidad perdida',
                    hintText: 'Ingresa la cantidad',
                    prefixIcon: const Icon(Icons.numbers),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _accentColor, width: 2),
                    ),
                  ),
                  style: GoogleFonts.poppins(),
                ),
                const SizedBox(height: 16),
                // Campo de motivo
                TextField(
                  controller: motivoController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Motivo de la pérdida',
                    hintText: 'Ej: Se cayó, Vencido, Dañado...',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _accentColor, width: 2),
                    ),
                  ),
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isGuardando ? null : () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(color: _secondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: isGuardando
                  ? null
                  : () async {
                      final cantidadPerdida = int.tryParse(
                        cantidadController.text.trim(),
                      );
                      final motivo = motivoController.text.trim();

                      // Validaciones
                      if (cantidadPerdida == null || cantidadPerdida <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Ingresa una cantidad válida mayor a 0',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (cantidadPerdida > cantidad) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'La cantidad perdida no puede ser mayor al stock disponible ($cantidad)',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (motivo.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Debes ingresar un motivo para la merma',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setDialogState(() {
                        isGuardando = true;
                      });

                      try {
                        await _registrarMerma(
                          cantidadPerdida: cantidadPerdida,
                          motivo: motivo,
                        );

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Merma registrada exitosamente',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isGuardando = false;
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error al registrar merma: $e',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: _primaryColor,
                disabledBackgroundColor: Colors.grey,
              ),
              child: isGuardando
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primaryColor,
                      ),
                    )
                  : Text(
                      'Registrar Merma',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Registra la merma usando una transacción atómica
  Future<void> _registrarMerma({
    required int cantidadPerdida,
    required String motivo,
  }) async {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // 1. Obtener referencia al producto en stock
      final stockRef = FirebaseFirestore.instance
          .collection('eventos')
          .doc(eventoId)
          .collection('sectores')
          .doc(sectorId)
          .collection('stock')
          .doc(productoId);

      // 2. Leer el documento actual del stock
      final stockDoc = await transaction.get(stockRef);

      if (!stockDoc.exists) {
        throw Exception('El producto no existe en el stock');
      }

      final stockData = stockDoc.data() as Map<String, dynamic>;
      final cantidadActual = stockData['cantidad'] as int? ?? 0;

      // 3. Validar que hay suficiente stock
      if (cantidadActual < cantidadPerdida) {
        throw Exception(
          'Stock insuficiente. Disponible: $cantidadActual, Solicitado: $cantidadPerdida',
        );
      }

      // 4. Descontar la cantidad del stock
      transaction.update(stockRef, {
        'cantidad': cantidadActual - cantidadPerdida,
      });

      // 5. Crear documento de merma
      final mermaRef = FirebaseFirestore.instance
          .collection('eventos')
          .doc(eventoId)
          .collection('sectores')
          .doc(sectorId)
          .collection('mermas')
          .doc();

      transaction.set(mermaRef, {
        'fecha': FieldValue.serverTimestamp(),
        'productoId': productoId,
        'nombreProducto': nombre,
        'cantidadPerdida': cantidadPerdida,
        'motivo': motivo,
        'precio': precio, // Guardar precio para referencia histórica
      });
    });
  }
}
