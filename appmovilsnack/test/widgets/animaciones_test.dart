import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/fuentes.dart';
import 'package:front_appsnack/auth/login_screen.dart';
import 'package:front_appsnack/core/animaciones.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/screens/admin/home_admin.dart';
import 'package:front_appsnack/services/admin_estadisticas_service.dart';
import 'package:front_appsnack/widgets/comunes/animados.dart';
import 'package:front_appsnack/widgets/comunes/marca.dart';

/// Los demás tests corren sin animaciones (test/flutter_test_config.dart).
/// Aquí se activan para comprobar que todas terminan solas (ninguna queda
/// repitiéndose fuera de las cargas) y que nada se desborda mientras se
/// mueve.

Widget _app(Widget child) => MaterialApp(theme: AppTheme.tema, home: child);

Future<void> _tamano(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Avanza el reloj en pasos cortos hasta que terminen las animaciones, sin
/// pumpAndSettle (los relojes en pantalla piden un cuadro por segundo).
Future<void> _dejarTerminar(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  }
}

AdminResumenActivos _resumen() => AdminResumenActivos(
      totalVendido: 1250000,
      cantidadCierres: 4,
      promedioPorCierre: 312500,
      cantidadEventosActivos: 1,
      eventosConVentas: 2,
      transaccionesBandejeo: 9,
      montoBandejeoTurnosAbiertos: 45000,
      ingresosPorEvento: const [
        {'eventoId': 'e1', 'nombre': 'Partido del domingo', 'ingresos': 900000.0},
        {'eventoId': 'e2', 'nombre': 'Amistoso', 'ingresos': 350000.0},
      ],
      ingresosPorSector: const [
        {'nombreSector': 'Tribuna Norte', 'nombreEvento': 'Partido del domingo', 'total': 600000.0},
        {'nombreSector': 'Pacífico', 'nombreEvento': 'Partido del domingo', 'total': 300000.0},
      ],
      ventasEnElTiempo: VentasEnElTiempo(
        porHora: true,
        tramos: [
          for (final (h, m) in [(18, 150000.0), (19, 0.0), (20, 700000.0), (21, 400000.0)])
            (fecha: DateTime(2026, 9, 6, h), monto: m),
        ],
      ),
    );

void main() {
  setUpAll(cargarFuentesApp);
  setUp(() => Movimiento.reducido = false);
  tearDown(() => Movimiento.reducido = true);

  testWidgets('la cifra cuenta desde 0 y termina en el valor exacto', (tester) async {
    await tester.pumpWidget(_app(Scaffold(
      body: CifraAnimada(valor: 1500, formatear: (v) => '\$${v.round()}'),
    )));
    expect(find.text('\$0'), findsOneWidget);
    await _dejarTerminar(tester);
    expect(find.text('\$1500'), findsOneWidget);
  });

  testWidgets('con "Quitar animaciones" los atajos no envuelven nada', (tester) async {
    Movimiento.reducido = true;
    const hijo = SizedBox();
    expect(identical(hijo.entrada(orden: 3), hijo), isTrue);
    expect(identical(hijo.aparicionRebote(), hijo), isTrue);
    expect(identical(hijo.temblor(), hijo), isTrue);
  });

  testWidgets('un aviso que aparece no hace repetir la entrada de lo de abajo', (tester) async {
    var conAviso = false;
    late StateSetter cambiar;
    await tester.pumpWidget(_app(Scaffold(
      body: StatefulBuilder(builder: (context, setState) {
        cambiar = setState;
        return Column(
          children: [
            Aparece(child: conAviso ? const Text('aviso').entrada() : null),
            const Text('botón').entrada(orden: 3),
          ],
        );
      }),
    )));
    await _dejarTerminar(tester);

    cambiar(() => conAviso = true);
    await tester.pump();
    final opacidad = tester
        .widget<FadeTransition>(find
            .ancestor(of: find.text('botón'), matching: find.byType(FadeTransition))
            .first)
        .opacity
        .value;
    expect(opacidad, 1, reason: 'el botón no debe volver a desvanecerse');
    await _dejarTerminar(tester);
  });

  for (final (nombre, size) in [
    ('teléfono chico', const Size(320, 568)),
    ('tablet horizontal', const Size(1280, 800)),
  ]) {
    testWidgets('login animado en $nombre: termina y no se desborda', (tester) async {
      await _tamano(tester, size);
      await tester.pumpWidget(_app(const LoginScreen(
        mensajeInicial: 'Usuario o contraseña incorrectos',
      )));
      await _dejarTerminar(tester);
      // Ningún ticker sigue corriendo: todas las animaciones terminaron.
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.byType(Mascota), findsWidgets);
      expect(find.text('Ingresar'), findsOneWidget);
    });
  }

  testWidgets('admin animado: ventas y panel terminan', (tester) async {
    await _tamano(tester, const Size(390, 844));
    await tester.pumpWidget(_app(HomeAdmin(
      cargarResumen: () async => _resumen(),
      contarIncidencias: () async => 3,
    )));
    await _dejarTerminar(tester);
    // Ventas (pantalla principal): cifras y gráficos terminan solos.
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.text('\$1.250.000'), findsOneWidget);
    expect(find.text('Ventas en el tiempo'), findsOneWidget);
    expect(find.textContaining('Hora peak: 20:00 – 21:00'), findsOneWidget);

    // Panel: los módulos y sus íconos animados también terminan.
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Panel'),
    ));
    await _dejarTerminar(tester);
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.text('Eventos activos'), findsOneWidget);
  });
}
