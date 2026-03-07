import '../models/conversion_job.dart';

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
  ];

  /// Every format we support as input.
  static const allInputFormats = [...mediaFormats, ...imageFormats];

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
  ///
  /// CROSS-ENGINE LOGIC (Phase 2):
  ///   - Video input → can output to: other video, audio, AND image formats
  ///     (FFmpeg handles all of these: re-encode, extract audio, extract frame)
  ///   - Audio input → can output to: other audio and video formats
  ///   - Image input → can output to: other image formats only
  ///     (images have no audio/video data to extract)
  static List<String> getOutputFormats(String inputExtension) {
    final ext = _normalize(inputExtension);

    if (videoFormats.contains(ext)) {
      // Video → any media format + image formats (frame extraction)
      final outputs = <String>[
        ...videoFormats.where((f) => f != ext),
        ...audioFormats,
        // Image outputs via frame extraction (exclude jpeg duplicate)
        ...imageFormats.where((f) => f != 'jpeg'),
      ];
      return outputs;
    }

    if (audioFormats.contains(ext)) {
      // Audio → other audio + video formats
      return mediaFormats.where((f) => f != ext).toList();
    }

    if (imageFormats.contains(ext)) {
      // Image → other image formats only
      return imageFormats.where((f) => f != ext && f != 'jpeg').toList();
    }

    return [];
  }

  /// Determines which engine should handle a specific conversion pair.
  ///
  /// Rule: engine is determined by whoever can best READ the INPUT.
  /// - Media (video/audio) → FFmpeg (it's the only one that can read video)
  /// - Image → libvips first (C FFI, faster + lossless), ImageMagick as fallback
  static ConversionEngine? getEngineForConversion(
    String inputExt,
    String outputExt,
  ) {
    final input = _normalize(inputExt);
    final output = _normalize(outputExt);

    // Media input: FFmpeg handles everything
    if (mediaFormats.contains(input)) return ConversionEngine.ffmpeg;

    // Image input → output is GIF: libvips GIF support is limited, use ImageMagick
    if (imageFormats.contains(input) && output == 'gif') {
      return ConversionEngine.imageMagick;
    }

    // Image → image: use libvips (5-10x faster, lossless C library)
    if (imageFormats.contains(input)) return ConversionEngine.libvips;

    return null;
  }

  /// Returns true if this conversion extracts a single frame from video.
  /// Used by ConverterService to pick the right FFmpeg arguments.
  static bool isVideoToImage(String inputExt, String outputExt) {
    final input = _normalize(inputExt);
    final output = _normalize(outputExt);
    return videoFormats.contains(input) &&
        imageFormats.contains(output) &&
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
