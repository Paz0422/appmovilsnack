import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PanelVentas extends StatefulWidget {
  final String eventoId;
  final String nombreSector;

  const PanelVentas({
    super.key,
    required this.eventoId,
    required this.nombreSector,
  });

  @override
  State<PanelVentas> createState() => _PanelVentasState();
}

class _PanelVentasState extends State<PanelVentas> {
  String? _sectorActual; // Guarda el sector que se está mostrando
  List<String> _todosLosSectores = []; // Guarda todos los sectores del evento
  bool _isLoading = true; // Para mostrar un indicador de carga al inicio

  @override
  void initState() {
    super.initState();
    _sectorActual = widget.nombreSector;
    _cargarSectoresDelEvento();
  }

  Future<void> _cargarSectoresDelEvento() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('eventos')
          .doc(widget.eventoId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final sectoresFromDB = List<String>.from(data['sectores'] ?? []);

        setState(() {
          _todosLosSectores = sectoresFromDB;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 218, 188, 20),
        foregroundColor: Colors.white,
        title: _isLoading
            ? Text(
                'Cargando...',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              )
            : DropdownButton<String>(
                value: _sectorActual,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                dropdownColor: const Color.fromARGB(255, 87, 58, 131),
                underline: Container(), // Oculta la línea de abajo
                onChanged: (String? nuevoSector) {
                  if (nuevoSector != null) {
                    setState(() {
                      _sectorActual = nuevoSector;
                    });
                  }
                },
                items: _todosLosSectores.map<DropdownMenuItem<String>>((
                  String sector,
                ) {
                  return DropdownMenuItem<String>(
                    value: sector,
                    child: Text(sector),
                  );
                }).toList(),
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
              ),
            ),
    );
  }
}
