import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';

enum AuthState { unknown, guest, authenticated, sessionError }

class AuthProvider with ChangeNotifier {
  AuthProvider({AuthService? authService})
    : _auth = authService ?? AuthService();

  final AuthService _auth;

  AuthState _state = AuthState.unknown;
  AuthState get state => _state;
  bool get isAuthenticated => _state == AuthState.authenticated;

  UserProfile? _user;
  UserProfile? get user => _user;

  // Called once from main.dart via AuthProvider()..init().
  Future<void> init() => _tryRestoreSession();

  // Called from the "Повторить" button in ProfileScreen.
  Future<void> retryInit() async {
    _state = AuthState.unknown;
    notifyListeners();
    await _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    try {
      final hasSession = await _auth.hasSession();
      if (!hasSession) {
        _state = AuthState.guest;
        notifyListeners();
        return;
      }
      final newToken = await _auth.tryRefresh();
      if (newToken == null) {
        // _doRefresh clears tokens on 401; on network error tokens are preserved.
        // Check which case this is so we can offer a retry instead of dropping to guest.
        final stillHasSession = await _auth.hasSession();
        _state = stillHasSession ? AuthState.sessionError : AuthState.guest;
        notifyListeners();
        return;
      }
      _user = await _auth.getProfile();
      _state = _user != null ? AuthState.authenticated : AuthState.guest;
    } catch (_) {
      // SecureStorage unavailable (test env) — treat as guest.
      _state = AuthState.guest;
    }
    notifyListeners();
  }

  Future<String?> getAccessToken() => _auth.getAccessToken();

  // Calls the single-flight refresh and updates auth state on failure.
  // Use when an API call returns 401 to attempt silent re-auth before giving up.
  Future<String?> ensureFreshToken() async {
    final newToken = await _auth.tryRefresh();
    if (newToken == null) {
      final stillHasSession = await _auth.hasSession();
      if (!stillHasSession) _user = null;
      _state = stillHasSession ? AuthState.sessionError : AuthState.guest;
      notifyListeners();
    }
    return newToken;
  }

  Future<UserProfile> patchUser({String? fullName}) async {
    final updated = await _auth.patchProfile(fullName: fullName);
    _user = updated;
    notifyListeners();
    return updated;
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

  Future<void> deleteAccount() async {
    await _auth.deleteAccount();
    _user = null;
    _state = AuthState.guest;
    notifyListeners();
  }
}
