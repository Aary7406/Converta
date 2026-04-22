import '../models/conversion_job.dart';
import '../models/media_category.dart';

class FormatRegistry {
  static const videoFormats = ['mp4', 'mkv', 'avi', 'mov', 'webm'];
  static const audioFormats = ['mp3', 'wav', 'aac', 'flac', 'ogg'];
  static const mediaFormats = [...videoFormats, ...audioFormats];
  static const imageFormats = [
    'png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif', 'tiff', 'avif',
  ];

  static const allInputFormats = [...mediaFormats, ...imageFormats];

  // ── Category helpers (for tab UI) ─────────────────────────────────────────

  static List<String> inputFormatsForCategory(MediaCategory category) {
    switch (category) {
      case MediaCategory.photo: return imageFormats;
      case MediaCategory.video: return videoFormats;
      case MediaCategory.audio: return audioFormats;
      case MediaCategory.files: return [];
    }
  }

  static List<String> sameTypeFormats(MediaCategory category, String inputExt) {
    final ext = _norm(inputExt);
    return inputFormatsForCategory(category)
        .where((f) => f != ext && f != 'jpeg')
        .toList();
  }

  static List<MediaCategory> crossTypeTargets(MediaCategory source) {
    switch (source) {
      case MediaCategory.photo:  return [MediaCategory.video];
      case MediaCategory.video:  return [MediaCategory.audio, MediaCategory.photo];
      case MediaCategory.audio:  return [MediaCategory.video];
      case MediaCategory.files:  return [];
    }
  }

  static List<String> crossTypeFormats(MediaCategory target, String inputExt) {
    final ext = _norm(inputExt);
    switch (target) {
      case MediaCategory.photo:  return imageFormats.where((f) => f != 'jpeg').toList();
      case MediaCategory.video:  return videoFormats.where((f) => f != ext).toList();
      case MediaCategory.audio:  return audioFormats.where((f) => f != ext).toList();
      case MediaCategory.files:  return [];
    }
  }

  // ── Engine routing ─────────────────────────────────────────────────────────

  /// Returns the engine for a given input→output conversion pair.
  static ConversionEngine? getEngineForConversion(String inExt, String outExt) {
    final i = _norm(inExt);
    final o = _norm(outExt);

    // Any media input → ffmpeg
    if (mediaFormats.contains(i)) return ConversionEngine.ffmpeg;

    // Image → video → ffmpeg
    if (imageFormats.contains(i) && videoFormats.contains(o)) {
      return ConversionEngine.ffmpeg;
    }

    // Image → image (including AVIF) → vips.exe
    if (imageFormats.contains(i) && imageFormats.contains(o)) {
      return ConversionEngine.vips;
    }

    return null;
  }

  // ── Conversion-type predicates ─────────────────────────────────────────────

  static bool isVideoToImage(String i, String o) =>
      videoFormats.contains(_norm(i)) &&
      imageFormats.contains(_norm(o)) &&
      _norm(o) != 'gif';

  static bool isImageToVideo(String i, String o) =>
      imageFormats.contains(_norm(i)) && videoFormats.contains(_norm(o));

  static bool isVideoToGif(String i, String o) =>
      videoFormats.contains(_norm(i)) && _norm(o) == 'gif';

  static bool isSupported(String ext) => allInputFormats.contains(_norm(ext));

  static bool isAudioFormat(String fmt) =>
      audioFormats.contains(_norm(fmt));

  static String _norm(String ext) =>
      ext.replaceAll('.', '').toLowerCase().trim();
}
