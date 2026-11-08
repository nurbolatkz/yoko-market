FLUTTER    := flutter
API_BASE   := https://dashboard.yoko-sun.kz/api/v1
INVITE_DOM := https://app.yoko-sun.kz

# Common dart-defines for every production build.
# FAST_LOGIN_ENABLED defaults to true in AppConfig — no need to pass it
# unless rolling back (use the *-no-fast-login targets below).
PROD_DEFINES := \
	--dart-define=API_BASE=$(API_BASE) \
	--dart-define=INVITE_DOMAIN=$(INVITE_DOM)

ROLLBACK_DEFINES := $(PROD_DEFINES) --dart-define=FAST_LOGIN_ENABLED=false

# ── Android ───────────────────────────────────────────────────────────────────

.PHONY: build-android
build-android:
	$(FLUTTER) build apk --release $(PROD_DEFINES)

.PHONY: build-android-rollback
build-android-rollback:
	$(FLUTTER) build apk --release $(ROLLBACK_DEFINES)

# ── iOS ───────────────────────────────────────────────────────────────────────

.PHONY: build-ios
build-ios:
	$(FLUTTER) build ipa --release $(PROD_DEFINES)

.PHONY: build-ios-rollback
build-ios-rollback:
	$(FLUTTER) build ipa --release $(ROLLBACK_DEFINES)

# ── Dev / QA ──────────────────────────────────────────────────────────────────

.PHONY: run
run:
	$(FLUTTER) run --dart-define=API_BASE=$(API_BASE) --dart-define=INVITE_DOMAIN=$(INVITE_DOM)

.PHONY: test
test:
	$(FLUTTER) test

.PHONY: analyze
analyze:
	$(FLUTTER) analyze
