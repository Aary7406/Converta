import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../models/conversion_job.dart';

// ─── C type signatures ─────────────────────────────────────────────────────

typedef _ProgressCbNative = Void Function(Double, Pointer<Void>);

typedef _GifToMp4Native = Int32 Function(
  Pointer<Char>,
  Pointer<Char>,
  Int32,
  Pointer<Char>,
  Pointer<NativeFunction<_ProgressCbNative>>,
  Pointer<Void>,
);
typedef _GifToMp4Dart = int Function(
  Pointer<Char>,
  Pointer<Char>,
  int,
  Pointer<Char>,
  Pointer<NativeFunction<_ProgressCbNative>>,
  Pointer<Void>,
);

typedef _EncodeAvifNative = Int32 Function(
  Pointer<Char>,
  Pointer<Char>,
  Int32,
  Int32,
);
typedef _EncodeAvifDart = int Function(
  Pointer<Char>,
  Pointer<Char>,
  int,
  int,
);

typedef _DecodeAvifNative = Int32 Function(
  Pointer<Char>,
  Pointer<Char>,
  Int32,
);
typedef _DecodeAvifDart = int Function(
  Pointer<Char>,
  Pointer<Char>,
  int,
);

typedef _LastErrorNative = Pointer<Char> Function();
typedef _LastErrorDart = Pointer<Char> Function();

// ─── Helpers (top-level — Sendable across isolates) ──────────────────────────

/// Returns the full path to converta_core.dll (next to the exe).
String _dllPath() {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  return '$exeDir\\converta_core.dll';
}

/// Reads the last error string from the DLL without throwing.
String _lastError(DynamicLibrary lib) {
  try {
    final fn =
        lib.lookupFunction<_LastErrorNative, _LastErrorDart>('converta_last_error');
    return fn().cast<Utf8>().toDartString();
  } catch (_) {
    return 'unknown error';
  }
}

// ─── Isolate workers ─────────────────────────────────────────────────────────
// Must be top-level functions so they are Sendable by Isolate.run().

ConversionResult _workerGifToMp4(
  (String, String, String, int, String, SendPort?) args,
) {
  final (dllPath, input, output, crf, preset, sendPort) = args;
  final stop = Stopwatch()..start();

  try {
    final lib = DynamicLibrary.open(dllPath);
    final fn = lib.lookupFunction<_GifToMp4Native, _GifToMp4Dart>(
      'converta_gif_to_mp4',
    );

    final inPtr = input.toNativeUtf8();
    final outPtr = output.toNativeUtf8();
    final presetPtr = preset.toNativeUtf8();

    NativeCallable<_ProgressCbNative>? nativeCb;
    var cbPtr = Pointer<NativeFunction<_ProgressCbNative>>.fromAddress(0);

    if (sendPort != null) {
      // isolateLocal: called synchronously by C — safe for blocking encode loops
      nativeCb = NativeCallable<_ProgressCbNative>.isolateLocal(
        (double p, Pointer<Void> _) => sendPort.send(p),
      );
      cbPtr = nativeCb.nativeFunction;
    }

    try {
      final ret = fn(
        inPtr.cast<Char>(),
        outPtr.cast<Char>(),
        crf,
        presetPtr.cast<Char>(),
        cbPtr,
        Pointer<Void>.fromAddress(0),
      );
      stop.stop();
      return ConversionResult(
        success: ret == 0,
        outputPath: ret == 0 ? output : '',
        message: ret == 0 ? 'GIF \u2192 MP4 complete.' : _lastError(lib),
        elapsed: stop.elapsed,
      );
    } finally {
      malloc.free(inPtr);
      malloc.free(outPtr);
      malloc.free(presetPtr);
      nativeCb?.close();
    }
  } catch (e) {
    stop.stop();
    return ConversionResult(
      success: false,
      outputPath: '',
      message: e.toString(),
      elapsed: stop.elapsed,
    );
  }
}

