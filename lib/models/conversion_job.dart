/// Which external tool performs the conversion.
///
/// Think of this like choosing which machine in a factory to use:
/// - [ffmpeg]      → handles anything with audio or video (mp4, mp3, wav, etc.)
/// - [imageMagick] → fallback image-to-image (png → jpg, etc.)
/// - [libvips]     → high-speed lossless image-to-image via C FFI (preferred)
enum ConversionEngine { ffmpeg, imageMagick, libvips }

/// Holds all the info about ONE conversion request.
///
/// This is a plain data class — it doesn't DO anything, it just HOLDS data.
/// Keeping data separate from logic makes the code easier to test and change.
///
/// Example:
/// ```dart
/// final job = ConversionJob(
///   inputPath: 'C:/photos/cat.png',
///   outputFormat: 'jpg',
///   engine: ConversionEngine.imageMagick,
/// );
/// ```
class ConversionJob {
  /// Full path to the file the user picked (e.g. "C:/videos/clip.mp4").
  final String inputPath;

  /// The target format without a dot (e.g. "mp3", "jpg").
  final String outputFormat;

  /// Which engine will do the actual work.
  final ConversionEngine engine;

  const ConversionJob({
    required this.inputPath,
    required this.outputFormat,
    required this.engine,
  });
}

/// The result that comes back AFTER a conversion finishes.
///
/// [success] tells you if it worked.
/// [outputPath] is where the new file ended up.
/// [message] contains stdout/stderr — useful for debugging when things go wrong.
/// [elapsed] tells you how long the conversion took.
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
