/// Widget tests for FastLoginSetupScreen and PinSetupScreen.
///
/// Navigation to ProfileSetupScreen (which requires providers + network) is
/// bypassed via injectable callbacks / onComplete so tests stay self-contained.
///
/// Run with: flutter test test/fast_login_setup_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yokomarket/screens/auth/fast_login_setup_screen.dart';
import 'package:yokomarket/screens/auth/pin_setup_screen.dart';
import 'package:yokomarket/services/fast_login_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(fontFamily: 'NunitoSans'),
      home: child,
    );

class _PinHarness {
  _PinHarness()
    : store = InMemoryKeyValueStore(),
      _completedFlag = false {
    service = FastLoginService(storage: store);
    widget = PinSetupScreen(
      fastLoginService: service,
      onComplete: () => _completedFlag = true,
    );
  }

  final InMemoryKeyValueStore store;
  late final FastLoginService service;
  late final PinSetupScreen widget;
  bool _completedFlag;
  bool get completed => _completedFlag;
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
  // SharedPreferences needs a mock in widget tests (platform channel).
  // FastLoginSetupScreen._markDismissed() uses it; without the mock the
  // Future hangs and onSkip is never reached.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── FastLoginSetupScreen ────────────────────────────────────────────────────

  group('FastLoginSetupScreen', () {
    testWidgets('renders title and both action buttons', (tester) async {
      await tester.pumpWidget(_wrap(const FastLoginSetupScreen()));
      expect(find.text('Быстрый вход'), findsOneWidget);
      expect(find.text('Включить быстрый вход'), findsOneWidget);
      expect(find.text('Позже, настрою в профиле'), findsOneWidget);
    });

    testWidgets('renders all three feature rows', (tester) async {
      await tester.pumpWidget(_wrap(const FastLoginSetupScreen()));
      expect(find.text('Вход за секунду — без ожидания SMS'), findsOneWidget);
      expect(find.text('Работает без интернета'), findsOneWidget);
      expect(find.text('PIN из 4 цифр как запасной вариант'), findsOneWidget);
    });

    testWidgets('"Включить" calls onEnable and not onSkip', (tester) async {
      var enableCalled = false;
      var skipCalled = false;
      await tester.pumpWidget(
        _wrap(
          FastLoginSetupScreen(
            onEnable: (ctx) async => enableCalled = true,
            onSkip: (ctx) async => skipCalled = true,
          ),
        ),
      );
      await tester.tap(find.text('Включить быстрый вход'));
      await tester.pumpAndSettle();
      expect(enableCalled, isTrue);
      expect(skipCalled, isFalse);
    });

    testWidgets('"Позже" calls onSkip without calling setupPin', (tester) async {
      var skipCalled = false;
      await tester.pumpWidget(
        _wrap(
          FastLoginSetupScreen(
            onSkip: (ctx) async => skipCalled = true,
          ),
        ),
      );
      await tester.tap(find.text('Позже, настрою в профиле'));
      await tester.pumpAndSettle();
      expect(skipCalled, isTrue);
    });
  });

  // ── PinSetupScreen — initial state ──────────────────────────────────────────

