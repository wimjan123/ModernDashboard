import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

/// Manages user settings in Firestore with cross-device synchronization
class SettingsService {
  static SettingsService? _instance;
  static SettingsService get instance => _instance ??= SettingsService._();
  
  SettingsService._();

  /// Get the user's settings document reference
  DocumentReference<Map<String, dynamic>>? _getSettingsDocument() {
    final userId = FirebaseService.instance.getUserId();
    if (userId == null) return null;
    
    return FirebaseService.instance.firestore
        ?.collection('users')
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
      print('Error loading settings: $e');
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
      print('Error saving settings: $e');
      rethrow;
    }
  }

  /// Get specific setting value
  Future<T?> getSetting<T>(String key) async {
    try {
      final settings = await loadSettings();
      return settings[key] as T?;
    } catch (e) {
      print('Error getting setting $key: $e');
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
      print('Error updating setting $key: $e');
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
      print('Error exporting settings: $e');
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
      print('Error importing settings: $e');
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
        'signed_in_at': FirebaseService.instance.auth?.currentUser?.metadata.creationTime?.toIso8601String(),
        'last_sign_in': FirebaseService.instance.auth?.currentUser?.metadata.lastSignInTime?.toIso8601String(),
      };
    } catch (e) {
      print('Error getting user info: $e');
      return null;
    }
  }
}