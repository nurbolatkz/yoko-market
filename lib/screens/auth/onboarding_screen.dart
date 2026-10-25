import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui/app_button.dart';
import 'phone_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('onboarding_shown', true);
    });
  }

  void _startShopping() {
    Navigator.of(context).pop();
  }

  Future<void> _signIn() async {
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PhoneScreen()),
    );
    if (success == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Caption
              Text(
                'Добро пожаловать',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.navyMuted,
                ),
              ),
              const SizedBox(height: 8),
              // Brand RichText
              Row(
                children: [
                  Flexible(
                    child: RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Yo',
                            style: TextStyle(
                              color: AppColors.purple,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'NunitoSans',
                            ),
                          ),
                          TextSpan(
                            text: ' Market',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'NunitoSans',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Tagline
              Text(
                'Всё для вашей семьи',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              // Body description
              Text(
                'Любимые товары, удобная доставка и бонусы в одном приложении.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.navyMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              // NavRow
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Покупайте без регистрации',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.navyMuted,
                      ),
                    ),
                  ),
                  Text(
                    ' • ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.border,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      'Войдите, когда будете готовы',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.navyMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Buttons pinned to bottom
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      label: 'Начать покупки',
                      variant: AppButtonVariant.primary,
                      onPressed: _startShopping,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Войти в аккаунт',
                      variant: AppButtonVariant.secondary,
                      onPressed: _signIn,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
