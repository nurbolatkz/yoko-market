import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/account_recovery_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui/app_button.dart';

class AccountRecoveryScreen extends StatefulWidget {
  const AccountRecoveryScreen({super.key});

  @override
  State<AccountRecoveryScreen> createState() => _AccountRecoveryScreenState();
}

class _AccountRecoveryScreenState extends State<AccountRecoveryScreen> {
  final _orderController = TextEditingController();
  final _contactController = TextEditingController();
  final AccountRecoveryApi _api = AppConfig.mockAccountRecovery
      ? MockAccountRecoveryApi()
      : HttpAccountRecoveryApi();

  bool _loading = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _orderController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final order = _orderController.text.trim();
    final contact = _contactController.text.trim();
    if (order.isEmpty || contact.isEmpty) {
      setState(() => _error = 'Заполните оба поля.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.submitRequest(orderNumber: order, contact: contact);
      if (!mounted) return;
      setState(() => _submitted = true);
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _error = 'Не удалось отправить запрос. Проверьте интернет и попробуйте ещё раз.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        title: const Text('Восстановление',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: _submitted
            ? _SuccessView()
            : _FormView(
                theme: theme,
                orderController: _orderController,
                contactController: _contactController,
                loading: _loading,
                error: _error,
                onSubmit: _submit,
              ),
      ),
    );
  }
}

// ── Success view ───────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 32),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFE6F4EF),
            borderRadius: BorderRadius.circular(36),
          ),
          child: const Icon(Icons.check_rounded,
              color: AppColors.success, size: 36),
        ),
        const SizedBox(height: 20),
        const Text(
          'Запрос отправлен',
          style: TextStyle(
              color: AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Ответим в течение 1–2 рабочих дней.',
          style: TextStyle(
              color: AppColors.navyMuted, fontSize: 15, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Form view ──────────────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  const _FormView({
    required this.theme,
    required this.orderController,
    required this.contactController,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });

  final ThemeData theme;
  final TextEditingController orderController;
  final TextEditingController contactController;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  static const _inputBorder = OutlineInputBorder(
    borderRadius: AppRadii.inputBorder,
    borderSide: BorderSide(color: AppColors.border),
  );
  static const _focusedBorder = OutlineInputBorder(
    borderRadius: AppRadii.inputBorder,
    borderSide: BorderSide(color: AppColors.purple, width: 2),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Уже покупали у нас?',
            style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700, color: AppColors.navy)),
        const SizedBox(height: 8),
        const Text(
          'Если старые заказы и бонусы не появились, отправьте запрос на восстановление аккаунта.',
          style: TextStyle(
              color: AppColors.navyMuted, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: orderController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Номер старого заказа',
            hintText: 'Например, A-1098',
            border: OutlineInputBorder(borderRadius: AppRadii.inputBorder),
            enabledBorder: _inputBorder,
            focusedBorder: _focusedBorder,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: contactController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Контакт для ответа',
            hintText: '+7 777 123 45 67',
            border: OutlineInputBorder(borderRadius: AppRadii.inputBorder),
            enabledBorder: _inputBorder,
            focusedBorder: _focusedBorder,
          ),
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: 24),
        AppButton(
          label: 'Отправить запрос',
          loading: loading,
          variant:
              loading ? AppButtonVariant.disabled : AppButtonVariant.primary,
          onPressed: loading ? null : onSubmit,
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
              textAlign: TextAlign.center),
        ],
        const SizedBox(height: 20),
        const Text(
          'Не передавайте SMS-коды. Объединение аккаунтов выполняется после проверки.',
          style: TextStyle(
              color: AppColors.navyMuted, fontSize: 12, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
