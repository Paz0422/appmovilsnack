// Admin: gestionar categorías de productos (agregar, listar, eliminar)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:front_appsnack/utils/categorias_producto.dart';

class GestionCategorias extends StatefulWidget {
  const GestionCategorias({super.key});

  @override
  State<GestionCategorias> createState() => _GestionCategoriasState();
}

class _GestionCategoriasState extends State<GestionCategorias> {
  List<QueryDocumentSnapshot> _docs = [];
  bool _loading = true;
  String? _error;

  final Color primaryColor = const Color(0xFF2B2B2B);
  final Color accentColor = const Color(0xFFDABF41);
  final Color secondaryColor = const Color(0xFF6B4D2F);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await cargarCategoriasFirestore();
      final snap = await FirebaseFirestore.instance
          .collection('categorias')
          .orderBy('orden')
          .get();
      if (mounted) {
        setState(() {
          _docs = snap.docs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _agregarCategoria() async {
    String nombre = '';
    String iconoSeleccionado = 'restaurant';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Agregar categoría',
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
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        hintText: 'Ej: Bebidas calientes',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: accentColor, width: 2),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      onChanged: (v) => nombre = v.trim(),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: iconoSeleccionado,
                      decoration: InputDecoration(
                        labelText: 'Ícono',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: iconosDisponibles.map((e) {
                        return DropdownMenuItem(
                          value: e.key,
                          child: Row(
                            children: [
                              Icon(e.value, size: 22, color: secondaryColor),
                              const SizedBox(width: 8),
                              Text(e.key, style: GoogleFonts.poppins()),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          iconoSeleccionado = v;
                          setDialogState(() {});
                        }
                      },
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
                    if (nombre.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Escribe un nombre',
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
                    'Agregar',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    try {
      final col = FirebaseFirestore.instance.collection('categorias');
      final ultimo = _docs.isEmpty
          ? null
          : _docs.last.data() as Map<String, dynamic>?;
      final orden = _docs.isEmpty
          ? 0
          : (ultimo?['orden'] as num? ?? 0).toInt() + 1;
      await col.add({
        'nombre': nombre,
        'icono': iconoSeleccionado,
        'orden': orden,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Categoría "$nombre" agregada',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _eliminarCategoria(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?;
    final nombre = data?['nombre']?.toString() ?? 'esta categoría';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Eliminar categoría',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Eliminar "$nombre"? Los productos con esta categoría quedarán como "Otros".',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: secondaryColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Eliminar',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await doc.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Categoría eliminada', style: GoogleFonts.poppins()),
            backgroundColor: Colors.green,
          ),
        );
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: Text(
          'Categorías de productos',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _cargar,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error: $_error',
                  style: GoogleFonts.poppins(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _docs.length,
              itemBuilder: (context, index) {
                final doc = _docs[index];
                final data = doc.data() as Map<String, dynamic>?;
                final nombre = data?['nombre']?.toString() ?? 'Sin nombre';
                final icono = data?['icono']?.toString() ?? 'restaurant';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: accentColor.withValues(alpha: 0.2),
                      child: Icon(
                        iconoDesdeNombre(icono),
                        color: secondaryColor,
                      ),
                    ),
                    title: Text(
                      nombre,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _eliminarCategoria(doc),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarCategoria,
        backgroundColor: accentColor,
        foregroundColor: primaryColor,
        icon: const Icon(Icons.add),
        label: Text(
          'Agregar categoría',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
