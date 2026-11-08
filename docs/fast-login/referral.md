# Referral Code Survival

## Where the invite code currently lives (verified in code)

| Point | Action | File |
|-------|--------|------|
| Deep link received (`/invite/{code}`) | `PendingInvite.save(code)` | `lib/main.dart` |
| Initial link on cold start | `PendingInvite.save(code)` | `lib/main.dart` |
| After OTP success (new user) | `PendingInvite.consume()` → passed to `InviteCodeScreen` | `lib/screens/auth/otp_screen.dart` |
| InviteCodeScreen "accept" | `POST /profile/referral-code` | `lib/screens/auth/invite_code_screen.dart` |
| InviteCodeScreen "skip" | `PendingInvite.clear()` | `lib/screens/auth/invite_code_screen.dart` |

## Why fast login setup does not break this

`PendingInvite.consume()` is called in `OtpScreen` **before** `InviteCodeScreen` is
pushed. The invite code is therefore extracted from `SharedPreferences` and held in
a local `String?` variable, then passed as a constructor argument to `InviteCodeScreen`.

```
OtpScreen._verify():
  await auth.login(phone, code)                      // tokens saved
  final pendingCode = await PendingInvite.consume()  // code extracted + deleted
  Navigator.push(InviteCodeScreen(pendingCode: pendingCode))  // code in memory
```

`FastLoginSetupScreen` is inserted **after** `InviteCodeScreen` completes, by
`InviteCodeScreen` itself:

```
InviteCodeScreen._onAccept() / _onSkip():
  ... apply or clear invite ...
  Navigator.pushReplacement(FastLoginSetupScreen())   // ← new
  // was: Navigator.pushReplacement(ProfileSetupScreen())
```

`FastLoginSetupScreen` then navigates to `PinSetupScreen`, which navigates to
`ProfileSetupScreen`.

The invite code is applied (or skipped) **before** `FastLoginSetupScreen` appears.
The `PendingInvite` SharedPreferences key is already cleared at this point.
Fast login setup cannot interfere with the referral code in any way.

## Code change needed (PR-2)

In `lib/screens/auth/invite_code_screen.dart`, replace:
```dart
// after accept or skip:
Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
);
```
with:
```dart
Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (_) => const FastLoginSetupScreen()),
);
```

This is the only change needed. `FastLoginSetupScreen` ends at `ProfileSetupScreen`.

## Referral through "Forgot PIN" flow

When a user uses "Forgot PIN" → SMS re-auth, they are an **existing user** (`fullName`
is set). The `OtpScreen._verify()` early-exits for existing users without calling
`PendingInvite.consume()` or showing `InviteCodeScreen`. The referral code is unaffected.

## Edge case: deep link while on PinEntryScreen

If the app receives a deep link (`/invite/{code}`) while `PinEntryScreen` is showing:
- `AppLinks().uriLinkStream` fires in `_StartScreen`.
- `PendingInvite.save(code)` is called.
- PIN entry proceeds normally.
- After unlock, the user is on `MainScreen` (they are already authenticated).
- The invite code stays in `SharedPreferences` but will never be consumed because
  `InviteCodeScreen` is only shown to new users post-OTP.

**Mitigation**: on deep link received while authenticated, clear the pending invite
immediately (since the user is already registered and cannot apply a referral code).

```dart
// In _StartScreen._onDeepLink():
final code = _codeFromUri(uri);
if (code != null) {
  final auth = context.read<AuthProvider>();
  if (auth.isAuthenticated) {
    await PendingInvite.clear();   // discard — user already registered
  } else {
    await PendingInvite.save(code);
  }
}
```
