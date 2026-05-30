import 'package:flutter_test/flutter_test.dart';
import 'package:front_appsnack/core/app_theme.dart';

void main() {
  test('AppTheme.light expone un ThemeData válido', () {
    expect(AppTheme.light, isNotNull);
    expect(AppTheme.light.useMaterial3, isTrue);
  });
}
