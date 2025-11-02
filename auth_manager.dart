import 'package:cloud_firestore/cloud_firestore.dart';

class AuthManager {
  static final AuthManager _instance = AuthManager._internal();
  factory AuthManager() => _instance;
  AuthManager._internal();

  DocumentSnapshot? loggedInVendor;
}
