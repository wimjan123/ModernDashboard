import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// Manages user settings in Firestore with cross-device synchronization
/// and handles authentication state changes with automatic settings migration
class SettingsService {
  static SettingsService? _instance;
  static SettingsService get instance => _instance ??= SettingsService._();
  
  SettingsService._() {
    _initializeAuthListener();
  }

  // Auth state management
  StreamSubscription<User?>? _authSubscription;
  StreamController<Map<String, dynamic>?>? _settingsStreamController;
  Map<String, dynamic>? _preservedSettings;

  /// Get the user's settings document reference
  DocumentReference<Map<String, dynamic>>? _getSettingsDocument() {
    final userId = FirebaseService.instance.getUserId();
    if (userId == null) return null;
    
    return FirebaseService.instance.firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('app_settings');
  }

  /// Load settings from Firestore
  Future<Map<String, dynamic>> loadSettings() async {
    try {
      final doc = _getSettingsDocument();
      if (doc == null) {
        return _getDefaultSettings();
      }

      final snapshot = await doc.get();
      if (snapshot.exists) {
        final data = snapshot.data()!;
        // Merge with defaults to ensure all settings exist
        return {..._getDefaultSettings(), ...data};
      } else {
        // First time user - create default settings
        final defaults = _getDefaultSettings();
        await doc.set(defaults);
        return defaults;
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      return _getDefaultSettings();
    }
  }

  /// Save settings to Firestore
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      final doc = _getSettingsDocument();
      if (doc == null) {
        throw Exception('User not authenticated');
      }

      // Add timestamp for tracking when settings were last updated
      final settingsWithTimestamp = {
        ...settings,
        'lastUpdated': FieldValue.serverTimestamp(),
        'version': '1.1.0', // Firebase version
      };

      await doc.set(settingsWithTimestamp, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving settings: $e');
      rethrow;
    }
  }

  /// Get specific setting value
  Future<T?> getSetting<T>(String key) async {
    try {
      final settings = await loadSettings();
      return settings[key] as T?;
    } catch (e) {
      debugPrint('Error getting setting $key: $e');
      return null;
    }
  }

