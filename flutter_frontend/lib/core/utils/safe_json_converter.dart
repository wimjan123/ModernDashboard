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

  static Map<String, dynamic> sanitizeForWeb(Map<String, dynamic> json) {
    if (!kIsWeb) return json;

    final sanitized = <String, dynamic>{};
    
    json.forEach((key, value) {
      try {
        // Test if the value can be safely accessed
        value?.toString(); // Test if the value can be safely accessed
        sanitized[key] = value;
      } catch (e) {
        log('SafeJsonConverter: Sanitizing field $key due to web compatibility issue: $e');
        sanitized[key] = null;
      }
    });

    return sanitized;
  }
}