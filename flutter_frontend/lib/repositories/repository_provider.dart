import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase/firebase_service.dart';
import '../core/services/error_reporting_service.dart';
import '../core/utils/safe_json_converter.dart';
import 'todo_repository.dart';
import 'weather_repository.dart';
import 'news_repository.dart';
import 'rss_feed_repository.dart';
import 'video_stream_repository.dart';
import 'firestore_todo_repository.dart';
import 'cloud_weather_repository.dart';
import 'cloud_news_repository.dart';
import 'mock_todo_repository.dart';
import 'mock_weather_repository.dart';
import 'mock_news_repository.dart';

/// Repository provider managing Firebase-based data services
/// Provides centralized access to all repositories with proper initialization
class RepositoryProvider extends ChangeNotifier {
  static RepositoryProvider? _instance;
  static RepositoryProvider get instance => _instance ??= RepositoryProvider._();
  
  RepositoryProvider._();

  TodoRepository? _todoRepository;
  WeatherRepository? _weatherRepository;
  NewsRepository? _newsRepository;
  RSSFeedRepository? _rssFeedRepository;
  VideoStreamRepository? _videoStreamRepository;
  
  bool _isInitialized = false;
  bool _authenticationRequired = false;
  
  // Offline mode state management
  bool _offlineModeActive = false;
  StreamSubscription<bool>? _offlineModeSubscription;
  
  // Error tracking for intelligent offline switching
  int _consecutiveErrors = 0;
  DateTime? _lastErrorTime;
  final int _maxConsecutiveErrors = 3;
  final Duration _errorWindowDuration = const Duration(minutes: 5);
  
  bool get isInitialized => _isInitialized;
  bool get requiresAuthentication => _authenticationRequired;
  bool get offlineModeActive => _offlineModeActive;

  /// Environment variables and feature flags
  static const bool _useCloudFunctions = 
      bool.fromEnvironment('USE_CLOUD_FUNCTIONS', defaultValue: true);
  static const bool _enableOfflineMode = 
      bool.fromEnvironment('ENABLE_OFFLINE_MODE', defaultValue: true);

  /// Initialize all repositories with Firebase or mock implementations based on availability
  Future<void> initialize() async {
    try {
      // Subscribe to Firebase offline mode changes
      _offlineModeSubscription = FirebaseService.instance.offlineModeStream.listen(
        (isOffline) {
          final wasOffline = _offlineModeActive;
          _offlineModeActive = isOffline;
          
          if (wasOffline != _offlineModeActive) {
            log('RepositoryProvider: Offline mode changed to $_offlineModeActive');
            notifyListeners();
          }
        },
        onError: (error) {
          log('RepositoryProvider: Error in offline mode stream: $error');
          _handleInitializationError(error);
        },
      );

      // Check if Firebase is initialized and offline mode
      final firebaseInitialized = FirebaseService.instance.isInitialized;
      final currentlyOffline = FirebaseService.instance.isOfflineMode;
      
      if (!firebaseInitialized || (currentlyOffline && _enableOfflineMode)) {
        // Initialize offline repositories
        _offlineModeActive = true;
        await _initializeOfflineRepositories();
        log('RepositoryProvider: All repositories initialized in offline mode');
      } else {
        // Initialize Firebase repositories
        _offlineModeActive = false;
        
        // Check authentication status and log warning if needed
        if (!FirebaseService.instance.isAuthenticated()) {
          log('RepositoryProvider: Firebase initialized but user not authenticated. Some repositories may have limited functionality.');
        }

        // Initialize all repositories with Firebase implementations
        await _initializeTodoRepository();
        await _initializeWeatherRepository();
        await _initializeNewsRepository();
        await _initializeRSSFeedRepository();
        await _initializeVideoStreamRepository();
        log('RepositoryProvider: All repositories initialized with Firebase');
      }

      // Reset error tracking on successful initialization
      _consecutiveErrors = 0;
      _lastErrorTime = null;
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _handleInitializationError(e);
      
      // Try offline mode as fallback if enabled
      if (_enableOfflineMode && !_offlineModeActive) {
        try {
          log('RepositoryProvider: Attempting offline mode as fallback');
          _offlineModeActive = true;
          await _initializeOfflineRepositories();
          _isInitialized = true;
          notifyListeners();
          log('RepositoryProvider: Successfully initialized in offline mode as fallback');
          return;
        } catch (offlineError) {
          log('RepositoryProvider: Offline fallback also failed: $offlineError');
          ErrorReportingService.instance.reportError(
            'repository_initialization_failed',
            offlineError,
            StackTrace.current,
            context: {
              'fallback_mode': 'offline',
              'original_error': e.toString(),
            },
            severity: ErrorSeverity.critical,
          );
        }
      }
      throw Exception('Failed to initialize repositories: $e');
    }
  }

