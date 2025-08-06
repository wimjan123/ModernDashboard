import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

class CppBridge {
  static final DynamicLibrary _dylib = Platform.isWindows
      ? DynamicLibrary.open('dashboard_backend.dll')
      : Platform.isMacOS
          ? DynamicLibrary.open('libdashboard_backend.dylib')
          : DynamicLibrary.open('libdashboard_backend.so');

  // Function signatures
  static final Pointer<Utf8> Function() _getNewsData = _dylib
      .lookup<NativeFunction<Pointer<Utf8> Function()>>('get_news_data')
      .asFunction();

  static final Pointer<Utf8> Function() _getWeatherData = _dylib
      .lookup<NativeFunction<Pointer<Utf8> Function()>>('get_weather_data')
      .asFunction();

  static final Pointer<Utf8> Function() _getTodoData = _dylib
      .lookup<NativeFunction<Pointer<Utf8> Function()>>('get_todo_data')
      .asFunction();

  static final Pointer<Utf8> Function() _getMailData = _dylib
      .lookup<NativeFunction<Pointer<Utf8> Function()>>('get_mail_data')
      .asFunction();

  static final int Function(Pointer<Utf8>) _startStream = _dylib
      .lookup<NativeFunction<Int32 Function(Pointer<Utf8>)>>('start_stream')
      .asFunction();

  static final int Function() _initializeEngine = _dylib
      .lookup<NativeFunction<Int32 Function()>>('initialize_dashboard_engine')
      .asFunction();

  static final int Function() _shutdownEngine = _dylib
      .lookup<NativeFunction<Int32 Function()>>('shutdown_dashboard_engine')
      .asFunction();

  // Wrapper methods
  static String getNewsData() {
    final result = _getNewsData();
    return result.toDartString();
  }

  static String getWeatherData() {
    final result = _getWeatherData();
    return result.toDartString();
  }

  static String getTodoData() {
    final result = _getTodoData();
    return result.toDartString();
  }

  static String getMailData() {
    final result = _getMailData();
    return result.toDartString();
  }

  static bool startStream(String streamUrl) {
    final urlPointer = streamUrl.toNativeUtf8();
    final result = _startStream(urlPointer);
    malloc.free(urlPointer);
    return result == 1;
  }

  static bool initializeEngine() {
    return _initializeEngine() == 1;
  }

  static bool shutdownEngine() {
    return _shutdownEngine() == 1;
  }
}
