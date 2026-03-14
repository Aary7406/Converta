import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Optimized Matrix Digital Rain.
///
/// PERFORMANCE: Glyph Atlas approach.
/// All 64 chars are pre-rendered into a single ui.Image once.
/// Each frame uses canvas.drawImageRect() — GPU copy with zero CPU text layout.
/// Animation uses a raw Ticker + 60fps delta-time gate to avoid burning
/// 120/144Hz on text rendering. RepaintBoundary isolates from UI tree.

class MatrixRainBackground extends StatefulWidget {
  const MatrixRainBackground({super.key});

  @override
  State<MatrixRainBackground> createState() => _MatrixRainBackgroundState();
}

class _MatrixRainBackgroundState extends State<MatrixRainBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTime = Duration.zero;

  ui.Image? _atlas;
  List<Rect>? _glyphRects;

  List<_DropColumn>? _columns;
  double _accumulator = 0;
  final _repaint = _RepaintSignal();
  final math.Random _rng = math.Random();

  // Cap to 60fps regardless of display refresh rate
  static const double _frameBudget = 1000.0 / 60.0;

  static const double _glyphW = 14.0;
  static const double _glyphH = 18.0;
  static const String chars =
      '日ﾊﾐﾋｰｳｼﾅﾓﾆｻﾜﾂｵﾘｱﾎﾃﾏｹﾒｴｶｷﾑﾕﾗｾﾈｽﾀﾇﾍ1234567890ZXCVBAQWE';
  static const Color green = Color(0xFF00FF41);
  static const Color white = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _buildAtlas();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _atlas?.dispose();
    _repaint.dispose();
    super.dispose();
  }

  /// Pre-render all characters into a single atlas image (one-time cost).
  Future<void> _buildAtlas() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const cols = 8;
    final rows = (chars.length / cols).ceil();
    final glyphRects = <Rect>[];

    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < chars.length; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final x = col * _glyphW;
      final y = row * _glyphH;

      tp.text = TextSpan(
        text: chars[i],
        style: const TextStyle(
          color: green,
          fontSize: 14,
          fontFamily: 'Consolas',
          height: 1.2,
        ),
      );
      tp.layout(maxWidth: _glyphW + 4);
      tp.paint(canvas, Offset(x, y));
      glyphRects.add(Rect.fromLTWH(x, y, _glyphW, _glyphH));
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (cols * _glyphW).ceil(),
      (rows * _glyphH).ceil(),
    );

    if (mounted) {
      setState(() {
        _atlas = image;
        _glyphRects = List.unmodifiable(glyphRects);
      });
    }
  }

  void _onTick(Duration elapsed) {
    if (_atlas == null || _columns == null) return;
    final delta = (elapsed - _lastTime).inMilliseconds.toDouble();
    _lastTime = elapsed;
    _accumulator += delta;

    if (_accumulator >= _frameBudget) {
      _accumulator -= _frameBudget;
      _stepSim();
      _repaint.ping();
    }
  }

  void _initColumns(double w, double h) {
    final count = (w / _glyphW).floor() + 1;
    _columns = List.generate(count, (i) => _makeCol(i * _glyphW, h));
  }

  _DropColumn _makeCol(double x, double screenH) {
    final len = _rng.nextInt(22) + 7;
    return _DropColumn(
      x: x,
      y: _rng.nextDouble() * -screenH * 1.5,
      speed: _rng.nextDouble() * 6 + 4,
      length: len,
      chars: List.generate(len, (_) => _rng.nextInt(chars.length)),
      screenH: screenH,
    );
  }

  void _stepSim() {
    for (final col in _columns!) {
      col.y += col.speed;
      if (_rng.nextDouble() < 0.15) {
        final idx = _rng.nextInt(col.chars.length);
        col.chars[idx] = _rng.nextInt(chars.length);
      }
      if (col.y - col.length * _glyphH > col.screenH) {
        final len = _rng.nextInt(22) + 7;
        col.y = _rng.nextDouble() * -col.screenH;
        col.speed = _rng.nextDouble() * 6 + 4;
        col.length = len;
        col.chars = List.generate(len, (_) => _rng.nextInt(chars.length));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final colCount = (w / _glyphW).floor() + 1;
          if (_columns == null || _columns!.length != colCount) {
            _initColumns(w, h);
          }
          return CustomPaint(
            painter: _RainPainter(
              atlas: _atlas,
              glyphRects: _glyphRects,
              columns: _columns,
              repaint: _repaint,
              glyphW: _glyphW,
              glyphH: _glyphH,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

// ─── REPAINT SIGNAL ──────────────────────────────────────────────────────────

class _RepaintSignal extends ChangeNotifier {
  void ping() => notifyListeners();
}

// ─── COLUMN STATE ────────────────────────────────────────────────────────────

class _DropColumn {
  double x, y, speed;
  int length;
  List<int> chars;
  final double screenH;
  _DropColumn({
    required this.x,
    required this.y,
    required this.speed,
    required this.length,
    required this.chars,
    required this.screenH,
  });
}

// ─── PAINTER ─────────────────────────────────────────────────────────────────

class _RainPainter extends CustomPainter {
  final ui.Image? atlas;
  final List<Rect>? glyphRects;
  final List<_DropColumn>? columns;
  final double glyphW, glyphH;

  _RainPainter({
    required this.atlas,
    required this.glyphRects,
    required this.columns,
    required ChangeNotifier repaint,
    required this.glyphW,
    required this.glyphH,
  }) : super(repaint: repaint);

  final _bgPaint = Paint()..color = Colors.black;
  final _whitePaint = Paint()..color = _MatrixRainBackgroundState.white;

  // Pre-allocated Paint objects for 10 discrete alpha levels.
  // This avoids creating new Color objects per-glyph per-frame (~3000/sec).
  late final List<Paint> _greenPaints = List.generate(10, (i) {
    final alpha = ((i + 1) / 10).clamp(0.1, 1.0);
    return Paint()
      ..color = _MatrixRainBackgroundState.green.withValues(alpha: alpha);
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, _bgPaint);

    final a = atlas;
    final g = glyphRects;
    final cols = columns;
    if (a == null || g == null || cols == null || g.isEmpty) return;

    for (final col in cols) {
      for (int i = 0; i < col.length; i++) {
        final charY = col.y - (i * glyphH);
        if (charY > size.height || charY < -glyphH) continue;

        final charIdx = col.chars[i % col.chars.length] % g.length;
        final src = g[charIdx];
        final dst = Rect.fromLTWH(col.x, charY, glyphW, glyphH);

        if (i == 0) {
          canvas.drawImageRect(a, src, dst, _whitePaint);
        } else {
          // Map continuous alpha to one of 10 pre-allocated Paint buckets
          final alphaFraction = (1.0 - i / col.length).clamp(0.1, 1.0);
          final paintIndex = ((alphaFraction * 10).ceil() - 1).clamp(0, 9);
          canvas.drawImageRect(a, src, dst, _greenPaints[paintIndex]);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter old) =>
      old.atlas != atlas || old.columns != columns;
}
