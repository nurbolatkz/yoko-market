import 'package:shared_preferences/shared_preferences.dart';

/// Persists a pending referral invite code across cold starts and screen transitions.
///
/// Lifecycle:
///   1. App opens via deep link `/invite/{code}` → [save] stores the code.
///   2. After OTP: [consume] returns the code and clears it atomically.
///   3. If user skips the invite step: [clear] removes it.
///
/// Uses SharedPreferences so the code survives process restarts.
abstract final class PendingInvite {
  static const _key = 'pending_invite_code';

  static Future<void> save(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code.trim().toUpperCase());
  }

  /// Returns the stored code and removes it atomically, or null if none.
  static Future<String?> consume() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null) await prefs.remove(_key);
    return code;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
