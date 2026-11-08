# Fast Login — Implementation Plan

**Status:** planning  
**Author:** Nurbolat  
**Date:** 2026-11-08

## Index

| File | Contents |
|------|----------|
| [architecture.md](architecture.md) | Chosen storage model, library choices, tradeoffs |
| [screens.md](screens.md) | Full user flow, all screens, edge cases |
| [security.md](security.md) | PIN protection, attempt limits, threat model |
| [backend.md](backend.md) | Race conditions, rotation atomicity, new endpoints |
| [referral.md](referral.md) | Referral code survival through fast login flow |
| [rollout.md](rollout.md) | Phases, feature flag, metrics, rollback |

## What this feature is

After a one-time SMS login, users unlock the app with a **4-digit app PIN** or
**biometrics** instead of going through SMS every time. The existing JWT
refresh token is the credential; fast login controls *access* to it, not the
server session.

## What it is not

- It does not replace server-side sessions (JWT tokens remain unchanged).
- It does not create a new server session per unlock.
- The PIN is not a password; it cannot recover a lost refresh token.
- It does not apply to manager / dashboard users.

## Implementation phases (small PRs)

| PR | Scope |
|----|-------|
| **PR-1** | Add packages; `FastLoginService` + tests (no UI) |
| **PR-2** | `FastLoginSetupScreen` + `PinSetupScreen` inserted after `InviteCodeScreen` |
| **PR-3** | `PinEntryScreen` + cold-start gating in `_StartScreen` |
| **PR-4** | Biometric prompt in `PinEntryScreen`; fallback to PIN |
| **PR-5** | "Forgot PIN" → SMS re-auth → new PIN setup |
| **PR-6** | Backend: `GETDEL`-based atomic rotation; device_id revocation |
| **PR-7** | Feature flag removal; production metrics |

## First task

Write `lib/services/fast_login_service.dart` with the five core methods
(`isEnabled`, `setupPin`, `verifyPin`, `unlockWithBiometrics`, `disable`)
and unit-test them against a fake `FlutterSecureStorage`. No screens, no UI.
See [architecture.md](architecture.md) for the storage contract.
