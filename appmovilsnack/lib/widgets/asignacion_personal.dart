// Gestión de Personal: base de empleados (nombre + RUT), lista para exportar a Excel/CSV

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:front_appsnack/widgets/share_csv_file_io.dart'
    if (dart.library.html) 'package:front_appsnack/widgets/share_csv_file.dart'
    as share_csv;

const String _kRolVendedor = 'Vendedor';

/// Formato RUT chileno: 20.458.984-7 (puntos cada 3 dígitos, guión antes del dígito verificador)
String formatRut(String input) {
  final solo = input.replaceAll(RegExp(r'[^\dKk]'), '').toUpperCase();
  if (solo.isEmpty) return '';
  if (solo.length == 1) return solo;
  final cuerpo = solo.substring(0, solo.length - 1);
  final dv = solo.substring(solo.length - 1);
  final buf = StringBuffer();
  for (int i = 0; i < cuerpo.length; i++) {
    if (i > 0 && (cuerpo.length - i) % 3 == 0) buf.write('.');
    buf.write(cuerpo[i]);
  }
  return '${buf.toString()}-$dv';
}

class _RutInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatRut(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AsignacionPersonal extends StatefulWidget {
  const AsignacionPersonal({super.key});

  @override
  State<AsignacionPersonal> createState() => _AsignacionPersonalState();
}

class _AsignacionPersonalState extends State<AsignacionPersonal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);
  final Color backgroundColor = const Color(0xFFFDFBF7);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Gestión de Personal',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
        bottom: TabBar(
          controller: _tabController,
          labelColor: accentColor,
          unselectedLabelColor: Colors.white70,
          indicatorColor: accentColor,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 20),
                  const SizedBox(width: 8),
                  Text('Empleados', style: GoogleFonts.poppins(fontSize: 14)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.list_alt, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Lista y exportar',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _EmpleadosTab(
            primaryColor: primaryColor,
            accentColor: accentColor,
            secondaryColor: secondaryColor,
            backgroundColor: backgroundColor,
          ),
          _AsignarYExportarTab(
            primaryColor: primaryColor,
            accentColor: accentColor,
            secondaryColor: secondaryColor,
            backgroundColor: backgroundColor,
          ),
        ],
      ),
    );
  }
}

// --- Pestaña: Base de empleados (nombre + RUT) ---
class _EmpleadosTab extends StatelessWidget {
  final Color primaryColor;
  final Color accentColor;
  final Color secondaryColor;
  final Color backgroundColor;

  const _EmpleadosTab({
    required this.primaryColor,
    required this.accentColor,
    required this.secondaryColor,
    required this.backgroundColor,
  });

