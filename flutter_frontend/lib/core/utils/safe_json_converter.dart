import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';

class SafeJsonConverter {
  static T? safeFromJson<T>(
    Map<String, dynamic>? json,
    T Function(Map<String, dynamic>) fromJson, {
    String? context,
    Map<String, dynamic>? fallbackData,
  }) {
    if (json == null || json.isEmpty) {
      log('SafeJsonConverter: Null or empty JSON provided for ${T.toString()}');
      return null;
    }

    try {
      return fromJson(json);
    } on TypeError catch (e, stackTrace) {
      _logSerializationError(
        'TypeError during JSON parsing',
        T.toString(),
        json,
        e,
        stackTrace,
        context,
      );
      
      // Try with fallback data if provided
      if (fallbackData != null) {
        try {
          final mergedJson = <String, dynamic>{...fallbackData, ...json};
          return fromJson(mergedJson);
        } catch (fallbackError) {
          log('SafeJsonConverter: Fallback parsing also failed: $fallbackError');
        }
      }
      
      return null;
    } catch (e, stackTrace) {
      _logSerializationError(
        'General error during JSON parsing',
        T.toString(),
        json,
        e,
        stackTrace,
        context,
      );
      return null;
    }
  }

  static List<T> safeFromJsonList<T>(
    List<dynamic>? jsonList,
    T Function(Map<String, dynamic>) fromJson, {
    String? context,
    bool skipInvalidItems = true,
  }) {
    if (jsonList == null || jsonList.isEmpty) {
      return <T>[];
    }

    final results = <T>[];
    int skippedCount = 0;

    for (int i = 0; i < jsonList.length; i++) {
      try {
        final item = jsonList[i];
        if (item is Map<String, dynamic>) {
          final parsed = safeFromJson<T>(
            item,
            fromJson,
            context: context != null ? '$context[index: $i]' : 'index: $i',
          );
          if (parsed != null) {
            results.add(parsed);
          } else if (skipInvalidItems) {
            skippedCount++;
          }
        } else {
          log('SafeJsonConverter: Invalid item type at index $i: ${item.runtimeType}');
          if (skipInvalidItems) {
            skippedCount++;
          }
        }
      } catch (e) {
        log('SafeJsonConverter: Error processing item at index $i: $e');
        if (skipInvalidItems) {
          skippedCount++;
        } else {
          rethrow;
        }
      }
    }

    if (skippedCount > 0) {
      log('SafeJsonConverter: Skipped $skippedCount invalid items from list of ${jsonList.length}');
    }

    return results;
  }

  static Map<String, dynamic>? safeToJson<T>(
    T? object,
    Map<String, dynamic> Function(T) toJson, {
    String? context,
  }) {
    if (object == null) {
      return null;
    }

    try {
      return toJson(object);
    } catch (e, stackTrace) {
      _logSerializationError(
        'Error during JSON serialization',
        T.toString(),
        null,
        e,
        stackTrace,
        context,
      );
      return null;
    }
  }

  static bool validateRequiredFields(
    Map<String, dynamic> json,
    List<String> requiredFields, {
    String? context,
  }) {
    final missingFields = <String>[];
    
    for (final field in requiredFields) {
      if (!json.containsKey(field) || json[field] == null) {
        missingFields.add(field);
      }
    }

    if (missingFields.isNotEmpty) {
      log(
        'SafeJsonConverter: Missing required fields in ${context ?? 'unknown context'}: '
        '${missingFields.join(', ')}',
      );
      return false;
    }

    return true;
  }

  static bool isValidFieldType<T>(dynamic value, String fieldName, {String? context}) {
    if (value == null) return true; // Null values are handled separately
    
    final isValid = value is T;
    if (!isValid) {
      log(
        'SafeJsonConverter: Invalid field type for $fieldName in ${context ?? 'unknown context'}: '
        'expected ${T.toString()}, got ${value.runtimeType}',
      );
    }
    
    return isValid;
  }

