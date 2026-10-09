import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'otp_screen.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

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

    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      // Wrap in scroll view so the content isn't clipped when the keyboard opens.
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          32,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Введите номер телефона',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Мы отправим SMS с кодом подтверждения',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            // ── Phone input with fixed +7 prefix ────────────────────────
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                // Accept up to 11 digits to handle pasted full numbers;
                // onChanged strips the country-code prefix automatically.
                LengthLimitingTextInputFormatter(11),
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
                // If user pastes a full number (11 digits), strip the leading '7' or '8'.
                if (value.length > 10) {
                  final stripped = (value.startsWith('7') || value.startsWith('8'))
                      ? value.substring(1)
                      : value.substring(0, 10);
                  _controller.value = TextEditingValue(
                    text: stripped,
                    selection: TextSelection.collapsed(offset: stripped.length),
                  );
                }
                if (_fieldError != null || _serviceError != null) {
                  setState(() {
                    _fieldError = null;
                    _serviceError = null;
                  });
                }
              },
              onSubmitted: (_) => _requestOtp(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _requestOtp,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Получить код', style: TextStyle(fontSize: 16)),
            ),
            // ── Service error banner (separate from field format errors) ─
            if (_serviceError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _serviceError!,
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