  Future<void> _agregarOEditar(
    BuildContext context, {
    DocumentSnapshot? doc,
  }) async {
    final nombreController = TextEditingController(
      text: doc != null
          ? (doc.data() as Map<String, dynamic>)['nombre']?.toString() ?? ''
          : '',
    );
    final rutController = TextEditingController(
      text: doc != null
          ? formatRut(
              (doc.data() as Map<String, dynamic>)['rut']?.toString() ?? '',
            )
          : '',
    );

    final guardado = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text(
            doc == null ? 'Agregar empleado' : 'Editar empleado',
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
                    labelText: 'Nombre',
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
                const SizedBox(height: 16),
                TextField(
                  controller: rutController,
                  decoration: InputDecoration(
                    labelText: 'RUT (ej: 20.458.984-7)',
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
                  keyboardType: TextInputType.text,
                  inputFormatters: [_RutInputFormatter()],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(color: secondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final nombre = nombreController.text.trim();
                if (nombre.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Ingresa el nombre',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: primaryColor,
              ),
              child: Text(
                'Guardar',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (guardado != true) return;

    final nombre = nombreController.text.trim();
    final rut = formatRut(rutController.text.trim());

    try {
      if (doc == null) {
        await FirebaseFirestore.instance.collection('empleados').add({
          'nombre': nombre,
          'rut': rut.isEmpty ? rutController.text.trim() : rut,
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Empleado agregado', style: GoogleFonts.poppins()),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await doc.reference.update({
          'nombre': nombre,
          'rut': rut.isEmpty ? rutController.text.trim() : rut,
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Empleado actualizado',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _eliminar(BuildContext context, DocumentSnapshot doc) async {
    final nombre =
        (doc.data() as Map<String, dynamic>)['nombre']?.toString() ??
        'este empleado';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text(
          'Eliminar empleado',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        content: Text('¿Eliminar a "$nombre"?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: secondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
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
      ),
    );
    if (confirmar != true) return;
    try {
      await doc.reference.delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Empleado eliminado', style: GoogleFonts.poppins()),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('empleados')
              .orderBy('nombre')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: secondaryColor),
                  ),
                ),
              );
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: secondaryColor.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay empleados.\nAgrega nombre y RUT.',
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
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final d = doc.data() as Map<String, dynamic>;
                final nombre = d['nombre']?.toString() ?? '';
                final rut = d['rut']?.toString() ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: accentColor.withValues(alpha: 0.2),
                      child: Icon(Icons.person, color: accentColor),
                    ),
                    title: Text(
                      nombre,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: primaryColor,
                      ),
                    ),
                    subtitle: Text(
                      'RUT: $rut',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: secondaryColor,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: accentColor),
                          onPressed: () => _agregarOEditar(context, doc: doc),
                          tooltip: 'Editar',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _eliminar(context, doc),
                          tooltip: 'Eliminar',
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 24,
          child: FloatingActionButton(
            onPressed: () => _agregarOEditar(context),
            backgroundColor: accentColor,
            foregroundColor: primaryColor,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

// --- Pestaña: Lista (marcar empleados) y exportar a Excel/CSV ---
class _AsignarYExportarTab extends StatefulWidget {
  final Color primaryColor;
  final Color accentColor;
  final Color secondaryColor;
  final Color backgroundColor;

  const _AsignarYExportarTab({
    required this.primaryColor,
    required this.accentColor,
    required this.secondaryColor,
    required this.backgroundColor,
  });

  @override
  State<_AsignarYExportarTab> createState() => _AsignarYExportarTabState();
}

class _AsignarYExportarTabState extends State<_AsignarYExportarTab> {
  final Map<String, bool> _seleccionados = {};
  bool _exportando = false;
  late Future<QuerySnapshot> _empleadosFuture;

  static const String _rolVendedor = _kRolVendedor;

  @override
  void initState() {
    super.initState();
    _empleadosFuture = FirebaseFirestore.instance
        .collection('empleados')
        .orderBy('nombre')
        .get();
  }

  void _refrescarLista() {
    setState(() {
      _empleadosFuture = FirebaseFirestore.instance
          .collection('empleados')
          .orderBy('nombre')
          .get();
    });
  }

  /// CSV sin comillas innecesarias; solo se escapan campos con coma o salto de línea
  static String _csvCell(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Marca los empleados que van en la lista y exporta a Excel.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: widget.secondaryColor,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _refrescarLista,
                icon: const Icon(Icons.refresh, size: 20),
                label: Text(
                  'Refrescar',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<QuerySnapshot>(
            future: _empleadosFuture,
            builder: (context, empSnap) {
              if (empSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (empSnap.hasError) {
                return Center(
                  child: Text(
                    'Error al cargar',
                    style: GoogleFonts.poppins(color: widget.secondaryColor),
                  ),
                );
              }
              final empleados = empSnap.data?.docs ?? [];
              if (empleados.isEmpty) {
                return Center(
                  child: Text(
                    'Agrega empleados en la pestaña "Empleados".',
                    style: GoogleFonts.poppins(color: widget.secondaryColor),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: empleados.length,
                itemBuilder: (context, index) {
                  final doc = empleados[index];
                  final d = doc.data() as Map<String, dynamic>;
                  final id = doc.id;
                  final nombre = d['nombre']?.toString() ?? '';
                  final rut = d['rut']?.toString() ?? '';
                  final asignado = _seleccionados[id] ?? false;
                  return _FilaEmpleadoLista(
                    key: ValueKey(id),
                    id: id,
                    nombre: nombre,
                    rut: rut,
                    asignado: asignado,
                    accentColor: widget.accentColor,
                    primaryColor: widget.primaryColor,
                    secondaryColor: widget.secondaryColor,
                    onChanged: (v) {
                      setState(() => _seleccionados[id] = v ?? false);
                    },
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _exportando ? null : _exportarCsv,
            icon: _exportando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.table_chart),
            label: Text(
              _exportando ? 'Exportando...' : 'Exportar a Excel / CSV',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              foregroundColor: widget.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportarCsv() async {
    setState(() => _exportando = true);
    try {
      final empleadosSnap = await FirebaseFirestore.instance
          .collection('empleados')
          .get();
      final filas = <List<String>>[];
      for (final doc in empleadosSnap.docs) {
        if (_seleccionados[doc.id] != true) continue;
        final d = doc.data();
        filas.add([
          d['nombre']?.toString() ?? '',
          d['rut']?.toString() ?? '',
          _rolVendedor,
        ]);
      }
      if (filas.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Marca al menos un empleado para exportar.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() => _exportando = false);
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('Nombre,RUT,Rol');
      for (final row in filas) {
        buffer.writeln(row.map(_csvCell).join(','));
      }
      final csv = buffer.toString();
      const fileName = 'lista_trabajadores.csv';
      await share_csv.shareCsvAsFile(csv, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lista exportada. Abre el archivo .csv con Excel.',
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
              'Error al exportar: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }
}

/// Fila de empleado en la lista: evita que el parpadeo afecte a toda la lista.
class _FilaEmpleadoLista extends StatelessWidget {
  final String id;
  final String nombre;
  final String rut;
  final bool asignado;
  final Color accentColor;
  final Color primaryColor;
  final Color secondaryColor;
  final ValueChanged<bool?> onChanged;

  const _FilaEmpleadoLista({
    super.key,
    required this.id,
    required this.nombre,
    required this.rut,
    required this.asignado,
    required this.accentColor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: asignado ? Colors.green : Colors.transparent,
          width: asignado ? 2 : 0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Checkbox(
          value: asignado,
          activeColor: accentColor,
          onChanged: onChanged,
        ),
        title: Text(
          nombre,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
        subtitle: Text(
          'RUT: $rut',
          style: GoogleFonts.poppins(fontSize: 12, color: secondaryColor),
        ),
      ),
    );
  }
}