  static T? getFieldWithFallback<T>(
    Map<String, dynamic> json,
    String fieldName,
    T fallbackValue, {
    String? context,
  }) {
    try {
      final value = json[fieldName];
      if (value == null) {
        return fallbackValue;
      }
      
      if (value is T) {
        return value;
      } else {
        log(
          'SafeJsonConverter: Field $fieldName has wrong type in ${context ?? 'unknown context'}: '
          'expected ${T.toString()}, got ${value.runtimeType}, using fallback',
        );
        return fallbackValue;
      }
    } catch (e) {
      log(
        'SafeJsonConverter: Error accessing field $fieldName in ${context ?? 'unknown context'}: $e, '
        'using fallback',
      );
      return fallbackValue;
    }
  }

  static void _logSerializationError(
    String errorType,
    String objectType,
    Map<String, dynamic>? json,
    dynamic error,
    StackTrace stackTrace,
    String? context,
  ) {
    final contextStr = context != null ? ' (Context: $context)' : '';
    
    log(
      '$errorType for $objectType$contextStr: $error',
      error: error,
      stackTrace: kDebugMode ? stackTrace : null,
    );

    if (json != null && kDebugMode) {
      try {
        final prettyJson = const JsonEncoder.withIndent('  ').convert(json);
        log('SafeJsonConverter: Problematic JSON data:\n$prettyJson');
      } catch (e) {
        log('SafeJsonConverter: Could not stringify JSON data: $e');
        log('SafeJsonConverter: Raw JSON keys: ${json.keys.join(', ')}');
      }
    }

    // Web-specific debugging for JavaScript interop issues
    if (kIsWeb && error.toString().contains('JavaScriptObject')) {
      log('SafeJsonConverter: Detected JavaScript interop error - this is a known Flutter Web + Firebase issue');
      log('SafeJsonConverter: Consider upgrading Firebase packages or implementing web-specific handling');
    }
  }

  static bool hasWebCompatibilityIssue(dynamic error) {
    return kIsWeb && 
           (error.toString().contains('JavaScriptObject') ||
            error.toString().contains('_TypeError') ||
            error.toString().contains('TypeError'));
  }

  // Cache for runtime type strings to avoid repeated toString() calls
  static final Map<Type, String> _typeStringCache = <Type, String>{};
  static const int _maxCacheSize = 100;
  
  // Set for known problematic type patterns
  static final Set<String> _problematicTypePatterns = {
    'JavaScriptObject',
    '_Interceptor',
    'JSObject',
    '_JSObject',
  };

  static Map<String, dynamic> sanitizeForWeb(Map<String, dynamic> json) {
    if (!kIsWeb) return json;

    // Early termination for problematic objects
    if (_hasKnownProblematicStructure(json)) {
      log('SafeJsonConverter: Detected problematic object structure - applying aggressive sanitization');
      return _sanitizeProblematicObject(json);
    }

    // Enhanced size limits to prevent performance issues with large objects
    const int maxFields = 100;
    const int maxStringLength = 10000;
    const int maxNestingDepth = 10;
    
    if (json.length > maxFields) {
      log('SafeJsonConverter: Object too large (${json.length} fields), limiting to first $maxFields fields');
    }

    final sanitized = <String, dynamic>{};
    int processedFields = 0;
    
    for (final entry in json.entries) {
      if (processedFields >= maxFields) break;
      
      final key = entry.key;
      final value = entry.value;
      
      try {
        final sanitizedValue = _sanitizeValue(value, maxStringLength, maxNestingDepth, 0);
        if (sanitizedValue != null) {
          sanitized[key] = sanitizedValue;
        }
      } catch (e) {
        log('SafeJsonConverter: Critical error sanitizing field $key: $e');
        sanitized[key] = null;
      }
      
      processedFields++;
    }

    return sanitized;
  }

  /// Check for known problematic object structures that should be handled specially
  static bool _hasKnownProblematicStructure(Map<String, dynamic> json) {
    // Quick check for Firebase Timestamp-like structures
    if (json.containsKey('seconds') && json.containsKey('nanoseconds')) {
      return true;
    }
    
    // Check for objects with many complex nested structures
    int complexFieldCount = 0;
    for (final value in json.values) {
      if (value is Map || value is List) {
        complexFieldCount++;
        if (complexFieldCount > 20) { // Arbitrary threshold for "too complex"
          return true;
        }
      }
    }
    
    return false;
  }

