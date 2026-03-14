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
          // Lighter shadow to improve repaint performance (Systematic Debugging)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: -1,
            offset: const Offset(0, 8),
          ),
        ],
        // Simple subtle border instead of a complex multi-stop gradient overlay
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.0,
        ),
        // A subtle static color tint allows the blur to handle the heavy lifting without extra gradient calculations
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: AdaptiveBlurView(
          // systemMaterial provides a solid, "Frosted Glass" look replacing the overly shiny/laggy ultra thin material
          blurStyle: BlurStyle.systemMaterial,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
