import 'package:flutter_test/flutter_test.dart';
import 'package:front_appsnack/core/precio.dart';

void main() {
  test('separa miles con punto y redondea', () {
    expect(separarMiles(0), '0');
    expect(separarMiles(999), '999');
    expect(separarMiles(1000), '1.000');
    expect(separarMiles(1250000), '1.250.000');
    expect(separarMiles(1499.6), '1.500');
    expect(separarMiles(-12345), '-12.345');
  });

  test('formato único de pesos', () {
    expect(formatearPesos(1250000), '\$1.250.000');
    expect(formatearPesos(312500.4), '\$312.500');
    expect(formatearPesos(-1500), '-\$1.500');
    expect(formatearPesos(-0.4), '\$0');
  });

  test('precio de producto', () {
    expect(textoPrecio(1500), '\$1.500');
    expect(textoPrecio(0), 'Sin precio');
    expect(etiquetaPrecio(1500), 'Precio: \$1.500');
  });
}
