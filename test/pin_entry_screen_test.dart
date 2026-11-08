/// Widget tests for PinEntryScreen and _StartScreen PIN gating.
///
/// Run with: flutter test test/pin_entry_screen_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yokomarket/main.dart';
import 'package:yokomarket/providers/auth_provider.dart';
import 'package:yokomarket/providers/market_provider.dart';
import 'package:yokomarket/providers/orders_provider.dart';
import 'package:yokomarket/providers/address_provider.dart';
import 'package:yokomarket/providers/wishlist_provider.dart';
import 'package:yokomarket/screens/auth/pin_entry_screen.dart';
import 'package:yokomarket/services/fast_login_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(fontFamily: 'NunitoSans'),
      home: child,
    );

class _Harness {
  _Harness({String? correctPin}) {
    store = InMemoryKeyValueStore();
    service = FastLoginService(storage: store);
    _successFlag = false;
    _forgotFlag = false;
    if (correctPin != null) {
      // setupPin is async; callers must call await harness.setup(pin)
      _pendingPin = correctPin;
    }
    widget = PinEntryScreen(
      fastLoginService: service,
      onSuccess: () => _successFlag = true,
      onForgotPin: () => _forgotFlag = true,
    );
  }

  late final InMemoryKeyValueStore store;
  late final FastLoginService service;
  late final PinEntryScreen widget;
  bool _successFlag = false;
  bool _forgotFlag = false;
  String? _pendingPin;

  bool get succeeded => _successFlag;
  bool get forgotTapped => _forgotFlag;

  Future<void> setup(String pin) => service.setupPin(pin);
}

Future<void> _tap(WidgetTester t, String digit) async {
  await t.tap(find.text(digit).first);
  await t.pump();
}

