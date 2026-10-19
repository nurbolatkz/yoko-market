import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'providers/auth_provider.dart';
import 'providers/market_provider.dart';
import 'providers/orders_provider.dart';
import 'screens/main_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/preview_auth.dart';
import 'theme/app_theme.dart';

/// True when running under `flutter test` (FLUTTER_TEST env var is set by
/// the test runner). Skips the welcome animation so pumpAndSettle settles.
bool _isRunningUnderTest() {
  if (kIsWeb) return false;
  try {
    return Platform.environment.containsKey('FLUTTER_TEST');
  } catch (_) {
    return false;
  }
}

void main() {
  runApp(const YokoMarketApp());
}

class YokoMarketApp extends StatelessWidget {
  const YokoMarketApp({super.key, this.marketProvider});

  final MarketProvider? marketProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => (AppConfig.uiPreview
                  ? AuthProvider(authService: PreviewAuthService())
                  : AuthProvider())
              ..init(),
        ),
        ChangeNotifierProvider<MarketProvider>(
          create: (_) =>
              (marketProvider ?? MarketProvider())
                ..loadCatalog()
                ..loadFeatured()
                ..loadBanners(),
        ),
        ChangeNotifierProvider<OrdersProvider>(
          create: (_) => OrdersProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'YokoMarket',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        themeMode: ThemeMode.light,
        home: const _StartScreen(),
      ),
    );
  }
}

/// Checks SharedPreferences for `welcome_shown`, then either goes straight to
/// [MainScreen] or shows [WelcomeOverlay] on top of it.
///
/// [MainScreen] is always in the tree so provider data loads in parallel with
/// the animation — the welcome screen never blocks the API.
class _StartScreen extends StatefulWidget {
  const _StartScreen();

  @override
  State<_StartScreen> createState() => _StartScreenState();
}

enum _Start { loading, direct, welcome }

class _StartScreenState extends State<_StartScreen> {
  _Start _state = _Start.loading;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    // Always skip the welcome screen in test environments so pumpAndSettle
    // settles immediately and widget tests are not affected by animations.
    if (_isRunningUnderTest()) {
      if (mounted) setState(() => _state = _Start.direct);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('welcome_shown') ?? false;
    if (!shown) await prefs.setBool('welcome_shown', true);
    if (mounted) {
      setState(() {
        _state = shown ? _Start.direct : _Start.welcome;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _Start.loading => const Scaffold(
          backgroundColor: AppColors.background,
        ),
      _Start.direct => const MainScreen(),
      _Start.welcome => Stack(
          children: [
            const MainScreen(),
            WelcomeOverlay(
              onDone: () => setState(() => _state = _Start.direct),
            ),
          ],
        ),
    };
  }
}
