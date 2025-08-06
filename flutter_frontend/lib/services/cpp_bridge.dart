import 'package:flutter/foundation.dart';

class CppBridge {
  static String getNewsData() {
    // CppBridge fallback - return empty to make FFI failure obvious
    debugPrint('CppBridge: getNewsData() called - FFI failed, no native data available');
    return '[]';
  }

  static String getWeatherData() {
    debugPrint('CppBridge: getWeatherData() called - FFI failed, no native data available');
    return '{}';
  }

  static String getTodoData() {
    debugPrint('CppBridge: getTodoData() called - FFI failed, no native data available');
    return '[]';
  }

  static String getMailData() {
    debugPrint('CppBridge: getMailData() called - FFI failed, no native data available');
    return '[]';
  }

  static bool startStream(String streamUrl) {
    debugPrint('CppBridge: startStream() called - FFI failed, cannot start stream');
    return false;
  }

  static bool initializeEngine() {
    debugPrint('CppBridge: initializeEngine() called - this indicates FFI loading failed');
    return false; // Return false to indicate failure
  }

  static bool shutdownEngine() {
    return true;
  }
  
  // Add todo management methods for compatibility
  static bool updateTodoItem(String jsonData) {
    debugPrint('CppBridge: updateTodoItem() called - FFI failed, cannot update todos');
    return false;
  }
  
  static bool addTodoItem(String jsonData) {
    debugPrint('CppBridge: addTodoItem() called - FFI failed, cannot add todos');
    return false;
  }
  
  static bool deleteTodoItem(String itemId) {
    debugPrint('CppBridge: deleteTodoItem() called - FFI failed, cannot delete todos');
    return false;
  }
}
