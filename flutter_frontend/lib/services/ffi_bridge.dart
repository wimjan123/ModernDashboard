import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

typedef _init_native = ffi.Int32 Function();
typedef _init_dart = int Function();

typedef _get_news_native = ffi.Pointer<ffi.Utf8> Function();
typedef _get_news_dart = ffi.Pointer<ffi.Utf8> Function();

class FfiBridge {
  static ffi.DynamicLibrary? _lib;
  static _init_dart? _initialize;
  static _get_news_dart? _getNewsData;

  static bool get isSupported => !Platform.isAndroid && !Platform.isIOS && !Platform.isLinux && !Platform.isWindows ? Platform.isMacOS : (Platform.isLinux || Platform.isWindows);

  static void _ensureLoaded() {
    if (_lib != null) return;

    if (Platform.isMacOS) {
      // Expect libmoderndash.dylib to be discoverable via @rpath inside Flutter macOS app bundle
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
    final ptr = _getNewsData!.call();
    // Convert C string (Utf8) to Dart string without taking ownership (C-side holds static/memoized buffers)
    return ptr.cast<ffi.Utf8>().toDartString();
  }
}

// Utf8 helpers: since we avoid external packages, implement minimal toDartString
extension _Utf8Pointer on ffi.Pointer<ffi.Utf8> {
  String toDartString() {
    final List<int> codeUnits = [];
    int offset = 0;
    while (true) {
      final int byte = this.elementAt(offset).value;
      if (byte == 0) break;
      codeUnits.add(byte);
      offset += 1;
    }
    return String.fromCharCodes(codeUnits);
  }
}