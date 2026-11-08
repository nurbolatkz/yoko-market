# User Flow & Screens

## Happy path: first-time SMS login

```
PhoneScreen
  └─► OtpScreen
        └─► (new user) InviteCodeScreen
              └─► FastLoginSetupScreen          ← NEW (PR-2)
                    └─► PinSetupScreen           ← NEW (PR-2)
                          └─► BiometricPrompt    ← inline in PinSetupScreen (PR-4)
                                └─► ProfileSetupScreen
                                      └─► MainScreen

        └─► (existing user, fullName set) MainScreen
```

## Happy path: returning user cold start

```
App launch
  └─► _StartScreen.initState()
        └─► FastLoginService.isEnabled() == true
              └─► PinEntryScreen                ← NEW (PR-3)
                    ├─► biometric challenge → success → MainScreen  (PR-4)
                    └─► PIN entry → correct → tryRefresh() → MainScreen
```

## Cold start, fast login NOT enabled

```
App launch
  └─► AuthService.hasSession() == true
        └─► tryRefresh() → success → MainScreen  (existing behaviour)
```

## Foreground return (app was backgrounded)

After returning from background, the app does **not** immediately lock.
Lock on foreground return is applied only after a configurable idle time
(`_kForegroundLockAfterMs = 5 * 60 * 1000`, i.e. 5 minutes).

Implementation: `WidgetsBindingObserver.didChangeAppLifecycleState` in
`_StartScreen`. Record `_lastForeground` timestamp. On `AppLifecycleState.resumed`:
if `now - _lastForeground > _kForegroundLockAfterMs` and fast login is enabled,
push `PinEntryScreen` modally.

The `yoko_access` / `yoko_refresh` tokens are NOT cleared during this lock.
The lock is purely a local UI gate.

## "Forgot PIN?" flow

```
PinEntryScreen
  └─► "Забыли PIN?" link
        └─► PhoneScreen (fromForgotPin: true)
              └─► OtpScreen (returnResultOnSuccess: false)
                    └─► OTP success → AuthProvider.login()
                          └─► PinSetupScreen (fromRecovery: true)
                                └─► FastLoginService.disable() first
                                      └─► FastLoginService.setupPin(newPin)
                                            └─► MainScreen
```

After SMS-based recovery, the old refresh token for this device is
revoked if still valid (see [backend.md](backend.md)).

## No network on cold start

```
PinEntryScreen → PIN correct
  └─► AuthService.tryRefresh() → network error (DioException, no 401)
        └─► tokens NOT cleared
              └─► AuthProvider.state = sessionError
                    └─► PinEntryScreen shows offline banner:
                        "Нет интернета. Последний сеанс загружен."
                        └─► app opens MainScreen with stale cached data
```

A network error is NOT treated as an invalid session. `sessionError` state
already handles this in `AuthProvider` — the fix is surfacing the reason.

## Biometric setup cancelled during PinSetupScreen

```
PinSetupScreen → PIN confirmed → BiometricPrompt → user cancels
  └─► FastLoginSetupScreen does NOT wipe the PIN
        └─► "Skip biometrics" is recorded (fl_biometric_enabled = "0")
              └─► fast login enabled with PIN only
                    └─► proceed to ProfileSetupScreen
```

## Biometric changed on device (fingerprint re-enrolled)

On Android, `BiometricManager.canAuthenticate()` returns
`BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED` when the biometric key was
invalidated. On iOS, `local_auth` throws `PermanentlyLockedOut` or the
attempt simply returns false.

Handling: on biometric failure that is not a user cancellation (error type
`biometricOnlyNotSupported` or `permanentlyLockedOut`), show:
"Биометрия изменилась. Введите PIN." and fall back to `PinEntryScreen`.
Do NOT clear the PIN or tokens — the PIN remains valid.

## Logout from ProfileScreen

```
ProfileScreen → "Выйти"
  └─► AuthService.logout()     (saves refresh token BEFORE clearing, then sends to server)
        └─► FastLoginService.disable()
              └─► AuthProvider.state = guest
                    └─► _StartScreen re-renders → WelcomeScreen
```

## Account deletion

Same as logout, plus the existing `deleteAccount()` call. `FastLoginService.disable()`
is called before the DELETE request, so if the network call fails, the user is
still logged out locally with no fast-login data left.

## Screens list

| Screen | File | PR |
|--------|------|----|
| `FastLoginSetupScreen` | `lib/screens/auth/fast_login_setup_screen.dart` | PR-2 |
| `PinSetupScreen` | `lib/screens/auth/pin_setup_screen.dart` | PR-2 |
| `PinEntryScreen` | `lib/screens/auth/pin_entry_screen.dart` | PR-3 |
| Biometric prompt | Inline in `PinEntryScreen` via `FastLoginService.unlockWithBiometrics()` | PR-4 |
| `PinRecoveryScreen` | Not needed — reuse existing `PhoneScreen` + `OtpScreen` with `fromForgotPin` param | PR-5 |

## FastLoginSetupScreen

- Full screen, dismissible with "Позже" (bottom link).
- Primary CTA: "Включить быстрый вход".
- Shown once per device. If dismissed, store `fl_setup_dismissed = "1"` in
  `SharedPreferences` (not `FlutterSecureStorage` — this is not a secret).
  Do NOT show it again on subsequent logins unless user enables it in Settings.
- Provides a Settings toggle in `SettingsScreen` to enable later.

## PinSetupScreen

- Entry 1: "Введите PIN из 4 цифр".
- Entry 2: "Повторите PIN". If mismatch → shake animation, clear both, restart.
- PIN cells: same visual style as OTP cells (4 cells, `AppColors.purple` border on active).
- On confirm: `FastLoginService.setupPin(pin)`. On error (ArgumentError) show inline error.
- After PIN saved: if `local_auth.isAvailable()` → show biometric setup inline.

## PinEntryScreen

- Shown as the first screen on cold start (pushed over `_StartScreen` before `MainScreen`).
- 4 PIN cells + numeric keypad (custom widget — avoids system keyboard visibility issues).
- Biometric shortcut button (Face ID / fingerprint icon) — hidden if not enrolled.
- "Забыли PIN?" link at bottom.
- Shows remaining attempt count after 3 wrong attempts:
  "Осталось попыток: 2"
- Shows lockout timer when locked:
  "Попробуйте через 00:28"