  void _handleInitializationError(dynamic error) {
    final now = DateTime.now();
    
    // Reset counter if enough time has passed
    if (_lastErrorTime != null && now.difference(_lastErrorTime!) > _errorWindowDuration) {
      _consecutiveErrors = 0;
    }
    
    _consecutiveErrors++;
    _lastErrorTime = now;
    
    // Report the error
    ErrorReportingService.instance.reportError(
      'repository_initialization_error',
      error,
      StackTrace.current,
      context: {
        'consecutive_errors': _consecutiveErrors,
        'firebase_initialized': FirebaseService.instance.isInitialized,
        'offline_mode_active': _offlineModeActive,
      },
      severity: _consecutiveErrors >= _maxConsecutiveErrors ? ErrorSeverity.critical : ErrorSeverity.high,
    );

    // Check for web compatibility issues
    if (kIsWeb && SafeJsonConverter.hasWebCompatibilityIssue(error)) {
      log('RepositoryProvider: Detected web compatibility issue in initialization');
      
      // Automatically switch to offline mode if we haven't already
      if (!_offlineModeActive && _enableOfflineMode) {
        log('RepositoryProvider: Auto-switching to offline mode due to web compatibility issue');
        switchToOfflineMode().catchError((offlineError) {
          log('RepositoryProvider: Failed auto-switch to offline mode: $offlineError');
        });
      }
    }
  }

