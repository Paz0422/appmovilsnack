// Archivo: lib/widgets/asignacion_personal.dart
// Módulo de Asignación de Personal - Gestión de vendedores por sector de evento

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AsignacionPersonal extends StatefulWidget {
  const AsignacionPersonal({super.key});

  @override
  State<AsignacionPersonal> createState() => _AsignacionPersonalState();
}

class _AsignacionPersonalState extends State<AsignacionPersonal> {
  String? _eventoSeleccionadoId;
  String? _nombreEventoSeleccionado;
  String? _sectorSeleccionadoId;
  String? _nombreSectorSeleccionado;
  
  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);
  final Color backgroundColor = const Color(0xFFFDFBF7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Asignación de Personal',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
        actions: [
          if (_eventoSeleccionadoId != null && _sectorSeleccionadoId != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar',
              onPressed: () {
                setState(() {
                  _eventoSeleccionadoId = null;
                  _nombreEventoSeleccionado = null;
                  _sectorSeleccionadoId = null;
                  _nombreSectorSeleccionado = null;
                });
              },
            ),
        ],
      ),
      body: _eventoSeleccionadoId == null
          ? _buildSeleccionEvento()
          : _sectorSeleccionadoId == null
              ? _buildSeleccionSector()
              : _buildGestionPersonal(),
    );
  }

  Widget _buildSeleccionEvento() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eventos')
          .orderBy('nombre')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: accentColor),
          );
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
                    'Error al cargar eventos: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: secondaryColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 64,
                    color: secondaryColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay eventos disponibles',
                    style: GoogleFonts.poppins(
                      color: secondaryColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final eventos = snapshot.data!.docs;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecciona un Evento',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: eventos.length,
                  itemBuilder: (context, index) {
                    final evento = eventos[index];
                    final data = evento.data() as Map<String, dynamic>;
                    final nombreEvento = data['nombre']?.toString() ?? 'Sin nombre';

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
                            color: accentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.event,
                            color: accentColor,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          nombreEvento,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: primaryColor,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: accentColor,
                          size: 20,
                        ),
                        onTap: () {
                          setState(() {
                            _eventoSeleccionadoId = evento.id;
                            _nombreEventoSeleccionado = nombreEvento;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeleccionSector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eventos')
          .doc(_eventoSeleccionadoId!)
          .collection('sectores')
          .orderBy('nombre')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: accentColor),
          );
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
                    'Error al cargar sectores: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: secondaryColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _eventoSeleccionadoId = null;
                        _nombreEventoSeleccionado = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: primaryColor,
                    ),
                    child: Text(
                      'Volver',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 64,
                    color: secondaryColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay sectores disponibles para este evento',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: secondaryColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _eventoSeleccionadoId = null;
                        _nombreEventoSeleccionado = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: primaryColor,
                    ),
                    child: Text(
                      'Volver',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final sectores = snapshot.data!.docs;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: accentColor),
                    onPressed: () {
                      setState(() {
                        _eventoSeleccionadoId = null;
                        _nombreEventoSeleccionado = null;
                      });
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evento: $_nombreEventoSeleccionado',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: secondaryColor,
                          ),
                        ),
                        Text(
                          'Selecciona un Sector',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: sectores.length,
                  itemBuilder: (context, index) {
                    final sector = sectores[index];
                    final data = sector.data() as Map<String, dynamic>;
                    final nombreSector = data['nombre']?.toString() ?? 'Sin nombre';

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
                            color: secondaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: secondaryColor,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          nombreSector,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: primaryColor,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: accentColor,
                          size: 20,
                        ),
                        onTap: () {
                          setState(() {
                            _sectorSeleccionadoId = sector.id;
                            _nombreSectorSeleccionado = nombreSector;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGestionPersonal() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'vendedor')
          .orderBy('username')
          .snapshots(),
      builder: (context, vendedoresSnapshot) {
        if (vendedoresSnapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: accentColor),
          );
        }

        if (vendedoresSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar vendedores: ${vendedoresSnapshot.error}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: secondaryColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _sectorSeleccionadoId = null;
                        _nombreSectorSeleccionado = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: primaryColor,
                    ),
                    child: Text(
                      'Volver',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!vendedoresSnapshot.hasData || vendedoresSnapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: secondaryColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay vendedores disponibles',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: secondaryColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _sectorSeleccionadoId = null;
                        _nombreSectorSeleccionado = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: primaryColor,
                    ),
                    child: Text(
                      'Volver',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final vendedores = vendedoresSnapshot.data!.docs;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('eventos')
              .doc(_eventoSeleccionadoId!)
              .collection('sectores')
              .doc(_sectorSeleccionadoId!)
              .snapshots(),
          builder: (context, sectorSnapshot) {
            List<String> vendedoresAsignadosIds = [];
            
            if (sectorSnapshot.hasData && sectorSnapshot.data!.exists) {
              final sectorData = sectorSnapshot.data!.data() as Map<String, dynamic>?;
              final personalAsignado = sectorData?['personalAsignado'] as List<dynamic>?;
              if (personalAsignado != null) {
                vendedoresAsignadosIds = personalAsignado
                    .map((item) => item.toString())
                    .toList()
                    .cast<String>();
              }
            }

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: primaryColor.withOpacity(0.05),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: accentColor),
                        onPressed: () {
                          setState(() {
                            _sectorSeleccionadoId = null;
                            _nombreSectorSeleccionado = null;
                          });
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Evento: $_nombreEventoSeleccionado',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: secondaryColor,
                              ),
                            ),
                            Text(
                              'Sector: $_nombreSectorSeleccionado',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Vendedores asignados: ${vendedoresAsignadosIds.length}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: vendedores.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: secondaryColor.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay vendedores disponibles',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: secondaryColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: vendedores.length,
                          itemBuilder: (context, index) {
                            final vendedor = vendedores[index];
                            final vendedorData = vendedor.data() as Map<String, dynamic>;
                            final vendedorId = vendedor.id;
                            final username = vendedorData['username']?.toString() ?? 'Sin nombre';
                            final email = vendedorData['email']?.toString() ?? '';
                            final itemsVendidos = vendedorData['itemsvendidos'] as num? ?? 0;
                            final totalVendido = vendedorData['totalvendido'] as num? ?? 0;
                            
                            final isAsignado = vendedoresAsignadosIds.contains(vendedorId);

                            return _PersonalCard(
                              vendedorId: vendedorId,
                              username: username,
                              email: email,
                              itemsVendidos: itemsVendidos.toInt(),
                              totalVendido: totalVendido.toDouble(),
                              isAsignado: isAsignado,
                              eventoId: _eventoSeleccionadoId!,
                              sectorId: _sectorSeleccionadoId!,
                              primaryColor: primaryColor,
                              accentColor: accentColor,
                              secondaryColor: secondaryColor,
                              backgroundColor: backgroundColor,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PersonalCard extends StatefulWidget {
  final String vendedorId;
  final String username;
  final String email;
  final int itemsVendidos;
  final double totalVendido;
  final bool isAsignado;
  final String eventoId;
  final String sectorId;
  final Color primaryColor;
  final Color accentColor;
  final Color secondaryColor;
  final Color backgroundColor;

  const _PersonalCard({
    required this.vendedorId,
    required this.username,
    required this.email,
    required this.itemsVendidos,
    required this.totalVendido,
    required this.isAsignado,
    required this.eventoId,
    required this.sectorId,
    required this.primaryColor,
    required this.accentColor,
    required this.secondaryColor,
    required this.backgroundColor,
  });

  @override
  State<_PersonalCard> createState() => _PersonalCardState();
}

class _PersonalCardState extends State<_PersonalCard> {
  bool _isSaving = false;

  Future<void> _toggleAsignacion() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final sectorRef = FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .collection('sectores')
          .doc(widget.sectorId);

      final sectorDoc = await sectorRef.get();
      
      List<String> personalAsignado = [];
      if (sectorDoc.exists) {
        final sectorData = sectorDoc.data();
        final personalData = sectorData?['personalAsignado'] as List<dynamic>?;
        if (personalData != null) {
          personalAsignado = personalData
              .map((item) => item.toString())
              .toList();
        }
      }

      if (widget.isAsignado) {
        // Desasignar: remover el vendedor de la lista
        personalAsignado.remove(widget.vendedorId);
      } else {
        // Asignar: agregar el vendedor a la lista
        if (!personalAsignado.contains(widget.vendedorId)) {
          personalAsignado.add(widget.vendedorId);
        }
      }

      await sectorRef.set({
        'personalAsignado': personalAsignado,
        'nombre': sectorDoc.data()?['nombre'] ?? 'Sin nombre',
      }, SetOptions(merge: true));

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isAsignado
                  ? 'Vendedor desasignado exitosamente'
                  : 'Vendedor asignado exitosamente',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al ${widget.isAsignado ? "desasignar" : "asignar"} vendedor: $e',
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.isAsignado ? Colors.green : Colors.transparent,
          width: widget.isAsignado ? 2 : 0,
        ),
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
            color: widget.isAsignado
                ? Colors.green.withOpacity(0.2)
                : widget.accentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            widget.isAsignado ? Icons.person : Icons.person_outline,
            color: widget.isAsignado ? Colors.green : widget.accentColor,
            size: 28,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.username,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: widget.primaryColor,
                ),
              ),
            ),
            if (widget.isAsignado)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Asignado',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              widget.email,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: widget.secondaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.shopping_cart,
                  size: 14,
                  color: widget.secondaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Items: ${widget.itemsVendidos}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: widget.secondaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.attach_money,
                  size: 14,
                  color: widget.secondaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Total: \$${widget.totalVendido.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: widget.secondaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: _isSaving
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.accentColor,
                ),
              )
            : IconButton(
                icon: Icon(
                  widget.isAsignado ? Icons.remove_circle : Icons.add_circle,
                  color: widget.isAsignado ? Colors.red : Colors.green,
                ),
                onPressed: _toggleAsignacion,
                tooltip: widget.isAsignado ? 'Desasignar' : 'Asignar',
              ),
      ),
    );
  }
}
