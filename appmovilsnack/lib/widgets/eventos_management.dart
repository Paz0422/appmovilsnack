// Archivo: lib/widgets/eventos_management.dart
// Gestión de Eventos - CRUD completo de eventos y sectores

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';
import 'package:front_appsnack/core/tipografia.dart';
import 'package:front_appsnack/core/margen_inferior.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/widgets/comunes/cargando.dart';
import 'package:front_appsnack/core/animaciones.dart';

const _sectoresEventoDefault = [
  'Galeria Sur',
  'Galeria Norte',
  'Andes',
  'Pacifico',
];

class _SectorEnEdicion {
  final String? id;
  String nombre;

  _SectorEnEdicion({this.id, required this.nombre});
}

Map<String, dynamic> _datosSectorNuevo(String nombre) => {
  'nombre': nombre,
  'totalVendido': 0.0,
  'productosVendidos': 0,
  'vendedoresasignados': <dynamic>[],
};

String _normalizarNombreSector(String nombre) => nombre.trim().toLowerCase();

bool _listaContieneSector(
  List<_SectorEnEdicion> sectores,
  String nombre, {
  int? exceptoIndice,
}) {
  final normalizado = _normalizarNombreSector(nombre);
  for (var i = 0; i < sectores.length; i++) {
    if (exceptoIndice != null && i == exceptoIndice) continue;
    if (_normalizarNombreSector(sectores[i].nombre) == normalizado) return true;
  }
  return false;
}

Future<bool> _firestoreContieneSector(
  String eventoId,
  String nombre, {
  String? exceptoSectorId,
}) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('eventos')
      .doc(eventoId)
      .collection('sectores')
      .get();
  final normalizado = _normalizarNombreSector(nombre);
  for (final doc in snapshot.docs) {
    if (exceptoSectorId != null && doc.id == exceptoSectorId) continue;
    final existente = doc.data()['nombre']?.toString() ?? '';
    if (_normalizarNombreSector(existente) == normalizado) return true;
  }
  return false;
}

void _mostrarErrorSectorDuplicado(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Ya existe un sector con ese nombre.',
        style: AppFonts.inter(),
      ),
      backgroundColor: AppColors.errorFuerte,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

String _normalizarNombreEvento(String nombre) => nombre.trim().toLowerCase();

Future<bool> _existeOtroEventoActivoConNombre(
  String nombre, {
  String? exceptoEventoId,
}) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('eventos')
      .where('activo', isEqualTo: true)
      .get();
  final normalizado = _normalizarNombreEvento(nombre);
  for (final doc in snapshot.docs) {
    if (exceptoEventoId != null && doc.id == exceptoEventoId) continue;
    final existente =
        doc.data()['nombre']?.toString().trim().toLowerCase() ?? '';
    if (existente.isNotEmpty && existente == normalizado) return true;
  }
  return false;
}

const _msgEventoSinNombre = 'Por favor, ingrese un nombre para el evento.';
const _msgEventoSinSectores = 'Por favor, agregue al menos un sector.';
const _msgSectorDuplicado = 'Ya existe un sector con ese nombre.';
const _msgEventoActivoDuplicado =
    'Ya hay un evento activo con ese nombre. Desactive el otro o use otro nombre.';

Widget _bannerDialogo({required String mensaje, required bool esError}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: esError ? AppColors.errorSuave : AppColors.exitoSuave,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(
        color: esError ? AppColors.error : AppColors.exito,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          esError ? Icons.error_outline : Icons.check_circle_outline,
          color: esError ? AppColors.error : AppColors.exito,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            mensaje,
            style: AppFonts.inter(
              fontSize: 14,
              color: esError ? AppColors.error : AppColors.exito,
            ),
          ),
        ),
      ],
    ),
  );
}

Future<DocumentReference<Map<String, dynamic>>> _guardarEventoNuevo({
  required String nombre,
  required bool activo,
  required List<_SectorEnEdicion> sectores,
}) async {
  final firestore = FirebaseFirestore.instance;
  final eventoRef = firestore.collection('eventos').doc();
  final batch = firestore.batch();

  batch.set(eventoRef, {
    'nombre': nombre,
    'activo': activo,
    'fechaCreacion': FieldValue.serverTimestamp(),
  });

  final nombresUnicos = <String>{};
  for (final sector in sectores) {
    final trimmed = sector.nombre.trim();
    if (trimmed.isEmpty ||
        !nombresUnicos.add(_normalizarNombreSector(trimmed))) {
      continue;
    }
    batch.set(
      eventoRef.collection('sectores').doc(),
      _datosSectorNuevo(trimmed),
    );
  }

  await batch.commit();
  return eventoRef;
}