  /// Get TodoRepository instance
  TodoRepository get todoRepository {
    if (_todoRepository == null) {
      if (_authenticationRequired && !FirebaseService.instance.isAuthenticated()) {
        final modeInfo = _offlineModeActive ? ' (offline mode available)' : '';
        throw Exception('Repository requires user authentication. Please enable anonymous authentication or sign in.$modeInfo');
      }
      final modeInfo = _offlineModeActive ? ' App is in offline mode.' : '';
      throw Exception('TodoRepository not initialized. Call initialize() first.$modeInfo');
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

  /// Get RSSFeedRepository instance
  RSSFeedRepository get rssFeedRepository {
    if (_rssFeedRepository == null) {
      throw Exception('RSSFeedRepository not initialized. Call initialize() first.');
    }
    return _rssFeedRepository!;
  }

  /// Get VideoStreamRepository instance
  VideoStreamRepository get videoStreamRepository {
    if (_videoStreamRepository == null) {
      throw Exception('VideoStreamRepository not initialized. Call initialize() first.');
    }
    return _videoStreamRepository!;
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

  /// Initialize RSS feed repository with Firestore implementation
  Future<void> _initializeRSSFeedRepository() async {
    try {
      debugPrint('RepositoryProvider: Using Firestore RSS feed repository');
      _rssFeedRepository = FirestoreRSSFeedRepository();
    } catch (e) {
      throw Exception('Failed to initialize RSS feed repository: $e');
    }
  }

  /// Initialize video stream repository with Firestore implementation
  Future<void> _initializeVideoStreamRepository() async {
    try {
      debugPrint('RepositoryProvider: Using Firestore video stream repository');
      _videoStreamRepository = FirestoreVideoStreamRepository();
    } catch (e) {
      throw Exception('Failed to initialize video stream repository: $e');
    }
  }

  /// Initialize all repositories with offline/mock implementations
  Future<void> _initializeOfflineRepositories() async {
    try {
      await _initializeOfflineTodoRepository();
      await _initializeOfflineWeatherRepository();
      await _initializeOfflineNewsRepository();
      await _initializeOfflineRSSFeedRepository();
      await _initializeOfflineVideoStreamRepository();
      debugPrint('RepositoryProvider: All offline repositories initialized successfully');
    } catch (e) {
      throw Exception('Failed to initialize offline repositories: $e');
    }
  }

  /// Initialize todo repository with mock implementation
  Future<void> _initializeOfflineTodoRepository() async {
    try {
      debugPrint('RepositoryProvider: Using mock todo repository for offline mode');
      _todoRepository = MockTodoRepository();
      _authenticationRequired = false; // Mock repositories don't require auth
    } catch (e) {
      throw Exception('Failed to initialize mock todo repository: $e');
    }
  }

  /// Initialize weather repository with mock implementation
  Future<void> _initializeOfflineWeatherRepository() async {
    try {
      debugPrint('RepositoryProvider: Using mock weather repository for offline mode');
      _weatherRepository = MockWeatherRepository();
    } catch (e) {
      throw Exception('Failed to initialize mock weather repository: $e');
    }
  }

  /// Initialize news repository with mock implementation
  Future<void> _initializeOfflineNewsRepository() async {
    try {
      debugPrint('RepositoryProvider: Using mock news repository for offline mode');
      _newsRepository = MockNewsRepository();
    } catch (e) {
      throw Exception('Failed to initialize mock news repository: $e');
    }
  }

  /// Initialize RSS feed repository with mock implementation
  Future<void> _initializeOfflineRSSFeedRepository() async {
    try {
      debugPrint('RepositoryProvider: Using mock RSS feed repository for offline mode');
      _rssFeedRepository = MockRSSFeedRepository();
    } catch (e) {
      throw Exception('Failed to initialize mock RSS feed repository: $e');
    }
  }

  /// Initialize video stream repository with mock implementation
  Future<void> _initializeOfflineVideoStreamRepository() async {
    try {
      debugPrint('RepositoryProvider: Using mock video stream repository for offline mode');
      _videoStreamRepository = MockVideoStreamRepository();
    } catch (e) {
      throw Exception('Failed to initialize mock video stream repository: $e');
    }
  }

  /// Check if all repositories are using Firebase implementations
  bool get isUsingFirebase => 
      _todoRepository is FirestoreTodoRepository &&
      _weatherRepository is CloudWeatherRepository &&
      _newsRepository is CloudNewsRepository &&
      _rssFeedRepository is FirestoreRSSFeedRepository &&
      _videoStreamRepository is FirestoreVideoStreamRepository;

  /// Check if all repositories are using mock implementations (offline mode)
  bool get isUsingMockRepositories =>
      _todoRepository is MockTodoRepository &&
      _weatherRepository is MockWeatherRepository &&
      _newsRepository is MockNewsRepository &&
      _rssFeedRepository is MockRSSFeedRepository &&
      _videoStreamRepository is MockVideoStreamRepository;

  /// Switch to offline mode manually
  Future<void> switchToOfflineMode() async {
    if (_offlineModeActive) {
      log('RepositoryProvider: Already in offline mode');
      return;
    }

    try {
      log('RepositoryProvider: Switching to offline mode');
      _offlineModeActive = true;
      
      // Report the offline mode switch
      ErrorReportingService.instance.reportError(
        'offline_mode_switch',
        'User manually switched to offline mode',
        StackTrace.current,
        context: {
          'switch_type': 'manual',
          'consecutive_errors': _consecutiveErrors,
          'firebase_available': FirebaseService.instance.isInitialized,
        },
        severity: ErrorSeverity.medium,
      );
      
      await _initializeOfflineRepositories();
      
      // Reset error tracking since we're now in stable offline mode
      _consecutiveErrors = 0;
      _lastErrorTime = null;
      
      notifyListeners();
      log('RepositoryProvider: Successfully switched to offline mode');
    } catch (e) {
      log('RepositoryProvider: Failed to switch to offline mode: $e');
      
      ErrorReportingService.instance.reportError(
        'offline_mode_switch_failed',
        e,
        StackTrace.current,
        context: {
          'switch_type': 'manual',
        },
        severity: ErrorSeverity.high,
      );
      
      throw Exception('Failed to switch to offline mode: $e');
    }
  }

  /// Switch to online mode (attempt reconnection)
  Future<void> switchToOnlineMode() async {
    if (!_offlineModeActive) {
      log('RepositoryProvider: Already in online mode');
      return;
    }

    try {
      log('RepositoryProvider: Switching to online mode');
      
      // Check if Firebase is available before attempting switch
      if (!FirebaseService.instance.isInitialized) {
        throw Exception('Firebase not initialized - cannot switch to online mode');
      }
      
      // Test Firebase connectivity with a simple operation
      await _testFirebaseConnectivity();
      
      // If test passes, proceed with full initialization
      final wasOffline = _offlineModeActive;
      _offlineModeActive = false;
      
      await reset();
      await initialize();
      
      // Report successful switch
      ErrorReportingService.instance.reportError(
        'online_mode_switch',
        'Successfully switched from offline to online mode',
        StackTrace.current,
        context: {
          'switch_type': 'manual',
          'was_offline': wasOffline,
          'firebase_available': FirebaseService.instance.isInitialized,
        },
        severity: ErrorSeverity.low,
      );
      
      log('RepositoryProvider: Successfully switched to online mode');
    } catch (e) {
      log('RepositoryProvider: Failed to switch to online mode, staying in offline mode: $e');
      
      // Revert to offline mode
      _offlineModeActive = true;
      
      ErrorReportingService.instance.reportError(
        'online_mode_switch_failed',
        e,
        StackTrace.current,
        context: {
          'switch_type': 'manual',
          'reverted_to_offline': true,
        },
        severity: ErrorSeverity.medium,
      );
      
      // Don't throw error, just log it - offline mode is a valid fallback
      // Ensure offline repositories are still available
      try {
        await _initializeOfflineRepositories();
        notifyListeners();
      } catch (offlineError) {
        log('RepositoryProvider: Critical error - failed to revert to offline mode: $offlineError');
        throw Exception('Failed to switch to online mode and failed to revert to offline mode: $offlineError');
      }
    }
  }

  /// Test Firebase connectivity without full initialization
  Future<void> _testFirebaseConnectivity() async {
    try {
      // Simple connectivity test - try to access Firebase Auth
      if (!FirebaseService.instance.isAuthenticated()) {
        log('RepositoryProvider: Firebase available but user not authenticated');
      }
      
      // Additional connectivity tests could be added here
      log('RepositoryProvider: Firebase connectivity test passed');
    } catch (e) {
      throw Exception('Firebase connectivity test failed: $e');
    }
  }

  /// Automatically switch to offline mode when persistent errors are detected
  Future<bool> checkAndHandleErrors(dynamic error) async {
    if (!_enableOfflineMode || _offlineModeActive) {
      return false; // Already offline or offline mode disabled
    }

    final now = DateTime.now();
    
    // Reset counter if enough time has passed
    if (_lastErrorTime != null && now.difference(_lastErrorTime!) > _errorWindowDuration) {
      _consecutiveErrors = 0;
    }
    
    _consecutiveErrors++;
    _lastErrorTime = now;
    
    // Check for web compatibility issues (immediate switch)
    if (kIsWeb && SafeJsonConverter.hasWebCompatibilityIssue(error)) {
      log('RepositoryProvider: Detected web compatibility issue - switching to offline mode immediately');
      
      try {
        await switchToOfflineMode();
        return true;
      } catch (e) {
        log('RepositoryProvider: Failed to auto-switch to offline mode: $e');
        return false;
      }
    }
    
    // Check for consecutive errors threshold
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      log('RepositoryProvider: Reached max consecutive errors ($_maxConsecutiveErrors) - switching to offline mode');
      
      try {
        await switchToOfflineMode();
        return true;
      } catch (e) {
        log('RepositoryProvider: Failed to auto-switch to offline mode after consecutive errors: $e');
        return false;
      }
    }
    
    return false; // No automatic switch performed
  }

  /// Get error tracking information
  Map<String, dynamic> getErrorTrackingInfo() {
    return {
      'consecutive_errors': _consecutiveErrors,
      'last_error_time': _lastErrorTime?.toIso8601String(),
      'max_consecutive_errors': _maxConsecutiveErrors,
      'error_window_minutes': _errorWindowDuration.inMinutes,
      'auto_offline_enabled': _enableOfflineMode,
    };
  }

  /// Get information about offline mode status and available features
  Map<String, dynamic> getOfflineModeInfo() {
    return {
      'offline_mode_active': _offlineModeActive,
      'offline_mode_enabled': _enableOfflineMode,
      'available_features': _offlineModeActive ? [
        'Todo management with local storage',
        'Weather data with realistic mock data',
        'News feeds with sample articles',
        'Dashboard functionality',
      ] : [],
      'limitations': _offlineModeActive ? [
        'No real-time data synchronization',
        'Limited to sample/cached data',
        'No cloud backup or sync',
      ] : [],
    };
  }

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
      'offline_mode_enabled': _enableOfflineMode.toString(),
      'offline_mode_active': _offlineModeActive.toString(),
      'firebase_initialized': FirebaseService.instance.isInitialized.toString(),
      'user_authenticated': FirebaseService.instance.isAuthenticated().toString(),
      'auth_required': _authenticationRequired.toString(),
      'anonymous_auth_enabled': FirebaseService.instance.isAnonymousAuthEnabled.toString(),
      'repository_type': isUsingFirebase ? 'Firebase' : (isUsingMockRepositories ? 'Mock (Offline)' : 'Mixed'),
    };
  }

  /// Clean up resources
  @override
  Future<void> dispose() async {
    _offlineModeSubscription?.cancel();
    _offlineModeSubscription = null;
    _todoRepository = null;
    _weatherRepository = null;
    _newsRepository = null;
    _isInitialized = false;
    _offlineModeActive = false;
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
      
      // Check offline mode status
      health['offline_mode'] = _offlineModeActive;
      health['offline_mode_enabled'] = _enableOfflineMode;
      
      // Check if repositories are initialized and available
      health['todo_repo'] = _todoRepository != null && (!_authenticationRequired || FirebaseService.instance.isAuthenticated());
      health['weather_repo'] = _weatherRepository != null;
      health['news_repo'] = _newsRepository != null;
      
      // Overall health status
      health['repositories_available'] = health['todo_repo']! && health['weather_repo']! && health['news_repo']!;
      
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