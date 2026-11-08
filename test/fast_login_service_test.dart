/// Unit tests for FastLoginService.
///
/// All tests use [InMemoryKeyValueStore] and [FakeBiometrics] — no platform
/// channels, no FlutterSecureStorage, no local_auth binary.
///
/// Run with: flutter test test/fast_login_service_test.dart
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yokomarket/services/fast_login_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Builds a service with an injectable clock so lockout tests don't sleep.
FastLoginService _makeService({
  InMemoryKeyValueStore? store,
  FakeBiometrics? bio,
  int Function()? nowMs,
}) {
  return FastLoginService(
    storage: store ?? InMemoryKeyValueStore(),
    biometrics: bio ?? FakeBiometrics(),
    nowMs: nowMs,
  );
}

void main() {
  // ── isEnabled ──────────────────────────────────────────────────────────────

  group('isEnabled', () {
    test('returns false on empty storage', () async {
      final svc = _makeService();
      expect(await svc.isEnabled(), isFalse);
    });

    test('returns true after setupPin', () async {
      final svc = _makeService();
      await svc.setupPin('1234');
      expect(await svc.isEnabled(), isTrue);
    });

    test('returns false after disable', () async {
      final svc = _makeService();
      await svc.setupPin('1234');
      await svc.disable();
      expect(await svc.isEnabled(), isFalse);
    });
  });

  // ── setupPin ───────────────────────────────────────────────────────────────

  group('setupPin', () {
    test('rejects empty string', () async {
      final svc = _makeService();
      expect(() => svc.setupPin(''), throwsArgumentError);
    });

    test('rejects fewer than 4 digits', () async {
      final svc = _makeService();
      expect(() => svc.setupPin('123'), throwsArgumentError);
    });

    test('rejects more than 4 digits', () async {
      final svc = _makeService();
      expect(() => svc.setupPin('12345'), throwsArgumentError);
    });

    test('rejects non-digit characters', () async {
      final svc = _makeService();
      expect(() => svc.setupPin('12ab'), throwsArgumentError);
      expect(() => svc.setupPin(' 123'), throwsArgumentError);
    });

    test('pin_hash is not equal to raw PIN', () async {
      final store = InMemoryKeyValueStore();
      final svc = _makeService(store: store);
      await svc.setupPin('1234');
      final hash = store.peek('fl_pin_hash');
      expect(hash, isNotNull);
      expect(hash, isNot('1234'));
    });

    test('salt is generated and stored as base64', () async {
      final store = InMemoryKeyValueStore();
      final svc = _makeService(store: store);
      await svc.setupPin('1234');
      final saltB64 = store.peek('fl_pin_salt');
      expect(saltB64, isNotNull);
      // 32 bytes in base64 = 44 chars
      final decoded = base64.decode(saltB64!);
      expect(decoded.length, 32);
    });

    test('two setups on same store reuse salt', () async {
      final store = InMemoryKeyValueStore();
      final svc = _makeService(store: store);
      await svc.setupPin('1234');
      final salt1 = store.peek('fl_pin_salt');
      await svc.setupPin('5678');
      final salt2 = store.peek('fl_pin_salt');
      expect(salt1, equals(salt2));
    });

    test('different PINs produce different hashes', () async {
      final store1 = InMemoryKeyValueStore();
      final store2 = InMemoryKeyValueStore();
      // Same salt requires same store — use same service with two calls.
      final svc = _makeService(store: store1);
      await svc.setupPin('1111');
      final hash1 = store1.peek('fl_pin_hash');

      await svc.setupPin('2222');
      final hash2 = store1.peek('fl_pin_hash');

      expect(hash1, isNot(hash2));
      // Silence unused warning
      store2.peek('fl_pin_hash');
    });

    test('resets attempt counter to zero', () async {
      final store = InMemoryKeyValueStore();
      final svc = _makeService(store: store);
      // Simulate a dirty counter
      await store.write(
        'fl_pin_attempts',
        '{"count":3,"locked_until_ms":0}',
      );
      await svc.setupPin('1234');
      final raw = store.peek('fl_pin_attempts')!;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      expect(map['count'], 0);
    });
  });

  // ── verifyPin ──────────────────────────────────────────────────────────────

  group('verifyPin — correct PIN', () {
    test('returns true for correct PIN', () async {
      final svc = _makeService();
      await svc.setupPin('9999');
      expect(await svc.verifyPin('9999'), isTrue);
    });

    test('resets attempt counter on success', () async {
      final store = InMemoryKeyValueStore();
      final svc = _makeService(store: store);
      await svc.setupPin('1234');
      await svc.verifyPin('0000'); // wrong
      await svc.verifyPin('0000'); // wrong (count=2)
      await svc.verifyPin('1234'); // correct → reset
      final raw = store.peek('fl_pin_attempts')!;
      expect((jsonDecode(raw) as Map)['count'], 0);
    });

    test('correct PIN after partial failures still returns true', () async {
      final svc = _makeService();
      await svc.setupPin('5678');
      await svc.verifyPin('0000');
      await svc.verifyPin('0000');
      expect(await svc.verifyPin('5678'), isTrue);
    });
  });

  group('verifyPin — wrong PIN / attempt counter', () {
    test('returns false on first wrong attempt', () async {
      final svc = _makeService();
      await svc.setupPin('1234');
      expect(await svc.verifyPin('0000'), isFalse);
    });

    test('returns false on second and third wrong attempt', () async {
      final svc = _makeService();
      await svc.setupPin('1234');
      expect(await svc.verifyPin('0000'), isFalse);
      expect(await svc.verifyPin('0000'), isFalse);
      expect(await svc.verifyPin('0000'), isFalse);
    });

    test('increments count correctly', () async {
      final store = InMemoryKeyValueStore();
      final svc = _makeService(store: store);
      await svc.setupPin('1234');
      await svc.verifyPin('0000');
      final raw = store.peek('fl_pin_attempts')!;
      expect((jsonDecode(raw) as Map)['count'], 1);
    });
  });

  group('verifyPin — lockout on 4th failure', () {
    test('throws FastLoginLockedError after 4th wrong attempt', () async {
      var now = 1_000_000;
      final svc = _makeService(nowMs: () => now);
      await svc.setupPin('1234');
      await svc.verifyPin('0000'); // 1
      await svc.verifyPin('0000'); // 2
      await svc.verifyPin('0000'); // 3
      expect(
        () => svc.verifyPin('0000'), // 4 → 30 s lock
        throwsA(isA<FastLoginLockedError>()),
      );
    });

    test('FastLoginLockedError carries a future timestamp', () async {
      var now = 1_000_000;
      final svc = _makeService(nowMs: () => now);
      await svc.setupPin('1234');
      for (var i = 0; i < 3; i++) await svc.verifyPin('0000');
      try {
        await svc.verifyPin('0000'); // 4th
      } on FastLoginLockedError catch (e) {
        expect(e.lockedUntilMs, greaterThan(now));
        expect(e.lockedUntilMs, e.lockedUntilMs); // is an int
        return;
      }
      fail('Expected FastLoginLockedError');
    });

    test('call during lockout throws immediately without checking PIN', () async {
      var now = 1_000_000;
      final svc = _makeService(nowMs: () => now);
      await svc.setupPin('1234');
      for (var i = 0; i < 3; i++) await svc.verifyPin('0000');
      await expectLater(() => svc.verifyPin('0000'), throwsA(isA<FastLoginLockedError>()));
      // Try with correct PIN — still locked
      await expectLater(() => svc.verifyPin('1234'), throwsA(isA<FastLoginLockedError>()));
    });

    test('lockout expires and allows entry again', () async {
      var now = 1_000_000;
      final svc = _makeService(nowMs: () => now);
      await svc.setupPin('1234');
      for (var i = 0; i < 3; i++) await svc.verifyPin('0000');
      await expectLater(() => svc.verifyPin('0000'), throwsA(isA<FastLoginLockedError>()));
      // Advance clock past the 30-second lock
      now += 31 * 1000;
      expect(await svc.verifyPin('1234'), isTrue);
    });
  });

  group('verifyPin — extended lockout on 5th failure', () {
    test('throws FastLoginLockedError after 5th wrong attempt', () async {
      var now = 1_000_000;
      final svc = _makeService(nowMs: () => now);
      await svc.setupPin('1234');
      for (var i = 0; i < 3; i++) await svc.verifyPin('0000');
      await expectLater(() => svc.verifyPin('0000'), throwsA(isA<FastLoginLockedError>())); // 4
      // Advance past 30 s lock
      now += 31 * 1000;
      await expectLater(() => svc.verifyPin('0000'), throwsA(isA<FastLoginLockedError>())); // 5 → 5 min
    });

    test('5-min lock expires and allows entry', () async {
      var now = 1_000_000;
      final svc = _makeService(nowMs: () => now);
      await svc.setupPin('1234');
      for (var i = 0; i < 3; i++) await svc.verifyPin('0000');
      await expectLater(() => svc.verifyPin('0000'), throwsA(isA<FastLoginLockedError>())); // 4
      now += 31 * 1000; // past 30 s
      await expectLater(() => svc.verifyPin('0000'), throwsA(isA<FastLoginLockedError>())); // 5 → 5 min
      now += 5 * 60 * 1000 + 1000; // past 5 min
      expect(await svc.verifyPin('1234'), isTrue);
    });
  });

  group('verifyPin — wipe on 6th failure', () {
    test('throws FastLoginWipedError after 6th wrong attempt', () async {
      var now = 1_000_000;
      final svc = _makeService(nowMs: () => now);
      await svc.setupPin('1234');
      for (var i = 0; i < 3; i++) await svc.verifyPin('0000');
      await expectLater(() => svc.verifyPin('0000'), throwsA(isA<FastLoginLockedError>())); // 4
      now += 31 * 1000;
      await expectLater(() => svc.verifyPin('0000'), throwsA(isA<FastLoginLockedError>())); // 5 → 5 min lock
      now += 5 * 60 * 1000 + 1000;
      await expectLater(
        () => svc.verifyPin('0000'), // 6 → wipe
        throwsA(isA<FastLoginWipedError>()),
      );
    });

    test('isEnabled returns false after wipe', () async {
      var now = 1_000_000;
      final svc = _makeService(nowMs: () => now);
      await svc.setupPin('1234');
      for (var i = 0; i < 3; i++) await svc.verifyPin('0000');
      await expectLater(() => svc.verifyPin('0000'), throwsA(isA<FastLoginLockedError>()));
      now += 31 * 1000;
      await expectLater(() => svc.verifyPin('0000'), throwsA(isA<FastLoginLockedError>()));
      now += 5 * 60 * 1000 + 1000;
      await expectLater(() => svc.verifyPin('0000'), throwsA(isA<FastLoginWipedError>()));
      expect(await svc.isEnabled(), isFalse);
    });

    test('all fl_ storage keys cleared after wipe', () async {
      var now = 1_000_000;
      final store = InMemoryKeyValueStore();
      final svc = _makeService(store: store, nowMs: () => now);
      await svc.setupPin('1234');
      for (var i = 0; i < 3; i++) await svc.verifyPin('0000');
      await expectLater(() => svc.verifyPin('0000'), throwsA(isA<FastLoginLockedError>()));
      now += 31 * 1000;
      await expectLater(() => svc.verifyPin('0000'), throwsA(isA<FastLoginLockedError>()));
      now += 5 * 60 * 1000 + 1000;
      await expectLater(() => svc.verifyPin('0000'), throwsA(isA<FastLoginWipedError>()));

      expect(store.peek('fl_fast_login_enabled'), isNull);
      expect(store.peek('fl_pin_hash'), isNull);
      expect(store.peek('fl_pin_salt'), isNull);
      expect(store.peek('fl_pin_attempts'), isNull);
    });
  });

  group('verifyPin — missing storage data', () {
    test('throws FastLoginWipedError if hash missing', () async {
      final store = InMemoryKeyValueStore();
      final svc = _makeService(store: store);
      await svc.setupPin('1234');
      await store.delete('fl_pin_hash');
      await expectLater(() => svc.verifyPin('1234'), throwsA(isA<FastLoginWipedError>()));
    });

    test('throws FastLoginWipedError if salt missing', () async {
      final store = InMemoryKeyValueStore();
      final svc = _makeService(store: store);
      await svc.setupPin('1234');
      await store.delete('fl_pin_salt');
      await expectLater(() => svc.verifyPin('1234'), throwsA(isA<FastLoginWipedError>()));
    });
  });

  // ── disable ────────────────────────────────────────────────────────────────

  group('disable', () {
    test('clears all fl_ keys', () async {
      final store = InMemoryKeyValueStore();
      final svc = _makeService(store: store);
      await svc.setupPin('1234');
      await svc.disable();
      expect(store.peek('fl_fast_login_enabled'), isNull);
      expect(store.peek('fl_pin_hash'), isNull);
      expect(store.peek('fl_pin_salt'), isNull);
      expect(store.peek('fl_pin_attempts'), isNull);
    });

    test('does not touch yoko_ keys', () async {
      final store = InMemoryKeyValueStore();
      final svc = _makeService(store: store);
      await svc.setupPin('1234');
      // Simulate AuthService keys
      await store.write('yoko_access', 'access-jwt');
      await store.write('yoko_refresh', 'refresh-opaque');
      await svc.disable();
      expect(store.peek('yoko_access'), 'access-jwt');
      expect(store.peek('yoko_refresh'), 'refresh-opaque');
    });

    test('disable is idempotent', () async {
      final svc = _makeService();
      await svc.disable();
      await svc.disable(); // should not throw
      expect(await svc.isEnabled(), isFalse);
    });
  });

  // ── lockoutRemainingMs ─────────────────────────────────────────────────────

  group('lockoutRemainingMs', () {
    test('returns 0 when not locked', () async {
      final svc = _makeService();
      await svc.setupPin('1234');
      expect(await svc.lockoutRemainingMs(), 0);
    });

    test('returns positive ms during lockout', () async {
      var now = 1_000_000;
      final svc = _makeService(nowMs: () => now);
      await svc.setupPin('1234');
      for (var i = 0; i < 3; i++) await svc.verifyPin('0000');
      await expectLater(() => svc.verifyPin('0000'), throwsA(isA<FastLoginLockedError>()));
      final remaining = await svc.lockoutRemainingMs();
      expect(remaining, greaterThan(0));
      expect(remaining, lessThanOrEqualTo(30 * 1000));
    });

    test('returns 0 after lockout expires', () async {
      var now = 1_000_000;
      final svc = _makeService(nowMs: () => now);
      await svc.setupPin('1234');
      for (var i = 0; i < 3; i++) await svc.verifyPin('0000');
      await expectLater(() => svc.verifyPin('0000'), throwsA(isA<FastLoginLockedError>()));
      now += 31 * 1000;
      expect(await svc.lockoutRemainingMs(), 0);
    });
  });

  // ── unlockWithBiometrics ───────────────────────────────────────────────────

  group('unlockWithBiometrics', () {
    test('returns false when biometrics unavailable', () async {
      final svc = _makeService(bio: FakeBiometrics(available: false));
      expect(await svc.unlockWithBiometrics(), isFalse);
    });

    test('returns false when biometrics available but challenge fails', () async {
      final svc = _makeService(bio: FakeBiometrics(available: true, result: false));
      expect(await svc.unlockWithBiometrics(), isFalse);
    });

    test('returns true when biometrics succeeds', () async {
      final svc = _makeService(bio: FakeBiometrics(available: true, result: true));
      expect(await svc.unlockWithBiometrics(), isTrue);
    });
  });

  // ── getDeviceId ────────────────────────────────────────────────────────────

  group('getDeviceId', () {
    test('returns a non-empty string', () async {
      final svc = _makeService();
      final id = await svc.getDeviceId();
      expect(id, isNotEmpty);
    });

    test('returns the same id on repeated calls', () async {
      final svc = _makeService();
      final id1 = await svc.getDeviceId();
      final id2 = await svc.getDeviceId();
      expect(id1, equals(id2));
    });

    test('two fresh services generate different ids', () async {
      final svc1 = _makeService();
      final svc2 = _makeService();
      expect(await svc1.getDeviceId(), isNot(await svc2.getDeviceId()));
    });

    test('looks like a UUID v4', () async {
      final svc = _makeService();
      final id = await svc.getDeviceId();
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });
  });
}
