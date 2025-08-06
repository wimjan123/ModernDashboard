// Web implementation that provides mock data
import 'cpp_bridge_stub.dart';

CppBridgeInterface createCppBridge() => _CppBridgeWeb();

class _CppBridgeWeb implements CppBridgeInterface {
  @override
  String getNewsData() {
    // Mock data for web platform
    return '''[
      {
        "title": "Sample News Article",
        "description": "This is a sample news article for web platform",
        "url": "https://example.com",
        "date": "${DateTime.now().toIso8601String()}"
      }
    ]''';
  }

  @override
  String getWeatherData() {
    return '''{
      "location": "Web Platform",
      "temperature": 22,
      "conditions": "Simulated Weather",
      "humidity": 65,
      "windSpeed": 5
    }''';
  }

  @override
  String getTodoData() {
    return '''[
      {
        "id": "1",
        "title": "Sample Todo Item",
        "completed": false,
        "date": "${DateTime.now().toIso8601String()}"
      }
    ]''';
  }

  @override
  String getMailData() {
    return '''[
      {
        "from": "demo@example.com",
        "subject": "Welcome to Modern Dashboard",
        "read": false,
        "date": "${DateTime.now().toIso8601String()}"
      }
    ]''';
  }

  @override
  bool startStream(String streamUrl) {
    // For web, we might use WebSockets or other web APIs
    print('Web: Starting stream for $streamUrl');
    return true;
  }

  @override
  bool initializeEngine() {
    print('Web: Dashboard engine initialized');
    return true;
  }

  @override
  bool shutdownEngine() {
    print('Web: Dashboard engine shutdown');
    return true;
  }
}