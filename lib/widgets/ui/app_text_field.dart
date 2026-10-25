import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.textInputAction,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.suffix,
    this.prefix,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final int? maxLines;
  final Widget? suffix;
  final Widget? prefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.navyMuted,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.inputBorder,
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            inputFormatters: inputFormatters,
            textInputAction: textInputAction,
            focusNode: focusNode,
            autofocus: autofocus,
            enabled: enabled,
            maxLines: maxLines,
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.navy,
            ),
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: suffix,
              prefixIcon: prefix,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        if (errorText != null && errorText!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.error,
            ),
          ),
        ],
      ],
    );
  }
}

class PhoneTextField extends StatefulWidget {
  const PhoneTextField({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.autofocus = false,
    this.textInputAction,
    this.focusNode,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  @override
  State<PhoneTextField> createState() => _PhoneTextFieldState();
}

class _PhoneTextFieldState extends State<PhoneTextField> {
  late final TextEditingController _controller;
  bool _isOwned = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _controller = TextEditingController();
      _isOwned = true;
    } else {
      _controller = widget.controller!;
    }
  }

  @override
  void dispose() {
    if (_isOwned) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: _controller,
      label: 'Номер телефона',
      hint: '+7 (___) ___-__-__',
      keyboardType: TextInputType.phone,
      errorText: widget.errorText,
      autofocus: widget.autofocus,
      textInputAction: widget.textInputAction,
      focusNode: widget.focusNode,
      onSubmitted: widget.onSubmitted,
      inputFormatters: [_PhoneMaskFormatter()],
      onChanged: (v) {
        final digits = v.replaceAll(RegExp(r'\D'), '');
        widget.onChanged?.call(digits.startsWith('7') ? '+$digits' : digits);
      },
    );
  }
}

class _PhoneMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('8')) digits = '7${digits.substring(1)}';
    if (digits.isNotEmpty && !digits.startsWith('7')) {
      digits = '7$digits';
    }
    if (digits.length > 11) digits = digits.substring(0, 11);

    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 0) buf.write('+');
      if (i == 1) buf.write(' (');
      if (i == 4) buf.write(') ');
      if (i == 7) buf.write('-');
      if (i == 9) buf.write('-');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
