import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart';

// Common typedefs
typedef _init_native = ffi.Int32 Function();
typedef _init_dart = int Function();

typedef _ptr_char = ffi.Pointer<ffi.Char>;

// Functions with no args returning const char*
typedef _noarg_str_native = _ptr_char Function();
typedef _noarg_str_dart = _ptr_char Function();

// Functions taking (const char*) and returning int
typedef _str_int_native = ffi.Int32 Function(_ptr_char);
typedef _str_int_dart = int Function(_ptr_char);

// Functions taking (const char*, const char*) and returning int
typedef _str_str_int_native = ffi.Int32 Function(_ptr_char, _ptr_char);
typedef _str_str_int_dart = int Function(_ptr_char, _ptr_char);

// Functions taking (const char*) and returning const char*
typedef _str_str_native = _ptr_char Function(_ptr_char);
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

  // Platform support
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

    // Core
    _initialize = _lookup<_init_native, _init_dart>('initialize_dashboard_engine');
    _shutdown = _lookup<_init_native, _init_dart>('shutdown_dashboard_engine');
    _updateWidgetConfig = _lookup<_str_str_int_native, _str_str_int_dart>('update_widget_config');

    // News
    _getNewsData = _lookup<_noarg_str_native, _noarg_str_dart>('get_news_data');
    _addNewsFeed = _lookup<_str_int_native, _str_int_dart>('add_news_feed');
    _removeNewsFeed = _lookup<_str_int_native, _str_int_dart>('remove_news_feed');

    // Stream
    _startStream = _lookup<_str_int_native, _str_int_dart>('start_stream');
    _stopStream = _lookup<_str_int_native, _str_int_dart>('stop_stream');
    _getStreamData = _lookup<_str_str_native, _str_str_dart>('get_stream_data');

    // Weather
    _getWeatherData = _lookup<_noarg_str_native, _noarg_str_dart>('get_weather_data');
    _updateWeatherLocation = _lookup<_str_int_native, _str_int_dart>('update_weather_location');

    // Todo
    _getTodoData = _lookup<_noarg_str_native, _noarg_str_dart>('get_todo_data');
    _addTodoItem = _lookup<_str_int_native, _str_int_dart>('add_todo_item');
    _updateTodoItem = _lookup<_str_int_native, _str_int_dart>('update_todo_item');
    _deleteTodoItem = _lookup<_str_int_native, _str_int_dart>('delete_todo_item');

    // Mail
    _getMailData = _lookup<_noarg_str_native, _noarg_str_dart>('get_mail_data');
    _configureMailAccount = _lookup<_str_int_native, _str_int_dart>('configure_mail_account');
  }

  static TFunc _lookup<TNative extends ffi.NativeType, TFunc extends Function>(String symbol) {
    return _lib!
        .lookup<ffi.NativeFunction<TNative>>(symbol)
        .asFunction<TFunc>();
  }

  // Helpers
  static String _toDartString(_ptr_char ptr) {
    if (ptr == ffi.nullptr) return '';
    return ptr.cast<Utf8>().toDartString();
  }

  static _ptr_char _asUtf8(String? s) {
    if (s == null) return ffi.nullptr;
    return s.toNativeUtf8().cast<ffi.Char>();
  }

  // Public API

  // Core
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