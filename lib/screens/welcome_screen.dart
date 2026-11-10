import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/ui/app_button.dart';
import 'auth/phone_screen.dart';

// ── Intro animation (first launch only) ──────────────────────────────────────

/// Splash animation shown once on first install. [onDone] is called when the
/// animation finishes or the user taps to skip.
///
/// Motion timeline (single controller, 2.8 s):
///   0.00–0.30  halo grows, "Y" badge pops in with spring + tilt
///   0.18–0.64  «Сәлем!» drawn stroke-by-stroke with a glowing pen tip
///   0.60–0.80  "Yo Market" wordmark slides up and fades in
///   0.66–0.82  yellow swoosh under the wordmark
///   0.86–1.00  everything zooms through and fades, revealing the app
///
/// Haptics: light tap on badge land, tick per letter, medium on wordmark.
class WelcomeOverlay extends StatefulWidget {
  const WelcomeOverlay({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<WelcomeOverlay> createState() => _WelcomeOverlayState();
}

class _WelcomeOverlayState extends State<WelcomeOverlay>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2800);

  static const _halo = Interval(0.00, 0.34, curve: Curves.easeOutCubic);
  static const _badge = Interval(0.02, 0.30, curve: Curves.elasticOut);
  static const _badgeTilt = Interval(0.02, 0.26, curve: Curves.easeOutBack);
  static const _draw = Interval(0.18, 0.64, curve: Curves.easeInOut);
  static const _wordmark = Interval(0.60, 0.80, curve: Curves.easeOutCubic);
  static const _swoosh = Interval(0.66, 0.82, curve: Curves.easeInOutCubic);
  static const _exit = Interval(0.86, 1.00, curve: Curves.easeInCubic);

  static const _badgeHapticAt = 0.06;
  static const _wordmarkHapticAt = 0.66;

  late final AnimationController _ctrl;
  late final List<double> _letterStarts = _SalemPainter.letterStartFractions();

