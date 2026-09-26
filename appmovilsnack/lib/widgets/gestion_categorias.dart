// Admin: gestionar categorías de productos (agregar, listar, eliminar)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';
import 'package:front_appsnack/core/tipografia.dart';
import 'package:front_appsnack/utils/categorias_producto.dart';
import 'package:front_appsnack/core/margen_inferior.dart';
import 'package:front_appsnack/core/app_theme.dart';

class GestionCategorias extends StatefulWidget {
  const GestionCategorias({super.key});

  @override
  State<GestionCategorias> createState() => _GestionCategoriasState();
}

class _GestionCategoriasState extends State<GestionCategorias> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  bool _loading = true;
  String? _error;

  final Color primaryColor = AppColors.primaryLight;
  final Color accentColor = AppColors.accent;
  final Color secondaryColor = AppColors.secondary;

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
    final messenger = ScaffoldMessenger.of(context);
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
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        hintText: 'Ej: Bebidas calientes',
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
                              Text(e.key, style: AppFonts.inter()),
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
                    style: AppFonts.inter(color: secondaryColor),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nombre.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Escribe un nombre',
                            style: AppFonts.inter(),
                          ),
                          backgroundColor: AppColors.errorFuerte,
                        ),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dorado,
                    foregroundColor: AppColors.negro,
                  ),
                  child: Text(
                    'Agregar',
                    style: AppFonts.inter(fontWeight: FontWeight.bold),
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
      final ultimo = _docs.isEmpty ? null : _docs.last.data();
      final orden = _docs.isEmpty
          ? 0
          : (ultimo?['orden'] as num? ?? 0).toInt() + 1;
      await col.add({
        'nombre': nombre,
        'icono': iconoSeleccionado,
        'orden': orden,
      });
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Categoría "$nombre" agregada',
              style: AppFonts.inter(),
            ),
            backgroundColor: AppColors.exitoFuerte,
          ),
        );
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: AppFonts.inter()),
            backgroundColor: AppColors.errorFuerte,
          ),
        );
      }
    }
  }

  Future<void> _eliminarCategoria(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final data = doc.data();
    final nombre = data['nombre']?.toString() ?? 'esta categoría';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Eliminar categoría',
          style: AppFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Eliminar "$nombre"? Los productos con esta categoría quedarán como "Otros".',
          style: AppFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: AppFonts.inter(color: secondaryColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Eliminar',
              style: AppFonts.inter(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await doc.reference.delete();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Categoría eliminada', style: AppFonts.inter()),
            backgroundColor: AppColors.exitoFuerte,
          ),
        );
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: AppFonts.inter()),
            backgroundColor: AppColors.errorFuerte,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Categorías de productos',
          style: AppFonts.inter(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _cargar,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorAmable(
              titulo: 'No pudimos cargar las categorías',
              detalle: 'Error: $_error',
              onReintentar: _cargar,
            )
          : ListView.builder(
              padding: conMargenInferior(
                context,
                const EdgeInsets.all(16),
                extra: espacioBotonFlotante,
              ),
              itemCount: _docs.length,
              itemBuilder: (context, index) {
                final doc = _docs[index];
                final data = doc.data();
                final nombre = data['nombre']?.toString() ?? 'Sin nombre';
                final icono = data['icono']?.toString() ?? 'restaurant';
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
                      style: AppFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
                      onPressed: () => _eliminarCategoria(doc),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarCategoria,
        backgroundColor: AppColors.dorado,
        foregroundColor: AppColors.negro,
        icon: const Icon(Icons.add),
        label: Text(
          'Agregar categoría',
          style: AppFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
