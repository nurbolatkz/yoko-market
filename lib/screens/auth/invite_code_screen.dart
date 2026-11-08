import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/referral_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui/app_button.dart';
import 'fast_login_setup_screen.dart';
import 'profile_setup_screen.dart';

/// Shown once after OTP for new users.
///
/// If a referral code was captured from a deep link it is pre-filled and the
/// user just confirms. Otherwise a collapsible "Есть код приглашения?" section
/// lets them type one manually or skip entirely.
///
/// After this screen (accept OR skip) [ProfileSetupScreen] is pushed.
/// The flag `invite_step_shown` prevents this screen from appearing again.
class InviteCodeScreen extends StatefulWidget {
  const InviteCodeScreen({super.key, this.pendingCode});

  /// Pre-filled code from a deep link, or null when arriving without one.
  final String? pendingCode;

  @override
  State<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends State<InviteCodeScreen> {
  final _codeController = TextEditingController();
  final _referralApi = ReferralApi();

  bool _manualExpanded = false;
  bool _loading = false;
  String? _error;

  bool get _hasPrefilledCode => widget.pendingCode != null;

  @override
  void initState() {
    super.initState();
    if (widget.pendingCode != null) {
      _codeController.text = widget.pendingCode!;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _proceed();
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthProvider>();
      final token = await auth.getAccessToken();
      if (!mounted) return;
      if (token == null) { _proceed(); return; }
      final bonus = await _referralApi.activateReferral(token, code);
      if (!mounted) return;
      if (bonus > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Код принят! +$bonus бонусов начислено'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      _proceed();
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = (e.response?.data is Map)
          ? e.response!.data['detail'] as String?
          : null;
      if (detail == 'already_referred') {
        _proceed(); // idempotent — just move on
      } else {
        setState(() {
          _error = detail == 'invalid_code'
              ? 'Неверный код. Проверьте и попробуйте снова.'
              : 'Не удалось применить код. Попробуйте позже.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _proceed() => _navigateNext();
  Future<void> _skip() => _navigateNext();

  Future<void> _navigateNext() async {
    await _markShown();
    if (!mounted) return;
    final Widget next = AppConfig.fastLoginEnabled
        ? const FastLoginSetupScreen()
        : const ProfileSetupScreen();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => next),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _markShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('invite_step_shown', true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _loading ? null : _skip,
            child: const Text('Пропустить',
                style: TextStyle(color: AppColors.navyMuted, fontSize: 14)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.purpleSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.card_giftcard_rounded,
                    color: AppColors.purple, size: 36),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _hasPrefilledCode ? 'Вас пригласили!' : 'Код приглашения',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _hasPrefilledCode
                  ? 'Вы перешли по реферальной ссылке. '
                    'Примените код, чтобы оба получили бонусы.'
                  : 'Если у вас есть реферальный код друга, '
                    'введите его ниже. Вы оба получите бонусы.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.navyMuted,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            if (_hasPrefilledCode) ...[
              // Pre-filled code card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.purpleSoft,
                  borderRadius: AppRadii.cardBorder,
                  border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.purple, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.pendingCode!,
                        style: const TextStyle(
                          color: AppColors.purple,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: widget.pendingCode!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Код скопирован'),
                              duration: Duration(seconds: 1)),
                        );
                      },
                      child: const Icon(Icons.copy_rounded,
                          color: AppColors.navyMuted, size: 18),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 13),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              AppButton(
                label: 'Применить код',
                loading: _loading,
                onPressed: _loading ? null : _apply,
              ),
            ] else ...[
              // Collapsible manual entry
              GestureDetector(
                onTap: () => setState(() => _manualExpanded = !_manualExpanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.cardBorder,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.card_giftcard_outlined,
                          color: AppColors.purple, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Есть код приглашения?',
                            style: TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                      ),
                      Icon(
                        _manualExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.navyMuted,
                      ),
                    ],
                  ),
                ),
              ),
              if (_manualExpanded) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _codeController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Введите код',
                    hintText: 'Например: ABC123',
                    border: OutlineInputBorder(
                        borderRadius: AppRadii.inputBorder),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadii.inputBorder,
                      borderSide: BorderSide(
                          color: _error != null
                              ? AppColors.error
                              : AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadii.inputBorder,
                      borderSide: const BorderSide(
                          color: AppColors.purple, width: 2),
                    ),
                    errorText: _error,
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _apply(),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Применить',
                  loading: _loading,
                  onPressed: _loading ? null : _apply,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
