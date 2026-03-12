import 'dart:io';

/// System information utility for adaptive performance tuning.
///
/// Queries available physical memory via WMIC (runs once, caches result)
/// and computes optimal buffer sizes to avoid memory pressure on
/// low-RAM systems while maximizing throughput on high-RAM ones.
class SystemInfo {
  static int? _cachedChunkSize;

  /// Returns the optimal write chunk size in bytes, scaled to available RAM.
  ///
  /// RAM TIERS:
  ///   < 4 GB free  →  512 KB  (conservative — avoids memory pressure)
  ///   4–8 GB free  →    1 MB  (balanced)
  ///   8–16 GB free →    2 MB  (fast writes)
  ///   16 GB+ free  →    4 MB  (maximum throughput)
  ///
  /// The WMIC query runs only once per app lifetime. Subsequent calls
  /// return the cached value with zero overhead.
  static Future<int> optimalWriteChunkSize() async {
    if (_cachedChunkSize != null) return _cachedChunkSize!;

    try {
      // WMIC returns free physical memory in KB.
      // /VALUE format → "FreePhysicalMemory=12345678\r\n"
      final result = await Process.run(
        'wmic',
        ['OS', 'get', 'FreePhysicalMemory', '/VALUE'],
      );

      if (result.exitCode == 0) {
        final match = RegExp(
          r'FreePhysicalMemory=(\d+)',
        ).firstMatch(result.stdout as String);

        if (match != null) {
          final freeKB = int.parse(match.group(1)!);
          final freeGB = freeKB / (1024 * 1024);
          _cachedChunkSize = _chunkForRam(freeGB);
          return _cachedChunkSize!;
        }
      }
    } catch (_) {
      // WMIC unavailable — fall back to default.
    }

    _cachedChunkSize = 1024 * 1024; // Default: 1 MB
    return _cachedChunkSize!;
  }

  static int _chunkForRam(double freeGB) {
    if (freeGB < 4) return 512 * 1024; //  512 KB
    if (freeGB < 8) return 1024 * 1024; //    1 MB
    if (freeGB < 16) return 2 * 1024 * 1024; //    2 MB
    return 4 * 1024 * 1024; //    4 MB
  }
}
