import 'package:flutter/foundation.dart';

class CppBridge {
  static String getNewsData() {
    if (kIsWeb) {
      return '''[
        {
          "title": "Sample News Article",
          "description": "This is a sample news article for web platform",
          "url": "https://example.com",
          "date": "${DateTime.now().toIso8601String()}"
        }
      ]''';
    } else {
      // For native platforms, we would use FFI here
      // For now, return mock data until FFI is properly set up
      return '[]';
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
      return '{"location":"City","temperature":22,"conditions":"Sunny"}';
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
      return '[{"id":"1","title":"Sample task","completed":false}]';
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
      return '[{"from":"sender@example.com","subject":"Test","read":false}]';
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
