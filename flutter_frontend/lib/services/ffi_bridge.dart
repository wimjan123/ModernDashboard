import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart';

// Native signatures (C ABI)
typedef _init_native = ffi.Int32 Function();
typedef _ptr_char = ffi.Pointer<ffi.Char>;
typedef _noarg_str_native = _ptr_char Function();
typedef _str_int_native = ffi.Int32 Function(_ptr_char);
typedef _str_str_int_native = ffi.Int32 Function(_ptr_char, _ptr_char);
typedef _str_str_native = _ptr_char Function(_ptr_char);

// Dart typedefs
typedef _init_dart = int Function();
typedef _noarg_str_dart = _ptr_char Function();
typedef _str_int_dart = int Function(_ptr_char);
typedef _str_str_int_dart = int Function(_ptr_char, _ptr_char);
typedef _str_str_dart = _ptr_char Function(_ptr_char);

class FfiBridge {
  static ffi.DynamicLibrary? _lib;

  // Core
  static _init_dart? _initialize;
  static _str_str_int_dart? _updateWidgetConfig;
  static _init_dart? _shutdown;

  // News
  static _noarg_str_dart? _getNewsData;
  static _str_int_dart? _addNewsFeed;
  static _str_int_dart? _removeNewsFeed;

  // Stream
  static _str_int_dart? _startStream;
  static _str_int_dart? _stopStream;
  static _str_str_dart? _getStreamData;

  // Weather
  static _noarg_str_dart? _getWeatherData;
  static _str_int_dart? _updateWeatherLocation;

  // Todo
  static _noarg_str_dart? _getTodoData;
  static _str_int_dart? _addTodoItem;
  static _str_int_dart? _updateTodoItem;
  static _str_int_dart? _deleteTodoItem;

  // Mail
  static _noarg_str_dart? _getMailData;
  static _str_int_dart? _configureMailAccount;

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

    // Use direct lookup with explicit NativeFunction<...> to satisfy bounds
    _initialize = _lib!
        .lookup<ffi.NativeFunction<_init_native>>('initialize_dashboard_engine')
        .asFunction<_init_dart>();
    _shutdown = _lib!
        .lookup<ffi.NativeFunction<_init_native>>('shutdown_dashboard_engine')
        .asFunction<_init_dart>();
    _updateWidgetConfig = _lib!
        .lookup<ffi.NativeFunction<_str_str_int_native>>('update_widget_config')
        .asFunction<_str_str_int_dart>();

    _getNewsData = _lib!
        .lookup<ffi.NativeFunction<_noarg_str_native>>('get_news_data')
        .asFunction<_noarg_str_dart>();
    _addNewsFeed = _lib!
        .lookup<ffi.NativeFunction<_str_int_native>>('add_news_feed')
        .asFunction<_str_int_dart>();
    _removeNewsFeed = _lib!
        .lookup<ffi.NativeFunction<_str_int_native>>('remove_news_feed')
        .asFunction<_str_int_dart>();

    _startStream = _lib!
        .lookup<ffi.NativeFunction<_str_int_native>>('start_stream')
        .asFunction<_str_int_dart>();
    _stopStream = _lib!
        .lookup<ffi.NativeFunction<_str_int_native>>('stop_stream')
        .asFunction<_str_int_dart>();
    _getStreamData = _lib!
        .lookup<ffi.NativeFunction<_str_str_native>>('get_stream_data')
        .asFunction<_str_str_dart>();

    _getWeatherData = _lib!
        .lookup<ffi.NativeFunction<_noarg_str_native>>('get_weather_data')
        .asFunction<_noarg_str_dart>();
    _updateWeatherLocation = _lib!
        .lookup<ffi.NativeFunction<_str_int_native>>('update_weather_location')
        .asFunction<_str_int_dart>();

    _getTodoData = _lib!
        .lookup<ffi.NativeFunction<_noarg_str_native>>('get_todo_data')
        .asFunction<_noarg_str_dart>();
    _addTodoItem = _lib!
        .lookup<ffi.NativeFunction<_str_int_native>>('add_todo_item')
        .asFunction<_str_int_dart>();
    _updateTodoItem = _lib!
        .lookup<ffi.NativeFunction<_str_int_native>>('update_todo_item')
        .asFunction<_str_int_dart>();
    _deleteTodoItem = _lib!
        .lookup<ffi.NativeFunction<_str_int_native>>('delete_todo_item')
        .asFunction<_str_int_dart>();

