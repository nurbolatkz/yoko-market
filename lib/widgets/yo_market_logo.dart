import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// «YO market» wordmark: «YO» in the brand gradient, «market» in ink.
/// Drawn in code (no image) so it stays sharp at any size.
class YoMarketLogo extends StatelessWidget {
  const YoMarketLogo({super.key, this.height = 36});

  /// Cap height of «YO»; «market» scales with it.
  final double height;

  @override
  Widget build(BuildContext context) {
    final size = height * 1.25;
    return Semantics(
      label: 'YO market',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: AppGradients.logo.createShader,
            child: Text(
              'YO',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w800,
                letterSpacing: -size * 0.06,
                height: 1,
                color: AppColors.surface,
              ),
            ),
          ),
          Text(
            'market',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: size * 0.82,
              fontWeight: FontWeight.w800,
              letterSpacing: -size * 0.03,
              height: 1,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
