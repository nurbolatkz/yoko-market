import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'providers/address_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/market_provider.dart';
import 'providers/orders_provider.dart';
import 'providers/wishlist_provider.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/main_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/pending_invite.dart';
import 'services/preview_auth.dart';
import 'theme/app_theme.dart';

/// Extracts a referral code from `/invite/{code}` paths.
String? _codeFromUri(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.length >= 2 && segments[0] == 'invite') {
    final code = segments[1].trim().toUpperCase();
    if (code.isNotEmpty) return code;
  }
  return null;
}

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

  // Capture the initial deep link before the first frame so the invite code
  // is available when InviteCodeScreen first reads PendingInvite.
  if (!_isRunningUnderTest() && !kIsWeb) {
    try {
      final appLinks = AppLinks();
      final initial = await appLinks.getInitialLink();
      if (initial != null) {
        final code = _codeFromUri(initial);
        if (code != null) await PendingInvite.save(code);
      }
    } catch (_) {}
  }

  final showWelcome = !_isRunningUnderTest();
  bool onboardingShown = false;
  if (!_isRunningUnderTest()) {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
      onboardingShown = prefs.getBool('onboarding_shown') ?? false;
    } catch (_) {
      onboardingShown = true;
    }
  }
  runApp(YokoMarketApp(showWelcome: showWelcome, onboardingShown: onboardingShown));
}

class YokoMarketApp extends StatelessWidget {
  const YokoMarketApp({
    super.key,
    this.marketProvider,
    this.showWelcome = false,
    this.onboardingShown = true,
  });

  final MarketProvider? marketProvider;
  final bool showWelcome;
  final bool onboardingShown;

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
        // AddressProvider loads saved addresses when authenticated, clears on logout.
        ChangeNotifierProxyProvider<AuthProvider, AddressProvider>(
          create: (_) => AddressProvider(),
          update: (_, auth, addresses) {
            addresses ??= AddressProvider();
            if (auth.isAuthenticated) {
              auth.getAccessToken().then((token) {
                if (token != null && !addresses!.isLoaded) {
                  addresses.load(token);
                }
              });
            } else if (auth.state == AuthState.guest) {
              addresses.clear();
            }
            return addresses;
          },
        ),
        // WishlistProvider syncs with backend when auth state changes.
        ChangeNotifierProxyProvider<AuthProvider, WishlistProvider>(
          create: (_) => WishlistProvider(),
          update: (_, auth, wishlist) {
            wishlist ??= WishlistProvider();
            if (auth.isAuthenticated) {
              auth.getAccessToken().then((token) {
                if (token != null) wishlist!.syncAfterLogin(token);
              });
            } else if (auth.state == AuthState.guest) {
              wishlist.clearForUser();
            }
            return wishlist;
          },
        ),
      ],
      child: MaterialApp(
        title: 'YokoMarket',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        themeMode: ThemeMode.light,
        home: _StartScreen(showWelcome: showWelcome, onboardingShown: onboardingShown),
      ),
    );
  }
}

/// Shows [WelcomeScreen] on every cold start (when [showWelcome]); goes straight to [MainScreen]
/// otherwise.
class _StartScreen extends StatefulWidget {
  const _StartScreen({
    required this.showWelcome,
    this.onboardingShown = true,
  });

  final bool showWelcome;
  final bool onboardingShown;

  @override
  State<_StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<_StartScreen> {
  late bool _showOverlay;

  @override
  void initState() {
    super.initState();
    _showOverlay = widget.showWelcome && !_isRunningUnderTest();
    _listenForLinks();
  }

  void _listenForLinks() {
    if (kIsWeb) return;
    try {
      AppLinks().uriLinkStream.listen((uri) async {
        final code = _codeFromUri(uri);
        if (code != null) await PendingInvite.save(code);
      });
    } catch (_) {}
  }

  void _onOverlayDone() {
    setState(() => _showOverlay = false);
    if (!widget.onboardingShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final auth = context.read<AuthProvider>();
        if (auth.state != AuthState.authenticated) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showOverlay) return const MainScreen();
    return WelcomeScreen(onDone: _onOverlayDone);
  }
}
