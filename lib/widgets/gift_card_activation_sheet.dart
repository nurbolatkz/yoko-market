import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/wallet.dart';
import '../services/wallet_api.dart';
import '../theme/app_theme.dart';
import '../utils/codes.dart';
import '../utils/format.dart';
import 'ui/app_button.dart';
import 'ui/app_text_field.dart';

/// Opens the «Активировать подарочную карту» sheet. Resolves with the
/// activation result, or null if the user closed the sheet without one.
Future<GiftCardActivation?> showGiftCardActivationSheet(
  BuildContext context, {
  required WalletApi api,
  required String token,
}) {
  return showModalBottomSheet<GiftCardActivation>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
    ),
    builder: (_) => _ActivationSheet(api: api, token: token),
  );
}

class _ActivationSheet extends StatefulWidget {
  const _ActivationSheet({required this.api, required this.token});

  final WalletApi api;
  final String token;

  @override
  State<_ActivationSheet> createState() => _ActivationSheetState();
}

class _ActivationSheetState extends State<_ActivationSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _locked = false;
  GiftCardActivation? _result;

  bool get _complete => Codes.isGiftCardCode(_controller.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (!_complete || _loading || _locked) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.activateGiftCard(
        widget.token,
        _controller.text,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _result = result);
    } on GiftCardException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.error.message;
        _locked = e.error == GiftCardError.tooManyAttempts;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Ошибка соединения. Проверьте сеть.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.x2l + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.border,
                  borderRadius: AppRadii.chipBorder,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_result == null) ..._form() else ..._success(_result!),
          ],
        ),
      ),
    );
  }

  List<Widget> _form() => [
        const Text(
          'Активировать подарочную карту',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Введите 12 символов кода — он под защитным слоем на карте',
          style: TextStyle(fontSize: 13, color: AppColors.navyMuted, height: 1.3),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _controller,
          hint: 'XXXX-XXXX-XXXX',
          autofocus: true,
          enabled: !_locked,
          errorText: _error,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          inputFormatters: [_GiftCodeFormatter()],
          onChanged: (_) => setState(() {
            if (!_locked) _error = null;
          }),
          onSubmitted: (_) => _activate(),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Активировать',
          loading: _loading,
          variant: _complete && !_locked
              ? AppButtonVariant.primary
              : AppButtonVariant.disabled,
          onPressed: _activate,
        ),
      ];

  List<Widget> _success(GiftCardActivation r) => [
        const Icon(
          Icons.card_giftcard_rounded,
          size: 56,
          color: AppColors.purple,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Карта на ${formatMoney(r.amount)} активирована',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        if (r.fromName != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Подарок от ${r.fromName}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppColors.navy),
          ),
        ],
        if (r.message != null && r.message!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '«${r.message}»',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppColors.navyMuted,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          [
            'Подарочный баланс: ${formatMoney(r.giftBalance)}',
            if (r.expiresAt != null) 'действует до ${formatDate(r.expiresAt!)}',
          ].join(' · '),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.navyMuted),
        ),
        const SizedBox(height: AppSpacing.x2l),
        AppButton(
          label: 'Готово',
          onPressed: () => Navigator.of(context).pop(r),
        ),
      ];
}

/// Upper-cases, maps Cyrillic look-alikes, keeps the safe alphabet and
/// inserts dashes: "k7qm29" → "K7QM-29".
class _GiftCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = Codes.normalize(newValue.text)
        .split('')
        .where(Codes.alphabet.contains)
        .take(Codes.giftCardLength)
        .join();
    final text = Codes.formatGiftCard(raw);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
