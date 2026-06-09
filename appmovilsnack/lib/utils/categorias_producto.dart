// Categorías de productos: listado por defecto y desde Firestore
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> categoriasProductoDefault = [
  'Bebestibles',
  'Snacks',
  'Masas',
  'Galletas',
  'Otros',
];

const String categoriaDefault = 'Otros';

/// Nombres de íconos que el admin puede elegir al crear una categoría
const List<MapEntry<String, IconData>> iconosDisponibles = [
  MapEntry('local_drink', Icons.local_drink),
  MapEntry('lunch_dining', Icons.lunch_dining),
  MapEntry('breakfast_dining', Icons.breakfast_dining),
  MapEntry('cookie', Icons.cookie),
  MapEntry('restaurant', Icons.restaurant),
  MapEntry('fastfood', Icons.fastfood),
  MapEntry('takeout_dining', Icons.takeout_dining),
  MapEntry('coffee', Icons.coffee),
  MapEntry('icecream', Icons.icecream),
  MapEntry('cake', Icons.cake),
  MapEntry('local_pizza', Icons.local_pizza),
  MapEntry('bakery_dining', Icons.bakery_dining),
];

IconData iconoDesdeNombre(String nombre) {
  for (final e in iconosDisponibles) {
    if (e.key == nombre) return e.value;
  }
  return Icons.restaurant;
}

/// Ícono por nombre de categoría (compatibilidad con categorías por defecto)
IconData iconoCategoria(String categoria) {
  final n = categoria.toLowerCase();
  if (n == 'bebestibles') return Icons.local_drink;
  if (n == 'snacks') return Icons.fastfood; // papas / comida rápida
  if (n == 'masas') return Icons.lunch_dining; // hamburguesa
  if (n == 'galletas') return Icons.cookie;
  return Icons.takeout_dining; // Otros: servilleta / llevar
}

/// Ícono para una categoría cargada desde Firestore (tiene campo icono)
IconData iconoCategoriaConIcono(String? iconoName) {
  if (iconoName != null && iconoName.isNotEmpty) {
    return iconoDesdeNombre(iconoName);
  }
  return Icons.restaurant;
}

/// Orden para mostrar; si [listaOrden] no se pasa, se usa la lista por defecto.
int ordenCategoria(String categoria, [List<String>? listaOrden]) {
  final lista = listaOrden ?? categoriasProductoDefault;
  final i = lista.indexOf(categoria);
  return i >= 0 ? i : lista.length;
}

/// Alias para compatibilidad
const categoriasProducto = categoriasProductoDefault;

/// Carga categorías desde Firestore. Si la colección está vacía, crea las por defecto.
Future<List<Map<String, String>>> cargarCategoriasFirestore() async {
  final col = FirebaseFirestore.instance.collection('categorias');
  final snap = await col.orderBy('orden').get();
  if (snap.docs.isEmpty) {
    // Crear categorías por defecto
    const iconos = [
      'local_drink',
      'fastfood',
      'lunch_dining',
      'cookie',
      'takeout_dining',
    ];
    for (int i = 0; i < categoriasProductoDefault.length; i++) {
      await col.add({
        'nombre': categoriasProductoDefault[i],
        'icono': iconos[i],
        'orden': i,
      });
    }
    return categoriasProductoDefault
        .asMap()
        .entries
        .map((e) => {'nombre': e.value, 'icono': iconos[e.key]})
        .toList();
  }
  return snap.docs.map((d) {
    final data = d.data();
    return {
      'nombre': data['nombre']?.toString() ?? '',
      'icono': data['icono']?.toString() ?? 'restaurant',
    };
  }).toList();
}

/// Lista solo los nombres, para compatibilidad donde se usa `List<String>`.
Future<List<String>> cargarNombresCategorias() async {
  final list = await cargarCategoriasFirestore();
  return list.map((e) => e['nombre'] ?? '').where((s) => s.isNotEmpty).toList();
}
