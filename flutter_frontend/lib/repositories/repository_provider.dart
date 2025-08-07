import 'package:flutter/foundation.dart';
import '../firebase/firebase_service.dart';
import 'todo_repository.dart';
import 'weather_repository.dart';
import 'news_repository.dart';
import 'firestore_todo_repository.dart';
import 'cloud_weather_repository.dart';
import 'cloud_news_repository.dart';

// Conditional imports - avoid FFI on web platform
import 'legacy_ffi_todo_repository.dart' if (dart.library.js_interop) 'mock_todo_repository.dart';

class RepositoryProvider extends ChangeNotifier {
  static RepositoryProvider? _instance;
  static RepositoryProvider get instance => _instance ??= RepositoryProvider._();
  
  RepositoryProvider._();

  TodoRepository? _todoRepository;
  WeatherRepository? _weatherRepository;
  NewsRepository? _newsRepository;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Environment variables and feature flags
  static const bool _useFirebaseTodos = 
      bool.fromEnvironment('USE_FIREBASE_TODOS', defaultValue: true);
  static const bool _useCloudFunctions = 
      bool.fromEnvironment('USE_CLOUD_FUNCTIONS', defaultValue: true);
  static const bool _enableOfflineMode = 
      bool.fromEnvironment('ENABLE_OFFLINE_MODE', defaultValue: true);

  /// Initialize all repositories
  Future<void> initialize() async {
    try {
      // Ensure Firebase is initialized first
      if (!FirebaseService.instance.isInitialized) {
        throw Exception('Firebase service must be initialized first');
      }

      // Initialize repositories based on configuration
      await _initializeTodoRepository();
      await _initializeWeatherRepository();
      await _initializeNewsRepository();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to initialize repositories: $e');
    }
  }

  /// Get TodoRepository instance
  TodoRepository get todoRepository {
    if (_todoRepository == null) {
      throw Exception('TodoRepository not initialized. Call initialize() first.');
    }
    return _todoRepository!;
  }

  /// Get WeatherRepository instance
  WeatherRepository get weatherRepository {
    if (_weatherRepository == null) {
      throw Exception('WeatherRepository not initialized. Call initialize() first.');
    }
    return _weatherRepository!;
  }

  /// Get NewsRepository instance
  NewsRepository get newsRepository {
    if (_newsRepository == null) {
      throw Exception('NewsRepository not initialized. Call initialize() first.');
    }
    return _newsRepository!;
  }

  /// Initialize todo repository based on configuration
  Future<void> _initializeTodoRepository() async {
    try {
      if (_useFirebaseTodos) {
        debugPrint('RepositoryProvider: Using Firebase todo repository');
        _todoRepository = FirestoreTodoRepository();
      } else {
        debugPrint('RepositoryProvider: Using legacy FFI todo repository');
        _todoRepository = LegacyFfiTodoRepository();
      }
    } catch (e) {
      // Fallback to legacy implementation if Firebase fails
      debugPrint('RepositoryProvider: Firebase todo repository failed, falling back to FFI: $e');
      _todoRepository = LegacyFfiTodoRepository();
    }
  }

  /// Initialize weather repository based on configuration
  Future<void> _initializeWeatherRepository() async {
    try {
      debugPrint('RepositoryProvider: Using Cloud weather repository');
      _weatherRepository = CloudWeatherRepository();
    } catch (e) {
      throw Exception('Failed to initialize weather repository: $e');
    }
  }

  /// Initialize news repository based on configuration
  Future<void> _initializeNewsRepository() async {
    try {
      debugPrint('RepositoryProvider: Using Cloud news repository');
      _newsRepository = CloudNewsRepository();
    } catch (e) {
      throw Exception('Failed to initialize news repository: $e');
    }
  }

  /// Switch to Firebase implementations
  Future<void> switchToFirebase() async {
    try {
      debugPrint('RepositoryProvider: Switching to Firebase repositories');
      
      // Switch todo repository
      _todoRepository = FirestoreTodoRepository();
      
      // Weather and news already use cloud implementations
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to switch to Firebase: $e');
    }
  }

  /// Switch to legacy FFI implementations
  Future<void> switchToLegacyFFI() async {
    try {
      debugPrint('RepositoryProvider: Switching to legacy FFI repositories');
      
      // Switch todo repository
      _todoRepository = LegacyFfiTodoRepository();
      
      // Weather and news remain cloud-based as there's no FFI equivalent
      
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to switch to legacy FFI: $e');
    }
  }

  /// Check if Firebase is being used for todos
  bool get isUsingFirebaseTodos => _todoRepository is FirestoreTodoRepository;

  /// Check if legacy FFI is being used for todos
  bool get isUsingLegacyTodos => _todoRepository is LegacyFfiTodoRepository;

  /// Get repository implementation info for debugging
  Map<String, String> getRepositoryInfo() {
    return {
      'todo': _todoRepository.runtimeType.toString(),
      'weather': _weatherRepository.runtimeType.toString(),
      'news': _newsRepository.runtimeType.toString(),
      'firebase_todos': _useFirebaseTodos.toString(),
      'cloud_functions': _useCloudFunctions.toString(),
      'offline_mode': _enableOfflineMode.toString(),
    };
  }

  /// Clean up resources
  Future<void> dispose() async {
    _todoRepository = null;
    _weatherRepository = null;
    _newsRepository = null;
    _isInitialized = false;
    super.dispose();
  }

  /// Reset and reinitialize all repositories
  Future<void> reset() async {
    await dispose();
    await initialize();
  }
}

/// Convenience methods for accessing repositories
extension RepositoryProviderExtensions on RepositoryProvider {
  /// Quick access to todo repository
  TodoRepository get todos => todoRepository;
  
  /// Quick access to weather repository
  WeatherRepository get weather => weatherRepository;
  
  /// Quick access to news repository
  NewsRepository get news => newsRepository;
}