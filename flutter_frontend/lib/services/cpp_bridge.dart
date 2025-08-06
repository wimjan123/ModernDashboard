import 'package:flutter/foundation.dart';

class CppBridge {
  static String getNewsData() {
    if (kIsWeb) {
      return '''[
        {
          "title": "Sample News Article",
          "description": "This is a sample news article for web platform",
          "source": "Web News",
          "url": "https://example.com",
          "date": "${DateTime.now().toIso8601String()}"
        }
      ]''';
    } else {
      // For native platforms, provide mock data until FFI is properly set up
      return '''[
        {
          "title": "Flutter Desktop App Running",
          "source": "Modern Dashboard",
          "description": "Your macOS app is working with mock data",
          "url": "https://flutter.dev",
          "date": "${DateTime.now().toIso8601String()}"
        },
        {
          "title": "Native Platform Detected",
          "source": "System Info",
          "description": "Running on desktop platform with fallback data",
          "url": "https://flutter.dev/desktop",
          "date": "${DateTime.now().subtract(Duration(hours: 1)).toIso8601String()}"
        }
      ]''';
    }
  }

  static String getWeatherData() {
    if (kIsWeb) {
      return '''{
        "location": "Web Platform",
        "temperature": 22,
        "conditions": "Simulated Weather",
        "humidity": 65,
        "windSpeed": 5
      }''';
    } else {
      return '''{
        "location": "macOS Desktop",
        "temperature": 24,
        "conditions": "Partly Cloudy",
        "humidity": 58,
        "windSpeed": 8
      }''';
    }
  }

  static String getTodoData() {
    if (kIsWeb) {
      return '''[
        {
          "id": "1",
          "title": "Sample Todo Item",
          "completed": false,
          "date": "${DateTime.now().toIso8601String()}"
        }
      ]''';
    } else {
      return '''[
        {
          "id": "1",
          "title": "Test macOS app functionality",
          "completed": false,
          "date": "${DateTime.now().toIso8601String()}"
        },
        {
          "id": "2", 
          "title": "Set up C++ FFI integration",
          "completed": false,
          "date": "${DateTime.now().add(Duration(hours: 1)).toIso8601String()}"
        }
      ]''';
    }
  }

  static String getMailData() {
    if (kIsWeb) {
      return '''[
        {
          "from": "demo@example.com",
          "subject": "Welcome to Modern Dashboard",
          "read": false,
          "date": "${DateTime.now().toIso8601String()}"
        }
      ]''';
    } else {
      return '''[
        {
          "from": "system@moderndashboard.app",
          "subject": "macOS App Successfully Launched",
          "read": false,
          "date": "${DateTime.now().toIso8601String()}"
        },
        {
          "from": "flutter@google.com", 
          "subject": "Desktop Platform Support Active",
          "read": true,
          "date": "${DateTime.now().subtract(Duration(minutes: 30)).toIso8601String()}"
        }
      ]''';
    }
  }

  static bool startStream(String streamUrl) {
    if (kIsWeb) {
      // For web, we might use WebSockets or other web APIs
      print('Web: Starting stream for $streamUrl');
      return true;
    } else {
      // For native platforms, this would call the FFI function
      return false;
    }
  }

  static bool initializeEngine() {
    if (kIsWeb) {
      print('Web: Dashboard engine initialized');
      return true;
    } else {
      // For native platforms, this would call the FFI function
      return true;
    }
  }

  static bool shutdownEngine() {
    if (kIsWeb) {
      print('Web: Dashboard engine shutdown');
      return true;
    } else {
      // For native platforms, this would call the FFI function
      return true;
    }
  }
}
