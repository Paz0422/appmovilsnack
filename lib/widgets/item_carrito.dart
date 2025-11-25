class ItemCarrito {
  final String nombre;
  final double precio;
  int cantidad;
  final int stock;

  ItemCarrito({
    required this.nombre,
    required this.precio,
    required this.cantidad,
    required this.stock,
  });

  // Método para convertir un ítem del carrito a un formato que Firestore entiende (Map)
  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'precio': precio,
      'cantidad': cantidad,
      'stock':
          stock, // Guardamos el stock en el momento de la venta por si acaso
    };
  }
}
