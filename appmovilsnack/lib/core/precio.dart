/// Productos sin precio: se guardan con `precio: 0` y solo se cuentan
/// (sus ventas suman $0 en cierres, bandejeo y estadísticas).
bool tienePrecio(num? precio) => precio != null && precio > 0;

/// "1.250.000": redondea al entero y separa miles con punto.
String separarMiles(num valor) {
  final s = valor.round().abs().toString();
  final buf = StringBuffer(valor.round() < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    buf.write(s[i]);
    final resto = s.length - i - 1;
    if (resto > 0 && resto % 3 == 0) buf.write('.');
  }
  return buf.toString();
}

/// "$1.250.000" o "-$1.500". Único formato de dinero de la app.
String formatearPesos(num monto) => monto.round() < 0
    ? '-\$${separarMiles(-monto)}'
    : '\$${separarMiles(monto)}';

/// "$1.500" o "Sin precio".
String textoPrecio(num? precio) =>
    tienePrecio(precio) ? formatearPesos(precio!) : 'Sin precio';

/// "Precio: $1.500" o "Sin precio".
String etiquetaPrecio(num? precio) =>
    tienePrecio(precio) ? 'Precio: ${textoPrecio(precio)}' : 'Sin precio';
