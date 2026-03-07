import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated mesh gradient background with multiple floating, gradient-based
/// pastel red/orange blobs on a pure AMOLED black background.
///
/// PERFORMANCE:
///   - vsync adapts to 60/120/144Hz automatically
///   - repaint: animation — no widget rebuilds per frame
///   - Pre-allocated Paint (with dynamic shaders)
///   - RepaintBoundary isolates from card layer

class AnimatedMeshBackground extends StatefulWidget {
  const AnimatedMeshBackground({super.key});

  @override
  State<AnimatedMeshBackground> createState() => _AnimatedMeshBackgroundState();
}

class _AnimatedMeshBackgroundState extends State<AnimatedMeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // Increased action speed — 15 seconds instead of 25 seconds
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _MeshPainter(animation: _controller),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ─── BLOB DEFINITION ─────────────────────────────────────────────────────────

class _Blob {
  final Color baseColor;
  final double baseRadius; // As fraction of canvas
  final double radiusPulse;

  // Lissajous drift parameters
  final double freqX, freqY;
  final double phaseX, phaseY;

  // Center position (normalized 0..1)
  final double centerX, centerY;

  // Drift amplitude (fraction of canvas)
  final double driftX, driftY;

  final double opacity;

  const _Blob({
    required this.baseColor,
    required this.baseRadius,
    required this.radiusPulse,
    required this.freqX,
    required this.freqY,
    required this.phaseX,
    required this.phaseY,
    required this.centerX,
    required this.centerY,
    required this.driftX,
    required this.driftY,
    required this.opacity,
  });
}

// ─── THE PAINTER ─────────────────────────────────────────────────────────────

class _MeshPainter extends CustomPainter {
  final Animation<double> _animation;

  _MeshPainter({required Animation<double> animation})
    : _animation = animation,
      super(repaint: animation);

