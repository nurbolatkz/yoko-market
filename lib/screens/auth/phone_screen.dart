import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
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
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Введите номер телефона');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ttl = await context.read<AuthProvider>().requestOtp(raw);
      if (!mounted) return;
      final success = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            phone: raw,
            ttl: ttl,
            onSuccess: widget.onSuccess,
          ),
        ),
      );
      if ((success == true) && mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _mapError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapError(DioException e) {
    final detail = _detail(e);
    return switch (detail) {
      'invalid_phone' => 'Неверный формат номера телефона.',
      'too_many_requests' => 'Слишком много запросов. Подождите минуту.',
      'sms_not_configured' => 'SMS-сервис временно недоступен. Обратитесь в поддержку.',
      _ => 'Ошибка соединения. Проверьте сеть.',
    };
  }

  static String? _detail(DioException e) =>
      (e.response?.data is Map)
          ? (e.response!.data as Map)['detail'] as String?
          : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]')),
              ],
              decoration: InputDecoration(
                labelText: 'Номер телефона',
                hintText: '+7 777 123 45 67',
                prefixIcon: const Icon(Icons.phone_outlined),
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
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
          ],
        ),
      ),
    );
  }
}
