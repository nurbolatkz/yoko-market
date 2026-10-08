import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    required this.ttl,
    this.onSuccess,
  });

  final String phone;
  final int ttl;
  final VoidCallback? onSuccess;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // Backend constants — kept in sync with mobile_auth.py:
  //   _OTP_RATE_LIMIT = 5 per 60 s → resend cooldown = 60 s
  //   _OTP_TTL = 300 s              → passed in via widget.ttl
  static const int _resendDelay = 60;

  final _controller = TextEditingController();

  bool _loading = false;
  bool _resending = false;
  bool _tooManyAttempts = false;
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
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.length != 6 || _loading || _tooManyAttempts || _ttlSeconds == 0) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().login(widget.phone, code);
      if (!mounted) return;
      widget.onSuccess?.call();
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = _detail(e);
      if (detail == 'too_many_attempts') _tooManyAttempts = true;
      setState(() => _error = _mapVerifyError(detail));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _resendSeconds > 0 || _loading) return;
    setState(() {
      _resending = true;
      _error = null;
      _tooManyAttempts = false;
    });
    try {
      final newTtl = await context.read<AuthProvider>().requestOtp(widget.phone);
      if (!mounted) return;
      _controller.clear();
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
    final canVerify = !_loading && !_tooManyAttempts && !codeExpired;

    return Scaffold(
      appBar: AppBar(title: const Text('Подтверждение')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Введите код из SMS',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Отправлено на ${widget.phone}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              enabled: canVerify,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                letterSpacing: 10,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: '– – – – – –',
                hintStyle: TextStyle(
                  color: theme.colorScheme.outline,
                  fontSize: 22,
                  letterSpacing: 8,
                ),
                errorText: _error ?? (codeExpired ? 'Код истёк. Запросите новый.' : null),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) {
                if (_error != null) setState(() => _error = null);
                if (v.length == 6 && canVerify) _verify();
              },
            ),
            // TTL countdown — only while code is still valid and more than 30s remain
            if (_ttlSeconds > 30)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Код действителен ещё $_ttlSeconds сек.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: canVerify ? _verify : null,
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
                  : const Text(
                      'Подтвердить',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 16),
            // Resend section — separate from code TTL
            Center(
              child: canResend
                  ? TextButton(
                      onPressed: _resend,
                      child: _resending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Отправить повторно'),
                    )
                  : Text(
                      'Повторная отправка через $_resendSeconds сек.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