ConversionResult _workerEncodeAvif(
  (String, String, String, int, int) args,
) {
  final (dllPath, input, output, quality, speed) = args;
  final stop = Stopwatch()..start();

  try {
    final lib = DynamicLibrary.open(dllPath);
    final fn = lib.lookupFunction<_EncodeAvifNative, _EncodeAvifDart>(
      'converta_encode_avif',
    );

    final inPtr = input.toNativeUtf8();
    final outPtr = output.toNativeUtf8();

    try {
      final ret = fn(inPtr.cast<Char>(), outPtr.cast<Char>(), quality, speed);
      stop.stop();
      return ConversionResult(
        success: ret == 0,
        outputPath: ret == 0 ? output : '',
        message: ret == 0 ? 'AVIF encode complete.' : _lastError(lib),
        elapsed: stop.elapsed,
      );
    } finally {
      malloc.free(inPtr);
      malloc.free(outPtr);
    }
  } catch (e) {
    stop.stop();
    return ConversionResult(
      success: false,
      outputPath: '',
      message: e.toString(),
      elapsed: stop.elapsed,
    );
  }
}

ConversionResult _workerDecodeAvif(
  (String, String, String, int) args,
) {
  final (dllPath, input, output, jpegQuality) = args;
  final stop = Stopwatch()..start();

  try {
    final lib = DynamicLibrary.open(dllPath);
    final fn = lib.lookupFunction<_DecodeAvifNative, _DecodeAvifDart>(
      'converta_decode_avif',
    );

    final inPtr = input.toNativeUtf8();
    final outPtr = output.toNativeUtf8();

    try {
      final ret = fn(inPtr.cast<Char>(), outPtr.cast<Char>(), jpegQuality);
      stop.stop();
      return ConversionResult(
        success: ret == 0,
        outputPath: ret == 0 ? output : '',
        message: ret == 0 ? 'AVIF decode complete.' : _lastError(lib),
        elapsed: stop.elapsed,
      );
    } finally {
      malloc.free(inPtr);
      malloc.free(outPtr);
    }
  } catch (e) {
    stop.stop();
    return ConversionResult(
      success: false,
      outputPath: '',
      message: e.toString(),
      elapsed: stop.elapsed,
    );
  }
}

// ─── Public API ───────────────────────────────────────────────────────────────

class NativeBridge {
  NativeBridge._();

  /// Converts an animated GIF to MP4 using the C DLL.
  ///
  /// [progress] — optional StreamSink to receive 0.0–1.0 progress values.
  /// Note: spec listed `Stream<double>`; corrected to `StreamSink<double>` because
  ///       a Stream is a consumer, not a sink — you cannot push into it.
  static Future<ConversionResult> gifToMp4({
    required String input,
    required String output,
    int crf = 18,
    String preset = 'slow',
    StreamSink<double>? progress,
  }) async {
    final dll = _dllPath();
    if (!File(dll).existsSync()) return _dllMissing();

    ReceivePort? progressPort;
    StreamSubscription<dynamic>? progressSub;

    if (progress != null) {
      progressPort = ReceivePort();
      // Forward double values from the worker isolate to the caller's sink.
      progressSub = progressPort.listen((msg) {
        if (msg is double) progress.add(msg);
      });
    }

    final sendPort = progressPort?.sendPort;

    try {
      return await Isolate.run(
        () => _workerGifToMp4((dll, input, output, crf, preset, sendPort)),
        debugName: 'converta_gif_to_mp4',
      );
    } finally {
      await progressSub?.cancel();
      progressPort?.close();
    }
  }

  /// Encodes a JPEG/PNG/BMP image to AVIF using the C DLL.
  static Future<ConversionResult> encodeAvif({
    required String input,
    required String output,
    int quality = 80,
    int speed = 4,
  }) async {
    final dll = _dllPath();
    if (!File(dll).existsSync()) return _dllMissing();

    return Isolate.run(
      () => _workerEncodeAvif((dll, input, output, quality, speed)),
      debugName: 'converta_encode_avif',
    );
  }

  /// Decodes an AVIF image to JPEG or PNG using the C DLL.
  static Future<ConversionResult> decodeAvif({
    required String input,
    required String output,
    int jpegQuality = 90,
  }) async {
    final dll = _dllPath();
    if (!File(dll).existsSync()) return _dllMissing();

    return Isolate.run(
      () => _workerDecodeAvif((dll, input, output, jpegQuality)),
      debugName: 'converta_decode_avif',
    );
  }
}

ConversionResult _dllMissing() => const ConversionResult(
      success: false,
      outputPath: '',
      message:
          'converta_core.dll not found next to the executable. Build the native library first.',
      elapsed: Duration.zero,
    );
