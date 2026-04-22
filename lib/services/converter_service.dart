import 'dart:io';
import 'dart:isolate';

import '../models/conversion_job.dart';
import 'format_registry.dart';
import 'libvips_converter.dart';
import 'native_bridge.dart';

class ConverterService {
  /// Absolute path to bundled ffmpeg.exe (next to the runner exe).
  static String get _ffmpeg {
    final dir = File(Platform.resolvedExecutable).parent.path;
    return '$dir${Platform.pathSeparator}ffmpeg.exe';
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  static Future<ConversionResult> convertInBackground({
    required String inputPath,
    required String outputFormat,
    required String outputPath,
  }) async {
    if (!File(inputPath).existsSync()) {
      return _err('Input file does not exist.');
    }

    final inExt = _ext(inputPath);

    // GIF → video: handled by native bridge (ffmpeg via CreateProcess)
    if (inExt == 'gif' && FormatRegistry.isImageToVideo(inExt, outputFormat)) {
      return NativeBridge.gifToMp4(
        input: inputPath,
        output: outputPath,
        crf: 18,
        preset: 'veryfast',
      );
    }

    final engine = FormatRegistry.getEngineForConversion(inExt, outputFormat);
    if (engine == null) {
      return _err('Unsupported conversion: .$inExt → .$outputFormat');
    }

    // Image-to-image: vips.exe (fast, no init issues, handles AVIF natively)
    if (engine == ConversionEngine.vips) {
      return LibvipsConverter.convertImage(
        inputPath: inputPath,
        outputPath: outputPath,
        outputFormat: outputFormat,
      );
    }

    // Video/audio: spawn isolate so UI stays at 60fps
    final ffmpeg = _ffmpeg;
    return Isolate.run(
      () => _ffmpegConvert(
        ffmpeg: ffmpeg,
        inputPath: inputPath,
        outputFormat: outputFormat,
        outputPath: outputPath,
      ),
      debugName: 'converta_ffmpeg',
    );
  }

  // ── FFmpeg worker (runs in Isolate.run) ────────────────────────────────────

  static Future<ConversionResult> _ffmpegConvert({
    required String ffmpeg,
    required String inputPath,
    required String outputFormat,
    required String outputPath,
  }) async {
    if (!File(inputPath).existsSync()) return _err('Input file not found.');

    final inExt = _ext(inputPath);
    final args = _buildFfmpegArgs(inExt, outputFormat, inputPath, outputPath);
    if (args == null) {
      return _err('Cannot build ffmpeg args for .$inExt → .$outputFormat');
    }

    // Two-pass GIF needs special handling
    if (args == _kTwoPassGif) {
      return _twoPassGif(ffmpeg, inputPath, outputPath);
    }

    return _run(ffmpeg, args, outputPath);
  }

  static const _kTwoPassGif = <String>['__TWO_PASS_GIF__'];

  static List<String>? _buildFfmpegArgs(
      String inExt, String outFmt, String input, String output) {
    if (FormatRegistry.isVideoToGif(inExt, outFmt)) return _kTwoPassGif;

    if (FormatRegistry.isVideoToImage(inExt, outFmt)) {
      return [
        '-y', '-hwaccel', 'auto', '-threads', '0',
        '-i', input, '-an', '-frames:v', '1', '-q:v', '2', output,
      ];
    }

    if (FormatRegistry.isImageToVideo(inExt, outFmt)) {
      return [
        '-y', '-loop', '1', '-r', '1',
        '-hwaccel', 'auto', '-threads', '0',
        '-i', input,
        '-c:v', 'libx264', '-tune', 'stillimage',
        '-t', '5', '-pix_fmt', 'yuv420p', output,
      ];
    }

    if (FormatRegistry.isAudioFormat(outFmt)) {
      return [
        '-y', '-threads', '0', '-i', input,
        '-vn', '-q:a', '0', output,
      ];
    }

    // Video → video
    return [
      '-y', '-hwaccel', 'auto', '-threads', '0',
      '-i', input, '-c:a', 'copy', '-qscale:v', '0',
      '-movflags', '+faststart', output,
    ];
  }

  // ── Two-pass video→GIF ────────────────────────────────────────────────────

  static Future<ConversionResult> _twoPassGif(
      String ffmpeg, String input, String output) async {
    final sw = Stopwatch()..start();
    final palette =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'gif_pal_${DateTime.now().millisecondsSinceEpoch}.png';

    try {
      final pass1 = await Process.run(ffmpeg, [
        '-y', '-threads', '0', '-i', input,
        '-vf', 'fps=8,scale=320:-1:flags=lanczos,palettegen=stats_mode=diff',
        palette,
      ]);
      if (pass1.exitCode != 0) {
        return ConversionResult(
          success: false, outputPath: '',
          message: 'GIF palette failed:\n${pass1.stderr}',
          elapsed: sw.elapsed,
        );
      }

      final pass2 = await Process.run(ffmpeg, [
        '-y', '-threads', '0', '-i', input, '-i', palette,
        '-lavfi',
        'fps=8,scale=320:-1:flags=lanczos[x];[x][1:v]'
        'paletteuse=dither=bayer:bayer_scale=5',
        output,
      ]);
      sw.stop();
      _tryDelete(palette);

      return pass2.exitCode == 0
          ? ConversionResult(
              success: true, outputPath: output,
              message: 'GIF conversion complete.',
              elapsed: sw.elapsed)
          : ConversionResult(
              success: false, outputPath: '',
              message: 'GIF encode failed:\n${pass2.stderr}',
              elapsed: sw.elapsed);
    } catch (e) {
      sw.stop();
      _tryDelete(palette);
      return ConversionResult(
          success: false, outputPath: '', message: '$e', elapsed: sw.elapsed);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Future<ConversionResult> _run(
      String exe, List<String> args, String outputPath) async {
    final sw = Stopwatch()..start();
    try {
      final r = await Process.run(exe, args);
      sw.stop();
      final ok = r.exitCode == 0;
      return ConversionResult(
        success: ok,
        outputPath: ok ? outputPath : '',
        message: ok
            ? 'Conversion complete.'
            : 'Failed (exit ${r.exitCode}):\n'
                '${('${r.stdout}\n${r.stderr}').trim()}',
        elapsed: sw.elapsed,
      );
    } catch (e) {
      sw.stop();
      final msg = '$e';
      return ConversionResult(
        success: false,
        outputPath: '',
        message: msg.contains('cannot find') || msg.contains('not recognized')
            ? 'ffmpeg.exe not found. Run a Release build.'
            : msg,
        elapsed: sw.elapsed,
      );
    }
  }

  static ConversionResult _err(String msg) => ConversionResult(
      success: false, outputPath: '', message: msg, elapsed: Duration.zero);

  static String _ext(String path) =>
      path.contains('.') ? path.split('.').last.toLowerCase() : '';

  static void _tryDelete(String path) {
    try {
      File(path).deleteSync();
    } catch (_) {}
  }
}
