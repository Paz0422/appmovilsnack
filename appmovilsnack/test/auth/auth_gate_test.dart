import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_appsnack/auth/auth_gate.dart';
import 'package:front_appsnack/auth/login_screen.dart';
import 'package:front_appsnack/core/app_theme.dart';
import '../helpers/fuentes.dart';

class _Usuario extends Fake implements User {
  _Usuario(this.uid);

  @override
  final String uid;
}

/// Pantalla elegida según el rol del perfil, sin abrir las pantallas reales
/// (que leen Firestore).
Widget _pantallaPara(PerfilUsuario perfil) =>
    Text(perfil.data()?['rol'] == 'admin' ? 'Panel admin' : 'Elegir estadio');

void main() {
  setUpAll(cargarFuentesApp);

  late StreamController<User?> sesion;
  // Perfiles leídos antes del test: las lecturas de FakeFirebaseFirestore no
  // avanzan con el reloj falso de testWidgets.
  late PerfilUsuario perfilAdmin;
  late int cierresDeSesion;
  late int verificaciones;

  setUp(() async {
    sesion = StreamController<User?>();
    final db = FakeFirebaseFirestore();
    await db.doc('usuarios/u1').set({'rol': 'admin', 'username': 'paz'});
    perfilAdmin = await db.doc('usuarios/u1').get();
    cierresDeSesion = 0;
    verificaciones = 0;
  });
  tearDown(() => sesion.close());

  Future<void> abrir(
    WidgetTester tester, {
    Future<PerfilUsuario?> Function(User user)? cargarPerfil,
    Future<void> Function()? verificarCuenta,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.tema,
      home: AuthGate(
        cambiosDeSesion: sesion.stream,
        // Solo existe el perfil de u1; para otro usuario el servidor
        // responde que no existe (null).
        cargarPerfil:
            cargarPerfil ?? (user) async => user.uid == 'u1' ? perfilAdmin : null,
        pantallaPara: _pantallaPara,
        verificarCuenta: verificarCuenta ?? () async => verificaciones++,
        cerrarSesion: () async {
          cierresDeSesion++;
          sesion.add(null);
        },
      ),
    ));
  }

  testWidgets('mientras Firebase restaura la sesión se ve la carga, no el login',
      (tester) async {
    await abrir(tester);
    await tester.pump(const Duration(seconds: 3));

    expect(find.byType(PantallaCargaInicial), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('con sesión guardada entra directo a la pantalla de su rol',
      (tester) async {
    final perfil = Completer<PerfilUsuario?>();
    await abrir(tester, cargarPerfil: (_) => perfil.future);

    sesion.add(_Usuario('u1'));
    await tester.pump();
    // El perfil todavía carga: sigue la pantalla de carga.
    expect(find.byType(PantallaCargaInicial), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    perfil.complete(perfilAdmin);
    await tester.pump();
    await tester.pump();
    expect(find.text('Panel admin'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('la verificación de la cuenta no demora la entrada', (tester) async {
    final nuncaTermina = Completer<void>();
    await abrir(tester, verificarCuenta: () {
      verificaciones++;
      return nuncaTermina.future;
    });

    sesion.add(_Usuario('u1'));
    await tester.pump();
    await tester.pump();

    expect(verificaciones, 1);
    expect(find.text('Panel admin'), findsOneWidget);
  });

  testWidgets('sin sesión muestra el login', (tester) async {
    await abrir(tester);
    sesion.add(null);
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(verificaciones, 0);
  });

  testWidgets('sin señal para el perfil no cierra la sesión y deja reintentar',
      (tester) async {
    var intentos = 0;
    await abrir(tester, cargarPerfil: (user) async {
      intentos++;
      if (intentos == 1) throw TimeoutException('sin señal');
      return perfilAdmin;
    });

    sesion.add(_Usuario('u1'));
    await tester.pump();
    await tester.pump();

    expect(find.text('No pudimos cargar su perfil'), findsOneWidget);
    expect(cierresDeSesion, 0);
    expect(find.byType(LoginScreen), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Panel admin'), findsOneWidget);
  });

  testWidgets('desde el error puede cerrar sesión', (tester) async {
    await abrir(tester, cargarPerfil: (_) async => throw TimeoutException(''));
    sesion.add(_Usuario('u1'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pump();
    await tester.pump();
    expect(cierresDeSesion, 1);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('si el perfil no existe cierra sesión y lo explica en el login',
      (tester) async {
    await abrir(tester);
    sesion.add(_Usuario('sin-perfil'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(cierresDeSesion, 1);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('No encontramos su perfil'), findsOneWidget);
  });
}
