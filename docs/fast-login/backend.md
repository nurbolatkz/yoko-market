# Backend Changes

## 1. Refresh token rotation is not atomic (existing bug)

**File**: `apps/auth/services/redis_service.py`, `rotate_refresh_token()`

**Current code** (verified by reading the file):
```python
def rotate_refresh_token(old_jti: str) -> str:
    r = get_redis()
    user_id = r.get(f'yokosun:mobile_refresh:{old_jti}')   # ← GET
    if not user_id:
        raise RefreshTokenExpiredError()
    r.delete(f'yokosun:mobile_refresh:{old_jti}')           # ← DELETE (separate command)
    return user_id
```

**Race condition**: two concurrent requests (e.g. background fetch + foreground refresh)
both execute GET before either executes DELETE. Both get `user_id`; both issue new
refresh tokens; server now has two valid sessions for one device.

**Fix** (requires Redis 6.2+, which ships with any Redis released after 2021):
```python
def rotate_refresh_token(old_jti: str) -> str:
    r = get_redis()
    user_id = r.getdel(f'yokosun:mobile_refresh:{old_jti}')   # atomic GET+DELETE
    if not user_id:
        raise RefreshTokenExpiredError()
    return user_id
```

Verify Redis version: `redis-cli INFO server | grep redis_version`

**Alternative for Redis < 6.2** (Lua script, same atomicity guarantee):
```python
_ROTATE_SCRIPT = r"""
local val = redis.call('GET', KEYS[1])
if val then redis.call('DEL', KEYS[1]) end
return val
"""
def rotate_refresh_token(old_jti: str) -> str:
    r = get_redis()
    user_id = r.eval(_ROTATE_SCRIPT, 1, f'yokosun:mobile_refresh:{old_jti}')
    if not user_id:
        raise RefreshTokenExpiredError()
    return user_id
```

This is a **standalone backend PR** that should be merged before the Flutter
fast-login PRs reach production.

## 2. Lost-response scenario (network drop after rotation)

**Scenario**: server deletes old JTI, generates new tokens, then sends the
response. Network drops before the response arrives. Client retries with the
old token → `refresh_token_expired` → user force-logged-out.

**Current behaviour**: Flutter catches 401 and calls `clearTokens()`.

**Proposed mitigation** (PR-6): add a short-lived "grace window" key:

```python
def rotate_refresh_token(old_jti: str) -> str:
    r = get_redis()
    new_refresh, new_jti = new_mobile_refresh_pair()          # generate before GETDEL
    # Pipeline: GETDEL old + SET new + SET grace
    with r.pipeline(transaction=True) as pipe:
        pipe.getdel(f'yokosun:mobile_refresh:{old_jti}')
        # Will be executed only if GETDEL returns a value — handled in app layer below
        result = pipe.execute()
    user_id = result[0]
    if not user_id:
        # Check grace key: same old_jti was already rotated 30s ago for this user
        grace = r.get(f'yokosun:mobile_refresh_grace:{old_jti}')
        if grace:
            # Re-issue fresh tokens for the same user (idempotent retry)
            return grace   # returns user_id from grace record
        raise RefreshTokenExpiredError()
    r.set(f'yokosun:mobile_refresh:{new_jti}', user_id, ex=REFRESH_TTL_DAYS * 86400)
    r.set(f'yokosun:mobile_refresh_grace:{old_jti}', user_id, ex=30)  # 30s grace
    return user_id
```

**Tradeoff**: 30-second replay window where the same old token can be retried.
This window is bounded and cannot be used to create unlimited sessions because
the user_id it returns is always the same. The new JTI assignment is handled
by the caller after the grace path is taken (new tokens issued for same user).

**Simpler alternative**: just surface the error more clearly to the user
("Сессия завершена, пожалуйста, войдите снова") instead of silently clearing.
This is acceptable if the network drop scenario is rare (< 0.1% of refreshes).

**Recommendation**: implement `GETDEL` atomicity fix (item 1) first; add grace
window only if telemetry shows meaningful lost-response failures.

## 3. Device ID tracking for targeted revocation

**Goal**: when a user recovers via SMS ("Forgot PIN"), revoke only THIS device's
session without invalidating sessions on other devices.

**Current state**: no device tracking. Logout revokes one specific JTI; there is
no way to revoke all tokens for a device.

**Implementation** (PR-6):

**Backend**:
- Add optional `device_id` to `POST /auth/refresh` and `POST /auth/verify-otp`.
- Store it alongside user_id in Redis: `r.set(key, f'{user_id}:{device_id}', ex=...)`
- New endpoint: `POST /api/v1/auth/revoke-device`
  ```
  Body: { "refresh_token": "...", "device_id": "uuid" }
  Auth: Bearer access_token
  ```
  Finds JTI by scanning device_id index → deletes it.

**Flutter**:
- `FastLoginService` stores `fl_device_id` (UUID, generated once, never rotated).
- `AuthService` includes `device_id` in refresh and verify-otp calls.
- On "Forgot PIN": send `POST /auth/revoke-device` with the current device_id
  before proceeding to SMS flow.

**Simpler alternative** (acceptable for v1): on "Forgot PIN", call `POST /auth/logout`
with the current refresh token (which IS available on the device at that point) to
revoke the existing session before starting a new one. This handles the common case
(user knows they're on the same device) without Redis index complexity.

**Recommendation**: use the simple alternative for v1; add device-indexed revocation
in a later phase when multi-device management UI is built.

## 4. Manager login rate limiting (separate PR, not in fast-login scope)

Confirmed in `apps/auth/views.py`: `manager_login` view has no rate limiting.
Add `django-ratelimit` as a separate PR. Noted here to avoid forgetting.

## 5. No new endpoints needed for the core fast-login flow

| Operation | Endpoint | Status |
|-----------|----------|--------|
| SMS OTP request | `POST /auth/request-otp` | existing |
| OTP verification | `POST /auth/verify-otp` | existing |
| Silent token refresh on cold start | `POST /auth/refresh` | existing |
| Logout / revoke on PIN disable | `POST /auth/logout` | existing |
| "Forgot PIN" re-auth | reuses full OTP flow | existing |

The 4-digit PIN and biometric unlock operate **entirely on-device**.
They do not touch the server. A correct PIN only grants access to the
already-stored refresh token; the subsequent `tryRefresh()` call is the
same network request that already happens on cold start today.

## 6. Load analysis

Fast login replaces the OTP flow for returning users. Expected impact:

| Scenario | Today | With fast login |
|----------|-------|-----------------|
| Cold start, returning user | 1 refresh call | 1 refresh call (unchanged) |
| Cold start, new user | 1 OTP req + 1 OTP verify | unchanged |
| Foreground return (< 5 min) | 0 calls | 0 calls (no lock applied) |
| Foreground return (> 5 min) | 0 calls | 1 PIN check (local) + 1 refresh call |

The main load increase: users who currently re-login via SMS every session will
switch to silent refresh. Net effect: **more `POST /auth/refresh` calls, fewer
`POST /auth/verify-otp` calls**. Redis GETDEL is O(1); this is not a concern at
any realistic user scale.

**Establish baseline metrics before launch**:
- p95 latency of `POST /auth/refresh`
- Redis memory usage for `yokosun:mobile_refresh:*` keys
- OTP request rate

Define acceptance criteria: p95 refresh latency < 200ms under 10× current peak.
Run a load test before removing the feature flag.
