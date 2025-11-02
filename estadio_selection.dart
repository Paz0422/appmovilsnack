import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/screens/vendedores/home_vendedor.dart';
import 'package:google_fonts/google_fonts.dart';

// Paleta de colores basada en el logo "Fusión"
const Color primaryColor = Color(0xFF2B2B2B); // Negro/marrón oscuro
const Color accentColor = Color(0xFFDABF41); // Dorado brillante
const Color secondaryColor = Color(0xFF6B4D2F); // Marrón medio
const Color backgroundColor = Color(0xFFFDFBF7); // Fondo claro elegante

class EstadioSelection extends StatefulWidget {
  const EstadioSelection({super.key});

  @override
  State<EstadioSelection> createState() => _EstadioSelectionState();
}

class _EstadioSelectionState extends State<EstadioSelection> {
  final Stream<QuerySnapshot> _eventosStream = FirebaseFirestore.instance
      .collection('eventos')
      .where('activo', isEqualTo: true)
      .snapshots();

  String? _eventoSeleccionadoId;
  String? _nombreEventoSeleccionado;
  String? _sectorSeleccionado;
  String? _sectorSeleccionadoId;

  // Control manual de expansión con Set para evitar conflictos
  final Set<String> _eventosExpandidos = <String>{};

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
            Image.asset("assets/imagenes/logo.png", height: 40),
            const SizedBox(width: 10),
            Text(
              "Fusión",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: accentColor,
              ),
            ),
            Icon(Icons.favorite_border, color: accentColor),
          ],
        ),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _eventosStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: accentColor),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error al cargar eventos: ${snapshot.error}',
                    style: GoogleFonts.openSans(color: secondaryColor),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'No hay eventos activos en este momento.',
                    style: GoogleFonts.openSans(color: secondaryColor),
                  ),
                );
              }

              final eventos = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 140, top: 16.0),
                itemCount: eventos.length,
                itemBuilder: (context, index) {
                  final eventoDoc = eventos[index];
                  final eventoData = eventoDoc.data() as Map<String, dynamic>;

                  final nombreEvento = eventoData['nombre'] ?? 'Sin nombre';
                  final ubicacionEvento =
                      eventoData['ubicacion'] ??
                      eventoData['Ubicacion'] ??
                      'Sin ubicación';

                  final isExpanded = _eventosExpandidos.contains(eventoDoc.id);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Card(
                      elevation: 6,
                      color: const Color.fromARGB(255, 254, 228, 200),
                      shadowColor: secondaryColor.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.0),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.stadium_outlined,
                              color: accentColor,
                              size: 36,
                            ),
                            title: Text(
                              nombreEvento,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            subtitle: Text(
                              ubicacionEvento,
                              style: GoogleFonts.lato(
                                color: secondaryColor,
                                fontSize: 12,
                              ),
                            ),
                            trailing: AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.expand_more,
                                color: accentColor,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                if (isExpanded) {
                                  _eventosExpandidos.remove(eventoDoc.id);
                                } else {
                                  _eventosExpandidos.add(eventoDoc.id);
                                }
                              });
                            },
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            height: isExpanded ? null : 0,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isExpanded ? 1.0 : 0.0,
                              child: isExpanded
                                  ? SectoresList(
                                      eventoId: eventoDoc.id,
                                      eventoSeleccionadoId:
                                          _eventoSeleccionadoId,
                                      sectorSeleccionadoId:
                                          _sectorSeleccionadoId,
                                      onSectorTap: (sectorId, nombreSector) {
                                        // SOLUCIÓN: No llamar setState aquí directamente
                                        // Usar post frame callback para evitar conflictos
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (mounted) {
                                                setState(() {
                                                  _eventoSeleccionadoId =
                                                      eventoDoc.id;
                                                  _nombreEventoSeleccionado =
                                                      nombreEvento;
                                                  _sectorSeleccionado =
                                                      nombreSector;
                                                  _sectorSeleccionadoId =
                                                      sectorId;
                                                  // Mantener expandido el evento seleccionado
                                                  _eventosExpandidos.add(
                                                    eventoDoc.id,
                                                  );
                                                });
                                              }
                                            });
                                      },
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (_sectorSeleccionado != null &&
              _eventoSeleccionadoId != null &&
              _sectorSeleccionadoId != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Seleccionado: $_nombreEventoSeleccionado / $_sectorSeleccionado',
                      style: GoogleFonts.lato(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward_ios),
                      label: const Text('Continuar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 50,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        elevation: 6,
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomeVendedor(
                              eventId: _eventoSeleccionadoId!,
                              sectorId: _sectorSeleccionadoId!,
                              nombreSector: _sectorSeleccionado!,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 👇 Widget independiente para listar sectores de un evento
class SectoresList extends StatelessWidget {
  final String eventoId;
  final String? eventoSeleccionadoId;
  final String? sectorSeleccionadoId;
  final Function(String sectorId, String nombreSector) onSectorTap;

  const SectoresList({
    super.key,
    required this.eventoId,
    required this.eventoSeleccionadoId,
    required this.sectorSeleccionadoId,
    required this.onSectorTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eventos')
          .doc(eventoId)
          .collection('sectores')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey,
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error al cargar sectores: ${snapshot.error}',
              style: GoogleFonts.openSans(color: Colors.redAccent),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No hay sectores disponibles para este evento.',
              style: GoogleFonts.openSans(color: secondaryColor),
              textAlign: TextAlign.center,
            ),
          );
        }

        final sectores = snapshot.data!.docs;

        return Column(
          children: sectores.map((sectorDoc) {
            final data = sectorDoc.data() as Map<String, dynamic>;
            final nombreSector = data['nombre'] ?? 'Sin nombre';

            final isSelected =
                eventoSeleccionadoId == eventoId &&
                sectorSeleccionadoId == sectorDoc.id;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 6,
              ),
              title: Text(
                nombreSector,
                style: GoogleFonts.lato(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? accentColor : primaryColor,
                ),
              ),
              tileColor: isSelected ? accentColor.withOpacity(0.15) : null,
              trailing: isSelected
                  ? Icon(Icons.check_circle, color: accentColor)
                  : null,
              onTap: () => onSectorTap(sectorDoc.id, nombreSector),
            );
          }).toList(),
        );
      },
    );
  }
}
