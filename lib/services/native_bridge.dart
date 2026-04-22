import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../models/conversion_job.dart';

// ─── C type signatures ────────────────────────────────────────────────────────

typedef _ProgressCbNative = Void Function(Double, Pointer<Void>);

typedef _GifToMp4Native = Int32 Function(
  Pointer<Char>, Pointer<Char>, Int32, Pointer<Char>,
  Pointer<NativeFunction<_ProgressCbNative>>, Pointer<Void>,
);
typedef _GifToMp4Dart = int Function(
  Pointer<Char>, Pointer<Char>, int, Pointer<Char>,
  Pointer<NativeFunction<_ProgressCbNative>>, Pointer<Void>,
);

typedef _LastErrorNative = Pointer<Char> Function();
typedef _LastErrorDart  = Pointer<Char> Function();

// ─── Helpers (top-level — Sendable across isolates) ──────────────────────────

String _dllPath() {
  final dir = File(Platform.resolvedExecutable).parent.path;
  return '$dir\\converta_core.dll';
}

String _lastError(DynamicLibrary lib) {
  try {
    final fn = lib.lookupFunction<_LastErrorNative, _LastErrorDart>(
        'converta_last_error');
    return fn().cast<Utf8>().toDartString();
  } catch (_) {
    return 'unknown error';
  }
}

// ─── GIF→MP4 isolate worker ───────────────────────────────────────────────────

ConversionResult _workerGifToMp4(
  (String, String, String, int, String, SendPort?) args,
) {
  final (dllPath, input, output, crf, preset, sendPort) = args;
  final sw = Stopwatch()..start();

  try {
    final lib = DynamicLibrary.open(dllPath);
    final fn  = lib.lookupFunction<_GifToMp4Native, _GifToMp4Dart>(
        'converta_gif_to_mp4');

    final inPtr     = input.toNativeUtf8();
    final outPtr    = output.toNativeUtf8();
    final presetPtr = preset.toNativeUtf8();

    NativeCallable<_ProgressCbNative>? nativeCb;
    var cbPtr = Pointer<NativeFunction<_ProgressCbNative>>.fromAddress(0);

    if (sendPort != null) {
      nativeCb = NativeCallable<_ProgressCbNative>.isolateLocal(
        (double p, Pointer<Void> _) => sendPort.send(p),
      );
      cbPtr = nativeCb.nativeFunction;
    }

    try {
      final ret = fn(
        inPtr.cast<Char>(), outPtr.cast<Char>(),
        crf, presetPtr.cast<Char>(),
        cbPtr, Pointer<Void>.fromAddress(0),
      );
      sw.stop();
      return ConversionResult(
        success: ret == 0,
        outputPath: ret == 0 ? output : '',
        message: ret == 0 ? 'GIF → MP4 complete.' : _lastError(lib),
        elapsed: sw.elapsed,
      );
    } finally {
      malloc.free(inPtr);
      malloc.free(outPtr);
      malloc.free(presetPtr);
      nativeCb?.close();
    }
  } catch (e) {
    sw.stop();
    return ConversionResult(
        success: false, outputPath: '', message: '$e', elapsed: sw.elapsed);
  }
}

// ─── Public API ───────────────────────────────────────────────────────────────

class NativeBridge {
  NativeBridge._();

  /// Converts an animated GIF to MP4 via converta_core.dll.
  /// The DLL drives the bundled ffmpeg.exe using CreateProcess (no PATH dep).
  static Future<ConversionResult> gifToMp4({
    required String input,
    required String output,
    int crf = 18,
    String preset = 'veryfast',
    StreamSink<double>? progress,
  }) async {
    final dll = _dllPath();
    if (!File(dll).existsSync()) {
      return const ConversionResult(
        success: false,
        outputPath: '',
        message: 'converta_core.dll not found. Build the native library first.',
        elapsed: Duration.zero,
      );
    }

    ReceivePort? port;
    StreamSubscription<dynamic>? sub;
    if (progress != null) {
      port = ReceivePort();
      sub = port.listen((m) { if (m is double) progress.add(m); });
    }

    try {
      return await Isolate.run(
        () => _workerGifToMp4((dll, input, output, crf, preset, port?.sendPort)),
        debugName: 'converta_gif_to_mp4',
      );
    } finally {
      await sub?.cancel();
      port?.close();
    }
  }
}
