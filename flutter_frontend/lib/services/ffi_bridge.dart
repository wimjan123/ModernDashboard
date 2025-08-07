import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/mock_data_service.dart';

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

  static bool get isSupported {
    if (_useMock) return true;
    if (!(Platform.isMacOS || Platform.isLinux || Platform.isWindows)) return false;
    _ensureLoaded();
    return _lib != null;
  }

  static bool get _useMock {
    // Prefer runtime dart-define, fallback to non-FFI platforms
    const useMockDefine =
        String.fromEnvironment('USE_MOCK_DATA', defaultValue: 'false');
    final envFlag = useMockDefine.toLowerCase() == 'true';
    // Web is handled by ffi_bridge_web.dart, but keep guard for completeness
    if (kIsWeb) return true;
    // Only allow mock on desktop targets
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      return envFlag;
    }
    return envFlag;
  }

  static void _ensureLoaded() {
    if (_useMock) {
      // Initialize shared mock once
      MockDataService().initialize();
      // Skip loading native libs entirely in mock mode
      return;
    }
    if (_lib != null) return;

    try {
      if (Platform.isMacOS) {
        // Try multiple locations for the .dylib file (including libmoderndash.dylib)
        print('FFI: Attempting to load macOS library...');
        final libPaths = [
          './moderndash.dylib',
          'moderndash.dylib', 
          './libmoderndash.dylib',
          'libmoderndash.dylib',
          '../build/moderndash.dylib',
          '../build/libmoderndash.dylib',
          './build/moderndash.dylib',
          './build/libmoderndash.dylib',
          '/usr/local/lib/moderndash.dylib',
          '/usr/local/lib/libmoderndash.dylib'
        ];
        
        bool loaded = false;
        for (final path in libPaths) {
          try {
            print('FFI: Trying $path');
            _lib = ffi.DynamicLibrary.open(path);
            print('FFI: ✅ Successfully loaded $path');
            loaded = true;
            break;
          } catch (e) {
            print('FFI: ❌ Failed $path: $e');
          }
        }
        
        if (!loaded) {
          throw Exception('FFI: Could not load any .dylib variant. Tried: ${libPaths.join(', ')}');
        }
      } else if (Platform.isLinux) {
        // Try multiple locations for the .so file
        print('FFI: Attempting to load Linux library...');
        final libPaths = [
          './moderndash.so',
          'moderndash.so',
          '../build/libmoderndash.so',
          './build/libmoderndash.so',  
          '/root/claude/ModernDashboard/build/libmoderndash.so',
          './libmoderndash.so',
          'libmoderndash.so',
          '/usr/local/lib/moderndash.so',
          '/usr/local/lib/libmoderndash.so'
        ];
        
        bool loaded = false;
        for (final path in libPaths) {
          try {
            print('FFI: Trying $path');
            _lib = ffi.DynamicLibrary.open(path);
            print('FFI: ✅ Successfully loaded $path');
            loaded = true;
            break;
          } catch (e) {
            print('FFI: ❌ Failed $path: $e');
          }
        }
        
        if (!loaded) {
          throw Exception('FFI: Could not load any .so variant. Tried: ${libPaths.join(', ')}');
        }
      } else if (Platform.isWindows) {
        _lib = ffi.DynamicLibrary.open('moderndash.dll');
      } else {
        throw UnsupportedError('FFI not supported on this platform');
      }
    } catch (e) {
      // If library loading fails, this will cause isSupported to be false
      // and the fallback to CppBridge will be used
      throw Exception('Failed to load native library: $e');
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
    try {
      print('FFI: initializeEngine() starting...');
      _ensureLoaded();
      if (_useMock) {
        print('FFI: Using mock mode (USE_MOCK_DATA=true)');
        return true;
      }
      
      if (_lib == null) {
        print('FFI: ❌ Library not loaded, cannot initialize');
        return false;
      }
      
      if (_initialize == null) {
        print('FFI: ❌ initialize_dashboard_engine function not found');
        return false;
      }
      
      print('FFI: Calling native initialize_dashboard_engine()...');
      final result = _initialize!.call();
      final success = result != 0;
      print('FFI: initialize_dashboard_engine() returned: $result (success: $success)');
      return success;
    } catch (e) {
      print('FFI: ❌ initializeEngine failed with exception: $e');
      return false;
    }
  }

  static bool shutdownEngine() {
    _ensureLoaded();
    if (_useMock) return true;
    final result = _shutdown!.call();
    return result != 0;
  }

  static bool updateWidgetConfig(String widgetId, String configJson) {
    _ensureLoaded();
    if (_useMock) return true;
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
    try {
      print('FFI: getNewsData() called');
      _ensureLoaded();
      if (_useMock) {
        print('FFI: Using mock data for news');
        return MockDataService().getNewsData();
      }
      
      if (_lib == null) {
        print('FFI: ❌ Library not loaded for getNewsData, falling back to mock data');
        return MockDataService().getNewsData();
      }
      
      if (_getNewsData == null) {
        print('FFI: ❌ get_news_data function not found, falling back to mock data');
        return MockDataService().getNewsData();
      }
      
      print('FFI: Calling native get_news_data()...');
      final ptr = _getNewsData!.call();
      final result = _toDartString(ptr);
      print('FFI: get_news_data() returned ${result.length} chars: ${result.substring(0, result.length.clamp(0, 100))}${result.length > 100 ? '...' : ''}');
      return result;
    } catch (e) {
      print('FFI: ❌ getNewsData failed: $e, falling back to mock data');
      return MockDataService().getNewsData();
    }
  }

  static bool addNewsFeed(String url) {
    _ensureLoaded();
    if (_useMock) return true;
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
    if (_useMock) return true;
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
    if (_useMock) return true;
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
    if (_useMock) return true;
    final s = _asUtf8(streamId);
    try {
      final res = _stopStream!.call(s);
      return res != 0;
    } finally {
      malloc.free(s);
    }
  }

  static String getStreamData(String streamId) {
    try {
      _ensureLoaded();
      if (_useMock) return MockDataService().getStreamData();
      
      if (_lib == null || _getStreamData == null) {
        print('FFI: ❌ Library or function not available for getStreamData, falling back to mock data');
        return MockDataService().getStreamData();
      }
      
      final s = _asUtf8(streamId);
      try {
        final ptr = _getStreamData!.call(s);
        return _toDartString(ptr);
      } finally {
        malloc.free(s);
      }
    } catch (e) {
      print('FFI getStreamData failed: $e, falling back to mock data');
      return MockDataService().getStreamData();
    }
  }

  // Weather
  static String getWeatherData() {
    try {
      _ensureLoaded();
      if (_useMock) return MockDataService().getWeatherData();
      
      if (_lib == null || _getWeatherData == null) {
        print('FFI: ❌ Library or function not available for getWeatherData, falling back to mock data');
        return MockDataService().getWeatherData();
      }
      
      final ptr = _getWeatherData!.call();
      return _toDartString(ptr);
    } catch (e) {
      print('FFI getWeatherData failed: $e, falling back to mock data');
      return MockDataService().getWeatherData();
    }
  }

  static bool updateWeatherLocation(String location) {
    _ensureLoaded();
    if (_useMock) return true;
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
    try {
      _ensureLoaded();
      if (_useMock) return MockDataService().getTodoData();
      
      if (_lib == null || _getTodoData == null) {
        print('FFI: ❌ Library or function not available for getTodoData, falling back to mock data');
        return MockDataService().getTodoData();
      }
      
      final ptr = _getTodoData!.call();
      return _toDartString(ptr);
    } catch (e) {
      print('FFI getTodoData failed: $e, falling back to mock data');
      return MockDataService().getTodoData();
    }
  }

  static bool addTodoItem(String jsonData) {
    _ensureLoaded();
    if (_useMock) return MockDataService().addTodoItem(jsonData);
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
    if (_useMock) return MockDataService().updateTodoItem(jsonData);
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
    if (_useMock) return MockDataService().deleteTodoItem(itemId);
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
    try {
      _ensureLoaded();
      if (_useMock) return MockDataService().getMailData();
      
      if (_lib == null || _getMailData == null) {
        print('FFI: ❌ Library or function not available for getMailData, falling back to mock data');
        return MockDataService().getMailData();
      }
      
      final ptr = _getMailData!.call();
      return _toDartString(ptr);
    } catch (e) {
      print('FFI getMailData failed: $e, falling back to mock data');
      return MockDataService().getMailData();
    }
  }

  static bool configureMailAccount(String jsonConfig) {
    _ensureLoaded();
    if (_useMock) return true;
    final c = _asUtf8(jsonConfig);
    try {
      final res = _configureMailAccount!.call(c);
      return res != 0;
    } finally {
      malloc.free(c);
    }
  }
}