  /// Update specific setting
  Future<void> updateSetting(String key, dynamic value) async {
    try {
      final doc = _getSettingsDocument();
      if (doc == null) {
        throw Exception('User not authenticated');
      }

      await doc.update({
        key: value,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating setting $key: $e');
      rethrow;
    }
  }

  /// Stream of settings changes for real-time updates
  Stream<Map<String, dynamic>?>? getSettingsStream() {
    final doc = _getSettingsDocument();
    if (doc == null) return null;

    return doc.snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        return {..._getDefaultSettings(), ...data};
      }
      return _getDefaultSettings();
    });
  }

  /// Default settings configuration
  Map<String, dynamic> _getDefaultSettings() {
    return {
      'refresh_interval': 30,
      'enable_news': true,
      'enable_weather': true,
      'enable_todos': true,
      'enable_mail': true,
      'theme_mode': 'dark',
      'notifications_enabled': true,
      'weather_units': 'celsius',
      'news_sources': [],
      'created_at': DateTime.now().toIso8601String(),
      'version': '1.1.0',
    };
  }

  /// Reset settings to defaults
  Future<void> resetToDefaults() async {
    await saveSettings(_getDefaultSettings());
  }

  /// Export settings for backup
  Future<Map<String, dynamic>?> exportSettings() async {
    try {
      return await loadSettings();
    } catch (e) {
      debugPrint('Error exporting settings: $e');
      return null;
    }
  }

  /// Import settings from backup
  Future<void> importSettings(Map<String, dynamic> settings) async {
    try {
      // Remove system fields that shouldn't be imported
      final importableSettings = Map<String, dynamic>.from(settings);
      importableSettings.remove('lastUpdated');
      importableSettings.remove('created_at');
      
      await saveSettings(importableSettings);
    } catch (e) {
      debugPrint('Error importing settings: $e');
      rethrow;
    }
  }

  /// Get user account information
  Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final userId = FirebaseService.instance.getUserId();
      if (userId == null) return null;

      return {
        'user_id': userId,
        'is_anonymous': FirebaseService.instance.isAnonymousUser(),
        'signed_in_at': FirebaseService.instance.auth.currentUser?.metadata.creationTime?.toIso8601String(),
        'last_sign_in': FirebaseService.instance.auth.currentUser?.metadata.lastSignInTime?.toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting user info: $e');
      return null;
    }
  }

  // Authentication State Handling

  /// Initialize authentication state listener
  void _initializeAuthListener() {
    try {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
        (User? user) {
          debugPrint('SettingsService: Auth state changed - User: ${user?.uid}');
          _handleAuthStateChange(user);
        },
        onError: (error) {
          debugPrint('SettingsService: Auth state error - $error');
        },
      );
    } catch (e) {
      debugPrint('SettingsService: Failed to initialize auth listener - $e');
    }
  }

  /// Handle authentication state changes
  void _handleAuthStateChange(User? user) {
    try {
      if (user != null) {
        debugPrint('SettingsService: User authenticated, refreshing settings stream');
        _refreshSettingsStream();
      } else {
        debugPrint('SettingsService: User signed out, closing settings stream');
        _closeSettingsStream();
      }
    } catch (e) {
      debugPrint('SettingsService: Error handling auth state change - $e');
    }
  }

  /// Refresh settings stream when auth state changes
  void _refreshSettingsStream() {
    try {
      _closeSettingsStream();
      _settingsStreamController = StreamController<Map<String, dynamic>?>.broadcast();
      
      final settingsStream = getSettingsStream();
      if (settingsStream != null) {
        settingsStream.listen(
          (settings) {
            _settingsStreamController?.add(settings);
          },
          onError: (error) {
            debugPrint('SettingsService: Settings stream error - $error');
            _settingsStreamController?.addError(error);
          },
        );
      }
    } catch (e) {
      debugPrint('SettingsService: Error refreshing settings stream - $e');
    }
  }

  /// Close settings stream
  void _closeSettingsStream() {
    try {
      _settingsStreamController?.close();
      _settingsStreamController = null;
    } catch (e) {
      debugPrint('SettingsService: Error closing settings stream - $e');
    }
  }

  /// Get enhanced settings stream that responds to auth changes
  Stream<Map<String, dynamic>?> getEnhancedSettingsStream() {
    if (_settingsStreamController == null) {
      _refreshSettingsStream();
    }
    return _settingsStreamController?.stream ?? Stream.empty();
  }

  /// Manually refresh settings stream
  void refreshSettingsStream() {
    _refreshSettingsStream();
  }

  // Settings Migration for Account Linking

  /// Preserve anonymous user settings before account linking
  Future<void> preserveAnonymousSettings() async {
    try {
      debugPrint('SettingsService: Preserving anonymous settings before account linking');
      final currentSettings = await loadSettings();
      _preservedSettings = Map<String, dynamic>.from(currentSettings);
      
      // Add preservation metadata
      _preservedSettings!['_preserved_at'] = DateTime.now().toIso8601String();
      _preservedSettings!['_preserved_user_id'] = FirebaseService.instance.getUserId();
      
      debugPrint('SettingsService: Successfully preserved ${_preservedSettings?.length ?? 0} settings');
    } catch (e) {
      debugPrint('SettingsService: Error preserving anonymous settings - $e');
      rethrow;
    }
  }

  /// Restore preserved settings after successful account linking
  Future<void> restorePreservedSettings() async {
    try {
      if (_preservedSettings == null) {
        debugPrint('SettingsService: No preserved settings to restore');
        return;
      }
      
      debugPrint('SettingsService: Restoring preserved settings after account linking');
      
      // Remove preservation metadata
      final settingsToRestore = Map<String, dynamic>.from(_preservedSettings!);
      settingsToRestore.remove('_preserved_at');
      settingsToRestore.remove('_preserved_user_id');
      
      // Save to the new user account
      await saveSettings(settingsToRestore);
      
      // Clean up preserved settings
      _preservedSettings = null;
      
      debugPrint('SettingsService: Successfully restored ${settingsToRestore.length} settings');
    } catch (e) {
      debugPrint('SettingsService: Error restoring preserved settings - $e');
      rethrow;
    }
  }

  /// Clean up preserved settings (called on failure)
  void cleanupPreservedSettings() {
    try {
      _preservedSettings = null;
      debugPrint('SettingsService: Cleaned up preserved settings');
    } catch (e) {
      debugPrint('SettingsService: Error cleaning up preserved settings - $e');
    }
  }

  /// Migrate settings from one user to another
  Future<void> migrateAnonymousSettings(String fromUserId, String toUserId) async {
    try {
      debugPrint('SettingsService: Migrating settings from $fromUserId to $toUserId');
      
      // Get source settings document
      final fromDoc = FirebaseService.instance.firestore
          .collection('users')
          .doc(fromUserId)
          .collection('settings')
          .doc('app_settings');
      
      
      final sourceSnapshot = await fromDoc.get();
      if (!sourceSnapshot.exists) {
        debugPrint('SettingsService: No source settings to migrate');
        return;
      }
      
      final sourceSettings = sourceSnapshot.data()!;
      
      // Get destination settings document
      final toDoc = FirebaseService.instance.firestore
          .collection('users')
          .doc(toUserId)
          .collection('settings')
          .doc('app_settings');
      
      final destSnapshot = await toDoc.get();
      Map<String, dynamic> finalSettings;
      
      if (destSnapshot.exists) {
        // Merge settings, preferring newer timestamps
        final destSettings = destSnapshot.data()!;
        finalSettings = _mergeSettings(sourceSettings, destSettings);
      } else {
        // No destination settings, use source settings
        finalSettings = Map<String, dynamic>.from(sourceSettings);
      }
      
      // Update migration metadata
      finalSettings['migrated_from'] = fromUserId;
      finalSettings['migrated_at'] = DateTime.now().toIso8601String();
      finalSettings['lastUpdated'] = FieldValue.serverTimestamp();
      
      // Save merged settings
      await toDoc.set(finalSettings);
      
      debugPrint('SettingsService: Successfully migrated settings');
    } catch (e) {
      debugPrint('SettingsService: Error migrating settings - $e');
      rethrow;
    }
  }

  /// Merge two settings maps, preferring newer timestamps
  Map<String, dynamic> _mergeSettings(
    Map<String, dynamic> source,
    Map<String, dynamic> destination,
  ) {
    final merged = Map<String, dynamic>.from(destination);
    
    // Get timestamps for comparison
    final sourceTimestamp = _getTimestamp(source['lastUpdated']);
    final destTimestamp = _getTimestamp(destination['lastUpdated']);
    
    // If source is newer, prefer source settings
    if (sourceTimestamp != null && destTimestamp != null) {
      if (sourceTimestamp.isAfter(destTimestamp)) {
        // Source is newer, use source settings but keep destination metadata
        merged.addAll(source);
        merged['merged_from_newer'] = true;
      } else {
        // Destination is newer, keep destination settings
        merged['merged_from_older'] = true;
      }
    } else {
      // Can't compare timestamps, merge manually
      source.forEach((key, value) {
        if (!merged.containsKey(key)) {
          merged[key] = value;
        }
      });
      merged['merged_without_timestamps'] = true;
    }
    
    return merged;
  }

  /// Extract DateTime from Firestore timestamp
  DateTime? _getTimestamp(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is String) {
        return DateTime.tryParse(timestamp);
      }
    } catch (e) {
      debugPrint('SettingsService: Error parsing timestamp - $e');
    }
    return null;
  }

  /// Dispose resources
  void dispose() {
    try {
      _authSubscription?.cancel();
      _closeSettingsStream();
      _preservedSettings = null;
      debugPrint('SettingsService: Disposed successfully');
    } catch (e) {
      debugPrint('SettingsService: Error during dispose - $e');
    }
  }
}