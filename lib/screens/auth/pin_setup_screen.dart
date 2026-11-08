import 'package:flutter/material.dart';

import '../../services/fast_login_service.dart';
import '../../theme/app_theme.dart';
import 'profile_setup_screen.dart';

/// Two-phase PIN creation screen.
///
/// Phase 1 — "Придумайте PIN": user enters a 4-digit PIN.
/// Phase 2 — "Повторите PIN": user confirms the same PIN.
///
/// On mismatch: cells shake, turn red, then reset to phase 1.
/// On match: calls [FastLoginService.setupPin], then invokes [onComplete]
/// (or pushes [ProfileSetupScreen] if [onComplete] is null).
///
/// [fastLoginService] and [onComplete] are injectable — used in widget tests.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({
    super.key,
    this.fastLoginService,
    this.onComplete,
  });

  /// Injected for tests. Defaults to [FastLoginService()] (production storage).
  final FastLoginService? fastLoginService;

  /// Called after PIN is successfully saved. If null, pushes [ProfileSetupScreen].
  final VoidCallback? onComplete;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen>
    with SingleTickerProviderStateMixin {
  late final FastLoginService _service;
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  String _pin1 = '';
  String _input = '';
  bool _isConfirming = false;
  bool _mismatch = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _service = widget.fastLoginService ?? FastLoginService();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear));

    _shakeCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _mismatch = false;
          _input = '';
          _pin1 = '';
          _isConfirming = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_input.length >= 4 || _loading || _mismatch) return;
    final next = _input + d;
    setState(() => _input = next);
    if (next.length == 4) {
      if (!_isConfirming) {
        _advanceToConfirm(next);
      } else {
        _checkMatch(next);
      }
    }
  }

  void _onBackspace() {
    if (_input.isEmpty || _loading || _mismatch) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _advanceToConfirm(String pin) async {
    // Brief pause so the user sees the 4th cell fill before the phase changes.
    await Future.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    setState(() {
      _pin1 = pin;
      _input = '';
      _isConfirming = true;
    });
  }

  Future<void> _checkMatch(String pin) async {
    if (pin == _pin1) {
      setState(() => _loading = true);
      try {
        await _service.setupPin(pin);
      } catch (_) {
        // ArgumentError is impossible here (4 digits verified by keypad),
        // but surface any unexpected storage error without crashing.
        if (mounted) setState(() => _loading = false);
        return;
      }
      if (!mounted) return;
      if (widget.onComplete != null) {
        widget.onComplete!();
      } else {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } else {
      setState(() => _mismatch = true);
      await _shakeCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _isConfirming ? 2 : 1;
    final title = _isConfirming ? 'Повторите PIN' : 'Придумайте PIN';
    final subtitle = _isConfirming
        ? 'Введите код ещё раз для подтверждения'
        : '4-значный код для быстрого входа';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Создание PIN'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scrollable header + cells — collapses gracefully on small screens.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.purpleSoft,
                            borderRadius: AppRadii.chipBorder,
                          ),
                          child: Text(
                            'Шаг $step из 2',
                            style: const TextStyle(
                              fontFamily: 'NunitoSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.navyMuted,
                      ),
                    ),
                    const SizedBox(height: 40),
                    AnimatedBuilder(
                      animation: _shakeAnim,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(_shakeAnim.value, 0),
                        child: child,
                      ),
                      child: _PinCellsRow(pin: _input, error: _mismatch),
                    ),
                    const SizedBox(height: 10),
                    if (_mismatch)
                      const Text(
                        'Коды не совпадают. Попробуйте снова.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 13,
                          color: AppColors.error,
                          height: 1.4,
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Keypad pinned at the bottom — always fully visible.
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: _PinKeypad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                disabled: _loading || _mismatch,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PIN cells row ─────────────────────────────────────────────────────────────

class _PinCellsRow extends StatelessWidget {
  const _PinCellsRow({required this.pin, this.error = false});

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
              ? Container(
                  width: 2,
                  height: 28,
                  color: AppColors.purple,
                )
              : null),
    );
  }
}

// ── Numeric keypad ────────────────────────────────────────────────────────────

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
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
              child: _BackspaceKey(
                onTap: disabled ? null : onBackspace,
              ),
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
