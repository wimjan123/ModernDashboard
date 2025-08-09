import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// Comprehensive authentication service that wraps FirebaseAuth with
/// email/password functionality and account linking capabilities
class AuthService {
  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;
  
  AuthService._internal();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseService get _firebaseService => FirebaseService.instance;

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Get current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      debugPrint('Successfully signed in user: ${credential.user?.email}');
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign in error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Unexpected sign in error: $e');
      throw Exception('An unexpected error occurred during sign in');
    }
  }

  /// Create user with email and password
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      debugPrint('Successfully created user account: ${credential.user?.email}');
      
      // Send email verification
      await credential.user?.sendEmailVerification();
      debugPrint('Email verification sent to ${credential.user?.email}');
      
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Account creation error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Unexpected account creation error: $e');
      throw Exception('An unexpected error occurred during account creation');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      debugPrint('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('Password reset error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Unexpected password reset error: $e');
      throw Exception('An unexpected error occurred sending password reset email');
    }
  }

  /// Link anonymous account with email/password credentials
  Future<UserCredential> linkAnonymousWithEmailPassword(String email, String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      if (!user.isAnonymous) {
        throw Exception('Current user is not anonymous');
      }

      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );

      final linkedCredential = await user.linkWithCredential(credential);
      
      debugPrint('Successfully linked anonymous account with email: $email');
      
      // Send email verification for newly linked account
      await linkedCredential.user?.sendEmailVerification();
      debugPrint('Email verification sent to linked account: $email');
      
      return linkedCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Account linking error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Unexpected account linking error: $e');
      throw Exception('An unexpected error occurred during account linking');
    }
  }

  /// Validate email format
  bool validateEmail(String email) {
    if (email.trim().isEmpty) return false;
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email.trim());
  }

  /// Validate password strength
  Map<String, dynamic> validatePassword(String password) {
    final validation = {
      'isValid': false,
      'errors': <String>[],
      'strength': 'weak',
    };

    if (password.isEmpty) {
      validation['errors'].add('Password cannot be empty');
      return validation;
    }

    if (password.length < 8) {
      validation['errors'].add('Password must be at least 8 characters long');
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      validation['errors'].add('Password must contain at least one uppercase letter');
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      validation['errors'].add('Password must contain at least one lowercase letter');
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      validation['errors'].add('Password must contain at least one number');
    }

    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      validation['errors'].add('Password must contain at least one special character');
    }

    // Determine strength
    final errors = validation['errors'] as List<String>;
    if (errors.isEmpty) {
      validation['isValid'] = true;
      validation['strength'] = 'strong';
    } else if (errors.length <= 2 && password.length >= 8) {
      validation['strength'] = 'medium';
    }

    return validation;
  }

  /// Get current user information
  Map<String, dynamic>? getCurrentUserInfo() {
    final user = currentUser;
    if (user == null) return null;

    return {
      'uid': user.uid,
      'email': user.email,
      'emailVerified': user.emailVerified,
      'isAnonymous': user.isAnonymous,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'creationTime': user.metadata.creationTime?.millisecondsSinceEpoch,
      'lastSignInTime': user.metadata.lastSignInTime?.millisecondsSinceEpoch,
      'providerData': user.providerData.map((info) => {
        'providerId': info.providerId,
        'uid': info.uid,
        'email': info.email,
      }).toList(),
    };
  }

  /// Check if current user's email is verified
  bool isEmailVerified() {
    return currentUser?.emailVerified ?? false;
  }

  /// Send email verification to current user
  Future<void> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      if (user.emailVerified) {
        throw Exception('Email is already verified');
      }

      await user.sendEmailVerification();
      debugPrint('Email verification sent to ${user.email}');
    } on FirebaseAuthException catch (e) {
      debugPrint('Email verification error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Unexpected email verification error: $e');
      throw Exception('An unexpected error occurred sending email verification');
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('User signed out successfully');
    } catch (e) {
      debugPrint('Sign out error: $e');
      throw Exception('An unexpected error occurred during sign out');
    }
  }

  /// Delete current user account
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      await user.delete();
      debugPrint('User account deleted successfully');
    } on FirebaseAuthException catch (e) {
      debugPrint('Account deletion error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Unexpected account deletion error: $e');
      throw Exception('An unexpected error occurred during account deletion');
    }
  }

  /// Update user password
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      if (user.isAnonymous) {
        throw Exception('Anonymous users cannot change passwords');
      }

      final validation = validatePassword(newPassword);
      if (!(validation['isValid'] as bool)) {
        final errors = validation['errors'] as List<String>;
        throw Exception('Password validation failed: ${errors.join(', ')}');
      }

      await user.updatePassword(newPassword);
      debugPrint('Password updated successfully');
    } on FirebaseAuthException catch (e) {
      debugPrint('Password update error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Unexpected password update error: $e');
      throw Exception('An unexpected error occurred during password update');
    }
  }

  /// Reauthenticate user with email and password
  Future<void> reauthenticateWithEmailAndPassword(String email, String password) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      debugPrint('User reauthenticated successfully');
    } on FirebaseAuthException catch (e) {
      debugPrint('Reauthentication error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Unexpected reauthentication error: $e');
      throw Exception('An unexpected error occurred during reauthentication');
    }
  }

  /// Check if user is anonymous
  bool isAnonymous() {
    return currentUser?.isAnonymous ?? false;
  }

  /// Check if user can upgrade account (is anonymous)
  bool canUpgradeAccount() {
    return isAnonymous();
  }

  /// Get list of auth providers for current user
  List<String> getAuthProviders() {
    final user = currentUser;
    if (user == null) return [];
    
    return user.providerData.map((info) => info.providerId).toList();
  }

  /// Handle Firebase Auth exceptions and provide user-friendly error messages
  Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No account found with this email address');
      case 'wrong-password':
        return Exception('Incorrect password');
      case 'email-already-in-use':
        return Exception('An account already exists with this email address');
      case 'weak-password':
        return Exception('The password is too weak');
      case 'invalid-email':
        return Exception('Please enter a valid email address');
      case 'user-disabled':
        return Exception('This account has been disabled');
      case 'too-many-requests':
        return Exception('Too many failed attempts. Please try again later');
      case 'operation-not-allowed':
        return Exception('Email/password sign in is not enabled');
      case 'requires-recent-login':
        return Exception('Please sign in again to complete this action');
      case 'credential-already-in-use':
        return Exception('This email is already associated with another account');
      case 'provider-already-linked':
        return Exception('This provider is already linked to your account');
      default:
        return Exception(e.message ?? 'An authentication error occurred');
    }
  }
}