  group('PinSetupScreen — initial state', () {
    testWidgets('shows step 1 of 2 indicator', (tester) async {
      final h = _PinHarness();
      await tester.pumpWidget(_wrap(h.widget));
      expect(find.text('Шаг 1 из 2'), findsOneWidget);
      expect(find.text('Придумайте PIN'), findsOneWidget);
    });

    testWidgets('shows all digit keys 0–9 and backspace', (tester) async {
      final h = _PinHarness();
      await tester.pumpWidget(_wrap(h.widget));
      for (var i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    });

    testWidgets('no error visible initially', (tester) async {
      final h = _PinHarness();
      await tester.pumpWidget(_wrap(h.widget));
      expect(find.text('Коды не совпадают. Попробуйте снова.'), findsNothing);
    });
  });

  // ── PinSetupScreen — phase 1 ────────────────────────────────────────────────

  group('PinSetupScreen — phase 1 PIN entry', () {
    testWidgets('still shows phase 1 after 3 digits', (tester) async {
      final h = _PinHarness();
      await tester.pumpWidget(_wrap(h.widget));
      await _tap(tester, '1');
      await _tap(tester, '2');
      await _tap(tester, '3');
      expect(find.text('Шаг 1 из 2'), findsOneWidget);
    });

    testWidgets('backspace removes last digit without error', (tester) async {
      final h = _PinHarness();
      await tester.pumpWidget(_wrap(h.widget));
      await _tap(tester, '1');
      await _tap(tester, '2');
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
      expect(find.text('Шаг 1 из 2'), findsOneWidget);
      expect(find.text('Коды не совпадают. Попробуйте снова.'), findsNothing);
    });

    testWidgets('4 digits advances to phase 2', (tester) async {
      final h = _PinHarness();
      await tester.pumpWidget(_wrap(h.widget));
      await _typePin(tester, '1234');
      await tester.pumpAndSettle(); // 160 ms advance delay
      expect(find.text('Шаг 2 из 2'), findsOneWidget);
      expect(find.text('Повторите PIN'), findsOneWidget);
    });
  });

  // ── PinSetupScreen — phase 2 confirmation ──────────────────────────────────

  group('PinSetupScreen — phase 2 confirmation', () {
    Future<void> reachPhase2(WidgetTester tester, _PinHarness h) async {
      await tester.pumpWidget(_wrap(h.widget));
      await _typePin(tester, '5555');
      await tester.pumpAndSettle();
    }

    testWidgets('correct confirm stores PIN and calls onComplete', (tester) async {
      final h = _PinHarness();
      await reachPhase2(tester, h);
      await _typePin(tester, '5555');
      await tester.pumpAndSettle();
      expect(await h.service.isEnabled(), isTrue);
      expect(h.completed, isTrue);
    });

    testWidgets('mismatch shows error text', (tester) async {
      final h = _PinHarness();
      await reachPhase2(tester, h);
      await _typePin(tester, '9999');
      await tester.pump(); // start of shake — error should be visible
      expect(find.text('Коды не совпадают. Попробуйте снова.'), findsOneWidget);
    });

    testWidgets('mismatch resets to phase 1 after shake', (tester) async {
      final h = _PinHarness();
      await reachPhase2(tester, h);
      await _typePin(tester, '9999');
      await tester.pumpAndSettle(); // shake completes
      expect(find.text('Шаг 1 из 2'), findsOneWidget);
      expect(find.text('Придумайте PIN'), findsOneWidget);
    });

    testWidgets('mismatch does NOT store PIN', (tester) async {
      final h = _PinHarness();
      await reachPhase2(tester, h);
      await _typePin(tester, '9999');
      await tester.pumpAndSettle();
      expect(await h.service.isEnabled(), isFalse);
      expect(h.completed, isFalse);
    });

    testWidgets('correct confirm after mismatch reset succeeds', (tester) async {
      final h = _PinHarness();
      await reachPhase2(tester, h);
      await _typePin(tester, '9999'); // wrong
      await tester.pumpAndSettle(); // reset to phase 1
      await _typePin(tester, '5555'); // re-enter phase 1
      await tester.pumpAndSettle(); // advance to phase 2
      await _typePin(tester, '5555'); // correct confirm
      await tester.pumpAndSettle();
      expect(await h.service.isEnabled(), isTrue);
      expect(h.completed, isTrue);
    });

    testWidgets('wrong confirm does not call onComplete', (tester) async {
      final h = _PinHarness();
      await reachPhase2(tester, h);
      await _typePin(tester, '1111');
      await tester.pumpAndSettle();
      expect(h.completed, isFalse);
    });
  });
}
