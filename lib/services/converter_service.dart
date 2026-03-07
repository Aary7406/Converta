import 'dart:io';

import '../models/conversion_job.dart';
import '../services/libvips_converter.dart';
import 'format_registry.dart';

/// Optimized conversion service.
///
/// PERFORMANCE OPTIMIZATIONS (Phase 2.1):
///
/// 1. VIDEO ENCODING: Uses -preset veryfast + CRF quality control.
///    - -preset veryfast: 3-5x faster than default 'medium' preset
///    - -crf 23: Constant Rate Factor — lets FFmpeg dynamically choose
///      the bitrate to maintain consistent quality. 23 = good quality,
///      smaller number = higher quality but bigger file.
///    - These two flags together give the best speed/quality trade-off.
///
/// 2. GIF: Two-pass palette generation (industry standard).
///    - Pass 1: Generates a custom 256-color palette from the video
///    - Pass 2: Applies that palette to the GIF frames
///    - Result: 2-4x smaller files, much better color accuracy
///    - Also reduced resolution to 320px wide (was 480px) for speed
///
/// 3. AUDIO: Uses -q:a for VBR (variable bitrate) encoding.
///    - -q:a 2 = high quality VBR (~190kbps for MP3)
///    - Faster than fixed bitrate and produces better quality/size ratio
///
/// 4. FRAME EXTRACTION: Already fast (single frame), but added -an flag
///    to skip audio processing entirely.

class ConverterService {
  static Future<ConversionResult> convert({
    required String inputPath,
    required String outputFormat,
    required String outputPath,
  }) async {
    final inputExtension = inputPath.split('.').last;
    final engine = FormatRegistry.getEngineForConversion(
      inputExtension,
      outputFormat,
    );

    if (engine == null) {
      return ConversionResult(
        success: false,
        outputPath: '',
        message: 'Unsupported input format: .$inputExtension',
        elapsed: Duration.zero,
      );
    }

    final String executable;
    final List<String> arguments;

    switch (engine) {
      case ConversionEngine.ffmpeg:
        executable = 'ffmpeg';

        if (FormatRegistry.isVideoToImage(inputExtension, outputFormat)) {
          // VIDEO → STILL IMAGE
          // -an        = ignore audio stream (faster, no point for image)
          // -frames:v 1 = grab just 1 frame
          // -q:v 2     = high quality output
          arguments = [
            '-y',
            '-i',
            inputPath,
            '-an',
            '-frames:v',
            '1',
            '-q:v',
            '2',
            outputPath,
          ];
        } else if (FormatRegistry.isVideoToGif(inputExtension, outputFormat)) {
          // VIDEO → GIF: Two-pass palette approach
          // This is MUCH faster than single-pass because the palette reduces
          // the color space upfront, so encoding each frame is cheaper.
          return _convertToGif(inputPath, outputPath);
        } else if (_isAudioOutput(outputFormat)) {
          // VIDEO/AUDIO → AUDIO
          // -vn        = skip video stream (faster for audio-only output)
          // -q:a 2     = high quality variable bitrate
          arguments = ['-y', '-i', inputPath, '-vn', '-q:a', '2', outputPath];
        } else {
          // VIDEO → VIDEO (re-encode)
          // -preset veryfast = 3-5x faster encoding
          // -crf 23          = good quality, smaller than default
          // -movflags +faststart = optimize for streaming (mp4 only, ignored by others)
          arguments = [
            '-y',
            '-i',
            inputPath,
            '-preset',
            'veryfast',
            '-crf',
            '15',
            '-movflags',
            '+faststart',
            outputPath,
          ];
        }
        break;

      case ConversionEngine.imageMagick:
        executable = 'magick';
        arguments = [inputPath, outputPath];
        break;

      case ConversionEngine.libvips:
        // Route directly to the libvips C library via Dart FFI.
        // This early-return bypasses the _runProcess() subprocess path entirely.
        return LibvipsConverter.convertImage(
          inputPath: inputPath,
          outputPath: outputPath,
          outputFormat: outputFormat,
        );
    }

    return _runProcess(executable, arguments, outputPath);
  }

