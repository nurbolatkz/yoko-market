# Security Model

## PIN attempt limits (persists across restarts)

The attempt counter is stored as JSON in `FlutterSecureStorage` under `fl_pin_attempts`:

```json
{ "count": 3, "locked_until_ms": 0 }
```

| Attempts | Consequence |
|----------|-------------|
| 1–3 | Allowed immediately |
| 4 | 30-second lockout (`locked_until_ms = now + 30_000`) |
| 5 | 5-minute lockout |
| 6+ | Wipe fast-login data (`FastLoginService.disable()`) + force SMS re-auth |

After a correct PIN, `count` resets to 0.

The counter survives app restarts because it lives in `FlutterSecureStorage`.
It does NOT survive reinstall (acceptable: reinstall implies device re-enrollment).

The lockout timer is enforced at verification time, not display time.
Even if the UI is bypassed (e.g., by killing and relaunching the app),
`verifyPin()` checks `locked_until_ms` before comparing the HMAC.

## Session gating: what is blocked before unlock

Before `PinEntryScreen` succeeds:

| Operation | Allowed |
|-----------|---------|
| Read `yoko_access` / `yoko_refresh` | **No** |
| Call `AuthService.tryRefresh()` | **No** |
| Make authenticated API calls | **No** |
| Show cached product/catalog data (non-sensitive) | Yes |
| Show WelcomeScreen / PhoneScreen for guest | Yes |

The gate is enforced in `_StartScreen.build()`:
```
if _fastLoginLocked && FastLoginService.isEnabled → show PinEntryScreen
else → normal _tryRestoreSession flow
```

`_fastLoginLocked` is a local boolean in `_StartScreenState`, initially `true`
when `FastLoginService.isEnabled() == true`, set to `false` after successful
PIN or biometric verification.

## Network errors do not wipe sessions

`AuthService._doRefresh()` already does this correctly (checked in code):
- 401 response → `clearTokens()` (server confirmed token invalid)
- `DioException` without response → tokens preserved, state = `sessionError`

No change needed here. The PIN entry screen must surface `sessionError` state
("Нет интернета, работаем в кешированном режиме") without forcing re-login.

## Device compromise boundary

On a **fully rooted** Android or **jailbroken** iOS device:

| Attack | Mitigation | Residual risk |
|--------|-----------|---------------|
| Extract `yoko_refresh` from Keystore | `EncryptedSharedPreferences` / Keychain require device unlock | Token exposed if device PIN is known to attacker |
| Extract `fl_pin_salt` and brute-force HMAC | Same Keystore protection | Salt exposed alongside token — attacker already has the token, rendering PIN moot |
| Bypass PIN check in Dart code | App reverse-engineering on rooted device | High risk; not mitigated by app-level code alone |

**Conclusion**: on a rooted/jailbroken device, all protection is equivalent to
the device unlock (screen lock). The app PIN adds no meaningful security against
an attacker with physical device access AND a rooted environment. This is true
of all mobile authentication schemes that do not use hardware-backed attestation
(Android StrongBox, iOS SecureEnclave) with remote attestation.

**Recommendation**: document this clearly; do not claim app PIN is secure against
physical device compromise. For high-value operations (payments, account deletion),
the existing SMS OTP requirement remains in place regardless of fast login state.

## Access token lifetime (60 min) — stolen token risk

A stolen access JWT is valid for up to 60 minutes. The app cannot revoke it
because it is stateless (no server-side blocklist for access tokens). Mitigations:

1. The refresh token (90-day, Redis) can be revoked immediately via `POST /auth/logout`.
2. After revocation, the access token expires within 60 min naturally.
3. For payment operations, consider requiring fresh OTP (already done in checkout).

Reducing access token TTL to 15 min would halve the window but increase refresh
load ~4×. Recommended only if payment volumes justify it.

## Manager login (existing gap — out of scope but documented)

`POST /api/v1/orders/auth/login` has **no rate limiting** (confirmed in `views.py`).
This should be fixed separately (not in this PR series):
- Add `django-ratelimit` decorator: 5 attempts / 60s per IP.
- After 10 failures: temporary IP block in nginx.

## Logging rules

Do NOT log:
- PIN digits (not even length)
- OTP codes
- Access or refresh tokens (not even prefixes)
- Biometric challenge results beyond pass/fail

Safe to log:
- `[fast_login] setup_complete user_id={uuid}` (no token data)
- `[fast_login] pin_attempt failed attempts={n}`
- `[fast_login] locked_out duration_ms={n}`
- `[fast_login] disabled (logout/recovery)`
