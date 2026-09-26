import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_appsnack/core/margen_inferior.dart';

void main() {
  Future<EdgeInsets> medir(
    WidgetTester tester, {
    required double barraSistema,
    bool conBarraInferior = false,
    double extra = 0,
  }) async {
    late EdgeInsets resultado;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          viewPadding: EdgeInsets.only(bottom: barraSistema),
          padding: EdgeInsets.only(bottom: barraSistema),
        ),
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar:
                conBarraInferior ? const SizedBox(height: 56) : null,
            body: Builder(
              builder: (context) {
                resultado = conMargenInferior(
                  context,
                  const EdgeInsets.all(16),
                  extra: extra,
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    return resultado;
  }

  testWidgets('suma la barra de navegación de Android al padding de la lista',
      (tester) async {
    final p = await medir(tester, barraSistema: 48);
    expect(p, const EdgeInsets.fromLTRB(16, 16, 16, 64));
  });

  testWidgets('más el espacio del botón flotante', (tester) async {
    final p = await medir(tester, barraSistema: 48, extra: espacioBotonFlotante);
    expect(p.bottom, 16 + 48 + espacioBotonFlotante);
  });

  testWidgets('no suma nada si el Scaffold ya tiene barra inferior propia',
      (tester) async {
    final p = await medir(tester, barraSistema: 48, conBarraInferior: true);
    expect(p.bottom, 16);
  });
}