  /// Two-pass GIF encoding:
  ///   Pass 1: Generate optimal 256-color palette from the video
  ///   Pass 2: Encode GIF using that palette
  ///
  /// WHY TWO PASSES?
  ///   GIF only supports 256 colors. Without a palette, FFmpeg picks colors
  ///   randomly → banding, dithering, huge file size. With a custom palette,
  ///   it picks the 256 BEST colors for your specific video → sharp, small GIF.
  ///
  /// SPEED OPTIMIZATIONS:
  ///   - fps=8: 8 frames per second (was 10, saves 20% encoding time)
  ///   - scale=320:-1: width 320px (was 480, cuts pixel count in half)
  ///   - lanczos: best quality scaling for downscale
  static Future<ConversionResult> _convertToGif(
    String inputPath,
    String outputPath,
  ) async {
    final stopwatch = Stopwatch()..start();

    // Create a temporary palette file next to the output
    final paletteDir = Directory.systemTemp;
    final palettePath =
        '${paletteDir.path}\\gif_palette_${DateTime.now().millisecondsSinceEpoch}.png';

    try {
      // ── Pass 1: Generate palette ──────────────────────────────────
      final paletteResult = await Process.run('ffmpeg', [
        '-y',
        '-i',
        inputPath,
        '-vf',
        'fps=8,scale=320:-1:flags=lanczos,palettegen=stats_mode=diff',
        palettePath,
      ]);

      if (paletteResult.exitCode != 0) {
        stopwatch.stop();
        return ConversionResult(
          success: false,
          outputPath: '',
          message: 'GIF palette generation failed:\n${paletteResult.stderr}',
          elapsed: stopwatch.elapsed,
        );
      }

      // ── Pass 2: Encode GIF with palette ───────────────────────────
      final gifResult = await Process.run('ffmpeg', [
        '-y',
        '-i',
        inputPath,
        '-i',
        palettePath,
        '-lavfi',
        'fps=8,scale=320:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5',
        outputPath,
      ]);

      stopwatch.stop();

      // Clean up temp palette file
      try {
        File(palettePath).deleteSync();
      } catch (_) {}

      final success = gifResult.exitCode == 0;
      return ConversionResult(
        success: success,
        outputPath: success ? outputPath : '',
        message: success
            ? 'GIF conversion completed successfully.'
            : 'GIF encoding failed:\n${gifResult.stderr}',
        elapsed: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      try {
        File(palettePath).deleteSync();
      } catch (_) {}

      return ConversionResult(
        success: false,
        outputPath: '',
        message: e.toString(),
        elapsed: stopwatch.elapsed,
      );
    }
  }

  /// Checks if the output format is audio-only.
  static bool _isAudioOutput(String format) {
    return FormatRegistry.audioFormats.contains(format.toLowerCase());
  }

  /// Runs an external process and wraps the result.
  static Future<ConversionResult> _runProcess(
    String executable,
    List<String> arguments,
    String outputPath,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await Process.run(executable, arguments);
      stopwatch.stop();

      final success = result.exitCode == 0;
      final combinedOutput = '${result.stdout}\n${result.stderr}'.trim();

      return ConversionResult(
        success: success,
        outputPath: success ? outputPath : '',
        message: success
            ? 'Conversion completed successfully.'
            : 'Conversion failed (exit code ${result.exitCode}):\n$combinedOutput',
        elapsed: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();

      String userMessage = e.toString();
      if (userMessage.contains('cannot find the file') ||
          userMessage.contains('is not recognized')) {
        userMessage =
            '"$executable" was not found. Make sure it is installed and on your system PATH.';
      }

      return ConversionResult(
        success: false,
        outputPath: '',
        message: userMessage,
        elapsed: stopwatch.elapsed,
      );
    }
  }
}
