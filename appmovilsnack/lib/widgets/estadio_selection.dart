import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:front_appsnack/screens/vendedores/home_vendedor.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/services/firestore_helpers.dart';
import 'package:google_fonts/google_fonts.dart';

// Compatibilidad con referencias existentes
const Color primaryColor = AppColors.primaryLight;
const Color accentColor = AppColors.accent;
const Color secondaryColor = AppColors.secondary;
const Color backgroundColor = AppColors.surface;

class EstadioSelection extends StatefulWidget {
  /// Si es true, el usuario viene del panel admin y al entrar al vendedor se mostrará "Volver al panel admin".
  final bool fromAdmin;

  const EstadioSelection({super.key, this.fromAdmin = false});

  @override
  State<EstadioSelection> createState() => _EstadioSelectionState();
}

class _EstadioSelectionState extends State<EstadioSelection> {
  late final Stream<QuerySnapshot> _eventosStream = FirestoreHelpers.streamEventosActivos();

  String? _eventoSeleccionadoId;
  String? _nombreEventoSeleccionado;
  String? _sectorSeleccionado;
  String? _sectorSeleccionadoId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/imagenes/logo.png",
              height: 35,
            ), // Logo en el AppBar
            const SizedBox(width: 10),
            Text(
              "Fusión",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // --- LOGO DE FONDO (MARCA DE AGUA) ---
          Center(
            child: Opacity(
              opacity: 0.07, // Ajusta la transparencia aquí (0.0 a 1.0)
              child: Image.asset(
                "assets/imagenes/logo.png",
                width: MediaQuery.of(context).size.width * 0.7, // 70% del ancho
                fit: BoxFit.contain,
              ),
            ),
          ),

          // --- CONTENIDO PRINCIPAL ---
          StreamBuilder<QuerySnapshot>(
            stream: _eventosStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: accentColor),
                );
              }

              final eventos = snapshot.data?.docs ?? [];

              if (eventos.isEmpty) {
                return const Center(child: Text('No hay eventos activos.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 160, top: 16),
                itemCount: eventos.length,
                itemBuilder: (context, index) {
                  final eventoDoc = eventos[index];
                  final eventoData = eventoDoc.data() as Map<String, dynamic>;

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppShadows.card,
                    ),
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: PageStorageKey<String>(
                          eventoDoc.id,
                        ), // Persistencia de apertura
                        leading: const Icon(
                          Icons.stadium_outlined,
                          color: accentColor,
                          size: 32,
                        ),
                        title: Text(
                          eventoData['nombre'] ?? 'Evento',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: primaryColor,
                          ),
                        ),
                        subtitle: Text(
                          eventoData['ubicacion'] ?? 'Sin ubicación',
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            color: secondaryColor,
                          ),
                        ),
                        iconColor: accentColor,
                        children: [
                          SectoresList(
                            eventoId: eventoDoc.id,
                            sectorSeleccionadoId: _sectorSeleccionadoId,
                            onSectorTap: (id, nombre) {
                              setState(() {
                                _eventoSeleccionadoId = eventoDoc.id;
                                _nombreEventoSeleccionado =
                                    eventoData['nombre'];
                                _sectorSeleccionadoId = id;
                                _sectorSeleccionado = nombre;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // --- PANEL DE CONFIRMACIÓN ---
          if (_sectorSeleccionadoId != null) _buildConfirmPanel(),
        ],
      ),
    );
  }

  Widget _buildConfirmPanel() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_nombreEventoSeleccionado',
              style: GoogleFonts.poppins(fontSize: 14, color: secondaryColor),
            ),
            Text(
              'Sector: $_sectorSeleccionado',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                ),
                onPressed: () async {
                  // No permitir entrar a sectores con turno cerrado
                  final sectorDoc = await FirestoreHelpers.getSector(
                    _eventoSeleccionadoId!,
                    _sectorSeleccionadoId!,
                  );
                  final sectorData = sectorDoc.data() as Map<String, dynamic>?;
                  if (sectorDoc.exists &&
                      sectorData != null &&
                      sectorData['turnoCerrado'] == true) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Este sector tiene el turno cerrado. Un administrador debe reabrirlo desde Gestión de eventos.',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                    return;
                  }
                  final bool puedeCerrarTurno;
                  if (widget.fromAdmin) {
                    puedeCerrarTurno = true; // El admin también puede cerrar turno
                  } else {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      puedeCerrarTurno = false;
                    } else {
                      final doc = await FirebaseFirestore.instance
                          .collection('usuarios')
                          .doc(user.uid)
                          .get();
                      final rol = doc.data()?['rol']?.toString() ?? 'vendedor';
                      puedeCerrarTurno = rol == 'encargado';
                    }
                  }
                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomeVendedor(
                        eventId: _eventoSeleccionadoId!,
                        sectorId: _sectorSeleccionadoId!,
                        nombreSector: _sectorSeleccionado!,
                        fromAdmin: widget.fromAdmin,
                        puedeCerrarTurno: puedeCerrarTurno,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'CONTINUAR',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET DE SECTORES ---
class SectoresList extends StatelessWidget {
  final String eventoId;
  final String? sectorSeleccionadoId;
  final Function(String id, String nombre) onSectorTap;

  const SectoresList({
    super.key,
    required this.eventoId,
    this.sectorSeleccionadoId,
    required this.onSectorTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreHelpers.streamSectores(eventoId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: LinearProgressIndicator(
              color: accentColor,
              backgroundColor: Colors.white24,
            ),
          );
        }

        final sectores = snapshot.data?.docs ?? [];

        return Column(
          children: sectores.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final nombre = data['nombre'] ?? 'Sector';
            final turnoCerrado = data['turnoCerrado'] == true;
            final isSelected = sectorSeleccionadoId == doc.id;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 30),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      nombre,
                      style: GoogleFonts.lato(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: turnoCerrado
                            ? Colors.grey
                            : (isSelected ? accentColor : primaryColor),
                      ),
                    ),
                  ),
                  if (turnoCerrado)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        'Turno cerrado',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: turnoCerrado
                  ? const Icon(Icons.lock_outline, color: Colors.grey, size: 20)
                  : (isSelected
                      ? const Icon(Icons.check_circle, color: accentColor)
                      : const Icon(
                          Icons.circle_outlined,
                          color: Colors.grey,
                          size: 20,
                        )),
              tileColor: isSelected ? accentColor.withOpacity(0.05) : null,
              onTap: turnoCerrado
                  ? null
                  : () => onSectorTap(doc.id, nombre),
              enabled: !turnoCerrado,
            );
          }).toList(),
        );
      },
    );
  }
}
