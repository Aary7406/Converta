import '../models/conversion_job.dart';
import '../models/media_category.dart';

/// The "brain" that knows which formats exist and which engine handles them.
///
/// PHASE 2 CHANGES:
///   - Cross-engine conversion: video can now convert to image formats
///     (FFmpeg extracts a frame) and to GIF (animated)
///   - Media formats can convert to ANY other media OR image format
///   - Image formats stay image-only (no audio data to extract)

class FormatRegistry {
  // ──────────────────────────────────────────────────────────────────────
  // FORMAT LISTS
  // ──────────────────────────────────────────────────────────────────────

  static const videoFormats = ['mp4', 'mkv', 'avi', 'mov', 'webm'];
  static const audioFormats = ['mp3', 'wav', 'aac', 'flac', 'ogg'];
  static const mediaFormats = [...videoFormats, ...audioFormats];
  static const imageFormats = [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'bmp',
    'gif',
    'tiff',
    'avif',
  ];

  /// Every format we support as input.
  static const allInputFormats = [...mediaFormats, ...imageFormats];

  // ──────────────────────────────────────────────────────────────────────
  // CATEGORY-AWARE HELPERS (for tab-based UI)
  // ──────────────────────────────────────────────────────────────────────

  /// Returns the accepted input extensions for a given tab category.
  static List<String> inputFormatsForCategory(MediaCategory category) {
    switch (category) {
      case MediaCategory.photo:
        return imageFormats;
      case MediaCategory.video:
        return videoFormats;
      case MediaCategory.audio:
        return audioFormats;
      case MediaCategory.files:
        return []; // Coming soon
    }
  }

  /// "Format Change" — same-type outputs (e.g. PNG→WEBP, MP4→MKV).
  /// Excludes the input format and the 'jpeg' duplicate.
  static List<String> sameTypeFormats(MediaCategory category, String inputExt) {
    final ext = _normalize(inputExt);
    final pool = inputFormatsForCategory(category);
    return pool.where((f) => f != ext && f != 'jpeg').toList();
  }

  /// "Filetype Change" — which OTHER categories can this input convert to?
  /// Returns a list of target categories (excluding Files = coming soon).
  static List<MediaCategory> crossTypeTargets(MediaCategory source) {
    switch (source) {
      case MediaCategory.photo:
        // Image → Video (5-second 1080p MP4)
        return [MediaCategory.video];
      case MediaCategory.video:
        // Video → Audio (extract), Video → Photo (frame extraction)
        return [MediaCategory.audio, MediaCategory.photo];
      case MediaCategory.audio:
        return [MediaCategory.video];
      case MediaCategory.files:
        return [];
    }
  }

  /// "Filetype Change" — formats available when converting TO a target category.
  static List<String> crossTypeFormats(
    MediaCategory target,
    String inputExt,
  ) {
    final ext = _normalize(inputExt);
    switch (target) {
      case MediaCategory.photo:
        return imageFormats.where((f) => f != 'jpeg').toList();
      case MediaCategory.video:
        return videoFormats.where((f) => f != ext).toList();
      case MediaCategory.audio:
        return audioFormats.where((f) => f != ext).toList();
      case MediaCategory.files:
        return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // PUBLIC METHODS
  // ──────────────────────────────────────────────────────────────────────

  /// Returns which engine handles this input format.
  static ConversionEngine? getEngine(String extension) {
    final ext = _normalize(extension);
    if (mediaFormats.contains(ext)) return ConversionEngine.ffmpeg;
    if (imageFormats.contains(ext)) return ConversionEngine.imageMagick;
    return null;
  }

  /// Returns valid output formats for a given input.
  static List<String> getOutputFormats(String inputExtension) {
    final ext = _normalize(inputExtension);

    if (videoFormats.contains(ext)) {
      final outputs = <String>[
        ...videoFormats.where((f) => f != ext),
        ...audioFormats,
        ...imageFormats.where((f) => f != 'jpeg'),
      ];
      return outputs;
    }

    if (audioFormats.contains(ext)) {
      return mediaFormats.where((f) => f != ext).toList();
    }

    if (imageFormats.contains(ext)) {
      return imageFormats.where((f) => f != ext && f != 'jpeg').toList();
    }

    return [];
  }

  /// Determines which engine should handle a specific conversion pair.
  static ConversionEngine? getEngineForConversion(
    String inputExt,
    String outputExt,
  ) {
    final input = _normalize(inputExt);
    final output = _normalize(outputExt);

    if (mediaFormats.contains(input)) return ConversionEngine.ffmpeg;
    if (isImageToVideo(input, output)) return ConversionEngine.ffmpeg;
    if (imageFormats.contains(input) && output == 'gif') {
      return ConversionEngine.imageMagick;
    }
    // Force FFmpeg for all GIF processing to prevent libvips multi-threading deadlocks
    if (input == 'gif') return ConversionEngine.ffmpeg;
    if (imageFormats.contains(input)) return ConversionEngine.libvips;
    return null;
  }

  /// Returns true if this conversion extracts a single frame from video.
  static bool isVideoToImage(String inputExt, String outputExt) {
    final input = _normalize(inputExt);
    final output = _normalize(outputExt);
    return videoFormats.contains(input) &&
        imageFormats.contains(output) &&
        output != 'gif';
  }

  /// Returns true if this conversion generates a video from a single image.
  static bool isImageToVideo(String inputExt, String outputExt) {
    final input = _normalize(inputExt);
    final output = _normalize(outputExt);
    return imageFormats.contains(input) &&
        videoFormats.contains(output) &&
        output != 'gif';
  }

  /// Returns true if this conversion creates an animated GIF from video.
  static bool isVideoToGif(String inputExt, String outputExt) {
    final input = _normalize(inputExt);
    final output = _normalize(outputExt);
    return videoFormats.contains(input) && output == 'gif';
  }

  static bool isSupported(String extension) {
    return allInputFormats.contains(_normalize(extension));
  }

  // ──────────────────────────────────────────────────────────────────────
  // PRIVATE
  // ──────────────────────────────────────────────────────────────────────

  static String _normalize(String ext) {
    return ext.replaceAll('.', '').toLowerCase().trim();
  }
}
