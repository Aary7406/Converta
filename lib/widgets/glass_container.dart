import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

/// Clear Liquid Glass container using the adaptive_platform_ui package.
///
/// On iOS 26+: Uses native UIVisualEffectView (true liquid glass)
/// On Windows/Android/Other: Falls back to BackdropFilter with a liquid glass
///   gradient that closely mimics the real iOS 26 Liquid Glass effect.
///
/// The AdaptiveBlurView handles all platform detection automatically.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 35,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 50,
            spreadRadius: -1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: AdaptiveBlurView(
        // systemUltraThinMaterial = clearest, least frosted glass
        blurStyle: BlurStyle.systemUltraThinMaterial,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