  bool _started = false;
  bool _finished = false;
  bool _badgeBuzzed = false;
  bool _wordmarkBuzzed = false;
  int _lettersBuzzed = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _total)
      ..addListener(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      Future.microtask(_finish);
    } else {
      _play();
    }
  }

  Future<void> _play() async {
    Future.delayed(_total + const Duration(seconds: 2), _finish);
    try {
      await _ctrl.forward().orCancel;
    } on TickerCanceled {
      return;
    }
    _finish();
  }

  void _skip() {
    if (_finished || _ctrl.value >= _exit.begin) return;
    _ctrl.value = _exit.begin;
    _ctrl.animateTo(
      1.0,
      duration: _total * (1 - _exit.begin) * 0.7,
    ).whenComplete(_finish);
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onDone();
  }

  void _onTick() {
    final t = _ctrl.value;
    if (!_badgeBuzzed && t >= _badgeHapticAt) {
      _badgeBuzzed = true;
      HapticFeedback.lightImpact();
    }
    final drawn = _draw.transform(t);
    while (_lettersBuzzed < _letterStarts.length &&
        drawn > 0 &&
        drawn >= _letterStarts[_lettersBuzzed]) {
      _lettersBuzzed++;
      HapticFeedback.selectionClick();
    }
    if (!_wordmarkBuzzed && t >= _wordmarkHapticAt) {
      _wordmarkBuzzed = true;
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          final exit = _exit.transform(t);
          final halo = _halo.transform(t);
          final badge = _badge.transform(t);
          final tilt = 1 - _badgeTilt.transform(t);
          final draw = _draw.transform(t);
          final word = _wordmark.transform(t);
          final swoosh = _swoosh.transform(t);

          return Opacity(
            opacity: 1 - exit,
            child: SizedBox.expand(
              child: Material(
                color: AppColors.background,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Soft purple halo behind the content.
                    Transform.scale(
                      scale: 0.5 + 0.7 * halo + 0.6 * exit,
                      child: Opacity(
                        opacity: halo,
                        child: Container(
                          width: 360,
                          height: 360,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.purpleSoft,
                                AppColors.background,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: 1 + 0.12 * exit,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.rotate(
                            angle: -0.35 * tilt,
                            child: Transform.scale(
                              scale: badge,
                              child: const _YBadge(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.x2l),
                          CustomPaint(
                            size: const Size(272, 72),
                            painter: _SalemPainter(
                              progress: draw,
                              color: AppColors.purple,
                              tipColor: AppColors.yellow,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Opacity(
                            opacity: word,
                            child: Transform.translate(
                              offset: Offset(0, 18 * (1 - word)),
                              child: const _AnimWordmark(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          CustomPaint(
                            size: const Size(140, 14),
                            painter: _SwooshPainter(
                              progress: swoosh,
                              color: AppColors.yellow,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _YBadge extends StatelessWidget {
  const _YBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.yellow,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Text(
        'Y',
        style: TextStyle(
          color: AppColors.purple,
          fontSize: 42,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _AnimWordmark extends StatelessWidget {
  const _AnimWordmark();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(letterSpacing: -0.5),
        children: [
          TextSpan(
            text: 'Y',
            style: TextStyle(
              color: AppColors.purple,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(
            text: 'o',
            style: TextStyle(
              color: AppColors.yellow,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(
            text: ' Market',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwooshPainter extends CustomPainter {
  const _SwooshPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(4, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.5,
        -size.height * 0.1,
        size.width - 4,
        size.height * 0.55,
      );
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_SwooshPainter old) =>
      old.progress != progress || old.color != color;
}

/// Draws «Сәлем!» stroke by stroke. [progress] drives the total drawn length
/// 0→1 across all contours, giving a pen-on-paper effect. A glowing tip rides
/// on the leading edge while drawing.
class _SalemPainter extends CustomPainter {
  const _SalemPainter({
    required this.progress,
    required this.color,
    required this.tipColor,
  });

  final double progress;
  final Color color;
  final Color tipColor;

  static const _contoursPerLetter = [1, 2, 1, 2, 1, 2];

  static List<double> letterStartFractions() {
    final metrics =
        _buildPath(const Size(272, 72)).computeMetrics().toList();
    final total = metrics.fold<double>(0, (s, m) => s + m.length);
    final starts = <double>[];
    var contour = 0;
    var len = 0.0;
    for (final count in _contoursPerLetter) {
      starts.add(len / total);
      for (var i = 0; i < count && contour < metrics.length; i++) {
        len += metrics[contour++].length;
      }
    }
    return starts;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final metrics = _buildPath(size).computeMetrics().toList();
    final totalLen = metrics.fold<double>(0, (s, m) => s + m.length);
    final target = totalLen * progress;

    var drawn = 0.0;
    Offset? tip;
    for (final m in metrics) {
      if (drawn >= target) break;
      final end = math.min(target - drawn, m.length);
      canvas.drawPath(m.extractPath(0, end), paint);
      tip = m.getTangentForOffset(end)?.position;
      drawn += m.length;
    }

    if (tip != null && progress < 1) {
      final fade = ((1 - progress) / 0.08).clamp(0.0, 1.0);
      canvas.drawCircle(
        tip,
        9,
        Paint()
          ..color = tipColor.withValues(alpha: 0.45 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        tip,
        4,
        Paint()..color = tipColor.withValues(alpha: fade),
      );
    }
  }

  static Path _buildPath(Size size) {
    final sx = size.width / 272.0;
    final sy = size.height / 72.0;

    double x(double v) => v * sx;
    double y(double v) => v * sy;

    final p = Path();

    // С
    p.moveTo(x(38), y(20));
    p.cubicTo(x(28), y(16), x(14), y(20), x(12), y(36));
    p.cubicTo(x(10), y(52), x(22), y(60), x(36), y(56));

    // ə (two strokes)
    p.moveTo(x(44), y(36));
    p.cubicTo(x(44), y(22), x(66), y(18), x(68), y(36));
    p.cubicTo(x(70), y(52), x(56), y(60), x(44), y(54));
    p.moveTo(x(44), y(36));
    p.lineTo(x(70), y(36));

    // л
    p.moveTo(x(74), y(56));
    p.lineTo(x(84), y(20));
    p.lineTo(x(96), y(56));

    // е (two strokes)
    p.moveTo(x(102), y(36));
    p.lineTo(x(126), y(36));
    p.moveTo(x(126), y(36));
    p.cubicTo(x(130), y(22), x(116), y(14), x(104), y(20));
    p.cubicTo(x(94), y(28), x(96), y(50), x(108), y(56));
    p.cubicTo(x(118), y(60), x(128), y(54), x(130), y(48));

    // м
    p.moveTo(x(136), y(56));
    p.lineTo(x(136), y(20));
    p.lineTo(x(152), y(44));
    p.lineTo(x(168), y(20));
    p.lineTo(x(168), y(56));

    // ! (two strokes: stem + dot)
    p.moveTo(x(178), y(18));
    p.cubicTo(x(178), y(30), x(176), y(42), x(176), y(50));
    p.moveTo(x(177), y(58));
    p.arcTo(
      Rect.fromCenter(center: Offset(x(177), y(60)), width: x(4), height: y(4)),
      0,
      math.pi * 2,
      false,
    );

    return p;
  }

  @override
  bool shouldRepaint(_SalemPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.tipColor != tipColor;
}

// ── Landing screen (shown after animation on first launch) ───────────────────

/// Landing screen with hero image and two action buttons.
/// [onDone] is called when the user starts as a guest ("Начать покупки").
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.purpleSoft,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Hero image — aligned to top so logo/faces are always visible.
          // BoxFit.cover crops the lavender bottom on small screens, which is fine.
          Semantics(
            label: 'YokoMarket — всё необходимое для семьи в одном месте. '
                'Мама с дочкой и корзина с товарами для малышей.',
            child: Image.asset(
              'assets/images/welcome/welcome_hero.webp',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),

          // Gradient fade from transparent to lavender — creates natural shelf
          // for buttons without covering faces or product photo.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.purpleSoft.withValues(alpha: 0.0),
                    AppColors.purpleSoft.withValues(alpha: 0.92),
                    AppColors.purpleSoft,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // Buttons anchored to safe bottom edge.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      label: 'Начать покупки',
                      onPressed: onDone,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Войти в аккаунт',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => _openLogin(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openLogin(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PhoneScreen(
          // onSuccess fires after OTP + profile setup complete.
          // Calling onDone dismisses this overlay so MainScreen is revealed.
          onSuccess: onDone,
        ),
      ),
    );
  }
}