Future<void> _typePin(WidgetTester t, String pin) async {
  for (final d in pin.split('')) {
    await _tap(t, d);
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── PinEntryScreen — initial state ──────────────────────────────────────────

  group('PinEntryScreen — initial state', () {
    testWidgets('renders title and subtitle', (tester) async {
      final h = _Harness();
      await h.setup('1234');
      await tester.pumpWidget(_wrap(h.widget));
      await tester.pump(); // settle initState async check
      expect(find.text('Введите PIN'), findsOneWidget);
      expect(find.text('Введите PIN для входа в приложение'), findsOneWidget);
    });

    testWidgets('shows all digit keys 0–9 and backspace', (tester) async {
      final h = _Harness();
      await h.setup('1234');
      await tester.pumpWidget(_wrap(h.widget));
      await tester.pump();
      for (var i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    });

    testWidgets('shows "Забыли PIN?" button', (tester) async {
      final h = _Harness();
      await h.setup('1234');
      await tester.pumpWidget(_wrap(h.widget));
      await tester.pump();
      expect(find.text('Забыли PIN?'), findsOneWidget);
    });

    testWidgets('no error or warning visible initially', (tester) async {
      final h = _Harness();
      await h.setup('1234');
      await tester.pumpWidget(_wrap(h.widget));
      await tester.pump();
      expect(find.textContaining('Осталось попыток'), findsNothing);
      expect(find.textContaining('Попробуйте через'), findsNothing);
      expect(find.textContaining('Слишком много'), findsNothing);
    });
  });

  // ── PinEntryScreen — correct PIN ────────────────────────────────────────────

  group('PinEntryScreen — correct PIN', () {
    testWidgets('calls onSuccess for correct PIN', (tester) async {
      final h = _Harness();
      await h.setup('5678');
      await tester.pumpWidget(_wrap(h.widget));
      await tester.pump();
      await _typePin(tester, '5678');
      await tester.pumpAndSettle();
      expect(h.succeeded, isTrue);
    });

    testWidgets('does NOT call onSuccess for wrong PIN', (tester) async {
      final h = _Harness();
      await h.setup('5678');
      await tester.pumpWidget(_wrap(h.widget));
      await tester.pump();
      await _typePin(tester, '1111');
      await tester.pumpAndSettle();
      expect(h.succeeded, isFalse);
    });
  });

  // ── PinEntryScreen — wrong PIN accumulation ─────────────────────────────────

  group('PinEntryScreen — wrong PIN accumulation', () {
    Future<void> reachN(WidgetTester t, _Harness h, int n) async {
      await t.pumpWidget(_wrap(h.widget));
      await t.pump();
      for (var i = 0; i < n; i++) {
        await _typePin(t, '9999'); // always wrong when correct is 5555
        await t.pumpAndSettle();
      }
    }

    testWidgets('1st wrong: cells reset, no warning shown', (tester) async {
      final h = _Harness();
      await h.setup('5555');
      await reachN(tester, h, 1);
      expect(find.textContaining('Осталось попыток'), findsNothing);
    });

    testWidgets('2nd wrong: attempt warning appears', (tester) async {
      final h = _Harness();
      await h.setup('5555');
      await reachN(tester, h, 2);
      expect(find.textContaining('Осталось попыток'), findsOneWidget);
    });

    testWidgets('3rd wrong: "Осталось попыток: 1" shown', (tester) async {
      final h = _Harness();
      await h.setup('5555');
      await reachN(tester, h, 3);
      expect(find.text('Осталось попыток: 1'), findsOneWidget);
    });

    testWidgets('backspace removes last digit', (tester) async {
      final h = _Harness();
      await h.setup('1234');
      await tester.pumpWidget(_wrap(h.widget));
      await tester.pump();
      await _tap(tester, '1');
      await _tap(tester, '2');
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
      // No error or warning — just normal state.
      expect(find.textContaining('Осталось попыток'), findsNothing);
    });
  });

  // ── PinEntryScreen — lockout ─────────────────────────────────────────────────

  group('PinEntryScreen — lockout', () {
    // Advances to the state where the 4th wrong attempt has triggered lockout.
    //
    // Attempts 1–3: pump(500ms) each — enough for the 400ms shake to complete
    // so the cells reset before the next attempt.
    // Attempt 4: NO pumpAndSettle — Timer.periodic would cause it to loop.
    Future<void> reachLock(WidgetTester t, _Harness h) async {
      await t.pumpWidget(_wrap(h.widget));
      await t.pump();
      for (var i = 0; i < 3; i++) {
        await _typePin(t, '9999');
        await t.pump(const Duration(milliseconds: 500)); // past 400ms shake
      }
      // 4th wrong: FastLoginLockedError → _lockedUntilMs set, timer started.
      await _typePin(t, '9999');
      // pump() inside _tap settled the async verifyPin; one extra pump for the
      // catch-block setState in case microtask queue needed another round-trip.
      await t.pump();
    }

    testWidgets('4th wrong shows lockout timer text', (tester) async {
      final h = _Harness();
      await h.setup('5555');
      await reachLock(tester, h);
      expect(find.textContaining('Попробуйте через'), findsOneWidget);
    });

    testWidgets('keypad is disabled when locked', (tester) async {
      final h = _Harness();
      await h.setup('5555');
      await reachLock(tester, h);
      expect(find.textContaining('Попробуйте через'), findsOneWidget);
      // Tapping a digit while locked must not add input or clear the lock text.
      await _tap(tester, '1');
      expect(find.textContaining('Попробуйте через'), findsOneWidget);
    });
  });

  // ── PinEntryScreen — wipe ────────────────────────────────────────────────────

  group('PinEntryScreen — wipe after too many failures', () {
    testWidgets('FastLoginWipedError calls onForgotPin', (tester) async {
      // Pre-advance the service to 5 attempts (count=5, locked 5 min) using the
      // injectable clock, then pump one more wrong attempt through the UI to
      // trigger FastLoginWipedError → onForgotPin.
      var fakeNow = DateTime.now().millisecondsSinceEpoch;
      final store = InMemoryKeyValueStore();
      final service = FastLoginService(storage: store, nowMs: () => fakeNow);
      await service.setupPin('5555');

      // Attempts 1–3: return false
      for (var i = 0; i < 3; i++) {
        await service.verifyPin('9999');
      }
      // Attempt 4 → lock 30s; skip past it
      try { await service.verifyPin('9999'); } on FastLoginLockedError { fakeNow += 31 * 1000; }
      // Attempt 5 → lock 5 min; skip past it
      try { await service.verifyPin('9999'); } on FastLoginLockedError { fakeNow += 6 * 60 * 1000; }
      // Service is now at count=5 — next wrong attempt wipes.

      var forgotCalled = false;
      final widget = PinEntryScreen(
        fastLoginService: service,
        onForgotPin: () => forgotCalled = true,
      );
      await tester.pumpWidget(_wrap(widget));
      await tester.pump(); // settle initState (lockoutRemainingMs = 0 after skip)

      // 6th wrong attempt → FastLoginWipedError → onForgotPin called.
      await _typePin(tester, '9999');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(forgotCalled, isTrue);
      expect(await service.isEnabled(), isFalse);
    });
  });

  // ── PinEntryScreen — forgot PIN button ──────────────────────────────────────

  group('PinEntryScreen — "Забыли PIN?"', () {
    testWidgets('tapping "Забыли PIN?" calls onForgotPin', (tester) async {
      final h = _Harness();
      await h.setup('1234');
      await tester.pumpWidget(_wrap(h.widget));
      await tester.pump();
      await tester.tap(find.text('Забыли PIN?'));
      await tester.pump();
      expect(h.forgotTapped, isTrue);
    });
  });

  // ── _StartScreen PIN gating ──────────────────────────────────────────────────

  group('_StartScreen PIN gating', () {
    Widget _wrapApp(Widget home) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider()..init(),
            ),
            ChangeNotifierProvider<MarketProvider>(
              create: (_) => MarketProvider(),
            ),
            ChangeNotifierProvider<OrdersProvider>(
              create: (_) => OrdersProvider(),
            ),
            ChangeNotifierProxyProvider<AuthProvider, AddressProvider>(
              create: (_) => AddressProvider(),
              update: (_, __, addr) => addr ?? AddressProvider(),
            ),
            ChangeNotifierProxyProvider<AuthProvider, WishlistProvider>(
              create: (_) => WishlistProvider(),
              update: (_, __, wl) => wl ?? WishlistProvider(),
            ),
          ],
          child: MaterialApp(home: home),
        );

    testWidgets('gating disabled: shows MainScreen without PIN entry', (tester) async {
      final store = InMemoryKeyValueStore();
      final svc = FastLoginService(storage: store);
      await svc.setupPin('1234');

      final screen = buildStartScreenForTest(
        showWelcome: false,
        onboardingShown: true,
        testFastLoginEnabled: false, // flag off
        fastLoginService: svc,
      );
      await tester.pumpWidget(_wrapApp(screen));
      await tester.pumpAndSettle();

      // PIN entry screen must NOT appear when flag is off.
      expect(find.text('Введите PIN'), findsNothing);
    });

    testWidgets('gating enabled + isEnabled: shows PinEntryScreen', (tester) async {
      final store = InMemoryKeyValueStore();
      final svc = FastLoginService(storage: store);
      await svc.setupPin('1234');

      final screen = buildStartScreenForTest(
        showWelcome: false,
        onboardingShown: true,
        testFastLoginEnabled: true,
        fastLoginService: svc,
      );
      await tester.pumpWidget(_wrapApp(screen));
      await tester.pumpAndSettle();

      expect(find.text('Введите PIN'), findsOneWidget);
    });

    testWidgets('gating enabled + not set up: skips PIN, shows app', (tester) async {
      final store = InMemoryKeyValueStore(); // no setupPin called
      final svc = FastLoginService(storage: store);

      final screen = buildStartScreenForTest(
        showWelcome: false,
        onboardingShown: true,
        testFastLoginEnabled: true,
        fastLoginService: svc,
      );
      await tester.pumpWidget(_wrapApp(screen));
      await tester.pumpAndSettle();

      expect(find.text('Введите PIN'), findsNothing);
    });
  });
}
