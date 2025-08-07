import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();
  
  FirebaseService._();

  FirebaseApp? _app;
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  User? _currentUser;
  
  bool get isInitialized => _app != null;
  User? get currentUser => _currentUser;
  FirebaseFirestore get firestore => _firestore!;
  FirebaseAuth get auth => _auth!;

  /// Initialize Firebase with default configuration
  Future<void> initializeFirebase() async {
    try {
      // Initialize Firebase app
      _app = await Firebase.initializeApp();
      
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
      
    } catch (e) {
      throw Exception('Failed to initialize Firebase: $e');
    }
  }

  /// Sign in anonymously for immediate app access
  Future<User?> signInAnonymously() async {
    try {
      final credential = await _auth!.signInAnonymously();
      _currentUser = credential.user;
      return _currentUser;
    } catch (e) {
      throw Exception('Failed to sign in anonymously: $e');
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
        await initializeFirebase();
        return;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          throw Exception('Failed to initialize Firebase after $maxRetries attempts: $e');
        }
        
        // Exponential backoff: wait 2^retryCount seconds
        await Future.delayed(Duration(seconds: (2 << retryCount)));
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