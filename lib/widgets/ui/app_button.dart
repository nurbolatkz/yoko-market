import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, disabled }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.fullWidth = true,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final Widget? icon;
  final bool fullWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDisabled = variant == AppButtonVariant.disabled || loading;
    final callback = isDisabled ? null : onPressed;

    Widget child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(label);

    if (!loading && icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [icon!, const SizedBox(width: 8), Text(label)],
      );
    }

    final minSize = Size(fullWidth ? double.infinity : 48, height);
    const textStyle = TextStyle(
      fontFamily: 'NunitoSans',
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    const shape = RoundedRectangleBorder(borderRadius: AppRadii.buttonBorder);

    switch (variant) {
      case AppButtonVariant.primary:
        return FilledButton(
          onPressed: callback,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.purple,
            foregroundColor: Colors.white,
            minimumSize: minSize,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            textStyle: textStyle,
            shape: shape,
          ),
          child: child,
        );

      case AppButtonVariant.secondary:
        return FilledButton(
          onPressed: callback,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.purpleSoft,
            foregroundColor: AppColors.purple,
            minimumSize: minSize,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            textStyle: textStyle,
            shape: shape,
          ),
          child: child,
        );

      case AppButtonVariant.disabled:
        return FilledButton(
          onPressed: null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.purpleDisabled,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.purpleDisabled,
            disabledForegroundColor: Colors.white,
            minimumSize: minSize,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            textStyle: textStyle,
            shape: shape,
          ),
          child: child,
        );
    }
  }
}
