import 'dart:convert';

class MockDataService {
  static final MockDataService _instance = MockDataService._internal();
  factory MockDataService() => _instance;
  MockDataService._internal();

  // State management for todo items
  List<Map<String, dynamic>> todoItems = [];

  // Initialize with sample data
  void initialize() {
    if (todoItems.isEmpty) {
      _generateSampleData();
    }
  }

  void _generateSampleData() {
    todoItems = [
      {
        "id": "1",
        "title": "🎨 Complete modern dashboard UI redesign",
        "completed": true,
        "priority": "high",
        "category": "Development",
        "dueDate": DateTime.now()
                .subtract(Duration(hours: 2))
                .millisecondsSinceEpoch ~/
            1000,
        "createdAt":
            DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch ~/
                1000,
        "description":
            "Implement modern glassmorphism UI with better UX and animations"
      },
      {
        "id": "2",
        "title": "🔧 Fix dashboard data loading and functionality",
        "completed": false,
        "priority": "high",
        "category": "Bug Fix",
        "dueDate":
            DateTime.now().add(Duration(hours: 4)).millisecondsSinceEpoch ~/
                1000,
        "createdAt": DateTime.now()
                .subtract(Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
        "description":
            "Ensure all widgets display data correctly and respond to user interaction"
      },
      {
        "id": "3",
        "title": "🌐 Deploy web version with full functionality",
        "completed": false,
        "priority": "medium",
        "category": "Deployment",
        "dueDate":
            DateTime.now().add(Duration(days: 1)).millisecondsSinceEpoch ~/
                1000,
        "createdAt": DateTime.now()
                .subtract(Duration(minutes: 30))
                .millisecondsSinceEpoch ~/
            1000,
        "description":
            "Ensure web platform works seamlessly with responsive design"
      }
    ];
  }

  String getNewsData() {
    final newsItems = [
      {
        "title": "🌐 Modern Dashboard Successfully Deployed to Web",
        "source": "Tech News",
        "description":
            "Your beautiful glassmorphism dashboard is now running perfectly on the web platform with rich interactive features.",
        "url": "https://flutter.dev/web",
        "date": DateTime.now().toIso8601String()
      },
      {
        "title": "🎨 Glassmorphism Design Trends Dominate 2024 UI",
        "source": "Design Weekly",
        "description":
            "Modern interfaces are embracing blur effects, gradients, and transparency for premium user experiences.",
        "url": "https://design.systems",
        "date": DateTime.now().subtract(Duration(hours: 2)).toIso8601String()
      }
    ];
    return jsonEncode(newsItems);
  }

  String getWeatherData() {
    final weather = {
      "location": "San Francisco, CA",
      "temperature": 22.5,
      "conditions": "Partly Cloudy",
      "humidity": 65,
      "windSpeed": 8.2,
      "icon": "partly-cloudy-day",
      "lastUpdated": DateTime.now().millisecondsSinceEpoch ~/ 1000
    };
    return jsonEncode(weather);
  }

  String getTodoData() => jsonEncode(todoItems);

  String getMailData() {
    final mailItems = [
      {
        "id": "1",
        "from": "team@moderndashboard.app",
        "fromName": "Modern Dashboard Team",
        "subject": "🎉 Your Dashboard is Live and Looking Amazing!",
        "read": false,
        "timestamp": DateTime.now()
                .subtract(Duration(minutes: 15))
                .millisecondsSinceEpoch ~/
            1000,
      },
      {
        "id": "2",
        "from": "notifications@github.com",
        "fromName": "GitHub",
        "subject": "🔔 New commits pushed to ModernDashboard repository",
        "read": false,
        "timestamp": DateTime.now()
                .subtract(Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
      }
    ];
    return jsonEncode(mailItems);
  }

  String getStreamData() => '{"status": "active", "data": "Stream simulation"}';

  bool addTodoItem(String jsonData) {
    try {
      final Map<String, dynamic> newItem = jsonDecode(jsonData);
      todoItems.add(newItem);
      return true;
    } catch (e) {
      return false;
    }
  }

  bool updateTodoItem(String jsonData) {
    try {
      final Map<String, dynamic> updatedItem = jsonDecode(jsonData);
      final String itemId = updatedItem['id'] as String;
      final int index = todoItems.indexWhere((item) => item['id'] == itemId);

      if (index >= 0) {
        todoItems[index] = updatedItem;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  bool deleteTodoItem(String itemId) {
    try {
      todoItems.removeWhere((item) => item['id'] == itemId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
