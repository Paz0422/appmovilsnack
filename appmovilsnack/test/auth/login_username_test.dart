import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_appsnack/auth/auth_manager.dart';

/// Auth falso con una sola cuenta: responde como Firebase Auth cuando el
/// correo o la contraseña no coinciden.
class _AuthFalso extends Fake implements FirebaseAuth {
  _AuthFalso({required this.email, required this.password});

  final String email;
  final String password;
  final intentos = <String>[];

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    intentos.add(email);
    if (email != this.email || password != this.password) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    return _CredencialFalsa();
  }
}

class _CredencialFalsa extends Fake implements UserCredential {}

void main() {
  late FakeFirebaseFirestore firestore;
  late _AuthFalso auth;
  final manager = AuthManager();

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = _AuthFalso(email: 'paz@test.cl', password: 'clave123');
    manager.usarInstanciasDePrueba(firestore: firestore, auth: auth);
    // Registrada como "Paz": el registro guarda el id normalizado.
    await firestore
        .collection('usernames')
        .doc(AuthManager.normalizarUsername('Paz'))
        .set({'email': 'paz@test.cl'});
  });

  tearDown(() => manager.usarInstanciasDePrueba());

  test('el registro guarda "Paz" como id normalizado "paz"', () {
    expect(AuthManager.normalizarUsername('Paz'), 'paz');
    expect(AuthManager.normalizarUsername(' Juan  Perez '), 'juanperez');
  });

  for (final escrito in ['Paz', 'paz', ' PAZ ']) {
    test('"$escrito" inicia sesión con la misma cuenta', () async {
      final error = await manager.iniciarSesion(
        username: escrito,
        password: 'clave123',
      );
      expect(error, isNull);
      expect(auth.intentos, ['paz@test.cl']);
    });
  }

  test('usuario inexistente: "Usuario o contraseña incorrectos"', () async {
    final error = await manager.iniciarSesion(
      username: 'nadie',
      password: 'clave123',
    );
    expect(error, 'Usuario o contraseña incorrectos');
    expect(auth.intentos, isEmpty);
  });

  test('contraseña incorrecta: "Usuario o contraseña incorrectos"', () async {
    final error = await manager.iniciarSesion(
      username: 'Paz',
      password: 'otra',
    );
    expect(error, 'Usuario o contraseña incorrectos');
  });

  test('username con "/" no rompe la búsqueda', () async {
    final error = await manager.iniciarSesion(
      username: 'a/b',
      password: 'clave123',
    );
    expect(error, 'Usuario o contraseña incorrectos');
  });
}
