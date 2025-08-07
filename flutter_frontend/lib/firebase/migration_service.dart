import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';
import 'settings_service.dart';
import '../repositories/todo_repository.dart';
import '../repositories/firestore_todo_repository.dart';

/// Migration service to transition data from local storage to Firebase
class MigrationService {
  static MigrationService? _instance;
  static MigrationService get instance => _instance ??= MigrationService._();
  
  MigrationService._();

  /// Check if migration is needed
  Future<bool> isMigrationNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if there's legacy data that needs migration
      final hasLegacySettings = prefs.containsKey('refresh_interval') ||
                               prefs.containsKey('enable_news') ||
                               prefs.containsKey('enable_weather') ||
                               prefs.containsKey('enable_todos') ||
                               prefs.containsKey('enable_mail');
      
      // Check if migration has already been completed
      final migrationCompleted = prefs.getBool('migration_completed') ?? false;
      
      return hasLegacySettings && !migrationCompleted;
    } catch (e) {
      debugPrint('Error checking migration status: $e');
      return false;
    }
  }

  /// Get migration summary for user confirmation
  Future<MigrationSummary> getMigrationSummary() async {
    final summary = MigrationSummary();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check settings migration
      if (prefs.containsKey('refresh_interval')) {
        summary.settingsToMigrate = {
          'refresh_interval': prefs.getInt('refresh_interval'),
          'enable_news': prefs.getBool('enable_news'),
          'enable_weather': prefs.getBool('enable_weather'),
          'enable_todos': prefs.getBool('enable_todos'),
          'enable_mail': prefs.getBool('enable_mail'),
        };
      }
      
      // Check for other legacy data
      final allKeys = prefs.getKeys();
      summary.totalItems = allKeys.length;
      summary.legacyKeys = allKeys.where((key) => !key.startsWith('firebase_')).toList();
      
    } catch (e) {
      debugPrint('Error getting migration summary: $e');
    }
    
    return summary;
  }

  /// Perform complete data migration from local to Firebase
  Future<MigrationResult> performMigration({
    bool migrateSettings = true,
    bool migrateTodos = true,
    bool migrateUserPreferences = true,
    void Function(String)? onProgress,
  }) async {
    final result = MigrationResult();
    
    try {
      // Ensure Firebase is initialized
      if (!FirebaseService.instance.isInitialized) {
        throw Exception('Firebase not initialized');
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      onProgress?.call('Starting migration...');
      
      // 1. Migrate Settings
      if (migrateSettings) {
        onProgress?.call('Migrating settings...');
        await _migrateSettings(prefs, result);
      }
      
      // 2. Migrate User Preferences
      if (migrateUserPreferences) {
        onProgress?.call('Migrating user preferences...');
        await _migrateUserPreferences(prefs, result);
      }
      
      // 3. Migrate Todos (if any local todos exist)
      if (migrateTodos) {
        onProgress?.call('Migrating todos...');
        await _migrateTodos(prefs, result);
      }
      
      // 4. Clean up old data (optional step)
      onProgress?.call('Cleaning up legacy data...');
      await _cleanupLegacyData(prefs, result);
      
      // 5. Mark migration as completed
      await prefs.setBool('migration_completed', true);
      await prefs.setString('migration_date', DateTime.now().toIso8601String());
      await prefs.setString('migrated_to_firebase', 'v1.1.0');
      
      onProgress?.call('Migration completed successfully!');
      result.success = true;
      result.completedAt = DateTime.now();
      
    } catch (e) {
      result.success = false;
      result.error = 'Migration failed: $e';
      debugPrint('Migration error: $e');
    }
    
    return result;
  }

  /// Migrate settings from SharedPreferences to Firestore
  Future<void> _migrateSettings(SharedPreferences prefs, MigrationResult result) async {
    try {
      final settingsToMigrate = <String, dynamic>{};
      
      // Extract legacy settings
      if (prefs.containsKey('refresh_interval')) {
        settingsToMigrate['refresh_interval'] = prefs.getInt('refresh_interval') ?? 30;
      }
      if (prefs.containsKey('enable_news')) {
        settingsToMigrate['enable_news'] = prefs.getBool('enable_news') ?? true;
      }
      if (prefs.containsKey('enable_weather')) {
        settingsToMigrate['enable_weather'] = prefs.getBool('enable_weather') ?? true;
      }
      if (prefs.containsKey('enable_todos')) {
        settingsToMigrate['enable_todos'] = prefs.getBool('enable_todos') ?? true;
      }
      if (prefs.containsKey('enable_mail')) {
        settingsToMigrate['enable_mail'] = prefs.getBool('enable_mail') ?? true;
      }
      
      // Add default values for new Firebase-specific settings
      settingsToMigrate.addAll({
        'theme_mode': 'dark',
        'notifications_enabled': true,
        'weather_units': 'celsius',
        'migrated_from_local': true,
      });
      
      if (settingsToMigrate.isNotEmpty) {
        await SettingsService.instance.saveSettings(settingsToMigrate);
        result.settingsMigrated = settingsToMigrate.length;
        debugPrint('Migrated ${settingsToMigrate.length} settings to Firebase');
      }
      
    } catch (e) {
      result.errors.add('Settings migration failed: $e');
      throw e;
    }
  }

  /// Migrate user preferences and app state
  Future<void> _migrateUserPreferences(SharedPreferences prefs, MigrationResult result) async {
    try {
      final userPrefs = <String, dynamic>{};
      
      // Migrate weather location preference
      final weatherLocation = prefs.getString('weather_location');
      if (weatherLocation != null) {
        userPrefs['weather_location'] = weatherLocation;
      }
      
      // Migrate news feed URLs
      final newsFeeds = prefs.getStringList('news_feeds');
      if (newsFeeds != null && newsFeeds.isNotEmpty) {
        userPrefs['news_feeds'] = newsFeeds;
      }
      
      // Migrate last update timestamps
      final lastWeatherUpdate = prefs.getString('last_weather_update');
      if (lastWeatherUpdate != null) {
        userPrefs['last_weather_update'] = lastWeatherUpdate;
      }
      
      final lastNewsUpdate = prefs.getString('last_news_update');
      if (lastNewsUpdate != null) {
        userPrefs['last_news_update'] = lastNewsUpdate;
      }
      
      if (userPrefs.isNotEmpty) {
        // Save user preferences to Firestore user document
        final userId = FirebaseService.instance.getUserId();
        if (userId != null) {
          await FirebaseService.instance.firestore
              .collection('users')
              .doc(userId)
              .collection('preferences')
              .doc('app_prefs')
              .set(userPrefs);
          
          result.preferencesMigrated = userPrefs.length;
          debugPrint('Migrated ${userPrefs.length} user preferences to Firebase');
        }
      }
      
    } catch (e) {
      result.errors.add('User preferences migration failed: $e');
      throw e;
    }
  }

  /// Migrate todos from local storage to Firestore
  Future<void> _migrateTodos(SharedPreferences prefs, MigrationResult result) async {
    try {
      // Check if there are any locally stored todos
      final todoKeys = prefs.getKeys().where((key) => key.startsWith('todo_')).toList();
      
      if (todoKeys.isNotEmpty) {
        final firestoreTodoRepo = FirestoreTodoRepository();
        int migratedCount = 0;
        
        for (final key in todoKeys) {
          try {
            final todoJson = prefs.getString(key);
            if (todoJson != null) {
              // Parse the JSON and create TodoItem
              // Note: This assumes todos were stored as JSON strings locally
              // Adjust parsing logic based on actual local storage format
              final todoData = {
                'title': todoJson, // Simplified - adjust based on actual format
                'description': '',
                'category': 'general',
                'priority': 'medium',
                'status': 'pending',
                'createdAt': DateTime.now(),
                'updatedAt': DateTime.now(),
              };
              
              final todo = TodoItem(
                id: '', // Will be generated by Firestore
                title: todoData['title'],
                description: todoData['description'],
                category: todoData['category'],
                priority: todoData['priority'],
                status: todoData['status'],
                createdAt: todoData['createdAt'],
                updatedAt: todoData['updatedAt'],
              );
              
              await firestoreTodoRepo.addTodo(todo);
              migratedCount++;
            }
          } catch (e) {
            debugPrint('Failed to migrate todo $key: $e');
            result.errors.add('Failed to migrate todo $key: $e');
          }
        }
        
        result.todosMigrated = migratedCount;
        debugPrint('Migrated $migratedCount todos to Firebase');
      }
      
    } catch (e) {
      result.errors.add('Todos migration failed: $e');
      // Don't throw here as this is not critical for the app to function
    }
  }

  /// Clean up legacy data after successful migration
  Future<void> _cleanupLegacyData(SharedPreferences prefs, MigrationResult result) async {
    try {
      final keysToRemove = [
        'refresh_interval',
        'enable_news',
        'enable_weather',
        'enable_todos',
        'enable_mail',
        'weather_location',
        'news_feeds',
        'last_weather_update',
        'last_news_update',
      ];
      
      // Also remove any todo keys
      final todoKeys = prefs.getKeys().where((key) => key.startsWith('todo_')).toList();
      keysToRemove.addAll(todoKeys);
      
      int removedCount = 0;
      for (final key in keysToRemove) {
        if (prefs.containsKey(key)) {
          await prefs.remove(key);
          removedCount++;
        }
      }
      
      result.legacyDataCleaned = removedCount;
      debugPrint('Cleaned up $removedCount legacy data entries');
      
    } catch (e) {
      result.errors.add('Legacy data cleanup failed: $e');
      // Don't throw here as cleanup failure shouldn't fail the migration
    }
  }

  /// Check migration status
  Future<MigrationStatus> getMigrationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (prefs.getBool('migration_completed') == true) {
        final migrationDate = prefs.getString('migration_date');
        final migratedVersion = prefs.getString('migrated_to_firebase');
        
        return MigrationStatus(
          isCompleted: true,
          completedAt: migrationDate != null ? DateTime.parse(migrationDate) : null,
          migratedToVersion: migratedVersion,
        );
      }
      
      return const MigrationStatus(isCompleted: false);
      
    } catch (e) {
      debugPrint('Error checking migration status: $e');
      return const MigrationStatus(isCompleted: false);
    }
  }

  /// Force reset migration status (for testing or re-migration)
  Future<void> resetMigrationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('migration_completed');
      await prefs.remove('migration_date');
      await prefs.remove('migrated_to_firebase');
    } catch (e) {
      debugPrint('Error resetting migration status: $e');
    }
  }
}

/// Summary of data available for migration
class MigrationSummary {
  Map<String, dynamic> settingsToMigrate = {};
  List<String> legacyKeys = [];
  int totalItems = 0;
  int estimatedTodos = 0;
  bool hasUserPreferences = false;
}

/// Result of migration operation
class MigrationResult {
  bool success = false;
  DateTime? completedAt;
  String? error;
  int settingsMigrated = 0;
  int preferencesMigrated = 0;
  int todosMigrated = 0;
  int legacyDataCleaned = 0;
  List<String> errors = [];

  @override
  String toString() {
    if (success) {
      return 'Migration successful: $settingsMigrated settings, $preferencesMigrated preferences, $todosMigrated todos migrated. $legacyDataCleaned legacy items cleaned up.';
    } else {
      return 'Migration failed: $error. Errors: ${errors.join(', ')}';
    }
  }
}

/// Current migration status
class MigrationStatus {
  final bool isCompleted;
  final DateTime? completedAt;
  final String? migratedToVersion;
  final String? error;

  const MigrationStatus({
    required this.isCompleted,
    this.completedAt,
    this.migratedToVersion,
    this.error,
  });
}