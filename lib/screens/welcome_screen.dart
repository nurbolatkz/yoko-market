import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shown once after install. `MainScreen` is in the widget tree underneath so
/// data loading starts in parallel — the animation never waits for the API.
class WelcomeOverlay extends StatefulWidget {
  const WelcomeOverlay({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<WelcomeOverlay> createState() => _WelcomeOverlayState();
}

class _WelcomeOverlayState extends State<WelcomeOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _drawCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _exitCtrl;

  bool _started = false;

  @override
  void initState() {
    super.initState();
    _drawCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      final reducedMotion = MediaQuery.of(context).disableAnimations;
      if (reducedMotion) {
        _drawCtrl.value = 1.0;
        _textCtrl.value = 1.0;
        Future.microtask(() { if (mounted) widget.onDone(); });
      } else {
        _play();
      }
    }
  }

  Future<void> _play() async {
    // Safety: dismiss after 5 s even if animation stalls (BlueStacks, low-end devices)
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) widget.onDone();
    });

    try {
      await _drawCtrl.forward();
      _textCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 400));
      await _exitCtrl.forward();
    } catch (_) {
      // TickerCanceled or similar — widget is being disposed, skip onDone
      return;
    }
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _drawCtrl.dispose();
    _textCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitCtrl,
      builder: (context, child) => Opacity(
        opacity: 1.0 - _exitCtrl.value,
        child: child,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drawn "Сәлем!" via vector path strokes
              AnimatedBuilder(
                animation: _drawCtrl,
                builder: (context, _) => CustomPaint(
                  size: const Size(272, 72),
                  painter: _SalemPainter(
                    progress: Curves.easeInOut.transform(_drawCtrl.value),
                    color: AppColors.purple,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // "Yoko Market" logo fades in after drawing is complete
              AnimatedBuilder(
                animation: _textCtrl,
                builder: (context, child) => Opacity(
                  opacity: Curves.easeOut.transform(_textCtrl.value),
                  child: child,
                ),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      letterSpacing: -0.5,
                    ),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the word «Сәлем!» stroke by stroke using PathMetrics.
///
/// Paths are defined in a 272 × 72 viewBox. Each [moveTo] starts a new
/// contour (stroke); [progress] drives the total drawn length from 0 → 1
/// across all contours in order, giving a genuine pen-on-paper effect.
class _SalemPainter extends CustomPainter {
  const _SalemPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = _buildPath(size);
    final metrics = path.computeMetrics().toList();

    final totalLen = metrics.fold<double>(0, (s, m) => s + m.length);
    final target = totalLen * progress;

    var drawn = 0.0;
    for (final m in metrics) {
      if (drawn >= target) break;
      final end = math.min(target - drawn, m.length);
      canvas.drawPath(m.extractPath(0, end), paint);
      drawn += m.length;
    }
  }

  /// All coordinates in a 272 × 72 viewBox.
  /// Cap-height ≈ y=8, baseline ≈ y=64.
  Path _buildPath(Size size) {
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
      old.progress != progress || old.color != color;
}
