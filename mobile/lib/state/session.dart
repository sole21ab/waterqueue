import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import '../services/api_client.dart';

class Session extends ChangeNotifier {
  AuthUser? _user;
  String? _token;

  AuthUser? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _user != null && _token != null;

  void signIn(AuthResult result) {
    _user = result.user;
    _token = result.token;
    notifyListeners();
  }

  void signOut() {
    _user = null;
    _token = null;
    notifyListeners();
  }
}
