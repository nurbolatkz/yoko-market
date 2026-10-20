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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Read the pref before the first frame so _StartScreen never renders a blank
  // loading scaffold — the decision is synchronous from the widget's perspective.
  bool welcomeShown = false;
  if (!_isRunningUnderTest()) {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
      welcomeShown = prefs.getBool('welcome_shown') ?? false;
      if (!welcomeShown) await prefs.setBool('welcome_shown', true);
    } catch (_) {
      welcomeShown = true; // on failure, skip the animation
    }
  }
  runApp(YokoMarketApp(welcomeShown: welcomeShown));
}

class YokoMarketApp extends StatelessWidget {
  const YokoMarketApp({
    super.key,
    this.marketProvider,
    this.welcomeShown = true,
  });

  final MarketProvider? marketProvider;
  final bool welcomeShown;

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
        home: _StartScreen(welcomeShown: welcomeShown),
      ),
    );
  }
}

/// Shows [WelcomeOverlay] on first launch; goes straight to [MainScreen]
/// otherwise. [MainScreen] is always in the tree so API calls start
/// immediately — the animation never delays data loading.
class _StartScreen extends StatefulWidget {
  const _StartScreen({required this.welcomeShown});

  final bool welcomeShown;

  @override
  State<_StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<_StartScreen> {
  late bool _showOverlay;

  @override
  void initState() {
    super.initState();
    _showOverlay = !widget.welcomeShown && !_isRunningUnderTest();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showOverlay) return const MainScreen();
    return Stack(
      children: [
        const MainScreen(),
        WelcomeOverlay(
          onDone: () => setState(() => _showOverlay = false),
        ),
      ],
    );
  }
}
