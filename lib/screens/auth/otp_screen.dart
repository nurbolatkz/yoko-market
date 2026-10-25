import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui/app_button.dart';
import 'profile_setup_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    required this.ttl,
    this.onSuccess,
    this.returnResultOnSuccess = false,
    this.fromCheckout = false,
  });

  final String phone;
  final int ttl;
  final VoidCallback? onSuccess;

  /// When true: verifies OTP and pops with `true` without updating AuthProvider
  /// state or calling [onSuccess]. Use for identity confirmation flows (e.g.
  /// account deletion) where a full login side-effect is undesirable.
  final bool returnResultOnSuccess;

  /// Passed through from PhoneScreen; may be used by downstream screens.
  final bool fromCheckout;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // Backend constants — kept in sync with mobile_auth.py:
  //   _OTP_RATE_LIMIT = 5 per 60 s → resend cooldown = 60 s
  //   _OTP_TTL = 300 s              → passed in via widget.ttl
  static const int _resendDelay = 60;

  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  String get _code => _otpController.text;

  bool _loading = false;
  bool _resending = false;
  bool _tooManyAttempts = false;
  bool _submitted = false; // prevents double-submit from auto-fill + button tap
  bool _hasError = false;
  String? _error;

  // Two separate counters managed by a single timer.
  // _ttlSeconds    — how long the current code is still valid (starts from widget.ttl = 300).
  // _resendSeconds — rate-limit cooldown before another OTP can be requested (starts from 60).
  late int _ttlSeconds;
  int _resendSeconds = _resendDelay;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ttlSeconds = widget.ttl;
    _startTimers();
  }

  void _startTimers([int? newTtl]) {
    _ttlSeconds = newTtl ?? widget.ttl;
    _resendSeconds = _resendDelay;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_ttlSeconds > 0) _ttlSeconds--;
        if (_resendSeconds > 0) _resendSeconds--;
        if (_ttlSeconds == 0 && _resendSeconds == 0) t.cancel();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  static String _formatTimer(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return phone;
    final last4 = digits.substring(digits.length - 4);
    return '+7 ••• ••• ${last4.substring(0, 2)} ${last4.substring(2)}';
  }

  Future<void> _verify() async {
    final code = _code.trim();
    if (code.length != 6 || _loading || _submitted || _tooManyAttempts || _ttlSeconds == 0) {
      return;
    }
    _submitted = true; // set before setState — blocks any concurrent call
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.returnResultOnSuccess) {
        await context.read<AuthProvider>().verifyOtpSilent(widget.phone, code);
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        await context.read<AuthProvider>().login(widget.phone, code);
        if (!mounted) return;
        final auth = context.read<AuthProvider>();
        if ((auth.user?.fullName ?? '').isEmpty) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          );
          if (!mounted) return;
        }
        widget.onSuccess?.call();
        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = _detail(e);
      if (detail == 'too_many_attempts') _tooManyAttempts = true;
      // Server expired the Redis key before the client timer hit zero (clock drift).
      // Force the client timer to zero so the verify button is disabled consistently.
      if (detail == 'code_expired') _ttlSeconds = 0;
      _submitted = false; // allow retry after a real error
      final hasError = detail == 'invalid_code';
      setState(() {
        _hasError = hasError;
        _error = _mapVerifyError(detail);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _resendSeconds > 0 || _loading) return;
    setState(() {
      _resending = true;
      _error = null;
      _hasError = false;
      _tooManyAttempts = false;
    });
    try {
      final newTtl = await context.read<AuthProvider>().requestOtp(widget.phone);
      if (!mounted) return;
      _otpController.clear();
      _hasError = false;
      _startTimers(newTtl); // reset both TTL and resend cooldown with fresh values
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _mapResendError(_detail(e)));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  static String? _detail(DioException e) =>
      (e.response?.data is Map)
          ? (e.response!.data as Map)['detail'] as String?
          : null;

  String _mapVerifyError(String? detail) => switch (detail) {
    'code_expired' => 'Код истёк. Запросите новый.',
    'too_many_attempts' => 'Превышено число попыток. Запросите новый код.',
    'invalid_code' => 'Неверный код. Попробуйте ещё раз.',
    _ => 'Ошибка соединения. Проверьте сеть.',
  };

  String _mapResendError(String? detail) => switch (detail) {
    'too_many_requests' => 'Слишком много запросов. Подождите минуту.',
    'sms_not_configured' => 'SMS-сервис временно недоступен.',
    'invalid_phone' => 'Неверный номер телефона.',
    _ => 'Ошибка соединения. Проверьте сеть.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codeExpired = _ttlSeconds == 0;
    final canResend = _resendSeconds == 0 && !_resending && !_loading;
    final canVerify = !_loading && !_tooManyAttempts && !codeExpired && _code.length == 6;

    final headline = _hasError ? 'Попробуйте ещё раз' : 'Проверьте сообщения';

    return Scaffold(
      appBar: AppBar(title: Text(_hasError ? 'Неверный код' : 'Код из SMS')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              headline,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Код отправлен на ${_maskPhone(widget.phone)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.navyMuted,
              ),
            ),
            const SizedBox(height: 24),
            if (widget.fromCheckout)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: AppColors.purpleSoft,
                  borderRadius: AppRadii.cardBorder,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shopping_bag_outlined, color: AppColors.purple, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ваши данные сохранятся — после входа вернём вас к оформлению.',
                        style: TextStyle(color: AppColors.purple, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            // 6-cell OTP input
            GestureDetector(
              onTap: () => _otpFocusNode.requestFocus(),
              child: Stack(
                children: [
                  // Visual cells (non-interactive)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) => _OtpCell(
                      char: i < _code.length ? _code[i] : '',
                      active: !_hasError && !_tooManyAttempts && i == _code.length,
                      error: _hasError || (_error != null && i < _code.length),
                    )),
                  ),
                  // Transparent input field that captures keyboard
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0,
                      child: TextField(
                        controller: _otpController,
                        focusNode: _otpFocusNode,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onChanged: (v) {
                          if (_hasError) setState(() { _hasError = false; _error = null; });
                          setState(() {});
                          if (v.length == 6 && canVerify) _verify();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_tooManyAttempts)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Слишком много попыток. Запросите новый код через несколько минут.',
                  style: const TextStyle(color: AppColors.error, fontSize: 13, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Подтвердить',
              loading: _loading,
              variant: canVerify ? AppButtonVariant.primary : AppButtonVariant.disabled,
              onPressed: canVerify ? _verify : null,
            ),
            const SizedBox(height: 16),
            Center(
              child: canResend
                  ? GestureDetector(
                      onTap: _resend,
                      child: _resending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Отправить код повторно',
                              style: TextStyle(
                                color: AppColors.purple,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                    )
                  : Text(
                      'Отправить повторно через ${_formatTimer(_resendSeconds)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.navyMuted, fontSize: 13),
                    ),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Изменить номер',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpCell extends StatelessWidget {
  const _OtpCell({required this.char, required this.active, required this.error});
  final String char;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final borderColor = error
        ? AppColors.error
        : active
            ? AppColors.purple
            : AppColors.border;
    return Container(
      width: 44,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.inputBorder,
        border: Border.all(color: borderColor, width: error || active ? 2 : 1.5),
      ),
      alignment: Alignment.center,
      child: char.isNotEmpty
          ? Text(
              char,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            )
          : (active
              ? Container(
                  width: 2,
                  height: 24,
                  color: AppColors.purple,
                )
              : null),
    );
  }
}
