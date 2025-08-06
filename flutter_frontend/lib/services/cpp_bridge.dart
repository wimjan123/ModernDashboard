// Conditional imports for platform-specific code
import 'cpp_bridge_stub.dart'
    if (dart.library.ffi) 'cpp_bridge_ffi.dart'
    if (dart.library.html) 'cpp_bridge_web.dart';

// Main CppBridge class that delegates to platform-specific implementations
class CppBridge {
  static final CppBridgeInterface _bridge = createCppBridge();

  static String getNewsData() => _bridge.getNewsData();
  static String getWeatherData() => _bridge.getWeatherData();
  static String getTodoData() => _bridge.getTodoData();
  static String getMailData() => _bridge.getMailData();
  static bool startStream(String streamUrl) => _bridge.startStream(streamUrl);
  static bool initializeEngine() => _bridge.initializeEngine();
  static bool shutdownEngine() => _bridge.shutdownEngine();
}
