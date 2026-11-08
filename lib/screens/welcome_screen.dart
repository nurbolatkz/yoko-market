import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/ui/app_button.dart';
import 'auth/phone_screen.dart';

/// Static welcome / landing screen shown to unauthenticated users.
/// Dismissed automatically when [AuthProvider] resolves to [AuthState.authenticated].
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onDone});

  /// Called by both "Начать покупки" and after successful login to remove this screen.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.purpleSoft,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Hero image — aligned to top so logo/faces are always visible.
          // BoxFit.cover crops the lavender bottom on small screens, which is fine.
          Semantics(
            label: 'YokoMarket — всё необходимое для семьи в одном месте. '
                'Мама с дочкой и корзина с товарами для малышей.',
            child: Image.asset(
              'assets/images/welcome/welcome_hero.webp',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),

          // Gradient fade from transparent to lavender — creates natural shelf
          // for buttons without covering faces or product photo.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.purpleSoft.withValues(alpha: 0.0),
                    AppColors.purpleSoft.withValues(alpha: 0.92),
                    AppColors.purpleSoft,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // Buttons anchored to safe bottom edge.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      label: 'Начать покупки',
                      onPressed: onDone,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Войти в аккаунт',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => _openLogin(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhoneScreen(
          onSuccess: () {
            // onSuccess fires after OTP + profile setup are complete.
            // AuthProvider is already authenticated at this point; _StartScreen
            // will dismiss us via its auth listener.
          },
        ),
      ),
    );
  }
}