    _getMailData = _lib!
        .lookup<ffi.NativeFunction<_noarg_str_native>>('get_mail_data')
        .asFunction<_noarg_str_dart>();
    _configureMailAccount = _lib!
        .lookup<ffi.NativeFunction<_str_int_native>>('configure_mail_account')
        .asFunction<_str_int_dart>();
  }

  static String _toDartString(_ptr_char ptr) {
    if (ptr == ffi.nullptr) return '';
    return ptr.cast<Utf8>().toDartString();
  }

  static _ptr_char _asUtf8(String? s) {
    if (s == null) return ffi.nullptr;
    return s.toNativeUtf8().cast<ffi.Char>();
  }

  // Public API
  static bool initializeEngine() {
    _ensureLoaded();
    final result = _initialize!.call();
    return result != 0;
  }

  static bool shutdownEngine() {
    _ensureLoaded();
    final result = _shutdown!.call();
    return result != 0;
  }

  static bool updateWidgetConfig(String widgetId, String configJson) {
    _ensureLoaded();
    final wid = _asUtf8(widgetId);
    final cfg = _asUtf8(configJson);
    try {
      final result = _updateWidgetConfig!.call(wid, cfg);
      return result != 0;
    } finally {
      malloc.free(wid);
      malloc.free(cfg);
    }
  }

  // News
  static String getNewsData() {
    _ensureLoaded();
    final ptr = _getNewsData!.call();
    return _toDartString(ptr);
  }

  static bool addNewsFeed(String url) {
    _ensureLoaded();
    final u = _asUtf8(url);
    try {
      final res = _addNewsFeed!.call(u);
      return res != 0;
    } finally {
      malloc.free(u);
    }
  }

  static bool removeNewsFeed(String url) {
    _ensureLoaded();
    final u = _asUtf8(url);
    try {
      final res = _removeNewsFeed!.call(u);
      return res != 0;
    } finally {
      malloc.free(u);
    }
  }

  // Stream
  static bool startStream(String url) {
    _ensureLoaded();
    final u = _asUtf8(url);
    try {
      final res = _startStream!.call(u);
      return res != 0;
    } finally {
      malloc.free(u);
    }
  }

  static bool stopStream(String streamId) {
    _ensureLoaded();
    final s = _asUtf8(streamId);
    try {
      final res = _stopStream!.call(s);
      return res != 0;
    } finally {
      malloc.free(s);
    }
  }

  static String getStreamData(String streamId) {
    _ensureLoaded();
    final s = _asUtf8(streamId);
    try {
      final ptr = _getStreamData!.call(s);
      return _toDartString(ptr);
    } finally {
      malloc.free(s);
    }
  }

  // Weather
  static String getWeatherData() {
    _ensureLoaded();
    final ptr = _getWeatherData!.call();
    return _toDartString(ptr);
  }

  static bool updateWeatherLocation(String location) {
    _ensureLoaded();
    final l = _asUtf8(location);
    try {
      final res = _updateWeatherLocation!.call(l);
      return res != 0;
    } finally {
      malloc.free(l);
    }
  }

  // Todo
  static String getTodoData() {
    _ensureLoaded();
    final ptr = _getTodoData!.call();
    return _toDartString(ptr);
  }

  static bool addTodoItem(String jsonData) {
    _ensureLoaded();
    final d = _asUtf8(jsonData);
    try {
      final res = _addTodoItem!.call(d);
      return res != 0;
    } finally {
      malloc.free(d);
    }
  }

  static bool updateTodoItem(String jsonData) {
    _ensureLoaded();
    final d = _asUtf8(jsonData);
    try {
      final res = _updateTodoItem!.call(d);
      return res != 0;
    } finally {
      malloc.free(d);
    }
  }

  static bool deleteTodoItem(String itemId) {
    _ensureLoaded();
    final i = _asUtf8(itemId);
    try {
      final res = _deleteTodoItem!.call(i);
      return res != 0;
    } finally {
      malloc.free(i);
    }
  }

  // Mail
  static String getMailData() {
    _ensureLoaded();
    final ptr = _getMailData!.call();
    return _toDartString(ptr);
  }

  static bool configureMailAccount(String jsonConfig) {
    _ensureLoaded();
    final c = _asUtf8(jsonConfig);
    try {
      final res = _configureMailAccount!.call(c);
      return res != 0;
    } finally {
      malloc.free(c);
    }
  }
}