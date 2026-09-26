/// Productos sin precio: se guardan con `precio: 0` y solo se cuentan
/// (sus ventas suman $0 en cierres, bandejeo y estadísticas).
bool tienePrecio(num? precio) => precio != null && precio > 0;

/// "$1500" o "Sin precio".
String textoPrecio(num? precio) =>
    tienePrecio(precio) ? '\$${precio!.toStringAsFixed(0)}' : 'Sin precio';

/// "Precio: $1500" o "Sin precio".
String etiquetaPrecio(num? precio) =>
    tienePrecio(precio) ? 'Precio: ${textoPrecio(precio)}' : 'Sin precio';
