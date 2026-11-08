import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Row of four PIN entry cells.
///
/// [pin] holds the digits typed so far (0–4 chars).
/// [error] turns all filled dots and borders red.
class PinCellsRow extends StatelessWidget {
  const PinCellsRow({super.key, required this.pin, this.error = false});

  final String pin;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < pin.length;
        final active = !error && i == pin.length && pin.length < 4;
        return _PinCell(filled: filled, active: active, error: error);
      }),
    );
  }
}

class _PinCell extends StatelessWidget {
  const _PinCell({
    required this.filled,
    required this.active,
    required this.error,
  });

  final bool filled;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final borderColor = error
        ? AppColors.error
        : active
            ? AppColors.purple
            : AppColors.border;
    final borderWidth = (active || error) ? 2.0 : 1.5;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 60,
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.inputBorder,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      alignment: Alignment.center,
      child: filled
          ? Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: error ? AppColors.error : AppColors.navy,
                shape: BoxShape.circle,
              ),
            )
          : (active
              ? Container(width: 2, height: 28, color: AppColors.purple)
              : null),
    );
  }
}

/// Numeric keypad with digits 0–9 and a backspace key.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.disabled = false,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _KeyRow(keys: const ['1', '2', '3'], onDigit: onDigit, disabled: disabled),
        const SizedBox(height: 10),
        _KeyRow(keys: const ['4', '5', '6'], onDigit: onDigit, disabled: disabled),
        const SizedBox(height: 10),
        _KeyRow(keys: const ['7', '8', '9'], onDigit: onDigit, disabled: disabled),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(child: SizedBox()),
            const SizedBox(width: 10),
            Expanded(
              child: _DigitKey(
                label: '0',
                onTap: disabled ? null : () => onDigit('0'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BackspaceKey(onTap: disabled ? null : onBackspace),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.keys,
    required this.onDigit,
    required this.disabled,
  });

  final List<String> keys;
  final void Function(String) onDigit;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _DigitKey(
              label: keys[i],
              onTap: disabled ? null : () => onDigit(keys[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.inputBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.inputBorder,
        child: Container(
          height: 64,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: onTap != null ? AppColors.navy : AppColors.navyMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _BackspaceKey extends StatelessWidget {
  const _BackspaceKey({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.inputBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.inputBorder,
        child: Container(
          height: 64,
          alignment: Alignment.center,
          child: Icon(
            Icons.backspace_outlined,
            size: 22,
            color: onTap != null ? AppColors.navy : AppColors.navyMuted,
          ),
        ),
      ),
    );
  }
}
