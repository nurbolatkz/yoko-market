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
  final _controller = TextEditingController();

  bool _loading = false;
  bool _resending = false;
  bool _tooManyAttempts = false;
  String? _error;
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          t.cancel();
        }
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
    if (code.length != 6 || _loading || _tooManyAttempts) return;
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
    if (_resending || _resendCountdown > 0 || _loading) return;
    setState(() {
      _resending = true;
      _error = null;
      _tooManyAttempts = false;
    });
    try {
      await context.read<AuthProvider>().requestOtp(widget.phone);
      if (!mounted) return;
      _controller.clear();
      _startCountdown();
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
    'invalid_phone' => 'Неверный номер телефона.',
    _ => 'Ошибка соединения. Проверьте сеть.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canResend = _resendCountdown == 0 && !_resending && !_loading;

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
              enabled: !_tooManyAttempts,
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
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) {
                if (_error != null) setState(() => _error = null);
                if (v.length == 6) _verify();
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: (_loading || _tooManyAttempts) ? null : _verify,
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
                      _resendCountdown > 0
                          ? 'Повторная отправка через $_resendCountdown сек.'
                          : 'Отправить повторно',
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
