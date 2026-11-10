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
import 'screens/auth/phone_screen.dart';
import 'screens/auth/pin_entry_screen.dart';
import 'screens/auth/pin_setup_screen.dart';
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

  // intro_shown: true after user dismisses WelcomeScreen for the first time.
  // Both the animation and the landing screen are skipped on subsequent launches.
  bool introShown = false;
  if (!_isRunningUnderTest()) {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
      introShown = prefs.getBool('intro_shown') ?? false;
    } catch (_) {
      introShown = true; // on failure, skip intro
    }
  }
  runApp(YokoMarketApp(introShown: introShown));
}

class YokoMarketApp extends StatelessWidget {
  const YokoMarketApp({
    super.key,
    this.marketProvider,
    this.introShown = true,
  });

  final MarketProvider? marketProvider;
  final bool introShown;

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
                ..loadBanners()
                ..loadBestSellers()
                ..loadNewArrivals(),
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
        home: _StartScreen(introShown: introShown),
      ),
    );
  }
}

/// Coordinates the first-launch intro flow and the ongoing PIN gate.
///
/// First launch ([introShown] == false):
///   1. [WelcomeOverlay] animation plays (2.8 s, tap to skip).
///   2. After animation: [WelcomeScreen] hero + 2 buttons.
///   3. User presses a button → `intro_shown` written to prefs → [MainScreen].
///
/// Subsequent launches ([introShown] == true): straight to [MainScreen].
///
/// [MainScreen] is always in the widget tree so API calls start immediately —
/// the animation never delays data loading.
///
/// When [AppConfig.fastLoginEnabled] is true and the user has set up a PIN,
/// [PinEntryScreen] gates the app before anything else is revealed.
class _StartScreen extends StatefulWidget {
  const _StartScreen({
    required this.introShown,
    this.testFastLoginEnabled,
    this.fastLoginService,
  });

  final bool introShown;
  final bool? testFastLoginEnabled;
  final FastLoginService? fastLoginService;

  @override
  State<_StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<_StartScreen> {
  late bool _showAnimation;
  late bool _showWelcome;

  /// null = PIN gate check in progress, true/false = resolved.
  bool? _pinNeeded;
  FastLoginService? _pinService;

  @override
  void initState() {
    super.initState();
    final firstLaunch = !widget.introShown && !_isRunningUnderTest();
    _showAnimation = firstLaunch;
    _showWelcome = firstLaunch;
    _listenForLinks();
    _checkPinGate();
  }

  Future<void> _checkPinGate() async {
    final flagEnabled = widget.testFastLoginEnabled ?? AppConfig.fastLoginEnabled;
    // Skip in test environment: FlutterSecureStorage has no platform channel
    // in widget tests and would hang indefinitely.
    if (!flagEnabled || _isRunningUnderTest()) {
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
        // Suppress intro when gating with PIN — playing the animation behind
        // the PIN screen and then again after unlock would be jarring.
        _showAnimation = false;
        _showWelcome = false;
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

  Future<void> _onForgotPin() async {
    await _pinService?.disable();
    if (!mounted) return;
    final authenticated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PhoneScreen(forgotPin: true)),
    );
    if (!mounted) return;
    if (authenticated != true) {
      setState(() { _pinNeeded = false; _pinService = null; });
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PinSetupScreen(
          onComplete: () => Navigator.of(context).pop(),
        ),
      ),
    );
    if (!mounted) return;
    setState(() { _pinNeeded = false; _pinService = null; });
  }

  void _onAnimationDone() {
    // Animation finished → reveal the landing screen.
    setState(() => _showAnimation = false);
  }

  void _onWelcomeDone() {
    // User pressed a button → persist and reveal the app.
    SharedPreferences.getInstance()
        .then((p) => p.setBool('intro_shown', true))
        .catchError((_) => false);
    setState(() => _showWelcome = false);
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state unconditionally so rebuilds fire when it changes.
    final auth = context.watch<AuthProvider>();

    if (_pinNeeded == null) {
      return const ColoredBox(color: AppColors.background);
    }

    if (_pinNeeded!) {
      return PinEntryScreen(
        fastLoginService: _pinService,
        onSuccess: () => setState(() { _pinNeeded = false; }),
        onForgotPin: _onForgotPin,
      );
    }

    // Belt-and-suspenders: if login completes via any path, auto-dismiss the
    // welcome overlay. The primary path is WelcomeScreen._openLogin() passing
    // onDone directly to PhoneScreen.onSuccess; this covers edge cases.
    if (_showWelcome && auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showWelcome) _onWelcomeDone();
      });
    }

    // MainScreen always present so network requests fire immediately.
    return Stack(
      children: [
        const MainScreen(),
        if (_showAnimation)
          WelcomeOverlay(onDone: _onAnimationDone),
        if (!_showAnimation && _showWelcome)
          WelcomeScreen(onDone: _onWelcomeDone),
      ],
    );
  }
}

/// Creates a [_StartScreen] with test-only overrides. Not for production use.
@visibleForTesting
Widget buildStartScreenForTest({
  bool introShown = true,
  bool? testFastLoginEnabled,
  FastLoginService? fastLoginService,
}) =>
    _StartScreen(
      introShown: introShown,
      testFastLoginEnabled: testFastLoginEnabled,
      fastLoginService: fastLoginService,
    );
