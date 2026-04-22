import 'dart:ui';
import 'package:flutter/material.dart';

/// Glassmorphism container — pure Flutter BackdropFilter.
///
/// Uses a single ImageFilter.blur pass clipped to the border radius.
/// No external packages, no platform DLLs, works on all Windows versions.
///
/// PERF:
///   - blur sigma capped at 14 (visually equivalent to 20+ but ~40% cheaper on GPU)
///   - RepaintBoundary should wrap the parent, not each card individually
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
