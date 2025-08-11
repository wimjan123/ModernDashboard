import 'dart:developer';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

class ErrorReportingService {
  static final ErrorReportingService _instance =
      ErrorReportingService._internal();
  static ErrorReportingService get instance => _instance;
  ErrorReportingService._internal();

  final Map<String, int> _errorCounts = {};
  final List<ErrorReport> _recentErrors = [];
  static const int maxRecentErrors = 50;
  static const Duration deduplicationWindow = Duration(minutes: 5);

  void reportError(
    String errorType,
    dynamic error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? context,
    String? userAction,
    ErrorSeverity severity = ErrorSeverity.medium,
  }) {
    final report = ErrorReport(
      type: errorType,
      error: error,
      stackTrace: stackTrace,
      context: context ?? _collectDefaultContext(),
      userAction: userAction,
      severity: severity,
      timestamp: DateTime.now(),
    );

    // Check for deduplication
    if (_shouldDeduplicateError(report)) {
      log('ErrorReportingService: Skipping duplicate error: $errorType');
      return;
    }

    // Add to recent errors list
    _recentErrors.add(report);
    if (_recentErrors.length > maxRecentErrors) {
      _recentErrors.removeAt(0);
    }

    // Update error counts
    final errorKey = _generateErrorKey(report);
    _errorCounts[errorKey] = (_errorCounts[errorKey] ?? 0) + 1;

    // Log the error
    _logError(report);

    // Report to external services if needed (placeholder)
    _reportToExternalServices(report);
  }

  void reportSerializationError(
    dynamic error,
    StackTrace? stackTrace,
    String modelType, {
    Map<String, dynamic>? jsonData,
    String? documentId,
  }) {
    final context = {
      'model_type': modelType,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      if (documentId != null) 'document_id': documentId,
      if (jsonData != null) 'json_keys': jsonData.keys.toList(),
    };

    reportError(
      'serialization_error',
      error,
      stackTrace,
      context: context,
      severity: ErrorSeverity.high,
    );
  }

  void reportNetworkError(
    dynamic error,
    StackTrace? stackTrace, {
    String? endpoint,
    String? method,
    int? statusCode,
  }) {
    final context = {
      'error_category': 'network',
      if (endpoint != null) 'endpoint': endpoint,
      if (method != null) 'method': method,
      if (statusCode != null) 'status_code': statusCode,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    };

    reportError(
      'network_error',
      error,
      stackTrace,
      context: context,
      severity: ErrorSeverity.medium,
    );
  }

  void reportFirebaseError(
    dynamic error,
    StackTrace? stackTrace, {
    String? operation,
    String? collection,
    String? documentId,
  }) {
    final context = {
      'error_category': 'firebase',
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      if (operation != null) 'operation': operation,
      if (collection != null) 'collection': collection,
      if (documentId != null) 'document_id': documentId,
    };

    ErrorSeverity severity = ErrorSeverity.medium;
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('javascriptobject') ||
        errorString.contains('typeerror')) {
      severity = ErrorSeverity.high;
      context['web_interop_issue'] = 'true';
    }

    reportError(
      'firebase_error',
      error,
      stackTrace,
      context: context,
      severity: severity,
    );
  }

  void reportWidgetError(
    dynamic error,
    StackTrace? stackTrace, {
    String? widgetName,
    String? userAction,
  }) {
    final context = {
      'error_category': 'widget',
      if (widgetName != null) 'widget_name': widgetName,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    };

    reportError(
      'widget_error',
      error,
      stackTrace,
      context: context,
      userAction: userAction,
      severity: ErrorSeverity.medium,
    );
  }

  List<ErrorReport> getRecentErrors({
    ErrorSeverity? minSeverity,
    String? errorType,
    Duration? since,
  }) {
    return _recentErrors.where((report) {
      if (minSeverity != null && report.severity.index < minSeverity.index) {
        return false;
      }
      if (errorType != null && report.type != errorType) {
        return false;
      }
      if (since != null &&
          report.timestamp.isBefore(DateTime.now().subtract(since))) {
        return false;
      }
      return true;
    }).toList();
  }

  Map<String, int> getErrorCounts() {
    return Map.from(_errorCounts);
  }

  Map<String, dynamic> getErrorSummary() {
    final now = DateTime.now();
    final recentErrors = _recentErrors
        .where(
          (e) => now.difference(e.timestamp).inHours < 24,
        )
        .toList();

    final errorsByType = <String, int>{};
    final errorsBySeverity = <ErrorSeverity, int>{};

    for (final error in recentErrors) {
      errorsByType[error.type] = (errorsByType[error.type] ?? 0) + 1;
      errorsBySeverity[error.severity] =
          (errorsBySeverity[error.severity] ?? 0) + 1;
    }

    return {
      'total_errors_24h': recentErrors.length,
      'errors_by_type': errorsByType,
      'errors_by_severity': errorsBySeverity.map((k, v) => MapEntry(k.name, v)),
      'most_common_error': errorsByType.entries.isNotEmpty
          ? errorsByType.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : null,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    };
  }

  void clearErrors() {
    _recentErrors.clear();
    _errorCounts.clear();
  }

  bool _shouldDeduplicateError(ErrorReport report) {
    final errorKey = _generateErrorKey(report);
    final recentSimilar = _recentErrors.where(
      (existing) =>
          _generateErrorKey(existing) == errorKey &&
          DateTime.now().difference(existing.timestamp) < deduplicationWindow,
    );

    return recentSimilar.length >=
        3; // Don't report more than 3 of the same error in 5 minutes
  }

  String _generateErrorKey(ErrorReport report) {
    final errorString = report.error.toString();
    final typePrefix = report.type;
    final contextKey = report.context['widget_name'] ??
        report.context['operation'] ??
        report.context['model_type'] ??
        'unknown';

    // Create a more sophisticated key using hash of error message
    final keyComponents = [
      typePrefix,
      contextKey,
      errorString,
      report.stackTrace?.toString().split('\n').take(3).join('\n') ??
          '', // First 3 lines of stack trace
    ];

    final combinedKey = keyComponents.join('|');
    final bytes = utf8.encode(combinedKey);
    final digest = sha256.convert(bytes);

    return '$typePrefix:$contextKey:${digest.toString().substring(0, 16)}';
  }

  Map<String, dynamic> _collectDefaultContext() {
    return {
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'debug_mode': kDebugMode,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  void _logError(ErrorReport report) {
    final contextStr =
        report.context.entries.map((e) => '${e.key}=${e.value}').join(', ');

    log(
      'ErrorReport[${report.severity.name.toUpperCase()}] ${report.type}: ${report.error}',
      error: report.error,
      stackTrace: kDebugMode ? report.stackTrace : null,
    );

    if (contextStr.isNotEmpty) {
      log('ErrorReport Context: $contextStr');
    }

    if (report.userAction != null) {
      log('ErrorReport User Action: ${report.userAction}');
    }
  }

  void _reportToExternalServices(ErrorReport report) {
    // Placeholder for external error reporting services like Crashlytics, Sentry, etc.
    // This would be implemented based on the specific service being used

    if (kDebugMode) {
      log('ErrorReportingService: Would report to external services: ${report.type}');
    }
  }
}

class ErrorReport {
  final String type;
  final dynamic error;
  final StackTrace? stackTrace;
  final Map<String, dynamic> context;
  final String? userAction;
  final ErrorSeverity severity;
  final DateTime timestamp;

  ErrorReport({
    required this.type,
    required this.error,
    this.stackTrace,
    required this.context,
    this.userAction,
    required this.severity,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'ErrorReport(type: $type, error: $error, severity: ${severity.name}, timestamp: $timestamp)';
  }
}

enum ErrorSeverity {
  low, // Minor issues, warnings
  medium, // Normal errors that don't break functionality
  high, // Serious errors that affect functionality
  critical, // Errors that crash the app or break core features
}

extension ErrorSeverityExtension on ErrorSeverity {
  String get name {
    switch (this) {
      case ErrorSeverity.low:
        return 'low';
      case ErrorSeverity.medium:
        return 'medium';
      case ErrorSeverity.high:
        return 'high';
      case ErrorSeverity.critical:
        return 'critical';
    }
  }
}
