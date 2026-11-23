import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yokomarket/providers/auth_provider.dart';
import 'package:yokomarket/screens/wallet_screen.dart';
import 'package:yokomarket/services/auth_service.dart';
import 'package:yokomarket/services/preview_auth.dart';
import 'package:yokomarket/services/wallet_api.dart';

class _GuestAuth extends AuthService {
  @override
  Future<bool> hasSession() async => false;
}

void main() {
  late MockWalletApi api;

  setUp(() {
    api = MockWalletApi(
      delay: Duration.zero,
      clock: () => DateTime(2026, 11, 23, 12),
    );
  });

  Future<void> pumpWallet(
    WidgetTester tester, {
    AuthService? auth,
    double textScale = 1,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) =>
            AuthProvider(authService: auth ?? PreviewAuthService())..init(),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: WalletScreen(api: api),
        ),
      ),
    );
    // Let auth restore + the zero-delay mock resolve, without waiting on
    // the repeating skeleton shimmer.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('shows balances, cashback progress and history', (tester) async {
    await pumpWallet(tester);

    expect(find.text('ПОДАРОЧНЫЙ БАЛАНС'), findsOneWidget);
    expect(find.text('0 ₸'), findsOneWidget);
    expect(find.text('1 250'), findsOneWidget); // YoCoin
    expect(find.text('Кэшбэк за ноябрь: 3%'), findsOneWidget);
    expect(
      find.text('Ещё 37 500 ₸ до 5% · осталось 7 дней'),
      findsOneWidget,
    );
    expect(
      find.text('Предварительно: ~1 875 YoCoin после окончания месяца'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Бонус за регистрацию'), 200);
    expect(find.text('+1 000 YoCoin'), findsOneWidget);
  });

  testWidgets('activating a gift card updates the balance', (tester) async {
    await pumpWallet(tester);

    await tester.tap(find.text('Активировать карту'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'k7qm29xth4pb');
    await tester.pump();
    expect(find.text('K7QM-29XT-H4PB'), findsOneWidget); // auto-formatted

    await tester.tap(find.text('Активировать'));
    await tester.pumpAndSettle();
    expect(find.text('Карта на 20 000 ₸ активирована'), findsOneWidget);
    expect(find.text('Подарок от Асель'), findsOneWidget);

    await tester.tap(find.text('Готово'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('20 000 ₸'), findsOneWidget);
    expect(find.text('Действует до 23.11.2027'), findsOneWidget);
  });

  testWidgets('wrong code shows the inline contract error', (tester) async {
    await pumpWallet(tester);

    await tester.tap(find.text('Активировать карту'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ABCDEFGHJKMN');
    await tester.pump();
    await tester.tap(find.text('Активировать'));
    await tester.pumpAndSettle();

    expect(find.text('Карта не найдена — проверьте код'), findsOneWidget);
  });

  testWidgets('no overflow at 360 dp and 1.5× text', (tester) async {
    await pumpWallet(tester, textScale: 1.5, size: const Size(360, 740));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Кэшбэк за ноябрь: 3%'), 200);
    await tester.scrollUntilVisible(find.text('Бонус за регистрацию'), 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest sees a sign-in hint', (tester) async {
    await pumpWallet(tester, auth: _GuestAuth());
    expect(find.text('Войдите в аккаунт, чтобы видеть кошелёк'), findsOneWidget);
  });
}
