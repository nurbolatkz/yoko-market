import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final double? radius;
  final BorderRadius? borderRadius;

  static Widget rect({
    double? width,
    double height = 16,
    double radius = 8,
  }) =>
      Skeleton(width: width, height: height, radius: radius);

  static Widget circle({double size = 40}) => Skeleton(
        width: size,
        height: size,
        borderRadius: BorderRadius.circular(size / 2),
      );

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.purpleSoft,
            borderRadius: widget.borderRadius ??
                BorderRadius.circular(
                    widget.radius ?? widget.height / 2),
          ),
        ),
      ),
    );
  }
}
