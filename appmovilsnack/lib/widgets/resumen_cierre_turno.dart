import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

/// Pantalla informativa que muestra el resumen de stock y ventas del sector
/// al cerrar el turno. Permite exportar el contenido como texto.
class ResumenCierreTurno extends StatefulWidget {
  final String eventoId;
  final String sectorId;
  final String nombreSector;
  final String? nombreEvento;
  /// Si es true (entró como admin), se muestra botón para volver al panel sin cerrar sesión.
  final bool fromAdmin;

  const ResumenCierreTurno({
    super.key,
    required this.eventoId,
    required this.sectorId,
    required this.nombreSector,
    this.nombreEvento,
    this.fromAdmin = false,
  });

  @override
  State<ResumenCierreTurno> createState() => _ResumenCierreTurnoState();
}

class _ResumenCierreTurnoState extends State<ResumenCierreTurno> {
  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);
  final Color backgroundColor = const Color(0xFFFDFBF7);

  List<Map<String, dynamic>> _stock = [];
  double _totalVendido = 0.0;
  double _totalEfectivo = 0.0;
  double _totalTarjeta = 0.0;
  int _cantidadVentas = 0;
  bool _isLoading = true;
  String? _nombreEvento;

  @override
  void initState() {
    super.initState();
    _nombreEvento = widget.nombreEvento ?? widget.eventoId;
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      // Cargar stock actual
      final stockSnapshot = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId)
          .collection('stock')
          .orderBy('nombre')
          .get();

      // Cargar transacciones del sector
      final transaccionesSnapshot = await FirebaseFirestore.instance
          .collection('transacciones')
          .where('eventoId', isEqualTo: widget.eventoId)
          .where('sectorId', isEqualTo: widget.sectorId)
          .get();

      double totalVendido = 0.0;
      double totalEfectivo = 0.0;
      double totalTarjeta = 0.0;
      for (var doc in transaccionesSnapshot.docs) {
        final data = doc.data();
        final monto = (data['montoTotal'] as num?)?.toDouble() ?? 0.0;
        totalVendido += monto;
        final metodo = data['metodoPago']?.toString().toLowerCase() ?? '';
        if (metodo.contains('efectivo')) {
          totalEfectivo += monto;
        } else if (metodo.contains('tarjeta')) {
          totalTarjeta += monto;
        }
      }

      if (mounted) {
        setState(() {
          _stock = stockSnapshot.docs.map((doc) {
            final d = doc.data();
            return {
              'nombre': d['nombre'] as String? ?? 'Sin nombre',
              'precio': (d['precio'] as num?)?.toDouble() ?? 0.0,
              'cantidad': d['cantidad'] as int? ?? 0,
            };
          }).toList();
          _totalVendido = totalVendido;
          _totalEfectivo = totalEfectivo;
          _totalTarjeta = totalTarjeta;
          _cantidadVentas = transaccionesSnapshot.docs.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando resumen: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _generarTextoExportable() {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('     RESUMEN DE CIERRE DE TURNO');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('Evento: $_nombreEvento');
    buffer.writeln('Sector: ${widget.nombreSector}');
    buffer.writeln(
      'Fecha: ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
    );
    buffer.writeln(
      'Hora: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    );
    buffer.writeln();
    buffer.writeln('───────────────────────────────────────');
    buffer.writeln('VENTAS DEL SECTOR');
    buffer.writeln('───────────────────────────────────────');
    buffer.writeln('Cantidad de ventas: $_cantidadVentas');
    buffer.writeln('Total vendido: \$${_totalVendido.toStringAsFixed(0)}');
    buffer.writeln(' - Efectivo: \$${_totalEfectivo.toStringAsFixed(0)}');
    buffer.writeln(' - Tarjeta:  \$${_totalTarjeta.toStringAsFixed(0)}');
    buffer.writeln();
    buffer.writeln('───────────────────────────────────────');
    buffer.writeln('STOCK ACTUAL');
    buffer.writeln('───────────────────────────────────────');
    for (var item in _stock) {
      buffer.writeln(
        '• ${item['nombre']}: ${item['cantidad']} unidades (\$${(item['precio'] as double).toStringAsFixed(0)} c/u)',
      );
    }
    buffer.writeln();
    buffer.writeln('═══════════════════════════════════════');
    return buffer.toString();
  }

  Future<void> _exportarTexto() async {
    try {
      await Share.share(
        _generarTextoExportable(),
        subject: 'Resumen Cierre Turno - ${widget.nombreSector}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al exportar: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmarCierre() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? vendedorNombre;
      if (user != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .get();
          vendedorNombre = userDoc.data()?['username']?.toString();
        } catch (_) {}
        vendedorNombre ??= user.displayName ?? user.email;
      }

      final sectorRef = FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId);

      final sectorSnap = await sectorRef.get();
      if (sectorSnap.exists && sectorSnap.data() != null) {
        final data = sectorSnap.data()!;
        List<dynamic> vendedores = List.from(data['vendedoresasignados'] ?? []);
        if (vendedorNombre != null && vendedorNombre.isNotEmpty) {
          vendedores.removeWhere((v) {
            final n = v is Map ? v['nombre']?.toString() : null;
            return n == vendedorNombre;
          });
        }
        await sectorRef.update({
          'vendedoresasignados': vendedores,
          'turnoCerrado': true,
          'turnoCerradoAt': FieldValue.serverTimestamp(),
        });
      }

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('Error en cierre de turno: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cerrar turno: $e',
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
        leading: widget.fromAdmin
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Volver al panel de vendedor',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'Resumen Cierre de Turno',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: accentColor,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
        actions: [
          if (widget.fromAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'Volver al panel de administración',
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _isLoading ? null : _exportarTexto,
            tooltip: 'Exportar como texto',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 20),
                  _buildVentasCard(),
                  const SizedBox(height: 20),
                  _buildStockCard(),
                  const SizedBox(height: 24),
                  _buildExportButton(),
                  const SizedBox(height: 16),
                  _buildCerrarButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evento: $_nombreEvento',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sector: ${widget.nombreSector}',
            style: GoogleFonts.poppins(fontSize: 14, color: secondaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year} - ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: secondaryColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVentasCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total vendido en el sector',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${_totalVendido.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Efectivo: \$${_totalEfectivo.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Tarjeta: \$${_totalTarjeta.toStringAsFixed(0)}',
                  textAlign: TextAlign.end,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$_cantidadVentas venta${_cantidadVentas == 1 ? '' : 's'} realizada${_cantidadVentas == 1 ? '' : 's'}',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stock actual',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          if (_stock.isEmpty)
            Text(
              'No hay productos en stock',
              style: GoogleFonts.poppins(fontSize: 14, color: secondaryColor),
            )
          else
            ..._stock.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['nombre'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    Text(
                      '${item['cantidad']} unidades',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: secondaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _exportarTexto,
        icon: const Icon(Icons.share),
        label: Text(
          'Exportar resumen como texto',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildCerrarButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _confirmarCierre,
        icon: const Icon(Icons.check_circle_outline),
        label: Text(
          'Finalizar y volver al inicio',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: accentColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
