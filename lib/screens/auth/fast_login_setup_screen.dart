import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui/app_button.dart';
import 'pin_setup_screen.dart';
import 'profile_setup_screen.dart';

/// Optional "Enable fast login?" prompt shown once after [InviteCodeScreen].
///
/// "Включить" → [PinSetupScreen] → [ProfileSetupScreen]
/// "Позже"    → [ProfileSetupScreen] (stores fl_setup_dismissed flag)
///
/// [onEnable] and [onSkip] override the default navigation — used in tests.
class FastLoginSetupScreen extends StatefulWidget {
  const FastLoginSetupScreen({
    super.key,
    this.onEnable,
    this.onSkip,
  });

  /// Called when "Включить быстрый вход" is tapped. If null, pushes
  /// [PinSetupScreen] then pops this screen.
  final Future<void> Function(BuildContext ctx)? onEnable;

  /// Called when "Позже" is tapped. If null, pushes [ProfileSetupScreen]
  /// then pops this screen.
  final Future<void> Function(BuildContext ctx)? onSkip;

  @override
  State<FastLoginSetupScreen> createState() => _FastLoginSetupScreenState();
}

class _FastLoginSetupScreenState extends State<FastLoginSetupScreen> {
  bool _busy = false;

  Future<void> _handleEnable() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (widget.onEnable != null) {
        await widget.onEnable!(context);
      } else {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const PinSetupScreen()),
        );
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleSkip() async {
    if (_busy) return;
    await _markDismissed();
    if (!mounted) return;
    if (widget.onSkip != null) {
      await widget.onSkip!(context);
    } else {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  Future<void> _markDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fl_setup_dismissed', true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: AppColors.purpleSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fingerprint_rounded,
                          color: AppColors.purple,
                          size: 44,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Быстрый вход',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Входите в приложение одним нажатием\nбез ожидания SMS-кода.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.navyMuted,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    _FeatureRow(
                      icon: Icons.bolt_rounded,
                      text: 'Вход за секунду — без ожидания SMS',
                    ),
                    const SizedBox(height: 16),
                    _FeatureRow(
                      icon: Icons.wifi_off_rounded,
                      text: 'Работает без интернета',
                    ),
                    const SizedBox(height: 16),
                    _FeatureRow(
                      icon: Icons.pin_outlined,
                      text: 'PIN из 4 цифр как запасной вариант',
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: 'Включить быстрый вход',
                    loading: _busy,
                    onPressed: _busy ? null : _handleEnable,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _busy ? null : _handleSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.navyMuted,
                      textStyle: const TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('Позже, настрою в профиле'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.purpleSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.purple, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
