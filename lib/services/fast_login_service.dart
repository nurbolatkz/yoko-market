import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

// ── Storage abstraction ───────────────────────────────────────────────────────

/// Injectable key-value store. Production: [SecureKeyValueStore].
/// Tests: [InMemoryKeyValueStore].
abstract interface class FastLoginStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Production adapter over [FlutterSecureStorage].
/// iOS: tokens survive background, not backed up to iCloud.
/// Android: AES-256 EncryptedSharedPreferences via Jetpack Security.
class SecureKeyValueStore implements FastLoginStorage {
  SecureKeyValueStore()
    : _inner = const FlutterSecureStorage(
        // Android v11+: default uses AES_GCM_NoPadding with hardware-backed
        // Keystore key — no extra parameter needed.
        // iOS: first_unlock_this_device keeps tokens available after first
        // unlock without iCloud backup.
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  final FlutterSecureStorage _inner;

  @override
  Future<String?> read(String key) => _inner.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _inner.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _inner.delete(key: key);
}

/// In-memory fake for unit tests.
class InMemoryKeyValueStore implements FastLoginStorage {
  final _map = <String, String>{};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;

  @override
  Future<void> delete(String key) async => _map.remove(key);

  /// Inspect raw storage in tests (never used in production code).
  String? peek(String key) => _map[key];
}

// ── Biometrics abstraction ────────────────────────────────────────────────────

/// Injectable biometric interface. Production: [SystemBiometrics].
/// Tests: [FakeBiometrics].
abstract interface class FastLoginBiometrics {
  Future<bool> canCheck();
  Future<bool> authenticate(String localizedReason);
}

/// Production adapter over [LocalAuthentication].
class SystemBiometrics implements FastLoginBiometrics {
  final _auth = LocalAuthentication();

  @override
  Future<bool> canCheck() => _auth.canCheckBiometrics;