  // 10 Blobs using RGB pastel reds and oranges.
  // Base radii increased (0.20-0.35) for better overlap and blending.
  static const _blobs = [
    // 1. Soft Coral
    _Blob(
      baseColor: Color.fromARGB(255, 255, 127, 80),
      baseRadius: 0.28,
      radiusPulse: 0.05,
      freqX: 1.2,
      freqY: 0.8,
      phaseX: 0.0,
      phaseY: 1.5,
      centerX: 0.30,
      centerY: 0.25,
      driftX: 0.25,
      driftY: 0.25,
      opacity: 0.70,
    ),
    // 2. Salmon
    _Blob(
      baseColor: Color.fromARGB(255, 250, 128, 114),
      baseRadius: 0.30,
      radiusPulse: 0.06,
      freqX: 0.7,
      freqY: 1.3,
      phaseX: 2.1,
      phaseY: 0.5,
      centerX: 0.70,
      centerY: 0.35,
      driftX: 0.30,
      driftY: 0.20,
      opacity: 0.75,
    ),
    // 3. Peach Puff
    _Blob(
      baseColor: Color.fromARGB(255, 255, 218, 185),
      baseRadius: 0.22,
      radiusPulse: 0.04,
      freqX: 0.9,
      freqY: 1.1,
      phaseX: 1.0,
      phaseY: 3.0,
      centerX: 0.45,
      centerY: 0.65,
      driftX: 0.35,
      driftY: 0.25,
      opacity: 0.65,
    ),
    // 4. Light Salmon
    _Blob(
      baseColor: Color.fromARGB(255, 255, 160, 122),
      baseRadius: 0.25,
      radiusPulse: 0.05,
      freqX: 1.4,
      freqY: 0.6,
      phaseX: 3.5,
      phaseY: 1.2,
      centerX: 0.80,
      centerY: 0.80,
      driftX: 0.20,
      driftY: 0.30,
      opacity: 0.80,
    ),
    // 5. Pale Apricot
    _Blob(
      baseColor: Color.fromARGB(255, 255, 200, 150),
      baseRadius: 0.20,
      radiusPulse: 0.03,
      freqX: 1.1,
      freqY: 1.4,
      phaseX: 0.5,
      phaseY: 2.2,
      centerX: 0.25,
      centerY: 0.75,
      driftX: 0.25,
      driftY: 0.22,
      opacity: 0.70,
    ),
    // 6. Deep Pastel Orange
    _Blob(
      baseColor: Color.fromARGB(255, 255, 140, 50),
      baseRadius: 0.26,
      radiusPulse: 0.05,
      freqX: 0.6,
      freqY: 0.9,
      phaseX: 4.0,
      phaseY: 0.8,
      centerX: 0.55,
      centerY: 0.15,
      driftX: 0.30,
      driftY: 0.15,
      opacity: 0.65,
    ),
    // 7. Muted Terracotta
    _Blob(
      baseColor: Color.fromARGB(255, 226, 114, 91),
      baseRadius: 0.35,
      radiusPulse: 0.07,
      freqX: 0.8,
      freqY: 1.2,
      phaseX: 1.5,
      phaseY: 2.8,
      centerX: 0.15,
      centerY: 0.45,
      driftX: 0.18,
      driftY: 0.28,
      opacity: 0.60,
    ),
    // 8. Soft Rose
    _Blob(
      baseColor: Color.fromARGB(255, 255, 153, 153),
      baseRadius: 0.24,
      radiusPulse: 0.04,
      freqX: 1.5,
      freqY: 0.7,
      phaseX: 2.5,
      phaseY: 1.1,
      centerX: 0.85,
      centerY: 0.50,
      driftX: 0.20,
      driftY: 0.35,
      opacity: 0.70,
    ),
    // 9. Light Orange
    _Blob(
      baseColor: Color.fromARGB(255, 255, 180, 100),
      baseRadius: 0.28,
      radiusPulse: 0.06,
      freqX: 0.5,
      freqY: 1.5,
      phaseX: 0.8,
      phaseY: 3.5,
      centerX: 0.50,
      centerY: 0.50,
      driftX: 0.35,
      driftY: 0.30,
      opacity: 0.65,
    ),
    // 10. Warm Sand
    _Blob(
      baseColor: Color.fromARGB(255, 244, 164, 96),
      baseRadius: 0.22,
      radiusPulse: 0.05,
      freqX: 1.3,
      freqY: 1.1,
      phaseX: 3.2,
      phaseY: 0.4,
      centerX: 0.20,
      centerY: 0.10,
      driftX: 0.25,
      driftY: 0.25,
      opacity: 0.75,
    ),
  ];

  final Paint _blobPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    // ── 1. AMOLED PITCH BLACK BASE ───────────────────────────────────────
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);

    final t = _animation.value;
    final angle = t * 2 * math.pi;
    final minDim = math.min(size.width, size.height);

    // ── 2. Draw Gradient Blobs ───────────────────────────────────────────
    for (final blob in _blobs) {
      _paintBlob(canvas, size, minDim, blob, angle);
    }
  }

  void _paintBlob(
    Canvas canvas,
    Size size,
    double minDim,
    _Blob blob,
    double angle,
  ) {
    // Lissajous drift -> High amplitude for lots of crossing action
    final dx = math.sin(angle * blob.freqX + blob.phaseX) * blob.driftX;
    final dy = math.sin(angle * blob.freqY + blob.phaseY) * blob.driftY;

    final x = (blob.centerX + dx) * size.width;
    final y = (blob.centerY + dy) * size.height;
    final center = Offset(x, y);

    // Faster pulsating action
    final pulse = (math.sin(angle * 4.0 + blob.phaseX) + 1) / 2;
    final radius = (blob.baseRadius + blob.radiusPulse * pulse) * minDim;

    // The gradient fades from the pastel base color to transparent black
    final gradient = RadialGradient(
      colors: [
        blob.baseColor.withValues(alpha: blob.opacity),
        blob.baseColor.withValues(alpha: blob.opacity * 0.4),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final rect = Rect.fromCircle(center: center, radius: radius);

    _blobPaint.shader = gradient.createShader(rect);
    // Add an explicit MaskFilter blur to completely eliminate hard edges
    // and make them melt together like lava lamps.
    _blobPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    // Additive blending for intersections
    _blobPaint.blendMode = BlendMode.screen;

    canvas.drawRect(rect, _blobPaint);
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) => false;
}
