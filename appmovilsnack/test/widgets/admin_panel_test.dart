import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/fuentes.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/screens/admin/home_admin.dart';
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

void main() {
  setUpAll(cargarFuentesApp);

  testWidgets('inicio: lo urgente primero, accesos rápidos y el resumen', (tester) async {
    await _abrirPanel(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Requiere atención'), findsOneWidget);
    expect(find.text('3 incidencias por resolver'), findsOneWidget);
    expect(find.text('Accesos rápidos'), findsOneWidget);
    expect(find.text('Agregar stock'), findsOneWidget);
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

  testWidgets('la barra inferior lleva a cada sección con sus opciones', (tester) async {
    await _abrirPanel(tester);

    final secciones = {
      'Evento': [
        'Cierres de turno',
        'Agregar stock',
        'Incidencias por resolver',
        'Bandejeo por sector',
        'Entrar como vendedor',
      ],
      'Reportes': [
        'Ventas por categoría',
        'Stock por sector',
        'Mermas',
        'Diferencias en traspasos',
        'Ranking de vendedores',
      ],
      'Ajustes': [
        'Eventos y sectores',
        'Productos y categorías',
        'Personal',
        'Usuarios y roles',
        'Cerrar sesión',
      ],
    };

    for (final seccion in secciones.entries) {
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(seccion.key),
      ));
      await tester.pump();
      for (final opcion in seccion.value) {
        final encontrado = find.text(opcion).hitTestable();
        await tester.scrollUntilVisible(encontrado, 200,
            scrollable: find.byType(Scrollable).hitTestable().first);
        expect(encontrado, findsOneWidget, reason: '${seccion.key} → $opcion');
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('las incidencias pendientes se ven en la sección Evento', (tester) async {
    await _abrirPanel(tester, incidencias: 7);
    // Contador sobre el ícono de la barra.
    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('7')),
      findsOneWidget,
    );
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Evento'),
    ));
    await tester.pump();
    // Y en la tarjeta de la opción.
    expect(
      find.descendant(of: find.byType(ListView).hitTestable(), matching: find.text('7')),
      findsOneWidget,
    );
  });

  testWidgets('en tablet la navegación va en una barra lateral', (tester) async {
    await _abrirPanel(tester, size: const Size(1280, 800));
    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('teléfono chico sin desbordes', (tester) async {
    await _abrirPanel(tester, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('con letra del sistema al 130 % no se desborda', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _abrirPanel(tester, size: const Size(360, 740));
    expect(tester.takeException(), isNull);
    for (final seccion in ['Evento', 'Reportes', 'Ajustes']) {
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(seccion),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: seccion);
    }
  });
}