Future<void> _sincronizarSectoresEvento({
  required DocumentReference<Map<String, dynamic>> eventoRef,
  required List<_SectorEnEdicion> sectores,
  required Set<String> idsOriginales,
}) async {
  final batch = FirebaseFirestore.instance.batch();
  final idsActuales = sectores
      .where((s) => s.id != null)
      .map((s) => s.id!)
      .toSet();

  for (final id in idsOriginales) {
    if (!idsActuales.contains(id)) {
      batch.delete(eventoRef.collection('sectores').doc(id));
    }
  }

  for (final sector in sectores) {
    final trimmed = sector.nombre.trim();
    if (trimmed.isEmpty) continue;
    if (sector.id != null) {
      batch.update(eventoRef.collection('sectores').doc(sector.id), {
        'nombre': trimmed,
      });
    } else {
      batch.set(
        eventoRef.collection('sectores').doc(),
        _datosSectorNuevo(trimmed),
      );
    }
  }

  await batch.commit();
}

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

  final Color primaryColor = AppColors.primaryLight;
  final Color accentColor = AppColors.accent;
  final Color secondaryColor = AppColors.secondary;
  final Color backgroundColor = AppColors.surface;

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
          .get();

      final docs = snapshot.docs.toList()
        ..sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>?;
          final dataB = b.data() as Map<String, dynamic>?;
          final na = dataA?['nombre']?.toString().toLowerCase() ?? '';
          final nb = dataB?['nombre']?.toString().toLowerCase() ?? '';
          return na.compareTo(nb);
        });

      setState(() {
        _eventos = docs;
        _eventosFiltrados = docs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Error al cargar eventos. Revise su conexión y permisos.';
          _isLoading = false;
        });
      }
    }
  }

  void _filtrarEventos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _eventosFiltrados = _eventos.where((evento) {
        if (query.isEmpty) return true;
        final data = evento.data() as Map<String, dynamic>?;
        final nombre = data?['nombre']?.toString().toLowerCase() ?? '';
        return nombre.contains(query);
      }).toList();
    });
  }

  Widget _iconoAccionEvento({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return IconButton(
      icon: Icon(icon, color: color, size: 22),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: AppTamanos.toque, minHeight: AppTamanos.toque),
      onPressed: onPressed,
    );
  }

  Future<void> _mostrarDialogoEvento({DocumentSnapshot? evento}) async {
    final messenger = ScaffoldMessenger.of(context);
    final nombreController = TextEditingController(
      text: evento?.data() != null
          ? (evento!.data() as Map<String, dynamic>)['nombre'] ?? ''
          : '',
    );
    bool activo = evento?.data() != null
        ? (evento!.data() as Map<String, dynamic>)['activo'] ?? false
        : true;

    List<_SectorEnEdicion> sectores = [];
    final idsSectoresOriginales = <String>{};

    if (evento == null) {
      sectores = _sectoresEventoDefault
          .map((n) => _SectorEnEdicion(nombre: n))
          .toList();
    } else {
      try {
        final snapshot = await evento.reference.collection('sectores').get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          sectores.add(
            _SectorEnEdicion(
              id: doc.id,
              nombre: data['nombre']?.toString() ?? 'Sin nombre',
            ),
          );
          idsSectoresOriginales.add(doc.id);
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'No se pudieron cargar los sectores: $e',
                style: AppFonts.inter(),
              ),
              backgroundColor: AppColors.errorFuerte,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    final sectorController = TextEditingController();
    var guardando = false;
    String? mensajeError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void mostrarError(String mensaje) {
              setDialogState(() => mensajeError = mensaje);
            }

            void limpiarError() {
              if (mensajeError != null) {
                setDialogState(() => mensajeError = null);
              }
            }

            void agregarSectorALista(String nombre) {
              final trimmed = nombre.trim();
              if (trimmed.isEmpty) return;
              if (_listaContieneSector(sectores, trimmed)) {
                mostrarError(_msgSectorDuplicado);
                return;
              }
              setDialogState(() {
                mensajeError = null;
                sectores.add(_SectorEnEdicion(nombre: trimmed));
                sectorController.clear();
              });
            }

            return AlertDialog(
              backgroundColor: backgroundColor,
              title: Text(
                evento == null ? 'Agregar Evento' : 'Editar Evento',
                style: AppFonts.inter(
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
                      if (mensajeError != null) ...[
                        _bannerDialogo(mensaje: mensajeError!, esError: true),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: nombreController,
                        onChanged: (_) => limpiarError(),
                        decoration: InputDecoration(
                          labelText: 'Nombre del Evento',
                          labelStyle: AppFonts.inter(color: secondaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: AppColors.dorado,
                              width: 2,
                            ),
                          ),
                        ),
                        style: AppFonts.inter(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sectores',
                        style: AppFonts.inter(
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
                                labelStyle: AppFonts.inter(
                                  color: secondaryColor,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: AppColors.dorado,
                                    width: 2,
                                  ),
                                ),
                              ),
                              style: AppFonts.inter(),
                              onSubmitted: (value) =>
                                  agregarSectorALista(value),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.add_circle,
                              color: AppColors.dorado,
                            ),
                            onPressed: () =>
                                agregarSectorALista(sectorController.text),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: secondaryColor.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: sectores.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Agregue al menos un sector',
                                  style: AppFonts.inter(
                                    fontSize: 14,
                                    color: secondaryColor.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: sectores.asMap().entries.map((
                                    entry,
                                  ) {
                                    final index = entry.key;
                                    final sector = entry.value;
                                    return ListTile(
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                      title: Text(
                                        sector.nombre,
                                        style: AppFonts.inter(fontSize: 14),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.edit_outlined,
                                              color: AppColors.dorado,
                                              size: 20,
                                            ),
                                            tooltip: 'Renombrar',
                                            onPressed: () async {
                                              final nuevo =
                                                  await showDialog<String>(
                                                    context: context,
                                                    useRootNavigator: true,
                                                    builder: (ctx) =>
                                                        _DialogRenombrarSector(
                                                          nombreInicial:
                                                              sector.nombre,
                                                          backgroundColor:
                                                              backgroundColor,
                                                          primaryColor:
                                                              primaryColor,
                                                          accentColor:
                                                              accentColor,
                                                          secondaryColor:
                                                              secondaryColor,
                                                        ),
                                                  );
                                              if (nuevo != null &&
                                                  nuevo.isNotEmpty) {
                                                if (_listaContieneSector(
                                                  sectores,
                                                  nuevo,
                                                  exceptoIndice: index,
                                                )) {
                                                  mostrarError(
                                                    _msgSectorDuplicado,
                                                  );
                                                  return;
                                                }
                                                setDialogState(() {
                                                  mensajeError = null;
                                                  sectores[index].nombre = nuevo
                                                      .trim();
                                                });
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: AppColors.error,
                                              size: 20,
                                            ),
                                            tooltip: 'Eliminar',
                                            onPressed: () {
                                              setDialogState(() {
                                                sectores.removeAt(index);
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Evento Activo',
                              style: AppFonts.inter(
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
                                mensajeError = null;
                              });
                            },
                            activeThumbColor: accentColor,
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
                    style: AppFonts.inter(color: secondaryColor),
                  ),
                ),
                ElevatedButton(
                  onPressed: guardando
                      ? null
                      : () async {
                          final nombre = nombreController.text.trim();

                          if (nombre.isEmpty) {
                            mostrarError(_msgEventoSinNombre);
                            return;
                          }

                          if (sectores.isEmpty) {
                            mostrarError(_msgEventoSinSectores);
                            return;
                          }

                          try {
                            setDialogState(() {
                              guardando = true;
                              mensajeError = null;
                            });

                            if (activo) {
                              final duplicado =
                                  await _existeOtroEventoActivoConNombre(
                                    nombre,
                                    exceptoEventoId: evento?.id,
                                  );
                              if (!context.mounted) return;
                              if (duplicado) {
                                mostrarError(_msgEventoActivoDuplicado);
                                return;
                              }
                            }

                            if (evento == null) {
                              await _guardarEventoNuevo(
                                nombre: nombre,
                                activo: activo,
                                sectores: sectores,
                              );
                            } else {
                              await evento.reference.update({
                                'nombre': nombre,
                                'activo': activo,
                              });
                              await _sincronizarSectoresEvento(
                                eventoRef:
                                    evento.reference
                                        as DocumentReference<
                                          Map<String, dynamic>
                                        >,
                                sectores: sectores,
                                idsOriginales: idsSectoresOriginales,
                              );
                            }

                            await _cargarEventos();
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  evento == null
                                      ? 'Evento agregado exitosamente'
                                      : 'Evento actualizado exitosamente',
                                  style: AppFonts.inter(),
                                ),
                                backgroundColor: AppColors.exitoFuerte,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            mostrarError('Error al guardar el evento: $e');
                          } finally {
                            setDialogState(() => guardando = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dorado,
                    foregroundColor: AppColors.negro,
                  ),
                  child: guardando
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryColor,
                          ),
                        )
                      : Text(
                          evento == null ? 'Agregar' : 'Guardar',
                          style: AppFonts.inter(fontWeight: FontWeight.bold),
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
    final messenger = ScaffoldMessenger.of(context);
    final nombre =
        (evento.data() as Map<String, dynamic>)['nombre'] ?? 'este evento';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text(
            'Confirmar Eliminación',
            style: AppFonts.inter(
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
          content: Text(
            '¿Está seguro de que desea eliminar "$nombre"? Esta acción eliminará todos los sectores y datos asociados. Esta acción no se puede deshacer.',
            style: AppFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: AppFonts.inter(color: secondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.negro,
              ),
              child: Text(
                'Eliminar',
                style: AppFonts.inter(fontWeight: FontWeight.bold),
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
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Evento eliminado exitosamente',
                style: AppFonts.inter(),
              ),
              backgroundColor: AppColors.exitoFuerte,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        await _cargarEventos();
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Error al eliminar el evento: $e',
                style: AppFonts.inter(),
              ),
              backgroundColor: AppColors.errorFuerte,
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
          'Eventos y sectores',
          style: AppFonts.inter(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
      ),
      body: _isLoading
          ? const CargandoTarjetas()
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppFonts.inter(
                        color: secondaryColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _cargarEventos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dorado,
                        foregroundColor: AppColors.negro,
                      ),
                      child: Text(
                        'Reintentar',
                        style: AppFonts.inter(fontWeight: FontWeight.bold),
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
                            fillColor: AppColors.tarjetaAlta,
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
                        backgroundColor: AppColors.dorado,
                        foregroundColor: AppColors.negro,
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _eventosFiltrados.isEmpty
                      ? EstadoVacio(
                          titulo: _searchController.text.isEmpty
                              ? 'No hay eventos registrados'
                              : 'No se encontraron eventos',
                          accion: ElevatedButton.icon(
                            onPressed: () => _mostrarDialogoEvento(),
                            icon: const Icon(Icons.add),
                            label: Text(
                              'Agregar Primer Evento',
                              style: AppFonts.inter(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.dorado,
                              foregroundColor: AppColors.negro,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: conMargenInferior(
                            context,
                            const EdgeInsets.symmetric(horizontal: 16),
                            extra: espacioBotonFlotante,
                          ),
                          itemCount: _eventosFiltrados.length,
                          itemBuilder: (context, index) => Builder(builder: (context) {
                            final evento = _eventosFiltrados[index];
                            final data = evento.data() as Map<String, dynamic>?;

                            final String nombreEvento =
                                data?['nombre']?.toString().trim().isNotEmpty ==
                                    true
                                ? data!['nombre'].toString()
                                : 'Evento sin nombre (${evento.id.substring(0, 6)}...)';
                            final bool activo = data?['activo'] == true;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: activo
                                      ? AppColors.exito
                                      : Colors.transparent,
                                  width: activo ? 2 : 0,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  4,
                                  10,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: activo
                                            ? AppColors.exito.withValues(
                                                alpha: 0.2,
                                              )
                                            : accentColor.withValues(
                                                alpha: 0.2,
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        activo ? Icons.event : Icons.event_busy,
                                        color: activo
                                            ? AppColors.exito
                                            : accentColor,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nombreEvento,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppFonts.inter(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              color: primaryColor,
                                            ),
                                          ),
                                          if (activo) ...[
                                            const SizedBox(height: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.exito
                                                    .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Activo',
                                                style: AppFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.exito,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _iconoAccionEvento(
                                          icon: Icons.location_on,
                                          color: AppColors.dorado,
                                          tooltip: 'Gestionar Sectores',
                                          onPressed: () =>
                                              _gestionarSectores(evento),
                                        ),
                                        _iconoAccionEvento(
                                          icon: Icons.edit,
                                          color: AppColors.dorado,
                                          onPressed: () =>
                                              _mostrarDialogoEvento(
                                                evento: evento,
                                              ),
                                        ),
                                        _iconoAccionEvento(
                                          icon: Icons.delete,
                                          color: AppColors.error,
                                          onPressed: () =>
                                              _eliminarEvento(evento),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).entradaEnLista(index),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoEvento(),
        backgroundColor: AppColors.dorado,
        foregroundColor: AppColors.negro,
        icon: const Icon(Icons.add),
        label: Text(
          'Agregar Evento',
          style: AppFonts.inter(fontWeight: FontWeight.bold),
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
  final Color primaryColor = AppColors.primaryLight;
  final Color accentColor = AppColors.accent;
  final Color secondaryColor = AppColors.secondary;
  final Color backgroundColor = AppColors.surface;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _mostrarDialogoSector({DocumentSnapshot? sector}) async {
    final messenger = ScaffoldMessenger.of(context);
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
            style: AppFonts.inter(
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
                    labelStyle: AppFonts.inter(color: secondaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppColors.dorado,
                        width: 2,
                      ),
                    ),
                  ),
                  style: AppFonts.inter(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: AppFonts.inter(color: secondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final nombre = nombreController.text.trim();

                if (nombre.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Por favor, ingrese un nombre para el sector.',
                        style: AppFonts.inter(),
                      ),
                      backgroundColor: AppColors.errorFuerte,
                    ),
                  );
                  return;
                }

                final duplicado = await _firestoreContieneSector(
                  widget.eventoId,
                  nombre,
                  exceptoSectorId: sector?.id,
                );
                if (!context.mounted) return;
                if (duplicado) {
                  _mostrarErrorSectorDuplicado(context);
                  return;
                }

                Navigator.of(context).pop();

                try {
                  final sectorData = _datosSectorNuevo(nombre);

                  if (sector == null) {
                    await FirebaseFirestore.instance
                        .collection('eventos')
                        .doc(widget.eventoId)
                        .collection('sectores')
                        .add(sectorData);
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Sector agregado exitosamente',
                            style: AppFonts.inter(),
                          ),
                          backgroundColor: AppColors.exitoFuerte,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } else {
                    await sector.reference.update({'nombre': nombre});
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Sector actualizado exitosamente',
                            style: AppFonts.inter(),
                          ),
                          backgroundColor: AppColors.exitoFuerte,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Error al guardar el sector: $e',
                          style: AppFonts.inter(),
                        ),
                        backgroundColor: AppColors.errorFuerte,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dorado,
                foregroundColor: AppColors.negro,
              ),
              child: Text(
                sector == null ? 'Agregar' : 'Guardar',
                style: AppFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _reabrirSector(DocumentSnapshot sector) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await sector.reference.update({
        'turnoCerrado': false,
        'turnoCerradoAt': FieldValue.delete(),
        // El stock del sector queda con el conteo del cierre: el vendedor sigue
        // operando con él. Unidades nuevas se suman con "Agregar stock"; la
        // carga inicial ya no se permite (StockService.bloqueosStockInicial).
      });
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Sector reabierto. Ya puede ser seleccionado por vendedores.',
              style: AppFonts.inter(),
            ),
            backgroundColor: AppColors.exitoFuerte,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error al reabrir: $e', style: AppFonts.inter()),
            backgroundColor: AppColors.errorFuerte,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _eliminarSector(DocumentSnapshot sector) async {
    final messenger = ScaffoldMessenger.of(context);
    final nombre =
        (sector.data() as Map<String, dynamic>)['nombre'] ?? 'este sector';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text(
            'Confirmar Eliminación',
            style: AppFonts.inter(
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
          content: Text(
            '¿Está seguro de que desea eliminar "$nombre"? Esta acción eliminará todos los datos asociados (stock, personal asignado, etc.). Esta acción no se puede deshacer.',
            style: AppFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: AppFonts.inter(color: secondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.negro,
              ),
              child: Text(
                'Eliminar',
                style: AppFonts.inter(fontWeight: FontWeight.bold),
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
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Sector eliminado exitosamente',
                style: AppFonts.inter(),
              ),
              backgroundColor: AppColors.exitoFuerte,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Error al eliminar el sector: $e',
                style: AppFonts.inter(),
              ),
              backgroundColor: AppColors.errorFuerte,
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
          style: AppFonts.inter(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
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
            return const Center(child: CargandoPuntos());
          }

          if (snapshot.hasError) {
            return ErrorAmable(
              titulo: 'No pudimos cargar los sectores',
              detalle: 'Error al cargar sectores: ${snapshot.error}',
              onReintentar: () => setState(() {}),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return EstadoVacio(
              titulo: 'No hay sectores registrados',
              accion: ElevatedButton.icon(
                onPressed: () => _mostrarDialogoSector(),
                icon: const Icon(Icons.add),
                label: Text(
                  'Agregar Primer Sector',
                  style: AppFonts.inter(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dorado,
                  foregroundColor: AppColors.negro,
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
                          fillColor: AppColors.tarjetaAlta,
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
                      backgroundColor: AppColors.dorado,
                      foregroundColor: AppColors.negro,
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: conMargenInferior(
                    context,
                    const EdgeInsets.symmetric(horizontal: 16),
                    extra: espacioBotonFlotante,
                  ),
                  itemCount: sectores.length,
                  itemBuilder: (context, index) => Builder(builder: (context) {
                    final sector = sectores[index];
                    final data = sector.data() as Map<String, dynamic>?;

                    final String nombreSector =
                        data?['nombre']?.toString().trim().isNotEmpty == true
                        ? data!['nombre'].toString()
                        : 'Sector sin nombre';
                    final bool turnoCerrado = data?['turnoCerrado'] == true;

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
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: secondaryColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                turnoCerrado
                                    ? Icons.lock_outline
                                    : Icons.location_on,
                                color: turnoCerrado
                                    ? AppColors.tintaSecundaria
                                    : secondaryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombreSector,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: primaryColor,
                                    ),
                                  ),
                                  if (turnoCerrado) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.aviso.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Turno cerrado',
                                        style: AppFonts.inter(
                                          fontSize: 14,
                                          color: AppColors.aviso,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (turnoCerrado)
                                  TextButton.icon(
                                    icon: const Icon(Icons.lock_open, size: 18),
                                    label: Text(
                                      'Reabrir',
                                      style: AppFonts.inter(fontSize: 14),
                                    ),
                                    onPressed: () => _reabrirSector(sector),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    color: AppColors.dorado,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: AppTamanos.toque,
                                    minHeight: AppTamanos.toque,
                                  ),
                                  onPressed: () =>
                                      _mostrarDialogoSector(sector: sector),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: AppColors.error,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: AppTamanos.toque,
                                    minHeight: AppTamanos.toque,
                                  ),
                                  onPressed: () => _eliminarSector(sector),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).entradaEnLista(index),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoSector(),
        backgroundColor: AppColors.dorado,
        foregroundColor: AppColors.negro,
        icon: const Icon(Icons.add),
        label: Text(
          'Agregar Sector',
          style: AppFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _DialogRenombrarSector extends StatefulWidget {
  final String nombreInicial;
  final Color backgroundColor;
  final Color primaryColor;
  final Color accentColor;
  final Color secondaryColor;

  const _DialogRenombrarSector({
    required this.nombreInicial,
    required this.backgroundColor,
    required this.primaryColor,
    required this.accentColor,
    required this.secondaryColor,
  });

  @override
  State<_DialogRenombrarSector> createState() => _DialogRenombrarSectorState();
}

class _DialogRenombrarSectorState extends State<_DialogRenombrarSector> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.nombreInicial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _guardar() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.backgroundColor,
      title: Text(
        'Renombrar sector',
        style: AppFonts.inter(
          fontWeight: FontWeight.bold,
          color: widget.primaryColor,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Nombre del sector',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        style: AppFonts.inter(),
        onSubmitted: (_) => _guardar(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: AppFonts.inter(color: widget.secondaryColor),
          ),
        ),
        ElevatedButton(
          onPressed: _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.dorado,
            foregroundColor: AppColors.negro,
          ),
          child: Text(
            'Guardar',
            style: AppFonts.inter(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
