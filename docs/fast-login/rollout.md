# Rollout Plan

## Feature flag

Add `FAST_LOGIN_ENABLED` to `AppConfig`:

```dart
// lib/config/app_config.dart
static const fastLoginEnabled = bool.fromEnvironment(
  'FAST_LOGIN_ENABLED',
  defaultValue: false,
);
```

Build with `--dart-define=FAST_LOGIN_ENABLED=true` to enable.

Gates:
- `FastLoginSetupScreen` is only shown if `AppConfig.fastLoginEnabled == true`.
- `PinEntryScreen` is only shown if `AppConfig.fastLoginEnabled == true`.
- `FastLoginService` methods work regardless of flag (service layer is always compiled in).

This means the feature can be enabled/disabled per build without code changes,
and the service can be tested in CI even when the flag is off.

## Phases

### Phase 0 — backend prerequisite (no Flutter changes)
- Fix `GETDEL` atomicity in `rotate_refresh_token`.
- Add structured logging for refresh failures.
- Establish baseline metrics (p95 refresh latency, OTP rate).
- **Merge before any Flutter PRs reach production.**

### Phase 1 — service layer (PR-1)
- Add `local_auth ^2.3.0` and `crypto ^3.0.5` to `pubspec.yaml`.
- Write `lib/services/fast_login_service.dart` (all methods).
- Unit tests: mock `FlutterSecureStorage`, cover setup, verify, lockout, disable.
- `FAST_LOGIN_ENABLED` flag defaults to false — no user-visible change.

### Phase 2 — setup screens (PR-2, flag off by default)
- `FastLoginSetupScreen` + `PinSetupScreen`.
- Wire into `InviteCodeScreen` navigation (replace `ProfileSetupScreen` target).
- Widget tests: setup happy path, PIN mismatch, "Позже" dismissal.
- Referral code passes through correctly (see [referral.md](referral.md)).

### Phase 3 — entry screen (PR-3, flag off by default)
- `PinEntryScreen` with numeric keypad widget.
- `_StartScreen` gating: `PinEntryScreen` shown when `isEnabled && fastLoginEnabled`.
- Integration test: cold start with and without fast login enabled.
- Test: attempt counter increments, lockout timer enforced across restarts.

### Phase 4 — biometrics (PR-4, flag off by default)
- Biometric prompt in `PinEntryScreen` and inline in `PinSetupScreen`.
- Handle `PermanentlyLockedOut` / `NotEnrolled` gracefully.
- Test on physical Android (fingerprint) and iOS (Face ID simulator mock).

### Phase 5 — PIN recovery (PR-5, flag off by default)
- "Забыли PIN?" link in `PinEntryScreen` → SMS re-auth flow.
- After recovery: call `POST /auth/logout` with current refresh token (revokes old session).
- Test: recovery replaces PIN, old PIN no longer works.

### Phase 6 — backend device tracking (PR-6, optional v1)
- Simple version: `POST /auth/logout` called with token on recovery (already in PR-5).
- Full version: `device_id` field in refresh and verify-otp requests.
- Load test: simulate 10× current peak, verify p95 < 200ms.

### Phase 7 — production launch (PR-7)
- Enable `FAST_LOGIN_ENABLED=true` in production build.
- Monitor: opt-in rate, PIN lockout rate, biometric success rate, refresh error rate.
- Keep flag in code for one release cycle in case rollback is needed.

## Rollback procedure

If a production issue is found after enabling the flag:
1. Build and release a new version with `FAST_LOGIN_ENABLED=false` (default).
2. Users with `fl_fast_login_enabled = "1"` stored: `PinEntryScreen` will not be
   shown (flag is off), so they fall through to normal `tryRefresh()` on cold start.
3. Their tokens remain valid — no forced logout.
4. Run `FastLoginService.disable()` on behalf of all users is NOT needed; the flag
   simply bypasses the lock screen. Data cleanup can happen in a later release.

## Metrics to monitor after launch

| Metric | Good | Bad |
|--------|------|-----|
| Fast login opt-in rate | > 40% of logins | < 10% (feature not compelling) |
| PIN lockout rate | < 1% of PIN verifications | > 5% (UI confusing) |
| Biometric success rate | > 85% when available | < 60% (enrollment issues) |
| `POST /auth/refresh` p95 | < 200ms | > 500ms |
| `POST /auth/logout` failure rate | < 1% | > 5% (revocation unreliable) |
| Force re-login rate (refresh 401) | < 0.5% | > 2% |

## Tests required before each PR merges

### Unit tests (all PRs)
- `FastLoginService.verifyPin`: correct PIN returns true; wrong PIN increments counter;
  lockout is enforced after 5 failures; correct PIN after partial failures resets counter.
- `FastLoginService.setupPin`: throws on non-4-digit input; salt is generated fresh;
  HMAC is not equal to raw PIN.
- `FastLoginService.disable`: clears all `fl_*` keys; does not touch `yoko_*` keys.

### Widget tests (PR-2, PR-3)
- `PinSetupScreen`: mismatch shows error, doesn't advance; confirm stores state.
- `PinEntryScreen`: lockout timer displays correctly; "Забыли PIN?" navigates away.
- `FastLoginSetupScreen`: "Позже" dismisses without calling `setupPin`.

### Integration tests (PR-3)
- Cold start with no stored session → `PhoneScreen`.
- Cold start with stored session and fast login enabled → `PinEntryScreen`.
- Cold start with stored session and fast login disabled → `MainScreen`.
- Offline cold start: `sessionError` state shown without clearing tokens.

### Backend tests (PR-6)
- Concurrent refresh: two simultaneous requests with same JTI — only one succeeds;
  the other gets `refresh_token_expired` (not a silent duplicate issue).
- `GETDEL` atomicity: use `fakeredis` to verify one and only one user_id returned.

### Device tests (manual, PR-4)
- Android: fingerprint unlock, fingerprint cancelled, biometric re-enrolled.
- iOS Simulator: Face ID mock (Simulator menu → Features → Face ID).
- iOS: biometric invalidated (add new fingerprint on real device) → PIN fallback shown.
