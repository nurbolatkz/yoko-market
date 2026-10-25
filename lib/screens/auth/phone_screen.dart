import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../services/legal_settings_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui/app_button.dart';
import 'otp_screen.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({
    super.key,
    this.onSuccess,
    this.fromCheckout = false,
  });

  final VoidCallback? onSuccess;
  final bool fromCheckout;

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  /// Field-level format error (shown as errorText under the input).
  String? _fieldError;

  /// Service-level error (shown as a banner below the button).
  String? _serviceError;

  LegalUrls? _legal;

  @override
  void initState() {
    super.initState();
    _loadLegal();
  }

  Future<void> _loadLegal() async {
    try {
      final urls = await LegalSettingsApi().getLegalUrls();
      if (!mounted) return;
      setState(() => _legal = urls);
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Builds the full E.164 number from the 10-digit input.
  // Input may arrive as 10 digits (national) or as a pasted full number.
  String? _toE164(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    // 10 digits: pure national → prepend KZ country code
    if (digits.length == 10) return '+7$digits';
    // 11 digits starting with 7: full number without '+'
    if (digits.length == 11 && digits.startsWith('7')) return '+$digits';
    // 11 digits starting with 8: legacy RU/KZ format
    if (digits.length == 11 && digits.startsWith('8')) return '+7${digits.substring(1)}';
    return null; // let backend reject anything else
  }

  int get _digitCount =>
      _controller.text.replaceAll(RegExp(r'\D'), '').length;

  Future<void> _requestOtp() async {
    final phone = _toE164(_controller.text);
    if (phone == null) {
      setState(() {
        _fieldError = 'Введите 10 цифр номера (без +7)';
        _serviceError = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _fieldError = null;
      _serviceError = null;
    });
    try {
      final ttl = await context.read<AuthProvider>().requestOtp(phone);
      if (!mounted) return;
      final success = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            phone: phone,
            ttl: ttl,
            onSuccess: widget.onSuccess,
            fromCheckout: widget.fromCheckout,
          ),
        ),
      );
      if ((success == true) && mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = _detail(e);
      setState(() {
        if (detail == 'invalid_phone') {
          _fieldError = 'Неверный формат номера.';
        } else {
          _serviceError = _mapServiceError(detail);
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapServiceError(String? detail) => switch (detail) {
    'too_many_requests' => 'Слишком много запросов. Подождите минуту и попробуйте снова.',
    'sms_not_configured' =>
      'SMS-сервис временно недоступен.\nОбратитесь в поддержку.',
    _ => 'Ошибка соединения. Проверьте интернет и повторите попытку.',
  };

  static String? _detail(DioException e) =>
      (e.response?.data is Map)
          ? (e.response!.data as Map)['detail'] as String?
          : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSubmit = _digitCount >= 10 && !_loading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Вход по телефону',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.navyMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Рады вас видеть',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Отправим SMS с кодом.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.navyMuted,
              ),
            ),
            const SizedBox(height: 32),
            // ── Phone input with fixed +7 prefix ────────────────────────
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _PhoneMaskFormatter(),
              ],
              decoration: InputDecoration(
                // Inline "+7 " prefix — visually part of the phone number.
                prefix: const Text(
                  '+7 ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                prefixIcon: const Icon(Icons.phone_outlined),
                hintText: '777 123 45 67',
                errorText: _fieldError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                if (_fieldError != null || _serviceError != null) {
                  setState(() {
                    _fieldError = null;
                    _serviceError = null;
                  });
                } else {
                  setState(() {});
                }
              },
              onSubmitted: (_) {
                if (canSubmit) _requestOtp();
              },
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Получить код',
              loading: _loading,
              variant: canSubmit
                  ? AppButtonVariant.primary
                  : AppButtonVariant.disabled,
              onPressed: canSubmit ? _requestOtp : null,
            ),
            // ── Service error banner (separate from field format errors) ─
            if (_serviceError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 18, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _serviceError!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            _LegalFooter(legal: _legal),
            const SizedBox(height: 12),
            AppButton(
              label: 'Продолжить без входа',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Phone mask formatter ──────────────────────────────────────────────────────

class _PhoneMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue val) {
    var digits = val.text.replaceAll(RegExp(r'\D'), '');
    // Strip leading country code from pasted numbers
    if (digits.length == 11 &&
        (digits.startsWith('7') || digits.startsWith('8'))) {
      digits = digits.substring(1);
    } else if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }
    final formatted = _applyMask(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _applyMask(String digits) {
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6 || i == 8) b.write(' ');
      b.write(digits[i]);
    }
    return b.toString();
  }
}

// ── Legal footer widget ───────────────────────────────────────────────────────

class _LegalFooter extends StatelessWidget {
  const _LegalFooter({required this.legal});
  final LegalUrls? legal;

  @override
  Widget build(BuildContext context) {
    final legal = this.legal;
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          color: AppColors.navyMuted,
          fontSize: 12,
          height: 1.5,
        ),
        children: [
          const TextSpan(text: 'Продолжая, вы принимаете '),
          if (legal != null && legal.termsUrl.isNotEmpty)
            _linkSpan('условия сервиса', legal.termsUrl, context)
          else
            const TextSpan(text: 'условия сервиса'),
          const TextSpan(text: ' и '),
          if (legal != null && legal.privacyUrl.isNotEmpty)
            _linkSpan('политику конфиденциальности', legal.privacyUrl, context)
          else
            const TextSpan(text: 'политику конфиденциальности'),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  InlineSpan _linkSpan(String text, String url, BuildContext context) =>
      TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.purple,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.purple,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.tryParse(url);
            if (uri != null) {
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {}
            }
          },
      );
}
