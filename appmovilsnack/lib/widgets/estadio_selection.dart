import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/screens/vendedores/home_vendedor.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/services/firestore_helpers.dart';
import 'package:front_appsnack/core/tipografia.dart';
import 'package:front_appsnack/core/margen_inferior.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';

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
      appBar: AppBar(
        centerTitle: false,
        leading: widget.fromAdmin
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Volver al panel de administración',
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              )
            : null,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset(
              "assets/imagenes/logo.png",
              height: 40,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 10),
            const MarcaFusion(tamano: 28),
          ],
        ),
      ),
      body: Stack(
        children: [
          // --- CONTENIDO PRINCIPAL ---
          StreamBuilder<QuerySnapshot>(
            key: ValueKey(_eventosRetryKey),
            stream: FirestoreHelpers.streamEventosActivos().timeout(
              const Duration(seconds: 30),
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorAmable(
                  titulo: 'No se pudieron cargar los eventos.',
                  mensaje: 'Revise la conexión o inténtelo de nuevo.',
                  onReintentar: () => setState(() => _eventosRetryKey++),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final eventos = snapshot.data?.docs ?? [];

              if (eventos.isEmpty) {
                return const EstadoVacio(
                  titulo: 'No hay eventos activos.',
                  mensaje:
                      'Cuando el administrador active un evento, aparecerá aquí.',
                );
              }

              return ListView.builder(
                padding: conMargenInferior(
                  context,
                  const EdgeInsets.only(bottom: 200, top: 8),
                ),
                itemCount: eventos.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Text(
                        '¿Dónde trabaja hoy?',
                        style: AppFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tinta,
                        ),
                      ),
                    );
                  }
                  final eventoDoc = eventos[index - 1];
                  final eventoData = eventoDoc.data() as Map<String, dynamic>;

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.separador),
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
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        leading: const CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.negro,
                          child: Icon(
                            Icons.stadium_outlined,
                            color: AppColors.dorado,
                            size: 26,
                          ),
                        ),
                        title: Text(
                          eventoData['nombre'] ?? 'Evento',
                          style: AppFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppColors.tinta,
                          ),
                        ),
                        subtitle:
                            (eventoData['ubicacion']?.toString().trim() ?? '')
                                .isNotEmpty
                            ? Text(
                                eventoData['ubicacion'].toString(),
                                style: AppFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.tintaSecundaria,
                                ),
                              )
                            : null,
                        iconColor: AppColors.tinta,
                        collapsedIconColor: AppColors.tinta,
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
        padding: conMargenInferior(
          context,
          const EdgeInsets.fromLTRB(20, 20, 20, 40),
        ),
        decoration: BoxDecoration(
          color: AppColors.tarjeta,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: const Border(top: BorderSide(color: AppColors.separador)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_nombreEventoSeleccionado',
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 16,
                color: AppColors.tintaSecundaria,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Sector: $_sectorSeleccionado',
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.tinta,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final eventId = _eventoSeleccionadoId;
                  final sectorId = _sectorSeleccionadoId;
                  final sectorNombre = _sectorSeleccionado;
                  if (eventId == null ||
                      sectorId == null ||
                      sectorNombre == null) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Seleccione un sector antes de continuar.',
                          style: AppFonts.inter(),
                        ),
                        backgroundColor: AppColors.avisoFuerte,
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
                          style: AppFonts.inter(),
                        ),
                        backgroundColor: AppColors.avisoFuerte,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                    return;
                  }
                  if (!mounted) return;
                  Navigator.push(
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
                child: const Text('CONTINUAR'),
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
      stream: FirestoreHelpers.streamSectores(
        widget.eventoId,
      ).timeout(const Duration(seconds: 25)),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No se pudieron cargar los sectores.',
                  style: AppFonts.inter(
                    fontSize: 16,
                    color: AppColors.tinta,
                    fontWeight: FontWeight.w700,
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
            child: LinearProgressIndicator(),
          );
        }

        final sectores = snapshot.data?.docs ?? [];

        if (sectores.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              'No hay sectores en este evento.',
              style: AppFonts.inter(
                fontSize: 16,
                color: AppColors.tintaSecundaria,
              ),
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
              minTileHeight: 60,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      nombre,
                      style: AppFonts.inter(
                        fontSize: 17,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: turnoCerrado
                            ? AppColors.tintaSecundaria
                            : AppColors.tinta,
                      ),
                    ),
                  ),
                  if (turnoCerrado)
                    Container(
                      margin: const EdgeInsets.only(left: 8.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.separador,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Turno cerrado',
                        style: AppFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tintaSecundaria,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: turnoCerrado
                  ? const Icon(
                      Icons.lock_outline,
                      color: AppColors.tintaSecundaria,
                      size: 24,
                    )
                  : (isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.negro,
                            size: 28,
                          )
                        : const Icon(
                            Icons.circle_outlined,
                            color: AppColors.bordeCampo,
                            size: 26,
                          )),
              tileColor: isSelected ? AppColors.doradoSuave : null,
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
