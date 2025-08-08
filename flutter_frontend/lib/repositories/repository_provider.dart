import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase/firebase_service.dart';
import 'todo_repository.dart';
import 'weather_repository.dart';
import 'news_repository.dart';
import 'firestore_todo_repository.dart';
import 'cloud_weather_repository.dart';
import 'cloud_news_repository.dart';

/// Repository provider managing Firebase-based data services
/// Provides centralized access to all repositories with proper initialization
class RepositoryProvider extends ChangeNotifier {
  static RepositoryProvider? _instance;
  static RepositoryProvider get instance => _instance ??= RepositoryProvider._();
  
  RepositoryProvider._();

  TodoRepository? _todoRepository;
  WeatherRepository? _weatherRepository;
  NewsRepository? _newsRepository;
  
  bool _isInitialized = false;
  bool _authenticationRequired = false;
  
  bool get isInitialized => _isInitialized;
  bool get requiresAuthentication => _authenticationRequired;

  /// Environment variables and feature flags
  static const bool _useCloudFunctions = 
      bool.fromEnvironment('USE_CLOUD_FUNCTIONS', defaultValue: true);
  static const bool _enableOfflineMode = 
      bool.fromEnvironment('ENABLE_OFFLINE_MODE', defaultValue: true);

  /// Initialize all repositories with Firebase implementations
  Future<void> initialize() async {
    try {
      // Ensure Firebase is initialized first
      if (!FirebaseService.instance.isInitialized) {
        throw Exception('Firebase service must be initialized first');
      }
      
      // Check authentication status and log warning if needed
      if (FirebaseService.instance.isInitialized && !FirebaseService.instance.isAuthenticated()) {
        debugPrint('RepositoryProvider: Firebase initialized but user not authenticated. Some repositories may have limited functionality.');
      }

      // Initialize all repositories with Firebase implementations
      await _initializeTodoRepository();
      await _initializeWeatherRepository();
      await _initializeNewsRepository();

      _isInitialized = true;
      notifyListeners();
      
      debugPrint('RepositoryProvider: All repositories initialized with Firebase');
    } catch (e) {
      throw Exception('Failed to initialize repositories: $e');
    }
  }

  /// Get TodoRepository instance
  TodoRepository get todoRepository {
    if (_todoRepository == null) {
      if (_authenticationRequired && !FirebaseService.instance.isAuthenticated()) {
        throw Exception('Repository requires user authentication. Please enable anonymous authentication or sign in.');
      }
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

  /// Initialize todo repository with Firestore implementation
  Future<void> _initializeTodoRepository() async {
    try {
      // Check authentication status directly before initialization
      if (!FirebaseService.instance.isAuthenticated()) {
        debugPrint('Todo repository requires authentication but user is not authenticated');
        _authenticationRequired = true;
        _todoRepository = null;
        return;
      }
      
      debugPrint('RepositoryProvider: Using Firestore todo repository');
      _todoRepository = FirestoreTodoRepository();
    } on FirebaseException catch (e) {
      debugPrint('Firebase error initializing todo repository: ${e.code} - ${e.message}');
      // Handle specific Firebase authentication errors
      if (e.code == 'unauthenticated' || e.code == 'permission-denied') {
        debugPrint('Todo repository requires authentication but user is not authenticated');
        _authenticationRequired = true;
        _todoRepository = null;
      } else {
        throw Exception('Failed to initialize Firestore todo repository: ${e.message}');
      }
    } catch (e) {
      debugPrint('Failed to initialize Firestore todo repository: $e');
      // Check if the error is authentication-related by checking Firebase auth state
      if (!FirebaseService.instance.isAuthenticated() && e.toString().contains('User not authenticated')) {
        debugPrint('Todo repository requires authentication but user is not authenticated');
        _authenticationRequired = true;
        _todoRepository = null;
      } else {
        throw Exception('Failed to initialize Firestore todo repository: $e');
      }
    }
  }

  /// Initialize weather repository with Cloud implementation
  Future<void> _initializeWeatherRepository() async {
    try {
      debugPrint('RepositoryProvider: Using Cloud weather repository');
      _weatherRepository = CloudWeatherRepository();
    } catch (e) {
      throw Exception('Failed to initialize weather repository: $e');
    }
  }

  /// Initialize news repository with Cloud implementation
  Future<void> _initializeNewsRepository() async {
    try {
      debugPrint('RepositoryProvider: Using Cloud news repository');
      _newsRepository = CloudNewsRepository();
    } catch (e) {
      throw Exception('Failed to initialize news repository: $e');
    }
  }

  /// Check if all repositories are using Firebase implementations
  bool get isUsingFirebase => 
      _todoRepository is FirestoreTodoRepository &&
      _weatherRepository is CloudWeatherRepository &&
      _newsRepository is CloudNewsRepository;

  /// Get list of repositories that are unavailable due to authentication requirements
  List<String> getUnavailableRepositories() {
    final unavailable = <String>[];
    
    if (_todoRepository == null && _authenticationRequired) {
      unavailable.add('TodoRepository');
    }
    
    return unavailable;
  }
  
  /// Get repository implementation info for debugging
  Map<String, String> getRepositoryInfo() {
    return {
      'todo': _todoRepository?.runtimeType.toString() ?? 'Not initialized',
      'weather': _weatherRepository?.runtimeType.toString() ?? 'Not initialized',
      'news': _newsRepository?.runtimeType.toString() ?? 'Not initialized',
      'cloud_functions': _useCloudFunctions.toString(),
      'offline_mode': _enableOfflineMode.toString(),
      'firebase_initialized': FirebaseService.instance.isInitialized.toString(),
      'user_authenticated': FirebaseService.instance.isAuthenticated().toString(),
      'auth_required': _authenticationRequired.toString(),
      'anonymous_auth_enabled': FirebaseService.instance.isAnonymousAuthEnabled.toString(),
    };
  }

  /// Clean up resources
  @override
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

  /// Check repository health and connectivity
  Future<Map<String, bool>> checkHealth() async {
    final health = <String, bool>{};
    
    try {
      // Check Firebase connectivity
      health['firebase'] = FirebaseService.instance.isInitialized;
      
      // Check if user is authenticated
      health['auth_available'] = FirebaseService.instance.isAuthenticated();
      health['auth_required'] = _authenticationRequired;
      
      // Check if repositories are initialized and available
      health['todo_repo'] = _todoRepository != null && (!_authenticationRequired || FirebaseService.instance.isAuthenticated());
      health['weather_repo'] = _weatherRepository != null;
      health['news_repo'] = _newsRepository != null;
      
    } catch (e) {
      debugPrint('Repository health check failed: $e');
    }
    
    return health;
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