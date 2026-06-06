import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  /// Incrementar para forzar un nuevo StreamBuilder tras error/timeout.
  int _eventosRetryKey = 0;

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
            key: ValueKey(_eventosRetryKey),
            stream: FirestoreHelpers.streamEventosActivos().timeout(
              const Duration(seconds: 30),
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'No se pudieron cargar los eventos.',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Revisa conexión o inténtalo de nuevo.',
                          style: GoogleFonts.lato(
                            fontSize: 13,
                            color: secondaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () =>
                              setState(() => _eventosRetryKey++),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                          style: FilledButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
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
                        subtitle:
                            (eventoData['ubicacion']?.toString().trim() ?? '')
                                    .isNotEmpty
                                ? Text(
                                    eventoData['ubicacion'].toString(),
                                    style: GoogleFonts.lato(
                                      fontSize: 12,
                                      color: secondaryColor,
                                    ),
                                  )
                                : null,
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
                  final eventId = _eventoSeleccionadoId;
                  final sectorId = _sectorSeleccionadoId;
                  final sectorNombre = _sectorSeleccionado;
                  if (eventId == null || sectorId == null || sectorNombre == null) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Seleccione un sector antes de continuar.',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  // No permitir entrar a sectores con turno cerrado
                  final sectorDoc = await FirestoreHelpers.getSector(
                    eventId,
                    sectorId,
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
                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomeVendedor(
                        eventId: eventId,
                        sectorId: sectorId,
                        nombreSector: sectorNombre,
                        fromAdmin: widget.fromAdmin,
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
class SectoresList extends StatefulWidget {
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
  State<SectoresList> createState() => _SectoresListState();
}

class _SectoresListState extends State<SectoresList> {
  int _retryKey = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey(_retryKey),
      stream: FirestoreHelpers.streamSectores(widget.eventoId).timeout(
        const Duration(seconds: 25),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No se pudieron cargar los sectores.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _retryKey++),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
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

        if (sectores.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              'No hay sectores en este evento.',
              style: GoogleFonts.lato(fontSize: 14, color: secondaryColor),
            ),
          );
        }

        return Column(
          children: sectores.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final nombre = data['nombre'] ?? 'Sector';
            final turnoCerrado = data['turnoCerrado'] == true;
            final isSelected = widget.sectorSeleccionadoId == doc.id;

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
              tileColor: isSelected
                  ? accentColor.withValues(alpha: 0.05)
                  : null,
              onTap: turnoCerrado
                  ? null
                  : () => widget.onSectorTap(doc.id, nombre),
              enabled: !turnoCerrado,
            );
          }).toList(),
        );
      },
    );
  }
}
