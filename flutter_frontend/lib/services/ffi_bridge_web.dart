// Web stub for FFI Bridge
// This file is used on web platform where FFI is not available
// Returns rich mock data for a functional web experience

import 'dart:convert';

class FfiBridge {
  static bool get isSupported => false;
  
  // Static state for todo items (simulates backend state)
  static List<Map<String, dynamic>> _todoItems = [];

  static bool initializeEngine() {
    // Initialize with sample todo items if empty
    if (_todoItems.isEmpty) {
      _todoItems = [
        {
          "id": "1",
          "title": "🎨 Complete modern dashboard UI redesign",
          "completed": true,
          "priority": "high",
          "category": "Development", 
          "dueDate": DateTime.now().subtract(Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
          "createdAt": DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
          "description": "Implement modern glassmorphism UI with better UX and animations"
        },
        {
          "id": "2",
          "title": "🔧 Fix dashboard data loading and functionality", 
          "completed": false,
          "priority": "high",
          "category": "Bug Fix",
          "dueDate": DateTime.now().add(Duration(hours: 4)).millisecondsSinceEpoch ~/ 1000,
          "createdAt": DateTime.now().subtract(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
          "description": "Ensure all widgets display data correctly and respond to user interaction"
        },
        {
          "id": "3", 
          "title": "🌐 Deploy web version with full functionality",
          "completed": false,
          "priority": "medium",
          "category": "Deployment",
          "dueDate": DateTime.now().add(Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
          "createdAt": DateTime.now().subtract(Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000,
          "description": "Ensure web platform works seamlessly with responsive design"
        },
        {
          "id": "4",
          "title": "🚀 Add real-time data integration",
          "completed": false,
          "priority": "low",
          "category": "Enhancement",
          "dueDate": DateTime.now().add(Duration(days: 3)).millisecondsSinceEpoch ~/ 1000,
          "createdAt": DateTime.now().subtract(Duration(minutes: 10)).millisecondsSinceEpoch ~/ 1000,
          "description": "Connect to live APIs for weather, news, and email data"
        }
      ];
    }
    return true; // Return true to show "Dashboard Online"
  }
  
  static bool shutdownEngine() => true;

  static String getNewsData() => '''[
    {
      "title": "🌐 Modern Dashboard Successfully Deployed to Web",
      "source": "Tech News",
      "description": "Your beautiful glassmorphism dashboard is now running perfectly on the web platform with rich interactive features.",
      "url": "https://flutter.dev/web",
      "date": "${DateTime.now().toIso8601String()}"
    },
    {
      "title": "🎨 Glassmorphism Design Trends Dominate 2024 UI",
      "source": "Design Weekly", 
      "description": "Modern interfaces are embracing blur effects, gradients, and transparency for premium user experiences.",
      "url": "https://design.systems",
      "date": "${DateTime.now().subtract(Duration(hours: 2)).toIso8601String()}"
    },
    {
      "title": "⚡ Flutter Web Performance Optimizations Released",
      "source": "Flutter Team",
      "description": "Latest updates bring significant improvements to web rendering performance and loading times.",
      "url": "https://flutter.dev/performance", 
      "date": "${DateTime.now().subtract(Duration(hours: 4)).toIso8601String()}"
    },
    {
      "title": "🔥 Cross-Platform Development Reaches New Heights",
      "source": "Developer Today",
      "description": "Single codebase solutions now deliver native-quality experiences across all platforms.",
      "url": "https://crossplatform.dev",
      "date": "${DateTime.now().subtract(Duration(hours: 6)).toIso8601String()}"
    }
  ]''';

  static String getWeatherData() => '''{
    "location": "San Francisco, CA",
    "temperature": 22.5,
    "conditions": "Partly Cloudy",
    "humidity": 65,
    "windSpeed": 8.2,
    "pressure": 1013.2,
    "visibility": 16.1,
    "uvIndex": 4,
    "icon": "partly-cloudy-day",
    "lastUpdated": "${DateTime.now().millisecondsSinceEpoch ~/ 1000}"
  }''';

  static String getTodoData() {
    // Return current state as JSON
    return jsonEncode(_todoItems);
  }

  static String getMailData() => '''[
    {
      "id": "1",
      "from": "team@moderndashboard.app",
      "fromName": "Modern Dashboard Team",
      "subject": "🎉 Your Dashboard is Live and Looking Amazing!",
      "read": false,
      "priority": "normal",
      "timestamp": "${DateTime.now().subtract(Duration(minutes: 15)).millisecondsSinceEpoch ~/ 1000}",
      "preview": "Congratulations! Your modern dashboard is now fully operational with beautiful glassmorphism design...",
      "category": "updates",
      "hasAttachments": false
    },
    {
      "id": "2",
      "from": "notifications@github.com", 
      "fromName": "GitHub",
      "subject": "🔔 New commits pushed to ModernDashboard repository",
      "read": false,
      "priority": "low",
      "timestamp": "${DateTime.now().subtract(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000}",
      "preview": "Recent updates include major UI improvements and functionality fixes for your dashboard project...",
      "category": "notifications", 
      "hasAttachments": false
    },
    {
      "id": "3",
      "from": "flutter-dev@google.com",
      "fromName": "Flutter Team",
      "subject": "📱 Flutter Web: Performance Best Practices",
      "read": true,
      "priority": "low", 
      "timestamp": "${DateTime.now().subtract(Duration(hours: 6)).millisecondsSinceEpoch ~/ 1000}",
      "preview": "Learn about the latest optimizations and techniques for building fast, responsive web applications...",
      "category": "education",
      "hasAttachments": true
    },
    {
      "id": "4",
      "from": "design@moderndashboard.app",
      "fromName": "Design System Team", 
      "subject": "🎨 New Design System Components Available",
      "read": true,
      "priority": "low",
      "timestamp": "${DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch ~/ 1000}",
      "preview": "Check out our latest glassmorphism components, animations, and responsive layouts for modern apps...",
      "category": "design",
      "hasAttachments": false
    }
  ]''';

  // Static methods that don't need functionality on web but should return success
  static bool updateWidgetConfig(String widgetId, String configJson) => true;
  static bool addNewsFeed(String url) => true;
  static bool removeNewsFeed(String url) => true;
  static bool startStream(String url) => true;
  static bool stopStream(String streamId) => true;
  static String getStreamData(String streamId) => '{"status": "active", "data": "Web stream simulation"}';
  static bool updateWeatherLocation(String location) => true;
  static bool addTodoItem(String jsonData) {
    try {
      final Map<String, dynamic> newItem = jsonDecode(jsonData);
      _todoItems.add(newItem);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  static bool updateTodoItem(String jsonData) {
    try {
      final Map<String, dynamic> updatedItem = jsonDecode(jsonData);
      final String itemId = updatedItem['id'] as String;
      final int index = _todoItems.indexWhere((item) => item['id'] == itemId);
      
      if (index >= 0) {
        _todoItems[index] = updatedItem;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  static bool deleteTodoItem(String itemId) {
    try {
      _todoItems.removeWhere((item) => item['id'] == itemId);
      return true;
    } catch (e) {
      return false;
    }
  }
  static bool configureMailAccount(String jsonConfig) => true;
}