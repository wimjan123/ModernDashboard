import 'dart:async';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../firebase_options.dart';
import '../core/exceptions/initialization_exception.dart';
import '../core/models/initialization_status.dart';
import '../core/services/backoff_strategy.dart';
import 'firebase_config_validator.dart';

class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();
  static final Logger _logger = Logger();

  FirebaseService._();

  FirebaseApp? _app;
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  User? _currentUser;
  bool _anonymousAuthEnabled = true;

  // Offline mode state management
  bool _isOfflineMode = false;
  StreamController<bool> _offlineModeController = StreamController<bool>.broadcast();
  StreamSubscription? _connectivitySubscription;
  
  // Progress tracking infrastructure
  StreamController<InitializationStatus> _statusController = StreamController<InitializationStatus>.broadcast();
  InitializationStatus? _currentStatus;
  Completer<void>? _currentCancelToken;

  bool get isInitialized => _app != null;
  bool get isAnonymousAuthEnabled => _anonymousAuthEnabled;
  User? get currentUser => _currentUser;
  FirebaseFirestore get firestore => _firestore!;
  FirebaseAuth get auth => _auth!;
  
  // Offline mode getters
  bool get isOfflineMode => _isOfflineMode;
  Stream<bool> get offlineModeStream => _offlineModeController.stream;
  
  // Progress tracking getters
  Stream<InitializationStatus> get initializationStatusStream => _statusController.stream;
  InitializationStatus? getCurrentStatus() => _currentStatus;

  /// Check network connectivity before Firebase operations
  Future<bool> _checkNetworkConnectivity() async {
    try {
      final dynamic connectivityResult = await Connectivity().checkConnectivity();
      // Handle both single result and list result for different versions
      late List<ConnectivityResult> results;
      if (connectivityResult is List<ConnectivityResult>) {
        results = connectivityResult;
      } else {
        results = [connectivityResult as ConnectivityResult];
      }
      
      final isConnected = results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
      _logger.d('Network connectivity check: $isConnected');
      return isConnected;
    } catch (e) {
      _logger.w('Failed to check network connectivity: $e');
      return false;
    }
  }

  /// Start monitoring connectivity changes
  void _startConnectivityMonitoring() {
    try {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        (dynamic connectivityResult) {
          // Handle both single result and list result for different versions
          late List<ConnectivityResult> results;
          if (connectivityResult is List<ConnectivityResult>) {
            results = connectivityResult;
          } else {
            results = [connectivityResult as ConnectivityResult];
          }
          
          final isConnected = results.contains(ConnectivityResult.mobile) ||
              results.contains(ConnectivityResult.wifi) ||
              results.contains(ConnectivityResult.ethernet);
          
          final wasOffline = _isOfflineMode;
          _isOfflineMode = !isConnected;
          
          if (wasOffline != _isOfflineMode) {
            _logger.i('Connectivity changed - offline mode: $_isOfflineMode');
            _offlineModeController.add(_isOfflineMode);
          }
        },
        onError: (error) {
          _logger.w('Connectivity monitoring error: $error');
        },
      );
      _logger.d('Connectivity monitoring started');
    } catch (e) {
      _logger.w('Failed to start connectivity monitoring: $e');
    }
  }

  /// Stop monitoring connectivity changes
  void _stopConnectivityMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _logger.d('Connectivity monitoring stopped');
  }

  /// Check if Firebase services are available
  Future<bool> _checkFirebaseAvailability() async {
    try {
      // Check network connectivity first before attempting Firestore operation
      if (!await _checkNetworkConnectivity()) {
        _logger.d('Network connectivity not available, Firebase services unavailable');
        return false;
      }
      
      if (_firestore == null) {
        return false;
      }
      
      // Try a simple Firestore operation with a short timeout
      final testDoc = _firestore!.collection('_test').doc('connectivity');
      await testDoc.get().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Firebase availability check timeout'),
      );
      
      _logger.d('Firebase services are available');
      return true;
    } on FirebaseException catch (e) {
      final networkRelatedCodes = ['unavailable', 'deadline-exceeded', 'network-request-failed'];
      if (networkRelatedCodes.contains(e.code)) {
        _logger.w('Firebase unavailable due to network: ${e.code}');
        return false;
      }
      _logger.w('Firebase availability check failed: ${e.code}');
      return false;
    } catch (e) {
      _logger.w('Firebase availability check failed: $e');
      return false;
    }
  }

  /// Detect offline mode based on network and Firebase availability
  Future<void> _detectOfflineMode() async {
    try {
      final hasNetwork = await _checkNetworkConnectivity();
      final firebaseAvailable = hasNetwork ? await _checkFirebaseAvailability() : false;
      
      final wasOffline = _isOfflineMode;
      _isOfflineMode = !hasNetwork || !firebaseAvailable;
      
      if (wasOffline != _isOfflineMode) {
        _logger.i('Offline mode changed to: $_isOfflineMode');
        _offlineModeController.add(_isOfflineMode);
      }
      
      if (_isOfflineMode) {
        final reason = !hasNetwork ? 'no network connection' : 'Firebase unavailable';
        _logger.w('Offline mode activated: $reason');
      }
    } catch (e) {
      _logger.w('Error detecting offline mode: $e');
      _isOfflineMode = true;
      _offlineModeController.add(_isOfflineMode);
    }
  }

  /// Validate Firebase configuration options
  void _validateFirebaseOptions(FirebaseOptions options) {
    final platform = defaultTargetPlatform;
    final result = FirebaseConfigValidator.validateFirebaseOptions(options, platform);
    
    if (!result.isValid) {
      _logger.e('Firebase configuration validation failed: ${result.getErrorSummary()}');
      for (final entry in result.fieldErrors.entries) {
        _logger.e('${entry.key}: ${entry.value}');
      }
      throw InitializationException(
        'invalid-config',
        'Firebase configuration validation failed: ${result.errors.join(', ')}',
        result.fieldErrors.toString(),
      );
    }
    
    if (result.hasWarnings) {
      _logger.w('Firebase configuration warnings: ${result.warnings.join(', ')}');
      for (final entry in result.fieldErrors.entries) {
        if (result.warnings.any((w) => w.contains(entry.key))) {
          _logger.w('${entry.key}: ${entry.value}');
        }
      }
    }
    
    _logger.i('Firebase configuration validation passed');
  }
  
  /// Validate platform-specific configuration
  void _validatePlatformSpecificConfig() {
    final platform = defaultTargetPlatform;
    
    if (!FirebaseConfigValidator.isPlatformSupported(platform)) {
      _logger.e('Platform $platform is not supported by Firebase configuration');
      throw InitializationException(
        'unsupported-platform',
        'Platform ${platform.name} is not supported. ${FirebaseConfigValidator.getPlatformConfigRequirements(platform)}',
        'Supported platforms: ${FirebaseConfigValidator.getSupportedPlatforms().join(', ')}',
      );
    }
    
    _logger.d('Platform ${platform.name} is supported by Firebase configuration');
  }


  /// Emit status update and store current status
  void _emitStatus(InitializationStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }
  
  /// Create status object with common parameters
  InitializationStatus _createStatus(
    InitializationPhase phase,
    String message, {
    int? currentAttempt,
    int? maxAttempts,
    double? progress,
    Duration? nextRetryIn,
    bool isRetrying = false,
    InitializationException? error,
  }) {
    return InitializationStatus(
      phase: phase,
      currentAttempt: currentAttempt ?? 1,
      maxAttempts: maxAttempts ?? 3,
      message: message,
      progress: progress,
      nextRetryIn: nextRetryIn,
      isRetrying: isRetrying,
      error: error,
    );
  }
  
  /// Check if operation should be cancelled
  bool _shouldCancel() {
    return _currentCancelToken?.isCompleted ?? false;
  }
  
  /// Initialize Firebase with default configuration
  Future<void> initializeFirebase({
    bool enableAnonymousAuth = true,
    BackoffStrategy? backoffStrategy,
  }) async {
    try {
      // Network connectivity check
      _emitStatus(_createStatus(
        InitializationPhase.networkCheck,
        'Checking network connectivity...',
        progress: 0.1,
      ));
      
      if (_shouldCancel()) return;
      
      if (!await _checkNetworkConnectivity()) {
        _logger.e('No internet connection available');
        throw const InitializationException(
          'no-network',
          'No internet connection available',
        );
      }
      
      // Configuration validation
      _emitStatus(_createStatus(
        InitializationPhase.configValidation,
        'Validating Firebase configuration...',
        progress: 0.2,
      ));
      
      if (_shouldCancel()) return;
      
      _validatePlatformSpecificConfig();
      _validateFirebaseOptions(DefaultFirebaseOptions.currentPlatform);

      // Firebase initialization
      _emitStatus(_createStatus(
        InitializationPhase.firebaseInit,
        'Initializing Firebase services...',
        progress: 0.4,
      ));
      
      if (_shouldCancel()) return;
      
      _logger.i('Starting Firebase initialization');
      _anonymousAuthEnabled = enableAnonymousAuth;
      
      // Initialize Firebase app
      _app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize Auth
      _auth = FirebaseAuth.instance;

      // Initialize Firestore with offline persistence
      _firestore = FirebaseFirestore.instance;

      // Enable offline persistence using the new settings approach
      _firestore!.settings = const Settings(persistenceEnabled: true);

      // Listen to authentication state changes
      _auth!.authStateChanges().listen((User? user) {
        _currentUser = user;
      });
      
      // Authentication phase
      _emitStatus(_createStatus(
        InitializationPhase.authentication,
        'Setting up authentication...',
        progress: 0.7,
      ));
      
      if (_shouldCancel()) return;

      // Sign in anonymously if no user exists and auth is enabled
      if (_auth!.currentUser == null && enableAnonymousAuth) {
        try {
          await signInAnonymously();
        } on FirebaseException catch (e) {
          if (e.code == 'operation-not-allowed') {
            _logger.w('Anonymous authentication is disabled in Firebase console. Continuing without authentication.');
            _anonymousAuthEnabled = false;
          } else {
            rethrow;
          }
        }
      } else if (_auth!.currentUser != null) {
        _currentUser = _auth!.currentUser;
      } else {
        _logger.i('Anonymous authentication disabled, continuing without authentication');
        _anonymousAuthEnabled = false;
      }
      
      // Repository initialization
      _emitStatus(_createStatus(
        InitializationPhase.repositoryInit,
        'Initializing data repositories...',
        progress: 0.9,
      ));
      
      if (_shouldCancel()) return;
      
      // Start connectivity monitoring and detect initial offline mode
      _startConnectivityMonitoring();
      await _detectOfflineMode();
      
      // Success
      _emitStatus(_createStatus(
        InitializationPhase.success,
        'Initialization completed successfully',
        progress: 1.0,
      ));
      
      _logger.i('Firebase initialization completed successfully');
    } on InitializationException catch (e) {
      _emitStatus(_createStatus(
        InitializationPhase.error,
        'Initialization failed: ${e.message}',
        error: e,
      ));
      rethrow;
    } on FirebaseException catch (e) {
      // Set offline mode for network-related Firebase errors
      final networkRelatedCodes = ['no-network', 'network-request-failed', 'unavailable'];
      if (networkRelatedCodes.contains(e.code)) {
        _isOfflineMode = true;
        _offlineModeController.add(_isOfflineMode);
        _logger.w('Firebase initialization failed due to network, offline mode activated: ${e.code}');
      }
      _logger.e('Firebase initialization failed', error: e, stackTrace: StackTrace.current);
      final initException = InitializationException(
        e.code,
        e.message ?? 'Unknown Firebase error',
        e.toString(),
      );
      _emitStatus(_createStatus(
        InitializationPhase.error,
        'Firebase error: ${e.message ?? 'Unknown error'}',
        error: initException,
      ));
      throw initException;
    } catch (e) {
      _logger.e('Unexpected error during Firebase initialization', error: e, stackTrace: StackTrace.current);
      final initException = InitializationException(
        'unknown-error',
        'Unexpected initialization error',
        e.toString(),
      );
      _emitStatus(_createStatus(
        InitializationPhase.error,
        'Unexpected error occurred',
        error: initException,
      ));
      throw initException;
    }
  }

  /// Sign in anonymously for immediate app access
  Future<User?> signInAnonymously() async {
    try {
      _logger.d('Attempting anonymous sign-in');
      final credential = await _auth!.signInAnonymously();
      _currentUser = credential.user;
      _logger.i('Anonymous sign-in successful');
      return _currentUser;
    } on FirebaseException catch (e) {
      _logger.e('Firebase anonymous sign-in failed', error: e, stackTrace: StackTrace.current);
      throw InitializationException(
        e.code,
        e.message ?? 'Unknown Firebase authentication error',
        e.toString(),
      );
    } catch (e) {
      _logger.e('Unexpected error during anonymous sign-in', error: e, stackTrace: StackTrace.current);
      throw InitializationException(
        'unknown-error',
        'Unexpected authentication error',
        e.toString(),
      );
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _auth!.signOut();
      _currentUser = null;
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  /// Get current user's ID for data scoping
  String? getUserId() {
    return _currentUser?.uid;
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    return _currentUser != null;
  }

  /// Check if current user is anonymous
  bool isAnonymousUser() {
    return _currentUser?.isAnonymous ?? false;
  }

  /// Cancel ongoing initialization
  void cancelInitialization() {
    if (_currentCancelToken != null && !_currentCancelToken!.isCompleted) {
      _currentCancelToken!.complete();
      _logger.i('Initialization cancelled by user');
    }
  }
  
  /// Retry Firebase initialization with configurable backoff strategy
  Future<void> retryInitialization({
    BackoffStrategy? backoffStrategy,
    bool enableAnonymousAuth = true,
  }) async {
    final strategy = backoffStrategy ?? BackoffStrategy();
    _currentCancelToken = Completer<void>();
    
    for (int attempt = 1; attempt <= strategy.maxAttempts; attempt++) {
      try {
        _logger.i('Retry attempt $attempt of ${strategy.maxAttempts}');
        
        // Update status for new attempt
        _emitStatus(_createStatus(
          InitializationPhase.retrying,
          'Preparing to retry initialization...',
          currentAttempt: attempt,
          maxAttempts: strategy.maxAttempts,
          isRetrying: true,
        ));
        
        if (_shouldCancel()) {
          _logger.i('Retry cancelled during attempt $attempt');
          return;
        }
        
        // If not the first attempt, apply backoff delay
        if (attempt > 1) {
          final delay = strategy.calculateDelay(attempt);
          _logger.d('Waiting ${delay.inSeconds} seconds before retry attempt $attempt');
          
          // Countdown during delay
          final startTime = DateTime.now();
          while (!_shouldCancel()) {
            final remaining = strategy.getRemainingDelay(attempt, startTime);
            if (remaining <= Duration.zero) break;
            
            _emitStatus(_createStatus(
              InitializationPhase.retrying,
              'Retrying initialization...',
              currentAttempt: attempt,
              maxAttempts: strategy.maxAttempts,
              nextRetryIn: remaining,
              isRetrying: true,
            ));
            
            await Future.delayed(const Duration(seconds: 1));
          }
          
          if (_shouldCancel()) {
            _logger.i('Retry cancelled during delay before attempt $attempt');
            return;
          }
        }
        
        // Attempt initialization
        await initializeFirebase(enableAnonymousAuth: enableAnonymousAuth);
        _logger.i('Firebase initialization retry successful on attempt $attempt');
        return;
        
      } on InitializationException catch (e) {
        // Skip retries for configuration validation errors that won't resolve with retries
        if (e.code == 'invalid-config' || e.code == 'unsupported-platform') {
          _logger.e('Skipping retries for configuration error: ${e.code}');
          rethrow;
        }
        
        _logger.w('Retry attempt $attempt failed: ${e.message}');
        
        if (!strategy.shouldRetry(attempt + 1)) {
          _logger.e('All retry attempts exhausted after $attempt attempts');
          final finalException = InitializationException(
            'retry-failed',
            'Failed to initialize Firebase after ${strategy.maxAttempts} attempts',
            e.toString(),
          );
          _emitStatus(_createStatus(
            InitializationPhase.error,
            'Initialization failed after ${strategy.maxAttempts} attempts',
            currentAttempt: attempt,
            maxAttempts: strategy.maxAttempts,
            error: finalException,
          ));
          throw finalException;
        }
      } catch (e) {
        _logger.w('Retry attempt $attempt failed: $e');
        
        if (!strategy.shouldRetry(attempt + 1)) {
          _logger.e('All retry attempts exhausted after $attempt attempts');
          final finalException = InitializationException(
            'retry-failed',
            'Failed to initialize Firebase after ${strategy.maxAttempts} attempts',
            e.toString(),
          );
          _emitStatus(_createStatus(
            InitializationPhase.error,
            'Initialization failed after ${strategy.maxAttempts} attempts',
            currentAttempt: attempt,
            maxAttempts: strategy.maxAttempts,
            error: finalException,
          ));
          throw finalException;
        }
      }
    }
  }

  /// Get Firestore collection reference scoped to current user
  CollectionReference getUserCollection(String collection) {
    final userId = getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore!.collection('users').doc(userId).collection(collection);
  }

  /// Get user document reference
  DocumentReference getUserDocument() {
    final userId = getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore!.collection('users').doc(userId);
  }

  /// Set offline mode manually (useful for testing)
  void setOfflineMode(bool offline) {
    final wasOffline = _isOfflineMode;
    _isOfflineMode = offline;
    
    if (wasOffline != _isOfflineMode) {
      _logger.i('Manual offline mode change: $_isOfflineMode');
      _offlineModeController.add(_isOfflineMode);
    }
  }

  /// Get reason for offline mode
  String getOfflineReason() {
    if (!_isOfflineMode) {
      return 'Online';
    }
    
    return 'Offline mode is active due to network or Firebase connectivity issues';
  }

  /// Dispose resources and cleanup
  void dispose() {
    _stopConnectivityMonitoring();
    _offlineModeController.close();
    _statusController.close();
    if (_currentCancelToken != null && !_currentCancelToken!.isCompleted) {
      _currentCancelToken!.complete();
    }
    _logger.d('FirebaseService disposed');
  }
}
