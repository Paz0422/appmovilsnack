import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_appsnack/auth/auth_manager.dart';

class _Usuario extends Fake implements User {
  _Usuario(this.uid, {this.email, this.errorAlRecargar});

  @override
  final String uid;

  @override
  final String? email;

  final Object? errorAlRecargar;

  @override
  Future<void> reload() async {
    if (errorAlRecargar != null) throw errorAlRecargar!;
  }
}

class _AuthFalso extends Fake implements FirebaseAuth {
  _AuthFalso(this.currentUser);

  @override
  User? currentUser;

  int cierres = 0;

  @override
  Future<void> signOut() async {
    cierres++;
    currentUser = null;
  }
}

void main() {
  // cerrarSesion consulta el navigator de la app.
  TestWidgetsFlutterBinding.ensureInitialized();
  final manager = AuthManager();
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());
  tearDown(() async {
    // Limpia el perfil en memoria del singleton entre tests.
    manager.usarInstanciasDePrueba(firestore: db, auth: _AuthFalso(null));
    await manager.cerrarSesion();
    manager.usarInstanciasDePrueba();
  });

  group('verificarCuentaVigente', () {
    Future<_AuthFalso> verificar(Object? error) async {
      final auth = _AuthFalso(_Usuario('u1', errorAlRecargar: error));
      manager.usarInstanciasDePrueba(firestore: db, auth: auth);
      await manager.verificarCuentaVigente();
      return auth;
    }

    test('sin señal mantiene la sesión', () async {
      final auth = await verificar(
        FirebaseAuthException(code: 'network-request-failed'),
      );
      expect(auth.cierres, 0);
    });

    test('un error cualquiera no cierra la sesión', () async {
      final auth = await verificar(Exception('timeout'));
      expect(auth.cierres, 0);
    });

    for (final codigo in AuthManager.codigosCuentaInvalida) {
      test('cuenta inválida ($codigo) cierra la sesión', () async {
        final auth = await verificar(FirebaseAuthException(code: codigo));
        expect(auth.cierres, 1);
      });
    }

    test('cuenta vigente no hace nada', () async {
      final auth = await verificar(null);
      expect(auth.cierres, 0);
    });
  });

  group('resolverPerfil', () {
    setUp(() => manager.usarInstanciasDePrueba(
          firestore: db,
          auth: _AuthFalso(null),
        ));

    test('encuentra el perfil por uid', () async {
      await db.doc('usuarios/u1').set({'rol': 'vendedor'});
      final perfil = await manager.resolverPerfil(_Usuario('u1'));
      expect(perfil?.id, 'u1');
      expect(manager.perfilEnCache()?.id, 'u1');
    });

    test('perfiles antiguos: por auth_uid o por email', () async {
      await db.doc('usuarios/viejo').set({'auth_uid': 'u2'});
      expect((await manager.resolverPerfil(_Usuario('u2')))?.id, 'viejo');

      await manager.cerrarSesion();
      await db.doc('usuarios/otro').set({'email': 'a@b.cl'});
      expect(
        (await manager.resolverPerfil(_Usuario('u3', email: 'a@b.cl')))?.id,
        'otro',
      );
    });

    test('si el servidor responde que no existe devuelve null', () async {
      expect(await manager.resolverPerfil(_Usuario('nadie')), isNull);
    });
  });
}
