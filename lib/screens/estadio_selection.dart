import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/screens/vendedores/home_vendedor.dart';
import 'package:google_fonts/google_fonts.dart';
import 'panel_ventas.dart'; // <-- Importa tu nueva pantalla

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

  // Variables de estado para guardar la selección
  String? _eventoSeleccionadoId;
  String? _nombreEventoSeleccionado;
  String? _sectorSeleccionado;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Elige Evento y Sector',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color.fromARGB(255, 218, 188, 20),
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _eventosStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color.fromARGB(255, 87, 58, 131),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('No hay eventos activos en este momento.'),
                );
              }

              final eventos = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  8.0,
                  8.0,
                  8.0,
                  120.0,
                ), // Espacio para el botón
                itemCount: eventos.length,
                itemBuilder: (context, index) {
                  final eventoDoc = eventos[index];
                  final eventoData = eventoDoc.data() as Map<String, dynamic>;

                  final nombreEvento = eventoData['nombre'] ?? 'Sin nombre';
                  final ubicacionEvento =
                      eventoData['Ubicacion'] ?? 'Sin ubicación';
                  final imageUrl = eventoData['imageUrl'] ?? '';
                  final List<dynamic> sectores = eventoData['sectores'] ?? [];

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 5,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    child: ExpansionTile(
                      // Previene que se expanda si no hay sectores
                      onExpansionChanged: (isExpanding) {
                        if (!isExpanding) {}
                      },
                      title: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(
                                      Icons.stadium_outlined,
                                      size: 40,
                                      color: Color.fromARGB(255, 0, 0, 0),
                                    ),
                                  )
                                : const Icon(
                                    Icons.stadium_outlined,
                                    size: 40,
                                    color: Color.fromARGB(255, 0, 0, 0),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombreEvento,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ubicacionEvento,
                                  style: GoogleFonts.lato(
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      children: sectores.map<Widget>((sector) {
                        final nombreSector = sector.toString();
                        final bool isSelected =
                            _eventoSeleccionadoId == eventoDoc.id &&
                            _sectorSeleccionado == nombreSector;

                        return ListTile(
                          title: Text(nombreSector),
                          tileColor: isSelected
                              ? Colors.deepPurple.withOpacity(0.1)
                              : null,
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.deepPurple,
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _eventoSeleccionadoId = eventoDoc.id;
                              _nombreEventoSeleccionado = nombreEvento;
                              _sectorSeleccionado = nombreSector;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  );
                },
              );
            },
          ),

          // Botón "Continuar" que aparece solo cuando hay una selección completa
          if (_sectorSeleccionado != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Selección: $_nombreEventoSeleccionado / $_sectorSeleccionado',
                      style: GoogleFonts.lato(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.point_of_sale_outlined),
                      label: const Text('Continuar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(
                          255,
                          218,
                          188,
                          20,
                        ),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomeVendedor(
                              eventId: _eventoSeleccionadoId!,
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
