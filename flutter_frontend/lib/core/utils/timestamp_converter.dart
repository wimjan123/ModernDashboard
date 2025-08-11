import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/foundation.dart';
import 'dart:js_util' as js_util if (dart.library.js) 'dart:js_util';

class TimestampConverter {
  static DateTime? parseTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      return null;
    }

    try {
      // Handle Firestore Timestamp objects
      if (timestamp is firestore.Timestamp) {
        return timestamp.toDate();
      }

      // Web-specific handling for Firestore timestamps
      if (kIsWeb) {
        // Handle JavaScript interop objects that might be Firestore timestamps
        try {
          if (timestamp.runtimeType.toString().contains('Timestamp')) {
            // Try to access seconds and nanoseconds properties
            final seconds = _getProperty(timestamp, 'seconds');
            final nanoseconds = _getProperty(timestamp, 'nanoseconds');

            if (seconds != null && nanoseconds != null) {
              final millisecondsFromSeconds = seconds * 1000;
              final millisecondsFromNanoseconds =
                  (nanoseconds / 1000000).round();
              return DateTime.fromMillisecondsSinceEpoch(
                millisecondsFromSeconds + millisecondsFromNanoseconds,
                isUtc: true,
              );
            }
          }
        } catch (e) {
          log('Web Firestore timestamp parsing failed: $e');
        }
      }

      // Handle Map-based timestamp representations
      if (timestamp is Map<String, dynamic>) {
        if (timestamp.containsKey('seconds') &&
            timestamp.containsKey('nanoseconds')) {
          final seconds = timestamp['seconds'] as int?;
          final nanoseconds = timestamp['nanoseconds'] as int?;

          if (seconds != null && nanoseconds != null) {
            final millisecondsFromSeconds = seconds * 1000;
            final millisecondsFromNanoseconds = (nanoseconds / 1000000).round();
            return DateTime.fromMillisecondsSinceEpoch(
              millisecondsFromSeconds + millisecondsFromNanoseconds,
              isUtc: true,
            );
          }
        }

        // Handle other timestamp formats in maps
        if (timestamp.containsKey('_seconds')) {
          final seconds = timestamp['_seconds'] as int?;
          final nanoseconds = timestamp['_nanoseconds'] as int? ?? 0;

          if (seconds != null) {
            final millisecondsFromSeconds = seconds * 1000;
            final millisecondsFromNanoseconds = (nanoseconds / 1000000).round();
            return DateTime.fromMillisecondsSinceEpoch(
              millisecondsFromSeconds + millisecondsFromNanoseconds,
              isUtc: true,
            );
          }
        }
      }

      // Handle integer milliseconds since epoch
      if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
      }

      // Handle string representations
      if (timestamp is String) {
        return DateTime.parse(timestamp);
      }

      // Handle DateTime objects directly
      if (timestamp is DateTime) {
        return timestamp;
      }

      // Log unhandled timestamp format for debugging
      log('Unhandled timestamp format: ${timestamp.runtimeType}, value: $timestamp');
      return null;
    } catch (e, stackTrace) {
      log(
        'Timestamp parsing error: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static dynamic _getProperty(dynamic obj, String property) {
    if (!kIsWeb) return null;

    try {
      // Use dart:js_util for proper JavaScript interop
      if (js_util.hasProperty(obj, property)) {
        return js_util.getProperty(obj, property);
      }
      return null;
    } catch (e) {
      log('TimestampConverter: Failed to get property $property from JavaScript object: $e');
      return null;
    }
  }

  static firestore.Timestamp? dateTimeToTimestamp(DateTime? dateTime) {
    if (dateTime == null) return null;

    try {
      return firestore.Timestamp.fromDate(dateTime);
    } catch (e) {
      log('DateTime to Timestamp conversion failed: $e');
      return null;
    }
  }

  static int? dateTimeToMilliseconds(DateTime? dateTime) {
    if (dateTime == null) return null;
    return dateTime.millisecondsSinceEpoch;
  }

  static Map<String, dynamic>? dateTimeToMap(DateTime? dateTime) {
    if (dateTime == null) return null;

    try {
      final timestamp = firestore.Timestamp.fromDate(dateTime);
      return {
        'seconds': timestamp.seconds,
        'nanoseconds': timestamp.nanoseconds,
      };
    } catch (e) {
      log('DateTime to Map conversion failed: $e');
      return null;
    }
  }

  static DateTime now() {
    return DateTime.now().toUtc();
  }

  static bool isValidTimestamp(dynamic timestamp) {
    return parseTimestamp(timestamp) != null;
  }
}
