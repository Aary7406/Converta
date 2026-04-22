enum ConversionEngine { ffmpeg, vips }

class ConversionResult {
  final bool success;
  final String outputPath;
  final String message;
  final Duration elapsed;

  const ConversionResult({
    required this.success,
    required this.outputPath,
    required this.message,
    required this.elapsed,
  });
}
