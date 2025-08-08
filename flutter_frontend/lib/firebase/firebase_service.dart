import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';
import '../firebase_options.dart';
import '../core/exceptions/initialization_exception.dart';

class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();
  static final Logger _logger = Logger();

  FirebaseService._();

  FirebaseApp? _app;
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  User? _currentUser;

  bool get isInitialized => _app != null;
  User? get currentUser => _currentUser;
  FirebaseFirestore get firestore => _firestore!;
  FirebaseAuth get auth => _auth!;

  /// Check network connectivity before Firebase operations
  Future<bool> _checkNetworkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.wifi) ||
          connectivityResult.contains(ConnectivityResult.ethernet);
      _logger.d('Network connectivity check: $isConnected');
      return isConnected;
    } catch (e) {
      _logger.w('Failed to check network connectivity: $e');
      return false;
    }
  }

  /// Initialize Firebase with default configuration
  Future<void> initializeFirebase() async {
    // Check network connectivity first
    if (!await _checkNetworkConnectivity()) {
      _logger.e('No internet connection available');
      throw const InitializationException(
        'no-network',
        'No internet connection available',
      );
    }

    try {
      _logger.i('Starting Firebase initialization');
      
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

      // Sign in anonymously if no user exists
      if (_auth!.currentUser == null) {
        await signInAnonymously();
      } else {
        _currentUser = _auth!.currentUser;
      }
      
      _logger.i('Firebase initialization completed successfully');
    } on FirebaseException catch (e) {
      _logger.e('Firebase initialization failed', error: e, stackTrace: StackTrace.current);
      throw InitializationException(
        e.code,
        e.message ?? 'Unknown Firebase error',
        e.toString(),
      );
    } catch (e) {
      _logger.e('Unexpected error during Firebase initialization', error: e, stackTrace: StackTrace.current);
      throw InitializationException(
        'unknown-error',
        'Unexpected initialization error',
        e.toString(),
      );
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

  /// Retry Firebase initialization with exponential backoff
  Future<void> retryInitialization({int maxRetries = 3}) async {
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        _logger.i('Retry attempt ${retryCount + 1} of $maxRetries');
        await initializeFirebase();
        _logger.i('Firebase initialization retry successful');
        return;
      } on InitializationException {
        rethrow;
      } catch (e) {
        retryCount++;
        _logger.w('Retry attempt $retryCount failed: $e');
        
        if (retryCount >= maxRetries) {
          _logger.e('All retry attempts exhausted');
          throw InitializationException(
            'retry-failed',
            'Failed to initialize Firebase after $maxRetries attempts',
            e.toString(),
          );
        }

        // Exponential backoff: wait 2^retryCount seconds
        final delay = Duration(seconds: (2 << retryCount));
        _logger.d('Waiting ${delay.inSeconds} seconds before retry');
        await Future.delayed(delay);
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
}