  /// Apply aggressive sanitization for known problematic objects
  static Map<String, dynamic> _sanitizeProblematicObject(Map<String, dynamic> json) {
    final sanitized = <String, dynamic>{};
    
    // Handle Firebase Timestamp conversion
    if (json.containsKey('seconds') && json.containsKey('nanoseconds')) {
      final seconds = json['seconds'];
      final nanoseconds = json['nanoseconds'];
      
      if (seconds is int && nanoseconds is int) {
        // Convert to ISO string for safe transport
        final dateTime = DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + (nanoseconds ~/ 1000000)
        );
        sanitized['_timestamp'] = dateTime.toIso8601String();
        sanitized['_original_seconds'] = seconds;
        sanitized['_original_nanoseconds'] = nanoseconds;
        return sanitized;
      }
    }
    
    // For other problematic objects, keep only primitive values
    for (final entry in json.entries) {
      final value = entry.value;
      if (value == null || value is bool || value is int || value is double) {
        sanitized[entry.key] = value;
      } else if (value is String && value.length <= 1000) {
        sanitized[entry.key] = value;
      } else {
        sanitized['${entry.key}_sanitized'] = value?.toString() ?? 'null';
      }
    }
    
    return sanitized;
  }

  /// Recursively sanitize a value with depth control
  static dynamic _sanitizeValue(dynamic value, int maxStringLength, int maxDepth, int currentDepth) {
    if (currentDepth > maxDepth) {
      return '[Max depth exceeded]';
    }
    
    // Fast path for primitive types
    if (value == null || value is bool || value is int || value is double) {
      return value;
    }
    
    if (value is String) {
      if (value.length > maxStringLength) {
        log('SafeJsonConverter: Truncated string from ${value.length} to $maxStringLength characters');
        return value.substring(0, maxStringLength);
      }
      return value;
    }
    
    // Handle collections with recursion limit
    if (value is List) {
      try {
        if (value.length > 50) { // Limit list size for performance
          log('SafeJsonConverter: Truncating list from ${value.length} to 50 items');
          return value.take(50)
              .map((item) => _sanitizeValue(item, maxStringLength, maxDepth, currentDepth + 1))
              .toList();
        }
        return value
            .map((item) => _sanitizeValue(item, maxStringLength, maxDepth, currentDepth + 1))
            .toList();
      } catch (e) {
        log('SafeJsonConverter: Error sanitizing list: $e');
        return [];
      }
    }
    
    if (value is Map<String, dynamic>) {
      try {
        final sanitized = <String, dynamic>{};
        for (final entry in value.entries) {
          final sanitizedValue = _sanitizeValue(entry.value, maxStringLength, maxDepth, currentDepth + 1);
          if (sanitizedValue != null) {
            sanitized[entry.key] = sanitizedValue;
          }
        }
        return sanitized;
      } catch (e) {
        log('SafeJsonConverter: Error sanitizing map: $e');
        return <String, dynamic>{};
      }
    }
    
    // Use cached type checking for performance
    if (_isProblematicType(value)) {
      log('SafeJsonConverter: Sanitizing problematic type: ${value.runtimeType}');
      return null;
    }
    
    // For other types, try minimal validation with caching
    try {
      final typeString = _getCachedTypeString(value.runtimeType);
      if (_problematicTypePatterns.any((pattern) => typeString.contains(pattern))) {
        return null;
      }
      
      // Try to access the object safely
      value.toString();
      return value;
    } catch (e) {
      log('SafeJsonConverter: Sanitizing value due to web compatibility issue: $e');
      return null;
    }
  }

  /// Get cached type string to avoid repeated toString() calls on runtimeType
  static String _getCachedTypeString(Type type) {
    // Check cache first
    if (_typeStringCache.containsKey(type)) {
      return _typeStringCache[type]!;
    }
    
    // Manage cache size
    if (_typeStringCache.length >= _maxCacheSize) {
      // Remove oldest entries (simple FIFO)
      final firstKey = _typeStringCache.keys.first;
      _typeStringCache.remove(firstKey);
    }
    
    // Add to cache
    final typeString = type.toString();
    _typeStringCache[type] = typeString;
    return typeString;
  }

  /// Fast check for known problematic types using pattern matching
  static bool _isProblematicType(dynamic value) {
    try {
      final typeString = _getCachedTypeString(value.runtimeType);
      return _problematicTypePatterns.any((pattern) => typeString.contains(pattern));
    } catch (e) {
      // If we can't even get the type string, it's definitely problematic
      return true;
    }
  }
}