  @override
  Future<bool> authenticate(String localizedReason) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      // These are all non-fatal: user cancelled, biometric not enrolled,
      // too many attempts (device lock), or feature not supported.
      // All of them mean "not unlocked" — fall back to PIN.
      if (e.code == auth_error.notEnrolled ||
          e.code == auth_error.lockedOut ||
          e.code == auth_error.permanentlyLockedOut ||
          e.code == auth_error.notAvailable) {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// Test fake: configure [result] before calling [authenticate].
class FakeBiometrics implements FastLoginBiometrics {
  bool available;
  bool result;

  FakeBiometrics({this.available = false, this.result = false});

  @override
  Future<bool> canCheck() async => available;

  @override
  Future<bool> authenticate(String localizedReason) async => result;
}

// ── Errors ────────────────────────────────────────────────────────────────────

/// Thrown by [FastLoginService.verifyPin] when too many wrong attempts have
/// triggered a lockout. [lockedUntilMs] is an epoch-millisecond timestamp;
/// use `lockedUntilMs - DateTime.now().millisecondsSinceEpoch` for display.
class FastLoginLockedError implements Exception {
  const FastLoginLockedError(this.lockedUntilMs);
  final int lockedUntilMs;
}

/// Thrown by [FastLoginService.verifyPin] after the maximum wrong-attempt
/// threshold is reached. All fast-login data has been wiped; the app must
/// route the user to SMS re-auth.
class FastLoginWipedError implements Exception {
  const FastLoginWipedError();
}

// ── Internal model ────────────────────────────────────────────────────────────

class _AttemptRecord {
  const _AttemptRecord({required this.count, required this.lockedUntilMs});

  factory _AttemptRecord.fromJson(Map<String, dynamic> j) => _AttemptRecord(
    count: (j['count'] as num).toInt(),
    lockedUntilMs: (j['locked_until_ms'] as num).toInt(),
  );

  final int count;
  final int lockedUntilMs;

  Map<String, dynamic> toJson() => {
    'count': count,
    'locked_until_ms': lockedUntilMs,
  };
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Manages 4-digit app PIN and optional biometric unlock.
///
/// Security model:
/// - The PIN is NEVER stored. Only HMAC-SHA256(pin, salt) is persisted.
/// - The salt is a random 32-byte value stored in Keychain/Keystore.
///   An attacker who can read it also has access to the refresh token directly,
///   so the PIN is not the weakest link on a compromised device.
/// - [verifyPin] enforces an exponential back-off and wipes state after 5
///   wrong attempts, requiring SMS re-auth.
///
/// Separation of concerns:
/// - This service owns only `fl_*` keys.
/// - `AuthService` owns `yoko_access` / `yoko_refresh`.
/// - [disable] never touches `yoko_*` keys.
class FastLoginService {
  FastLoginService({
    FastLoginStorage? storage,
    FastLoginBiometrics? biometrics,
    int Function()? nowMs,
  }) : _store = storage ?? SecureKeyValueStore(),
       _biometrics = biometrics ?? SystemBiometrics(),
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final FastLoginStorage _store;
  final FastLoginBiometrics _biometrics;
  final int Function() _nowMs;

  // Storage keys — all prefixed `fl_` to avoid collisions with AuthService.
  static const _kEnabled = 'fl_fast_login_enabled';
  static const _kPinHash = 'fl_pin_hash';
  static const _kPinSalt = 'fl_pin_salt';
  static const _kAttempts = 'fl_pin_attempts';
  static const _kDeviceId = 'fl_device_id';

  // Attempt thresholds.
  static const _kLock1AttemptCount = 4; // 30 s lock after this many failures
  static const _kLock2AttemptCount = 5; // 5 min lock after this many failures
  static const _kWipeAttemptCount = 6;  // wipe after this many failures
  static const _kLock1DurationMs = 30 * 1000;
  static const _kLock2DurationMs = 5 * 60 * 1000;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// True only when setup is complete (PIN stored, enabled flag set).
  Future<bool> isEnabled() async =>
      await _store.read(_kEnabled) == '1';

  /// Sets up fast login with [pin].
  ///
  /// Generates a fresh 32-byte salt (once per device), stores HMAC-SHA256,
  /// resets the attempt counter, and sets the enabled flag.
  ///
  /// Throws [ArgumentError] if [pin] is not exactly 4 ASCII digits.
  Future<void> setupPin(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('PIN must be exactly 4 digits, got: "${pin.length} chars"');
    }

    var saltB64 = await _store.read(_kPinSalt);
    final List<int> salt;
    if (saltB64 == null) {
      salt = _generateSalt();
      saltB64 = base64.encode(salt);
      await _store.write(_kPinSalt, saltB64);
    } else {
      salt = base64.decode(saltB64);
    }

    final hash = _computeHash(pin, salt);
    await _store.write(_kPinHash, hash);
    await _saveAttempts(const _AttemptRecord(count: 0, lockedUntilMs: 0));
    await _store.write(_kEnabled, '1');
  }

  /// Verifies [pin] against the stored HMAC.
  ///
  /// Returns `true` on success (and resets the attempt counter).
  /// Returns `false` on mismatch for the first 3 failures.
  /// Throws [FastLoginLockedError] after the 4th and 5th failures.
  /// Throws [FastLoginWipedError] after the 6th failure (all data wiped).
  ///
  /// The lock timer and attempt count persist across app restarts.
  Future<bool> verifyPin(String pin) async {
    final record = await _loadAttempts();
    final now = _nowMs();

    // Currently locked — do not check the PIN at all.
    if (record.lockedUntilMs > now) {
      throw FastLoginLockedError(record.lockedUntilMs);
    }

    // Already at wipe threshold (e.g., app restarted mid-lockout period).
    if (record.count >= _kWipeAttemptCount) {
      await disable();
      throw const FastLoginWipedError();
    }

    final saltB64 = await _store.read(_kPinSalt);
    final hashStored = await _store.read(_kPinHash);

    if (saltB64 == null || hashStored == null) {
      await disable();
      throw const FastLoginWipedError();
    }

    final salt = base64.decode(saltB64);
    final hashInput = _computeHash(pin, salt);

    if (_constantTimeEquals(hashInput, hashStored)) {
      await _saveAttempts(const _AttemptRecord(count: 0, lockedUntilMs: 0));
      return true;
    }

    // Wrong PIN — increment counter and apply lock/wipe.
    final newCount = record.count + 1;

    if (newCount >= _kWipeAttemptCount) {
      await disable();
      throw const FastLoginWipedError();
    }

    int newLockedUntil = 0;
    if (newCount == _kLock2AttemptCount) {
      newLockedUntil = now + _kLock2DurationMs;
    } else if (newCount == _kLock1AttemptCount) {
      newLockedUntil = now + _kLock1DurationMs;
    }

    await _saveAttempts(_AttemptRecord(count: newCount, lockedUntilMs: newLockedUntil));

    if (newLockedUntil > 0) throw FastLoginLockedError(newLockedUntil);
    return false;
  }

  /// Attempts biometric authentication.
  ///
  /// Returns `true` on success. Returns `false` if biometrics is unavailable,
  /// the user cancelled, biometric data changed, or any error occurs.
  /// Never throws.
  Future<bool> unlockWithBiometrics() async {
    if (!await _biometrics.canCheck()) return false;
    return _biometrics.authenticate('Используйте биометрию для входа в приложение');
  }

  /// Clears all fast-login data. Does NOT clear `yoko_access` / `yoko_refresh`.
  ///
  /// Call on: logout, SMS recovery ("Forgot PIN"), account deletion.
  Future<void> disable() async {
    await Future.wait([
      _store.delete(_kEnabled),
      _store.delete(_kPinHash),
      _store.delete(_kPinSalt),
      _store.delete(_kAttempts),
    ]);
  }

  /// Remaining lockout in milliseconds (0 = not locked).
  Future<int> lockoutRemainingMs() async {
    final record = await _loadAttempts();
    final remaining = record.lockedUntilMs - _nowMs();
    return remaining > 0 ? remaining : 0;
  }

  /// Returns the stable device identifier, generating it on first call.
  Future<String> getDeviceId() async {
    final existing = await _store.read(_kDeviceId);
    if (existing != null) return existing;
    final id = _generateUuid();
    await _store.write(_kDeviceId, id);
    return id;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  List<int> _generateSalt() {
    final rng = Random.secure();
    return List.generate(32, (_) => rng.nextInt(256));
  }

  String _computeHash(String pin, List<int> salt) =>
      Hmac(sha256, salt).convert(utf8.encode(pin)).toString();

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<_AttemptRecord> _loadAttempts() async {
    final raw = await _store.read(_kAttempts);
    if (raw == null) return const _AttemptRecord(count: 0, lockedUntilMs: 0);
    try {
      return _AttemptRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const _AttemptRecord(count: 0, lockedUntilMs: 0);
    }
  }

  Future<void> _saveAttempts(_AttemptRecord record) =>
      _store.write(_kAttempts, jsonEncode(record.toJson()));

  String _generateUuid() {
    final rng = Random.secure();
    final bytes = List.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    return [
      bytes.sublist(0, 4).map(hex).join(),
      bytes.sublist(4, 6).map(hex).join(),
      bytes.sublist(6, 8).map(hex).join(),
      bytes.sublist(8, 10).map(hex).join(),
      bytes.sublist(10, 16).map(hex).join(),
    ].join('-');
  }
}
