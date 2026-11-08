# Architecture

## Decision: biometric-gated Keychain/Keystore key + rate-limited app PIN fallback

### What we store and where

```
FlutterSecureStorage
  yoko_access           — JWT access token (60 min, existing)
  yoko_refresh          — opaque refresh token (90 days, existing)
  fl_pin_hash           — HMAC-SHA256(PIN, device_salt), hex string
  fl_pin_salt           — 32-byte random salt, base64 (generated once per device)
  fl_pin_attempts       — JSON: {count, locked_until_ms}  (persists across restarts)
  fl_fast_login_enabled — "1" when setup complete
  fl_device_id          — UUID generated once at install, sent on refresh calls
```

No other file, database, or plaintext storage.  
The PIN itself is **never stored**. Only a salted HMAC is stored.

### Why not PIN → AES key

A 4-digit PIN has 10 000 combinations. If an attacker extracts the encrypted
blob (possible on rooted/jailbroken devices), offline brute force takes under a
second. A PIN-derived key therefore provides no real protection; it only adds
complexity.

### How app PIN protection actually works here

1. A **random 256-bit salt** (`fl_pin_salt`) is generated once and stored in Keychain/Keystore.
2. On PIN setup: `fl_pin_hash = HMAC-SHA256(pin_digits, salt)` stored in
   `FlutterSecureStorage`.
3. On PIN entry: compute the same HMAC; compare constant-time to `fl_pin_hash`.
4. If correct: proceed to load `yoko_refresh`.
5. If wrong: increment `fl_pin_attempts`; apply backoff (see [security.md](security.md)).
6. The salt lives in Keychain/Keystore — it cannot be read without unlocking the
   device. This makes offline HMAC precomputation impractical even with 10 000
   combinations, because the attacker cannot obtain the salt without device
   access.

**Limitation**: on a rooted/jailbroken device the salt *can* be extracted,
reducing security to rate-limiting only. This is explicitly documented in
[security.md](security.md). The same device compromise also enables extraction
of the refresh token directly — so the PIN is not the weakest link.

### Why not system device passcode (alternative considered)

Using `kSecAccessControlDevicePasscode` (iOS) / `setDeviceSecure` (Android)
presents the **system passcode dialog**, not an in-app UI. This:
- breaks the app's visual design and UX continuity;
- cannot be tested in automated tests;
- is unavailable on devices without a system passcode set.

The app-PIN model gives us full UI control and consistent behaviour on all devices.

### Biometrics

`local_auth ^2.3.0` is used **only** to trigger the platform biometric challenge.
It does not store keys or tokens.

```
local_auth.authenticate()   →  success
      ↓
load yoko_refresh from FlutterSecureStorage
      ↓
pass to AuthService.tryRefresh()
```

Biometrics is optional and supplementary. If biometrics is unavailable, changed,
or cancelled, the app falls back to PIN entry without clearing the session.

### Separation: local_auth vs cryptographic storage

| Concern | Responsible component |
|---------|----------------------|
| Proving user presence (biometric challenge) | `local_auth` |
| Storing secret tokens at rest | `flutter_secure_storage` (Keychain/EncryptedSharedPrefs) |
| PIN verification (rate-limited) | `FastLoginService` (HMAC check) |
| Token rotation and server auth | `AuthService` / Django backend |

`local_auth` and `flutter_secure_storage` are **independent layers**.
Biometric success does not "decrypt" anything — it simply signals the app to
proceed with reading the already-protected token storage.

### Flutter packages to add (PR-1)

```yaml
local_auth: ^2.3.0        # biometric challenge
# flutter_secure_storage already present at ^11.0.0
# crypto: included transitively via dart:convert + pointycastle, but we
#   can use dart:convert + package:crypto for HMAC-SHA256
crypto: ^3.0.5
```

### Storage contract (`FastLoginService` public API)

```dart
// Returns true only after a complete setup (PIN set + fl_fast_login_enabled == "1").
Future<bool> isEnabled();

// Called during PIN setup. Generates salt if absent, stores HMAC, sets enabled flag.
// Throws ArgumentError if pin is not exactly 4 digits.
Future<void> setupPin(String pin);

// Returns true if pin matches stored HMAC. Applies attempt counter.
// Throws FastLoginLockedError if too many attempts.
// Never logs pin.
Future<bool> verifyPin(String pin);

// Triggers biometric challenge via local_auth. Returns true on success.
// Returns false if unavailable, cancelled, or not enrolled — does NOT throw.
Future<bool> unlockWithBiometrics();

// Clears all fast-login keys (called on logout, SMS recovery, account deletion).
// Does NOT clear yoko_access / yoko_refresh — AuthService owns those.
Future<void> disable();

// Returns remaining lockout milliseconds (0 = not locked).
Future<int> lockoutRemainingMs();
```

### iOS platform configuration (PR-1)

`Info.plist` must include:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Используется для быстрого входа в приложение</string>
```

`android/app/build.gradle` does not need changes; `local_auth` uses
`BiometricPrompt` automatically on API 28+.

### Flutter Secure Storage platform options

```dart
// iOS: token survives app reinstall only if iCloud Keychain enabled.
// Use kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly so tokens are
// not backed up to iCloud (sensitive session material).
static const _iosOpts = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
);

// Android: use EncryptedSharedPreferences (AES-256 via Jetpack Security).
static const _androidOpts = AndroidOptions(encryptedSharedPreferences: true);
```

These options apply to ALL FlutterSecureStorage writes in `AuthService` and
`FastLoginService`. Align them in PR-1.
