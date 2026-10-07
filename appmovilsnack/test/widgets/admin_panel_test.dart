import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/fuentes.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/screens/admin/home_admin.dart';
import 'package:front_appsnack/screens/admin/panel_funciones.dart';
import 'package:front_appsnack/services/admin_estadisticas_service.dart';

AdminResumenActivos _resumen() => const AdminResumenActivos(
      totalVendido: 1250000,
      cantidadCierres: 4,
      promedioPorCierre: 312500,
      cantidadEventosActivos: 1,
      eventosConVentas: 2,
      transaccionesBandejeo: 9,
      montoBandejeoTurnosAbiertos: 45000,
      ingresosPorEvento: [
        {'eventoId': 'e1', 'nombre': 'Partido del domingo', 'ingresos': 900000.0},
        {'eventoId': 'e2', 'nombre': 'Amistoso', 'ingresos': 350000.0},
      ],
      ingresosPorSector: [
        {'nombreSector': 'Tribuna Norte', 'nombreEvento': 'Partido del domingo', 'total': 600000.0},
        {'nombreSector': 'Pacífico', 'nombreEvento': 'Partido del domingo', 'total': 300000.0},
      ],
    );

Future<void> _abrirPanel(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  int incidencias = 3,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.tema,
    home: HomeAdmin(
      cargarResumen: () async => _resumen(),
      contarIncidencias: () async => incidencias,
    ),
  ));
  await tester.pump();
  await tester.pump();
}

Future<void> _irA(WidgetTester tester, String seccion) async {
  final barra = find.byType(NavigationBar);
  await tester.tap(find.descendant(
    of: barra.evaluate().isEmpty ? find.byType(NavigationRail) : barra,
    matching: find.text(seccion),
  ));
  await tester.pump();
}

Future<void> _verOpcion(WidgetTester tester, String texto) async {
  final opcion = find.text(texto);
  expect(opcion, findsOneWidget, reason: texto);
  // Lleva la opción al área visible y comprueba que se puede tocar.
  await tester.ensureVisible(opcion);
  await tester.pump();
  expect(opcion.hitTestable(), findsOneWidget, reason: texto);
}

void main() {
  setUpAll(cargarFuentesApp);

  testWidgets('ventas es la pantalla principal, con lo urgente arriba', (tester) async {
    await _abrirPanel(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Requiere atención'), findsOneWidget);
    expect(find.text('3 incidencias por resolver'), findsOneWidget);
    expect(find.text('Total vendido'), findsOneWidget);
    expect(find.text('\$1.250.000'), findsOneWidget);
    final actualizar = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.refresh_rounded),
    );
    expect(actualizar.onPressed, isNotNull);
  });

  testWidgets('sin incidencias no aparece "Requiere atención"', (tester) async {
    await _abrirPanel(tester, incidencias: 0);
    expect(find.text('Requiere atención'), findsNothing);
  });

  testWidgets('el panel tiene los cuatro botones', (tester) async {
    await _abrirPanel(tester);
    await _irA(tester, 'Panel');
    expect(find.byType(BotonCategoria), findsNWidgets(4));
    for (final boton in [
      'Entrar como vendedor',
      'Configuración de eventos',
      'Eventos activos',
      'Reportes',
    ]) {
      await _verOpcion(tester, boton);
    }
    await _verOpcion(tester, 'Cerrar sesión');
    expect(tester.takeException(), isNull);
  });

  final modulos = {
    'Configuración de eventos': [
      'Eventos y sectores',
      'Productos y categorías',
      'Personal',
      'Usuarios y roles',
    ],
    'Eventos activos': [
      'Agregar stock',
      'Cierres de turno',
      'Incidencias por resolver',
      'Bandejeo por sector',
    ],
    'Reportes': [
      'Ventas por categoría',
      'Stock por sector',
      'Mermas',
      'Diferencias en traspasos',
      'Ranking de vendedores',
    ],
  };
  for (final m in modulos.entries) {
    testWidgets('"${m.key}" abre sus módulos con ejemplo', (tester) async {
      await _abrirPanel(tester);
      await _irA(tester, 'Panel');
      await _verOpcion(tester, m.key);
      await tester.tap(find.text(m.key));
      await tester.pumpAndSettle();

      expect(find.byType(PantallaCategoria), findsOneWidget);
      expect(find.byType(MosaicoOpcion), findsNWidgets(m.value.length));
      for (final modulo in m.value) {
        await _verEnPantalla(tester, modulo);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('los módulos explican con un ejemplo', (tester) async {
    await _abrirPanel(tester);
    await _irA(tester, 'Panel');
    await tester.tap(find.text('Eventos activos'));
    await tester.pumpAndSettle();
    await _verEnPantalla(tester, 'Al puesto Norte se le acabaron las bebidas');
  });

  testWidgets('las incidencias se ven en la barra, en su botón y en su módulo',
      (tester) async {
    await _abrirPanel(tester, incidencias: 7);
    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('7')),
      findsOneWidget,
    );
    await _irA(tester, 'Panel');
    expect(
      find.descendant(
        of: find.widgetWithText(BotonCategoria, 'Eventos activos'),
        matching: find.text('7'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Eventos activos'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.widgetWithText(MosaicoOpcion, 'Incidencias por resolver'),
        matching: find.text('7'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('en tablet: barra lateral y los cuatro botones en una fila',
      (tester) async {
    await _abrirPanel(tester, size: const Size(1280, 800));
    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await _irA(tester, 'Panel');
    final filas = {
      for (final t in [
        'Entrar como vendedor',
        'Configuración de eventos',
        'Eventos activos',
        'Reportes',
      ])
        tester.getTopLeft(find.widgetWithText(BotonCategoria, t)).dy,
    };
    expect(filas, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final (nombre, size) in [
    ('tablet vertical', const Size(800, 1280)),
    ('teléfono chico', const Size(320, 640)),
  ]) {
    testWidgets('$nombre sin desbordes', (tester) async {
      await _abrirPanel(tester, size: size);
      expect(tester.takeException(), isNull);
      await _irA(tester, 'Panel');
      expect(tester.takeException(), isNull);
      await _verOpcion(tester, 'Reportes');
      await tester.tap(find.text('Reportes'));
      await tester.pumpAndSettle();
      await _verEnPantalla(tester, 'Ranking de vendedores');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('con letra del sistema al 130 % no se desborda', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _abrirPanel(tester, size: const Size(360, 740));
    expect(tester.takeException(), isNull);
    await _irA(tester, 'Panel');
    expect(tester.takeException(), isNull);
    await _verOpcion(tester, 'Configuración de eventos');
    await tester.tap(find.text('Configuración de eventos'));
    await tester.pumpAndSettle();
    await _verEnPantalla(tester, 'Usuarios y roles');
    expect(tester.takeException(), isNull);
  });
}

/// En una pantalla de categoría (sin IndexedStack): lleva el texto al área
/// visible y comprueba que se puede tocar.
Future<void> _verEnPantalla(WidgetTester tester, String texto) async {
  final f = find.text(texto);
  expect(f, findsOneWidget, reason: texto);
  await tester.ensureVisible(f);
  await tester.pump();
  expect(f.hitTestable(), findsOneWidget, reason: texto);
}
