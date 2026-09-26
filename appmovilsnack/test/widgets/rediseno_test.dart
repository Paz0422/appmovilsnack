import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/fuentes.dart';
import 'package:front_appsnack/auth/login_screen.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/core/avisos_sesion.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';
import 'package:front_appsnack/widgets/dashboard_card.dart';

Widget _app(Widget child) => MaterialApp(theme: AppTheme.tema, home: child);

Future<void> _tamano(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(cargarFuentesApp);

  group('componentes de marca', () {
    testWidgets('pantalla vacía con mascota y mensaje', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(
        body: EstadoVacio(
          titulo: 'Aún no hay traspasos',
          mensaje: 'Cuando otro sector le envíe productos, aparecerán aquí.',
        ),
      )));
      expect(find.text('Aún no hay traspasos'), findsOneWidget);
      expect(find.byType(Mascota), findsOneWidget);
    });

    testWidgets('error amable con Reintentar', (tester) async {
      var reintentos = 0;
      await tester.pumpWidget(_app(Scaffold(
        body: ErrorAmable(onReintentar: () => reintentos++),
      )));
      await tester.tap(find.text('Reintentar'));
      expect(reintentos, 1);
      final boton = tester.getSize(find.byType(ElevatedButton));
      expect(boton.height, greaterThanOrEqualTo(48));
    });

    testWidgets('error amable sin Reintentar no muestra botón', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: ErrorAmable())));
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('aviso con mascota se puede cerrar', (tester) async {
      var cerrado = false;
      await tester.pumpWidget(_app(Scaffold(
        body: AvisoMascota(
          tipo: TipoAviso.exito,
          titulo: '¡Turno cerrado!',
          onCerrar: () => cerrado = true,
        ),
      )));
      await tester.tap(find.byTooltip('Cerrar aviso'));
      expect(cerrado, isTrue);
    });
  });

  group('login', () {
    for (final (nombre, size) in [
      ('teléfono', const Size(360, 740)),
      ('teléfono chico', const Size(320, 568)),
      ('tablet horizontal', const Size(1280, 800)),
    ]) {
      testWidgets('se muestra sin desbordes en $nombre', (tester) async {
        await _tamano(tester, size);
        await tester.pumpWidget(_app(const LoginScreen()));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Ingresar'), findsOneWidget);
        expect(find.byType(Mascota), findsOneWidget);
        final boton = tester.getSize(find.widgetWithText(ElevatedButton, 'Ingresar'));
        expect(boton.height, greaterThanOrEqualTo(48));
      });
    }

    testWidgets('con letra del sistema al 130 % no se desborda', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _tamano(tester, const Size(360, 740));
      await tester.pumpWidget(_app(const LoginScreen(
        mensajeInicial: 'Usuario o contraseña incorrectos',
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('después de cerrar turno muestra el aviso una sola vez', (tester) async {
      await _tamano(tester, const Size(360, 740));
      AvisosSesion.turnoCerradoEn = 'Tribuna Norte';
      await tester.pumpWidget(_app(const LoginScreen()));
      expect(find.text('¡Turno cerrado!'), findsOneWidget);
      expect(find.textContaining('Tribuna Norte'), findsOneWidget);
      expect(AvisosSesion.turnoCerradoEn, isNull);
    });

    testWidgets('el error de sesión se muestra junto al formulario', (tester) async {
      await _tamano(tester, const Size(360, 740));
      await tester.pumpWidget(_app(const LoginScreen(
        mensajeInicial: 'Usuario o contraseña incorrectos',
      )));
      expect(find.text('Usuario o contraseña incorrectos'), findsOneWidget);
    });
  });

  testWidgets('tarjetas del panel del admin caben en un teléfono', (tester) async {
    await _tamano(tester, const Size(360, 740));
    await tester.pumpWidget(_app(Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DashboardCard.kpi(
            title: 'Total vendido',
            value: '\$12.345.678',
            subtitle: '3 partidos con ventas · 1 activo ahora',
            icon: Icons.payments_outlined,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 96,
            child: DashboardCard.stat(
              title: 'Bandejeo en turno abierto',
              value: '\$1.234.567',
              icon: Icons.point_of_sale_outlined,
            ),
          ),
        ],
      ),
    )));
    expect(tester.takeException(), isNull);
    expect(find.text('\$12.345.678'), findsOneWidget);
  });
}
