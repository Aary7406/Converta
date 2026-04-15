import 'dart:io';
import 'dart:isolate';

import '../models/conversion_job.dart';
import '../services/libvips_converter.dart';
import 'format_registry.dart';
import 'native_bridge.dart';

/// Routes conversions to the correct engine (FFmpeg, libvips, ImageMagick).
/// GIF→Video is delegated to VideoService. Heavy work runs in Isolate.run().

class ConverterService {
  /// Runs conversion off the UI thread. libvips calls its own isolate internally;
  /// FFmpeg/ImageMagick are wrapped in Isolate.run() for non-blocking subprocess management.
  static Future<ConversionResult> convertInBackground({
    required String inputPath,
    required String outputFormat,
    required String outputPath,
  }) async {
    // POKA-YOKE: Fail fast before spawning isolates or processes
    if (!File(inputPath).existsSync()) {
      return ConversionResult(
        success: false,
        outputPath: '',
        message: 'Input file does not exist. Please select a valid file.',
        elapsed: Duration.zero,
      );
    }

    final inputExtension = inputPath.contains('.') 
        ? inputPath.split('.').last.toLowerCase() 
        : '';
        
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

    if (engine == ConversionEngine.libvips) {
      // libvips already uses VipsPipelineCompute (built-in compute isolate).
      // Calling it directly avoids unnecessary double-isolate overhead.
      return LibvipsConverter.convertImage(
        inputPath: inputPath,
        outputPath: outputPath,
        outputFormat: outputFormat,
      );
    }

    if (outputFormat.toLowerCase() == 'avif') {
      return NativeBridge.encodeAvif(input: inputPath, output: outputPath);
    }
    
    if (inputExtension == 'avif') {
      return NativeBridge.decodeAvif(input: inputPath, output: outputPath);
    }

    // FFmpeg and ImageMagick spawn external processes via Process.run().
    // Moving this to a background isolate ensures the main isolate's event
    // loop stays free for 60fps UI rendering (Matrix Rain + glass cards).
    return Isolate.run(
      () => convert(
        inputPath: inputPath,
        outputFormat: outputFormat,
        outputPath: outputPath,
      ),
      debugName: 'converta_convert',
    );
  }

  static Future<ConversionResult> convert({
    required String inputPath,
    required String outputFormat,
    required String outputPath,
  }) async {
    // POKA-YOKE: Fail fast
    if (!File(inputPath).existsSync()) {
      return ConversionResult(
        success: false,
        outputPath: '',
        message: 'Input file does not exist.',
        elapsed: Duration.zero,
      );
    }

    final inputExtension = inputPath.contains('.') 
        ? inputPath.split('.').last.toLowerCase() 
        : '';
        
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
          // -threads 0 = use all CPU cores
          // -an        = ignore audio stream (faster, no point for image)
          // -frames:v 1 = grab just 1 frame
          // -q:v 2     = high quality output
          arguments = [
            '-y',
            '-threads',
            '0',
            '-i',
            inputPath,
            '-an',
            '-frames:v',
            '1',
            '-q:v',
            '2',
            outputPath,
          ];
        } else if (inputExtension == 'gif' &&
            FormatRegistry.isImageToVideo(inputExtension, outputFormat)) {
          // Handled earlier in convertInBackground -> VideoService -> NativeBridge
          return ConversionResult(
            success: false,
            outputPath: '',
            message: 'GIF logic routing error. Should not reach here.',
            elapsed: Duration.zero,
          );
        } else if (FormatRegistry.isImageToVideo(
          inputExtension,
          outputFormat,
        )) {
          // STILL IMAGE → VIDEO (5-second loop)
          arguments = [
            '-y',
            '-loop',
            '1',
            '-r',
            '1',
            '-threads',
            '0',
            '-i',
            inputPath,
            '-c:v',
            'libx264',
            '-tune',
            'stillimage',
            '-t',
            '5',
            '-pix_fmt',
            'yuv420p',
            outputPath,
          ];
        } else if (FormatRegistry.isVideoToGif(inputExtension, outputFormat)) {
          // VIDEO → GIF: Two-pass palette approach
          // This is MUCH faster than single-pass because the palette reduces
          // the color space upfront, so encoding each frame is cheaper.
          return _convertToGif(inputPath, outputPath);
        } else if (_isAudioOutput(outputFormat)) {
          // VIDEO/AUDIO → AUDIO
          // -threads 0 = use all CPU cores
          // -vn        = skip video stream (faster for audio-only output)
          // -q:a 0     = maximum VBR quality (approx 245-285 kbps)
          arguments = [
            '-y',
            '-threads',
            '0',
            '-i',
            inputPath,
            '-vn',
            '-q:a',
            '0',
            outputPath,
          ];
        } else {
          // VIDEO → VIDEO (re-encode)
          // -threads 0   = use all CPU cores (2-8x faster on multi-core)
          // -c:a copy    = copy audio stream exactly as is
          // -qscale:v 0  = highest possible dynamic quality (matches original bitrate)
          // -movflags +faststart = optimize for streaming
          arguments = [
            '-y',
            '-threads',
            '0',
            '-i',
            inputPath,
            '-c:a',
            'copy',
            '-qscale:v',
            '0',
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
        '-threads',
        '0',
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
        '-threads',
        '0',
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
