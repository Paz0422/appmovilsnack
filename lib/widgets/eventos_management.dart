// Archivo: lib/widgets/eventos_management.dart
// Gestión de Eventos - CRUD completo de eventos y sectores

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class EventosManagement extends StatefulWidget {
  const EventosManagement({super.key});

  @override
  State<EventosManagement> createState() => _EventosManagementState();
}

class _EventosManagementState extends State<EventosManagement> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _eventos = [];
  List<DocumentSnapshot> _eventosFiltrados = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _eventoSeleccionadoId;
  String? _nombreEventoSeleccionado;

  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);
  final Color backgroundColor = const Color(0xFFFDFBF7);

  @override
  void initState() {
    super.initState();
    _cargarEventos();
    _searchController.addListener(_filtrarEventos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarEventos() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('eventos')
          .orderBy('nombre')
          .get();

      setState(() {
        _eventos = snapshot.docs;
        _eventosFiltrados = _eventos;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Error al cargar eventos. Revisa tu conexión y permisos.';
          _isLoading = false;
        });
      }
    }
  }

  void _filtrarEventos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _eventosFiltrados = _eventos.where((evento) {
        final data = evento.data() as Map<String, dynamic>?;
        if (data == null || !data.containsKey('nombre')) {
          return false;
        }
        final nombre = data['nombre'].toString().toLowerCase();
        return nombre.contains(query);
      }).toList();
    });
  }

  Future<void> _mostrarDialogoEvento({DocumentSnapshot? evento}) async {
    final nombreController = TextEditingController(
      text: evento?.data() != null
          ? (evento!.data() as Map<String, dynamic>)['nombre'] ?? ''
          : '',
    );
    final ubicacionController = TextEditingController(
      text: evento?.data() != null
          ? (evento!.data() as Map<String, dynamic>)['ubicacion'] ?? ''
          : '',
    );
    bool activo = evento?.data() != null
        ? (evento!.data() as Map<String, dynamic>)['activo'] ?? false
        : false;

    // Lista de sectores para nuevos eventos
    List<String> sectores = [];
    if (evento != null && evento.data() != null) {
      final data = evento.data() as Map<String, dynamic>;
      if (data.containsKey('sectoresIniciales')) {
        sectores = List<String>.from(data['sectoresIniciales'] ?? []);
      }
    }
    final sectorController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: backgroundColor,
              title: Text(
                evento == null ? 'Agregar Evento' : 'Editar Evento',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nombreController,
                        decoration: InputDecoration(
                          labelText: 'Nombre del Evento',
                          labelStyle: GoogleFonts.poppins(
                            color: secondaryColor,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: accentColor,
                              width: 2,
                            ),
                          ),
                        ),
                        style: GoogleFonts.poppins(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: ubicacionController,
                        decoration: InputDecoration(
                          labelText: 'Ubicación',
                          labelStyle: GoogleFonts.poppins(
                            color: secondaryColor,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: accentColor,
                              width: 2,
                            ),
                          ),
                        ),
                        style: GoogleFonts.poppins(),
                      ),
                      if (evento == null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Sectores',
                          style: GoogleFonts.poppins(
                            color: secondaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: sectorController,
                                decoration: InputDecoration(
                                  labelText: 'Nombre del Sector',
                                  labelStyle: GoogleFonts.poppins(
                                    color: secondaryColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: accentColor,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                style: GoogleFonts.poppins(),
                                onSubmitted: (value) {
                                  if (value.trim().isNotEmpty) {
                                    setDialogState(() {
                                      sectores.add(value.trim());
                                      sectorController.clear();
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.add_circle, color: accentColor),
                              onPressed: () {
                                if (sectorController.text.trim().isNotEmpty) {
                                  setDialogState(() {
                                    sectores.add(sectorController.text.trim());
                                    sectorController.clear();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        if (sectores.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 150),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: secondaryColor.withOpacity(0.3),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: sectores.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final sector = entry.value;
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    title: Text(
                                      sector,
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setDialogState(() {
                                          sectores.removeAt(index);
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Evento Activo',
                              style: GoogleFonts.poppins(
                                color: secondaryColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Switch(
                            value: activo,
                            onChanged: (value) {
                              setDialogState(() {
                                activo = value;
                              });
                            },
                            activeColor: accentColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.poppins(color: secondaryColor),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final nombre = nombreController.text.trim();
                    final ubicacion = ubicacionController.text.trim();

                    if (nombre.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Por favor, ingresa un nombre para el evento.',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (evento == null && ubicacion.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Por favor, ingresa una ubicación para el evento.',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (evento == null && sectores.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Por favor, agrega al menos un sector.',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).pop();

                    try {
                      final eventoData = <String, dynamic>{
                        'nombre': nombre,
                        'activo': activo,
                      };

                      if (ubicacion.isNotEmpty) {
                        eventoData['ubicacion'] = ubicacion;
                      }

                      if (evento == null) {
                        // Agregar nuevo evento
                        final docRef = await FirebaseFirestore.instance
                            .collection('eventos')
                            .add(eventoData);

                        // Crear los sectores como subcolecciones
                        for (final sectorNombre in sectores) {
                          await docRef.collection('sectores').add({
                            'nombre': sectorNombre,
                            'totalVendido': 0.0,
                            'productosVendidos': 0,
                            'vendedoresasignados': <Map<String, dynamic>>[],
                          });
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Evento agregado exitosamente',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } else {
                        // Editar evento existente
                        await evento.reference.update(eventoData);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Evento actualizado exitosamente',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }

                      await _cargarEventos();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error al guardar el evento: $e',
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
                    backgroundColor: accentColor,
                    foregroundColor: primaryColor,
                  ),
                  child: Text(
                    evento == null ? 'Agregar' : 'Guardar',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _eliminarEvento(DocumentSnapshot evento) async {
    final nombre =
        (evento.data() as Map<String, dynamic>)['nombre'] ?? 'este evento';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text(
            'Confirmar Eliminación',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar "$nombre"? Esta acción eliminará todos los sectores y datos asociados. Esta acción no se puede deshacer.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(color: secondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Eliminar',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      try {
        // Eliminar todos los sectores primero
        final sectoresSnapshot = await evento.reference
            .collection('sectores')
            .get();

        for (var sector in sectoresSnapshot.docs) {
          await sector.reference.delete();
        }

        // Eliminar el evento
        await evento.reference.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Evento eliminado exitosamente',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        await _cargarEventos();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al eliminar el evento: $e',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _gestionarSectores(DocumentSnapshot evento) {
    setState(() {
      _eventoSeleccionadoId = evento.id;
      _nombreEventoSeleccionado =
          (evento.data() as Map<String, dynamic>)['nombre'] ?? 'Sin nombre';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_eventoSeleccionadoId != null) {
      return _GestionSectores(
        eventoId: _eventoSeleccionadoId!,
        nombreEvento: _nombreEventoSeleccionado!,
        onVolver: () {
          setState(() {
            _eventoSeleccionadoId = null;
            _nombreEventoSeleccionado = null;
          });
        },
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Gestión de Eventos',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: secondaryColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _cargarEventos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: primaryColor,
                      ),
                      child: Text(
                        'Reintentar',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar eventos...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: secondaryColor,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FloatingActionButton(
                        onPressed: () => _mostrarDialogoEvento(),
                        backgroundColor: accentColor,
                        foregroundColor: primaryColor,
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _eventosFiltrados.isEmpty
                      ? Center(
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
                                _searchController.text.isEmpty
                                    ? 'No hay eventos registrados'
                                    : 'No se encontraron eventos',
                                style: GoogleFonts.poppins(
                                  color: secondaryColor,
                                  fontSize: 16,
                                ),
                              ),
                              if (_searchController.text.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: ElevatedButton.icon(
                                    onPressed: () => _mostrarDialogoEvento(),
                                    icon: const Icon(Icons.add),
                                    label: Text(
                                      'Agregar Primer Evento',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentColor,
                                      foregroundColor: primaryColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _eventosFiltrados.length,
                          itemBuilder: (context, index) {
                            final evento = _eventosFiltrados[index];
                            final data = evento.data() as Map<String, dynamic>?;

                            if (data == null) {
                              return const SizedBox.shrink();
                            }

                            final String nombreEvento =
                                data['nombre']?.toString() ?? 'Sin nombre';
                            final bool activo = data['activo'] ?? false;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: activo
                                      ? Colors.green
                                      : Colors.transparent,
                                  width: activo ? 2 : 0,
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
                                    color: activo
                                        ? Colors.green.withOpacity(0.2)
                                        : accentColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    activo ? Icons.event : Icons.event_busy,
                                    color: activo ? Colors.green : accentColor,
                                    size: 28,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        nombreEvento,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                    if (activo)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          'Activo',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.location_on,
                                        color: accentColor,
                                      ),
                                      onPressed: () =>
                                          _gestionarSectores(evento),
                                      tooltip: 'Gestionar Sectores',
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        color: accentColor,
                                      ),
                                      onPressed: () =>
                                          _mostrarDialogoEvento(evento: evento),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _eliminarEvento(evento),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoEvento(),
        backgroundColor: accentColor,
        foregroundColor: primaryColor,
        icon: const Icon(Icons.add),
        label: Text(
          'Agregar Evento',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _GestionSectores extends StatefulWidget {
  final String eventoId;
  final String nombreEvento;
  final VoidCallback onVolver;

  const _GestionSectores({
    required this.eventoId,
    required this.nombreEvento,
    required this.onVolver,
  });

  @override
  State<_GestionSectores> createState() => _GestionSectoresState();
}

class _GestionSectoresState extends State<_GestionSectores> {
  final TextEditingController _searchController = TextEditingController();
  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);
  final Color backgroundColor = const Color(0xFFFDFBF7);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _mostrarDialogoSector({DocumentSnapshot? sector}) async {
    final nombreController = TextEditingController(
      text: sector?.data() != null
          ? (sector!.data() as Map<String, dynamic>)['nombre'] ?? ''
          : '',
    );

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text(
            sector == null ? 'Agregar Sector' : 'Editar Sector',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre del Sector',
                    labelStyle: GoogleFonts.poppins(color: secondaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: accentColor, width: 2),
                    ),
                  ),
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(color: secondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final nombre = nombreController.text.trim();

                if (nombre.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Por favor, ingresa un nombre para el sector.',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop();

                try {
                  final sectorData = <String, dynamic>{'nombre': nombre};

                  if (sector == null) {
                    // Agregar nuevo sector
                    await FirebaseFirestore.instance
                        .collection('eventos')
                        .doc(widget.eventoId)
                        .collection('sectores')
                        .add(sectorData);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Sector agregado exitosamente',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } else {
                    // Editar sector existente
                    await sector.reference.update(sectorData);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Sector actualizado exitosamente',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Error al guardar el sector: $e',
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
                backgroundColor: accentColor,
                foregroundColor: primaryColor,
              ),
              child: Text(
                sector == null ? 'Agregar' : 'Guardar',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _eliminarSector(DocumentSnapshot sector) async {
    final nombre =
        (sector.data() as Map<String, dynamic>)['nombre'] ?? 'este sector';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text(
            'Confirmar Eliminación',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar "$nombre"? Esta acción eliminará todos los datos asociados (stock, personal asignado, etc.). Esta acción no se puede deshacer.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(color: secondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Eliminar',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      try {
        // Eliminar subcolecciones relacionadas si existen
        // (stockInicial, personalAsignado, etc.)

        await sector.reference.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sector eliminado exitosamente',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al eliminar el sector: $e',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Sectores de ${widget.nombreEvento}',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onVolver,
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('eventos')
            .doc(widget.eventoId)
            .collection('sectores')
            .orderBy('nombre')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: accentColor));
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
                      'No hay sectores registrados',
                      style: GoogleFonts.poppins(
                        color: secondaryColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _mostrarDialogoSector(),
                      icon: const Icon(Icons.add),
                      label: Text(
                        'Agregar Primer Sector',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final sectores = snapshot.data!.docs;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar sectores...',
                          prefixIcon: Icon(Icons.search, color: secondaryColor),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 16,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton(
                      onPressed: () => _mostrarDialogoSector(),
                      backgroundColor: accentColor,
                      foregroundColor: primaryColor,
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sectores.length,
                  itemBuilder: (context, index) {
                    final sector = sectores[index];
                    final data = sector.data() as Map<String, dynamic>?;

                    if (data == null) {
                      return const SizedBox.shrink();
                    }

                    final String nombreSector =
                        data['nombre']?.toString() ?? 'Sin nombre';

                    final query = _searchController.text.toLowerCase();
                    if (query.isNotEmpty &&
                        !nombreSector.toLowerCase().contains(query)) {
                      return const SizedBox.shrink();
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: accentColor),
                              onPressed: () =>
                                  _mostrarDialogoSector(sector: sector),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _eliminarSector(sector),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoSector(),
        backgroundColor: accentColor,
        foregroundColor: primaryColor,
        icon: const Icon(Icons.add),
        label: Text(
          'Agregar Sector',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
