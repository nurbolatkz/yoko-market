import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Splash animation shown on every cold start. `MainScreen` sits underneath
/// in the widget tree so data loading starts in parallel — the animation never
/// waits for the API. Tap anywhere to skip.
///
/// Motion timeline (one controller, [_total] long):
///   0.00–0.30  halo grows, "Y" badge pops in with a spring + tilt
///   0.18–0.64  «Сәлем!» is drawn stroke by stroke with a glowing pen tip
///   0.60–0.80  "Yo Market" wordmark slides up and fades in
///   0.66–0.82  yellow swoosh under the wordmark
///   0.86–1.00  everything zooms through and fades, revealing the app
///
/// Haptics follow the motion: a light tap when the badge lands, a tick per
/// letter while the pen writes, and a medium tap when the wordmark settles.
class WelcomeOverlay extends StatefulWidget {
  const WelcomeOverlay({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<WelcomeOverlay> createState() => _WelcomeOverlayState();
}

class _WelcomeOverlayState extends State<WelcomeOverlay>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2800);

  // Phase intervals on the 0→1 master timeline.
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
    // Safety: dismiss even if the ticker stalls (low-end devices, emulators).
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
    // Jump straight to the exit phase and play it a little faster.
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
            // Material (not ColoredBox) gives Text a proper DefaultTextStyle;
            // SizedBox.expand makes the overlay cover the screen even though
            // the parent Stack hands it loose constraints.
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
                              child: const _Badge(),
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
                              child: const _Wordmark(),
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

/// Yellow circle with a purple "Y" — the app's header logo mark, enlarged.
class _Badge extends StatelessWidget {
  const _Badge();

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

class _Wordmark extends StatelessWidget {
  const _Wordmark();

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

/// A short hand-drawn underline that sweeps left → right.
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

/// Draws the word «Сәлем!» stroke by stroke using PathMetrics.
///
/// Paths are defined in a 272 × 72 viewBox. Each [Path.moveTo] starts a new
/// contour (stroke); [progress] drives the total drawn length from 0 → 1
/// across all contours in order, giving a pen-on-paper effect. While drawing,
/// a glowing pen tip rides on the end of the stroke.
class _SalemPainter extends CustomPainter {
  const _SalemPainter({
    required this.progress,
    required this.color,
    required this.tipColor,
  });

  final double progress;
  final Color color;
  final Color tipColor;

  /// Number of contours (strokes) per glyph, in drawing order:
  /// С, ə, л, е, м, !
  static const _contoursPerLetter = [1, 2, 1, 2, 1, 2];

  /// Fraction of the total stroke length (0–1) at which each letter begins.
  /// Used to fire one haptic tick per letter as the pen reaches it.
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
    if (size.isEmpty || progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
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

    // Pen tip: fades out over the last 8 % of the drawing.
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

  /// All coordinates in a 272 × 72 viewBox.
  /// Cap-height ≈ y=8, baseline ≈ y=64.
  static Path _buildPath(Size size) {
    final sx = size.width / 272.0;
    final sy = size.height / 72.0;

    double x(double v) => v * sx;
    double y(double v) => v * sy;

    final p = Path();

    // ── С ── (x: 2–40) open-right arc
    p.moveTo(x(36), y(9));
    p.cubicTo(x(14), y(3), x(2), y(18), x(2), y(36));
    p.cubicTo(x(2), y(54), x(14), y(68), x(36), y(64));

    // ── ə ── (x: 48–92) open-right oval + horizontal midbar
    p.moveTo(x(88), y(22));
    p.cubicTo(x(88), y(9), x(54), y(9), x(54), y(36));
    p.cubicTo(x(54), y(63), x(88), y(63), x(88), y(51));
    p.moveTo(x(54), y(36));
    p.lineTo(x(93), y(36));

    // ── л ── (x: 101–140) single flowing stroke
    p.moveTo(x(103), y(64));
    p.cubicTo(x(103), y(48), x(108), y(22), x(119), y(9));
    p.cubicTo(x(128), y(9), x(140), y(15), x(140), y(64));

    // ── е ── (x: 148–190) crossbar + upper arc, then lower arc
    p.moveTo(x(186), y(36));
    p.lineTo(x(150), y(36));
    p.cubicTo(x(147), y(36), x(149), y(9), x(168), y(9));
    p.cubicTo(x(187), y(9), x(193), y(22), x(186), y(36));
    p.moveTo(x(150), y(36));
    p.cubicTo(x(147), y(58), x(160), y(68), x(173), y(68));
    p.cubicTo(x(186), y(68), x(196), y(57), x(189), y(48));

    // ── м ── (x: 198–256) single M stroke
    p.moveTo(x(198), y(64));
    p.lineTo(x(198), y(9));
    p.cubicTo(x(198), y(9), x(213), y(51), x(227), y(51));
    p.cubicTo(x(241), y(51), x(256), y(9), x(256), y(9));
    p.lineTo(x(256), y(64));

    // ── ! ── vertical bar
    p.moveTo(x(265), y(9));
    p.lineTo(x(265), y(52));
    // dot (tiny oval)
    p.moveTo(x(262), y(62));
    p.cubicTo(x(262), y(57), x(268), y(57), x(268), y(62));
    p.cubicTo(x(268), y(67), x(262), y(67), x(262), y(62));

    return p;
  }

  @override
  bool shouldRepaint(_SalemPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.tipColor != tipColor;
}
