import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

// Import Utf8 and conversion helpers from package:ffi
import 'package:ffi/ffi.dart';

typedef _init_native = ffi.Int32 Function();
typedef _init_dart = int Function();

// Represent const char* as Pointer<ffi.Char> in Dart FFI (Dart 3+)
typedef _get_news_native = ffi.Pointer<ffi.Char> Function();
typedef _get_news_dart = ffi.Pointer<ffi.Char> Function();

class FfiBridge {
  static ffi.DynamicLibrary? _lib;
  static _init_dart? _initialize;
  static _get_news_dart? _getNewsData;

  // Support macOS/Linux/Windows; exclude mobile/web
  static bool get isSupported => Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  static void _ensureLoaded() {
    if (_lib != null) return;

    if (Platform.isMacOS) {
      _lib = ffi.DynamicLibrary.open('libmoderndash.dylib');
    } else if (Platform.isLinux) {
      _lib = ffi.DynamicLibrary.open('libmoderndash.so');
    } else if (Platform.isWindows) {
      _lib = ffi.DynamicLibrary.open('moderndash.dll');
    } else {
      throw UnsupportedError('FFI not supported on this platform');
    }

    _initialize = _lib!
        .lookup<ffi.NativeFunction<_init_native>>('initialize_dashboard_engine')
        .asFunction<_init_dart>();

    _getNewsData = _lib!
        .lookup<ffi.NativeFunction<_get_news_native>>('get_news_data')
        .asFunction<_get_news_dart>();
  }

  static bool initializeEngine() {
    _ensureLoaded();
    final result = _initialize!.call();
    return result != 0;
  }

  static String getNewsData() {
    _ensureLoaded();
    final ffi.Pointer<ffi.Char> ptr = _getNewsData!.call();
    // Convert zero-terminated C string to Dart string using package:ffi
    return ptr.cast<Utf8>().toDartString();
  }
}