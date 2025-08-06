import 'package:flutter/foundation.dart';
import 'mock_data_service.dart';

class CppBridge {
  static String getNewsData() {
    // Use shared mock service for consistency across platforms
    return MockDataService().getNewsData();
  }

  static String getWeatherData() {
    return MockDataService().getWeatherData();
  }

  static String getTodoData() {
    return MockDataService().getTodoData();
  }

  static String getMailData() {
    return MockDataService().getMailData();
  }

  static bool startStream(String streamUrl) {
    return true; // Simulate success
  }

  static bool initializeEngine() {
    MockDataService().initialize();
    return true;
  }

  static bool shutdownEngine() {
    return true;
  }
  
  // Add todo management methods for compatibility
  static bool updateTodoItem(String jsonData) {
    return MockDataService().updateTodoItem(jsonData);
  }
  
  static bool addTodoItem(String jsonData) {
    return MockDataService().addTodoItem(jsonData);
  }
  
  static bool deleteTodoItem(String itemId) {
    return MockDataService().deleteTodoItem(itemId);
  }
}
