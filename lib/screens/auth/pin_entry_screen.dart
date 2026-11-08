import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/fast_login_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui/pin_widgets.dart';

/// PIN entry screen shown on cold start when fast login is enabled.
///
/// On open: checks for available biometrics and auto-triggers the platform
/// challenge. The fingerprint button lets the user re-trigger it manually.
///
/// Calls [FastLoginService.verifyPin] on each 4-digit attempt.
/// - Correct → invokes [onSuccess] (or pops if null).
/// - Wrong ×1 → cells shake, reset.
/// - Wrong ×2–3 → "Осталось попыток: N" warning shown.
/// - Wrong ×4–5 → locked; countdown timer shown; biometric button hidden.
/// - Wrong ×6 → [FastLoginWipedError]: invokes [onForgotPin].
///
/// [fastLoginService] and callbacks are injectable for widget tests.
class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({
    super.key,
    this.fastLoginService,
    this.onSuccess,
    this.onForgotPin,
  });

  /// Injected for tests. Defaults to [FastLoginService()] (production).
  final FastLoginService? fastLoginService;

  /// Called after the correct PIN or a successful biometric challenge.
  /// If null, pops the current route (used when pushed over MainScreen).
  final VoidCallback? onSuccess;

  /// Called when "Забыли PIN?" is tapped or when the service wipes data.
  final VoidCallback? onForgotPin;

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen>
    with SingleTickerProviderStateMixin {
  late final FastLoginService _service;
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  String _input = '';
  bool _loading = false;
  bool _error = false;
  bool _wiped = false;
  bool _initDone = false;

  int _wrongAttempts = 0;
  int _lockedUntilMs = 0;
  Timer? _lockTimer;

  bool _biometricAvailable = false;
  bool _biometricLoading = false;

  bool get _isLocked => _lockedUntilMs > DateTime.now().millisecondsSinceEpoch;

  String get _lockCountdown {
    final remaining = _lockedUntilMs - DateTime.now().millisecondsSinceEpoch;
    if (remaining <= 0) return '';
    final totalSec = (remaining / 1000).ceil();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

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
        setState(() => _error = false);
      }
    });

    _initScreen();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _initScreen() async {
    final remaining = await _service.lockoutRemainingMs();
    final canBio = await _service.canUseBiometrics();
    if (!mounted) return;
    setState(() {
      _initDone = true;
      _biometricAvailable = canBio;
      if (remaining > 0) {
        _lockedUntilMs = DateTime.now().millisecondsSinceEpoch + remaining;
        _startLockTimer();
      }
    });
    // Auto-trigger biometric challenge when the screen opens.
    if (canBio && !_isLocked && !_wiped) {
      await _tryBiometric();
    }
  }

  void _onDigit(String d) {
    if (_input.length >= 4 || _loading || _isLocked || _error || _wiped ||
        !_initDone || _biometricLoading) {
      return;
    }
    final next = _input + d;
    setState(() => _input = next);
    if (next.length == 4) _verify(next);
  }

  void _onBackspace() {
    if (_input.isEmpty || _loading || _isLocked || _error || _wiped) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _verify(String pin) async {
    setState(() => _loading = true);
    try {
      final ok = await _service.verifyPin(pin);
      if (!mounted) return;
      if (ok) {
        _succeed();
        return;
      }
      _wrongAttempts++;
      setState(() { _error = true; _input = ''; });
      await _shakeCtrl.forward(from: 0);
    } on FastLoginLockedError catch (e) {
      if (!mounted) return;
      setState(() { _lockedUntilMs = e.lockedUntilMs; _input = ''; });
      _startLockTimer();
    } on FastLoginWipedError {
      if (!mounted) return;
      setState(() { _wiped = true; _input = ''; });
      widget.onForgotPin?.call();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _tryBiometric() async {
    if (_biometricLoading || _loading || _isLocked || _wiped || !_initDone) return;
    setState(() => _biometricLoading = true);
    try {
      final ok = await _service.unlockWithBiometrics();
      if (!mounted) return;
      if (ok) _succeed();
      // false = user cancelled → silent fallback; PIN input stays active.
    } finally {
      if (mounted) setState(() => _biometricLoading = false);
    }
  }

  void _succeed() {
    if (widget.onSuccess != null) {
      widget.onSuccess!();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _lockTimer?.cancel();
        return;
      }
      if (!_isLocked) {
        setState(() => _lockedUntilMs = 0);
        _lockTimer?.cancel();
        _lockTimer = null;
      } else {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keypadDisabled = _loading || _isLocked || _wiped || !_initDone || _biometricLoading;
    final showAttemptWarning = !_isLocked && !_wiped && _wrongAttempts >= 2;
    final attemptsUntilLock = (4 - _wrongAttempts).clamp(0, 4);
    final showBiometric = _biometricAvailable && !_isLocked && !_wiped;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Введите PIN',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Введите PIN для входа в приложение',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.navyMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    AnimatedBuilder(
                      animation: _shakeAnim,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(_shakeAnim.value, 0),
                        child: child,
                      ),
                      child: PinCellsRow(pin: _input, error: _error),
                    ),
                    const SizedBox(height: 10),
                    if (_wiped)
                      const Text(
                        'Слишком много попыток.\nВойдите через SMS для сброса.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 13,
                          color: AppColors.error,
                          height: 1.4,
                        ),
                      )
                    else if (_isLocked)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_clock_outlined,
                              size: 15, color: AppColors.error),
                          const SizedBox(width: 6),
                          Text(
                            'Попробуйте через $_lockCountdown',
                            style: const TextStyle(
                              fontFamily: 'NunitoSans',
                              fontSize: 13,
                              color: AppColors.error,
                              height: 1.4,
                            ),
                          ),
                        ],
                      )
                    else if (showAttemptWarning)
                      Text(
                        'Осталось попыток: $attemptsUntilLock',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 13,
                          color: AppColors.navyMuted,
                          height: 1.4,
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PinKeypad(
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                    disabled: keypadDisabled,
                  ),
                  if (showBiometric) ...[
                    const SizedBox(height: 12),
                    _BiometricButton(
                      loading: _biometricLoading,
                      onTap: _biometricLoading ? null : _tryBiometric,
                    ),
                  ],
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _wiped ? null : () => widget.onForgotPin?.call(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.navyMuted,
                      textStyle: const TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: const Text('Забыли PIN?'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BiometricButton extends StatelessWidget {
  const _BiometricButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.purple,
                ),
              )
            : const Icon(
                Icons.fingerprint_rounded,
                size: 48,
                color: AppColors.purple,
              ),
      ),
    );
  }
}
