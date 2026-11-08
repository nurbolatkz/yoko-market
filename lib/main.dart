import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
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
import 'screens/auth/pin_entry_screen.dart';
import 'screens/main_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/fast_login_service.dart';
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

/// Shows [WelcomeOverlay] on every cold start (when [showWelcome]); goes straight to [MainScreen]
/// otherwise. [MainScreen] is always in the tree so API calls start
/// immediately — the animation never delays data loading.
///
/// When [AppConfig.fastLoginEnabled] is true and the user has set up a PIN,
/// [PinEntryScreen] is shown before [MainScreen] is revealed.
class _StartScreen extends StatefulWidget {
  const _StartScreen({
    required this.showWelcome,
    this.onboardingShown = true,
    this.testFastLoginEnabled, // null = use AppConfig.fastLoginEnabled
    this.fastLoginService,     // null = use FastLoginService() (production)
  });

  final bool showWelcome;
  final bool onboardingShown;
  final bool? testFastLoginEnabled;
  final FastLoginService? fastLoginService;

  @override
  State<_StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<_StartScreen> {
  late bool _showOverlay;

  /// null = PIN gate check in progress, true/false = resolved.
  bool? _pinNeeded;
  FastLoginService? _pinService;

  @override
  void initState() {
    super.initState();
    _showOverlay = widget.showWelcome && !_isRunningUnderTest();
    _listenForLinks();
    _checkPinGate();
  }

  Future<void> _checkPinGate() async {
    final flagEnabled = widget.testFastLoginEnabled ?? AppConfig.fastLoginEnabled;
    if (!flagEnabled) {
      if (mounted) setState(() => _pinNeeded = false);
      return;
    }
    final svc = widget.fastLoginService ?? FastLoginService();
    final enabled = await svc.isEnabled();
    if (!mounted) return;
    setState(() {
      _pinNeeded = enabled;
      if (enabled) {
        _pinService = svc;
        // Suppress welcome overlay when gating with PIN — it would appear
        // behind the PIN screen and then again after unlock, which is jarring.
        _showOverlay = false;
      }
    });
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
    // Brief splash while checking secure storage for the PIN gate.
    if (_pinNeeded == null) {
      return const ColoredBox(color: AppColors.background);
    }

    // PIN gate: show PinEntryScreen as the root; MainScreen revealed on success.
    if (_pinNeeded!) {
      return PinEntryScreen(
        fastLoginService: _pinService,
        onSuccess: () => setState(() { _pinNeeded = false; }),
        onForgotPin: () {
          // PR-5 will route to PhoneScreen for SMS re-auth.
          // For now: disable fast login locally and open the app.
          _pinService?.disable().then((_) {
            if (mounted) setState(() { _pinNeeded = false; _pinService = null; });
          });
        },
      );
    }

    // Normal flow.
    if (!_showOverlay) return const MainScreen();
    return Stack(
      children: [
        const MainScreen(),
        WelcomeOverlay(onDone: _onOverlayDone),
      ],
    );
  }
}

/// Creates a [_StartScreen] with test-only overrides. Not for production use.
@visibleForTesting
Widget buildStartScreenForTest({
  bool showWelcome = false,
  bool onboardingShown = true,
  bool? testFastLoginEnabled,
  FastLoginService? fastLoginService,
}) =>
    _StartScreen(
      showWelcome: showWelcome,
      onboardingShown: onboardingShown,
      testFastLoginEnabled: testFastLoginEnabled,
      fastLoginService: fastLoginService,
    );
