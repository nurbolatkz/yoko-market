import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';

enum AuthState { unknown, guest, authenticated }

class AuthProvider with ChangeNotifier {
  AuthProvider({AuthService? authService})
    : _auth = authService ?? AuthService();

  final AuthService _auth;

  AuthState _state = AuthState.unknown;
  AuthState get state => _state;
  bool get isAuthenticated => _state == AuthState.authenticated;

  UserProfile? _user;
  UserProfile? get user => _user;

  Future<void> init() async {
    try {
      final hasSession = await _auth.hasSession();
      if (!hasSession) {
        _state = AuthState.guest;
        notifyListeners();
        return;
      }
      final newToken = await _auth.tryRefresh();
      if (newToken == null) {
        _state = AuthState.guest;
        notifyListeners();
        return;
      }
      _user = await _auth.getProfile();
      _state = _user != null ? AuthState.authenticated : AuthState.guest;
    } catch (_) {
      // SecureStorage unavailable (test env) — treat as guest
      _state = AuthState.guest;
    }
    notifyListeners();
  }

  Future<int> requestOtp(String phone) => _auth.requestOtp(phone);

  Future<void> login(String phone, String code) async {
    _user = await _auth.verifyOtp(phone, code);
    _state = AuthState.authenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.logout();
    _user = null;
    _state = AuthState.guest;
    notifyListeners();
  }
}
