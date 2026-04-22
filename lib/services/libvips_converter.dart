import 'dart:io';
import '../models/conversion_job.dart';

class LibvipsConverter {
  /// Resolves vips.exe next to the runner executable.
  static String _vipsExe() {
    final dir = File(Platform.resolvedExecutable).parent.path;
    return '$dir${Platform.pathSeparator}vips.exe';
  }

  /// Converts any image format to any other image format.
  /// Runs in a background [Process] — never blocks the UI thread.
  static Future<ConversionResult> convertImage({
    required String inputPath,
    required String outputPath,
    required String outputFormat,
  }) async {
    final vips = _vipsExe();
    final stopwatch = Stopwatch()..start();

    // Guard: vips.exe must be present (copied by CMake POST_BUILD)
    if (!File(vips).existsSync()) {
      return ConversionResult(
        success: false,
        outputPath: '',
        message: 'vips.exe not found next to the executable. '
            'Run a Release build so CMake copies it.',
        elapsed: Duration.zero,
      );
    }

    // Build vips arguments for the target format
    final args = _buildArgs(inputPath, outputPath, outputFormat);

    try {
      final result = await Process.run(vips, args);
      stopwatch.stop();

      if (result.exitCode == 0) {
        return ConversionResult(
          success: true,
          outputPath: outputPath,
          message: 'Converted via libvips '
              '(.${outputFormat.toUpperCase()}).',
          elapsed: stopwatch.elapsed,
        );
      }

      // vips writes errors to stderr
      final err = (result.stderr as String).trim();
      return ConversionResult(
        success: false,
        outputPath: '',
        message: 'vips error (exit ${result.exitCode})'
            '${err.isNotEmpty ? ":\n$err" : ""}',
        elapsed: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return ConversionResult(
        success: false,
        outputPath: '',
        message: 'vips.exe failed to launch: $e',
        elapsed: stopwatch.elapsed,
      );
    }
  }

  // ── Argument builder ───────────────────────────────────────────────────────
  //
  // vips CLI: vips.exe <operation> <input>[options] <output>[save-options]
  //
  // The simplest reliable operation is `copy` which reads, decodes, and
  // re-encodes using the format inferred from the output extension.
  // Save options are appended as query-string parameters on the output path.

  static List<String> _buildArgs(
      String input, String output, String format) {
    final fmt = format.toLowerCase();
    final String outWithOptions;

    switch (fmt) {
      case 'jpg':
      case 'jpeg':
        // Q=95, optimize Huffman table
        outWithOptions = '$output[Q=95,optimize_coding=true]';
        break;
      case 'webp':
        // Lossless WebP
        outWithOptions = '$output[lossless=true]';
        break;
      case 'avif':
        // AVIF via libheif + libaom (bundled in libvips/bin)
        // Q=80 ≈ visually lossless; speed=6 balances encode time
        outWithOptions = '$output[Q=80,speed=6]';
        break;
      case 'tiff':
        // Lossless TIFF with deflate compression
        outWithOptions = '$output[compression=deflate]';
        break;
      case 'png':
        // Default PNG is lossless; compression=9 for smallest size
        outWithOptions = '$output[compression=9]';
        break;
      default:
        outWithOptions = output;
    }

    return ['copy', input, outWithOptions];
  }
}
