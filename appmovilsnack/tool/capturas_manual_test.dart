// Genera las capturas de pantalla del manual de uso (manual/capturas/).
//
// No es un test de la app: dibuja cada pantalla con las fuentes reales y
// datos de ejemplo, y guarda un PNG. Está fuera de test/ para que no corra
// con `flutter test`. Ejecutar desde appmovilsnack/:
//
//   flutter test tool/capturas_manual_test.dart
//
// Las pantallas que leen Firestore directamente (stock, bandejeo,
// traspasos, mermas, cierre) no se pueden dibujar aquí sin una base real.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_appsnack/auth/login_screen.dart';
import 'package:front_appsnack/auth/register_screen.dart';
import 'package:front_appsnack/auth/reset_password_screen.dart';
import 'package:front_appsnack/core/animaciones.dart';
import 'package:front_appsnack/core/app_theme.dart';
import 'package:front_appsnack/core/avisos_sesion.dart';
import 'package:front_appsnack/screens/admin/home_admin.dart';
import 'package:front_appsnack/screens/vendedores/home_vendedor.dart';
import 'package:front_appsnack/services/admin_estadisticas_service.dart';

import '../test/helpers/fuentes.dart';

/// Tamaño de un teléfono Android común (en puntos) y densidad de la imagen.
const _telefono = Size(393, 852);
const _tablet = Size(1280, 800);
const _densidad = 3.0;

final _salida = Directory('../manual/capturas');
final _marco = GlobalKey();

AdminResumenActivos _resumenEjemplo() => AdminResumenActivos(
  totalVendido: 1842500,
  cantidadCierres: 4,
  promedioPorCierre: 418125,
  cantidadEventosActivos: 1,
  eventosConVentas: 1,
  transaccionesBandejeo: 12,
  montoBandejeoTurnosAbiertos: 170000,
  ingresosPorEvento: const [
    {'eventoId': 'e1', 'nombre': 'Partido del domingo', 'ingresos': 1842500.0},
  ],
  ingresosPorSector: const [
    {'nombreSector': 'Galería Norte', 'nombreEvento': 'Partido del domingo', 'total': 612000.0},
    {'nombreSector': 'Pacífico', 'nombreEvento': 'Partido del domingo', 'total': 498500.0},
    {'nombreSector': 'Galería Sur', 'nombreEvento': 'Partido del domingo', 'total': 401000.0},
    {'nombreSector': 'Andes', 'nombreEvento': 'Partido del domingo', 'total': 331000.0},
  ],
  ventasEnElTiempo: VentasEnElTiempo(
    porHora: true,
    tramos: [
      for (final (h, m) in [
        (16, 95000.0),
        (17, 260000.0),
        (18, 410000.0),
        (19, 318000.0),
        (20, 529500.0),
        (21, 230000.0),
      ])
        (fecha: DateTime(2026, 9, 6, h), monto: m),
    ],
  ),
);

Future<void> _guardar(WidgetTester tester, String nombre) async {
  await tester.runAsync(() async {
    final limite =
        _marco.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final imagen = await limite.toImage(pixelRatio: _densidad);
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
    final archivo = File('${_salida.path}/$nombre.png');
    await archivo.writeAsBytes(bytes!.buffer.asUint8List());
  });
  // ignore: avoid_print
  print('captura: $nombre');
}

/// Dibuja [pantalla] en el tamaño dado, con las imágenes de la marca ya
/// cargadas (si no, salen en blanco).
Future<void> _mostrar(
  WidgetTester tester,
  Widget pantalla, {
  Size tamano = _telefono,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _marco,
      child: MaterialApp(
        // Pantalla nueva en cada captura (si no, se reutiliza el estado).
        key: UniqueKey(),
        theme: AppTheme.tema,
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => pantalla,
        ),
      ),
    ),
  );
  final contexto = tester.element(find.byType(Builder).first);
  await tester.runAsync(() async {
    for (final img in ['logo.png', 'mascota.png']) {
      await precacheImage(AssetImage('assets/imagenes/$img'), contexto);
    }
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _tocar(WidgetTester tester, String texto, {Type? dentroDe}) async {
  final f = dentroDe == null
      ? find.text(texto)
      : find.descendant(of: find.byType(dentroDe), matching: find.text(texto));
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  final contexto = tester.element(find.byType(Builder).first);
  await tester.runAsync(() async {
    for (final img in ['logo.png', 'mascota.png']) {
      await precacheImage(AssetImage('assets/imagenes/$img'), contexto);
    }
  });
  await tester.pump();
}

HomeAdmin _admin({int incidencias = 2}) => HomeAdmin(
  cargarResumen: () async => _resumenEjemplo(),
  contarIncidencias: () async => incidencias,
);

void main() {
  setUpAll(() async {
    await cargarFuentesApp();
    // Firebase "de mentira": las pantallas que lo piden al construirse no
    // fallan, y sin datos muestran su estado inicial.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    Movimiento.reducido = true;
    _salida.createSync(recursive: true);
  });

  testWidgets('acceso', (tester) async {
    await _mostrar(tester, const LoginScreen());
    await _guardar(tester, 'login');

    await _mostrar(tester, const LoginScreen(
      mensajeInicial: 'Usuario o contraseña incorrectos',
    ));
    await _guardar(tester, 'login_error');

    AvisosSesion.turnoCerradoEn = 'Galería Norte';
    await _mostrar(tester, const LoginScreen());
    await _guardar(tester, 'login_turno_cerrado');

    await _mostrar(tester, const RegisterScreen());
    await _guardar(tester, 'registro');

    await _mostrar(tester, const ResetPasswordScreen());
    await _guardar(tester, 'recuperar');
  });

  testWidgets('vendedor', (tester) async {
    // Sin base de datos, las consultas de Firestore fallan después de
    // dibujar: esos errores se ignoran, solo interesa la imagen.
    await runZonedGuarded(() async {
    await _mostrar(tester, const HomeVendedor(
      eventId: 'Partido del domingo',
      sectorId: 'norte',
      nombreSector: 'Galería Norte',
    ));
    await tester.pump(const Duration(seconds: 1));
    await _guardar(tester, 'vendedor_panel');
    // El reloj del panel se reprograma cada segundo: se desmonta la pantalla
    // y se deja vencer el último timer.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    }, (_, _) {});
  });

  testWidgets('administrador en teléfono', (tester) async {
    await _mostrar(tester, _admin());
    await tester.pump();
    await _guardar(tester, 'admin_ventas');

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -620));
    await tester.pump(const Duration(milliseconds: 600));
    await _guardar(tester, 'admin_ventas_graficos');

    await _tocar(tester, 'Panel', dentroDe: NavigationBar);
    await _guardar(tester, 'admin_panel');

    for (final (categoria, archivo) in [
      ('Configuración de eventos', 'admin_configuracion'),
      ('Eventos activos', 'admin_eventos_activos'),
      ('Reportes', 'admin_reportes'),
    ]) {
      await _tocar(tester, categoria);
      await _guardar(tester, archivo);
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
    }
  });

  testWidgets('administrador en tablet', (tester) async {
    await _mostrar(tester, _admin(), tamano: _tablet);
    await tester.pump();
    await _guardar(tester, 'tablet_ventas');
    await _tocar(tester, 'Panel', dentroDe: NavigationRail);
    await _guardar(tester, 'tablet_panel');
  });
}
