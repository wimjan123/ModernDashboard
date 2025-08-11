import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:developer';
import '../../core/services/error_reporting_service.dart';
import '../../core/services/web_compatibility_service.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace stackTrace)? onError;
  final VoidCallback? onRetry;
  final String? context;
  final bool showStackTrace;
  final ErrorDisplayMode displayMode;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.onError,
    this.onRetry,
    this.context,
    this.showStackTrace = false,
    this.displayMode = ErrorDisplayMode.detailed,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;
  bool _hasError = false;
  FlutterExceptionHandler? _previousOnError;

  @override
  void initState() {
    super.initState();
    // Store the previous error handler and chain to it
    _previousOnError = FlutterError.onError;
    FlutterError.onError = _handleFlutterError;
  }

  @override
  void dispose() {
    // Restore the previous error handler
    if (_previousOnError != null) {
      FlutterError.onError = _previousOnError;
    }
    super.dispose();
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    // First, call the previous error handler to maintain global error handling
    _previousOnError?.call(details);
    
    // Only handle the error locally if this widget is still mounted
    if (mounted) {
      setState(() {
        _error = details.exception;
        _stackTrace = details.stack;
        _hasError = true;
      });
      
      _logError(details.exception, details.stack);
    }
  }

  void _logError(Object error, StackTrace? stackTrace) {
    final contextStr = widget.context != null ? ' (${widget.context})' : '';
    log(
      'ErrorBoundary: Caught error$contextStr: $error',
      error: error,
      stackTrace: kDebugMode ? stackTrace : null,
    );
    
    // Report error to ErrorReportingService for centralized tracking
    ErrorReportingService.instance.reportWidgetError(
      error,
      stackTrace,
      widgetName: widget.context ?? 'ErrorBoundary',
      userAction: 'Widget rendering or interaction',
    );
    
    // Check for web-specific compatibility issues
    if (kIsWeb) {
      WebCompatibilityService.instance.initialize().then((_) {
        final isWebCompatibilityIssue = WebCompatibilityService.instance.isKnownFirebaseInteropIssue(error);
        if (isWebCompatibilityIssue) {
          log('ErrorBoundary: Detected web compatibility issue - logging recommendations');
          final recommendations = WebCompatibilityService.instance.getRecommendedFixes();
          if (recommendations.isNotEmpty) {
            log('ErrorBoundary web compatibility recommendations: ${recommendations.keys.join(', ')}');
          }
          
          // Report web-specific error with additional context
          ErrorReportingService.instance.reportError(
            'web_compatibility_widget_error',
            error,
            stackTrace,
            context: {
              'widget_context': widget.context ?? 'ErrorBoundary',
              'web_compatibility_issue': true,
              'recommendations': recommendations.keys.toList(),
              'compatibility_report': WebCompatibilityService.instance.hasCompatibilityIssues(),
            },
            severity: ErrorSeverity.high,
          );
        }
      }).catchError((e) {
        log('ErrorBoundary: Failed to initialize WebCompatibilityService: $e');
      });
    }
  }

  void _retry() {
    if (mounted) {
      setState(() {
        _error = null;
        _stackTrace = null;
        _hasError = false;
      });
      
      widget.onRetry?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && _error != null) {
      if (widget.onError != null) {
        return widget.onError!(_error!, _stackTrace ?? StackTrace.empty);
      }
      
      return _buildErrorWidget(context, _error!, _stackTrace);
    }

    return _SafeWidgetWrapper(
      child: widget.child,
      onError: (error, stackTrace) {
        if (mounted) {
          setState(() {
            _error = error;
            _stackTrace = stackTrace;
            _hasError = true;
          });
          
          _logError(error, stackTrace);
        }
      },
    );
  }

  Widget _buildErrorWidget(BuildContext context, Object error, StackTrace? stackTrace) {
    final theme = Theme.of(context);
    
    switch (widget.displayMode) {
      case ErrorDisplayMode.minimal:
        return _buildMinimalError(theme);
      case ErrorDisplayMode.detailed:
        return _buildDetailedError(context, theme, error, stackTrace);
      case ErrorDisplayMode.debug:
        return _buildDebugError(context, theme, error, stackTrace);
    }
  }

  Widget _buildMinimalError(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Error occurred',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          if (widget.onRetry != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: _retry,
              child: Icon(
                Icons.refresh,
                color: theme.colorScheme.primary,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailedError(BuildContext context, ThemeData theme, Object error, StackTrace? stackTrace) {
    final errorType = _categorizeError(error);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getErrorIcon(errorType),
                color: theme.colorScheme.error,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getErrorTitle(errorType),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _getErrorMessage(errorType, error),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.onRetry != null)
                ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                  ),
                ),
              const Spacer(),
              if (kDebugMode)
                TextButton(
                  onPressed: () => _showDebugDialog(context, error, stackTrace),
                  child: const Text('Debug Info'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugError(BuildContext context, ThemeData theme, Object error, StackTrace? stackTrace) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Debug Error Information',
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Error: $error',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
          if (stackTrace != null && widget.showStackTrace) ...[
            const SizedBox(height: 8),
            Text(
              'Stack Trace:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(
                  stackTrace.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
          if (widget.onRetry != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _retry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }

  ErrorType _categorizeError(Object error) {
    final errorString = error.toString().toLowerCase();
    
    // Use WebCompatibilityService for more accurate web error detection
    if (kIsWeb) {
      final isWebCompatibilityIssue = WebCompatibilityService.instance.isKnownFirebaseInteropIssue(error);
      if (isWebCompatibilityIssue) {
        return ErrorType.serialization;
      }
    }
    
    // Fallback to string-based detection
    if (errorString.contains('javascriptobject') || 
        errorString.contains('typeerror') ||
        errorString.contains('interop')) {
      return ErrorType.serialization;
    }
    
    if (errorString.contains('socket') || 
        errorString.contains('network') ||
        errorString.contains('connection')) {
      return ErrorType.network;
    }
    
    if (errorString.contains('permission') || 
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden')) {
      return ErrorType.permission;
    }
    
    return ErrorType.unknown;
  }

  IconData _getErrorIcon(ErrorType errorType) {
    switch (errorType) {
      case ErrorType.serialization:
        return Icons.data_usage_outlined;
      case ErrorType.network:
        return Icons.wifi_off_outlined;
      case ErrorType.permission:
        return Icons.lock_outline;
      case ErrorType.unknown:
        return Icons.error_outline;
    }
  }

  String _getErrorTitle(ErrorType errorType) {
    switch (errorType) {
      case ErrorType.serialization:
        return 'Data Processing Error';
      case ErrorType.network:
        return 'Connection Error';
      case ErrorType.permission:
        return 'Permission Error';
      case ErrorType.unknown:
        return 'Something went wrong';
    }
  }

  String _getErrorMessage(ErrorType errorType, Object error) {
    switch (errorType) {
      case ErrorType.serialization:
        // Provide web-specific guidance if available
        if (kIsWeb && WebCompatibilityService.instance.hasCompatibilityIssues()) {
          final recommendations = WebCompatibilityService.instance.getRecommendedFixes();
          if (recommendations.containsKey('offline_mode')) {
            return 'There was a data processing issue due to browser compatibility. Consider switching to offline mode for better stability.';
          } else if (recommendations.containsKey('firebase_packages')) {
            return 'This appears to be a Firebase compatibility issue. The system can switch to offline mode to continue working.';
          }
        }
        return 'There was an issue processing the data. This might be due to a compatibility issue with your browser or outdated data format.';
      case ErrorType.network:
        return 'Unable to connect to the service. Please check your internet connection and try again.';
      case ErrorType.permission:
        return 'You don\'t have permission to access this resource. Please check your account settings.';
      case ErrorType.unknown:
        return 'An unexpected error occurred. Please try again, and if the problem persists, contact support.';
    }
  }

  void _showDebugDialog(BuildContext context, Object error, StackTrace? stackTrace) {
    // Gather additional debug information
    final errorSummary = ErrorReportingService.instance.getErrorSummary();
    final recentErrors = ErrorReportingService.instance.getRecentErrors(
      minSeverity: ErrorSeverity.medium,
      since: const Duration(minutes: 30),
    );
    
    String webCompatibilityInfo = 'N/A (not on web platform)';
    if (kIsWeb) {
      if (WebCompatibilityService.instance.hasCompatibilityIssues()) {
        webCompatibilityInfo = WebCompatibilityService.instance.generateCompatibilityReport();
      } else {
        webCompatibilityInfo = 'No compatibility issues detected';
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $error'),
              const SizedBox(height: 16),
              
              // Error reporting summary
              const Text(
                'Error Summary (24h):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Total errors: ${errorSummary['total_errors_24h']}'),
              if (errorSummary['most_common_error'] != null)
                Text('Most common: ${errorSummary['most_common_error']}'),
              const SizedBox(height: 8),
              
              // Recent similar errors
              if (recentErrors.isNotEmpty) ...[
                Text(
                  'Recent similar errors (${recentErrors.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                ...recentErrors.take(3).map(
                  (report) => Text(
                    '• ${report.type} (${report.severity.name}) - ${_formatTimestamp(report.timestamp)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Web compatibility information
              if (kIsWeb) ...[
                const Text(
                  'Web Compatibility:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: Text(
                      webCompatibilityInfo,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Stack trace
              if (stackTrace != null) ...[
                const Text(
                  'Stack Trace:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Text(
                      stackTrace.toString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (kIsWeb && WebCompatibilityService.instance.hasCompatibilityIssues())
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Show web compatibility recommendations
                _showWebCompatibilityDialog(context);
              },
              child: const Text('Web Solutions'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showWebCompatibilityDialog(BuildContext context) {
    final recommendations = WebCompatibilityService.instance.getRecommendedFixes();
    final issues = WebCompatibilityService.instance.getDetectedIssues();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Web Compatibility Solutions'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Detected Issues:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...issues.map(
                (issue) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ${issue.title} (${issue.severity.name})',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '  ${issue.description}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '  💡 ${issue.suggestion}',
                        style: const TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),
              if (recommendations.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Recommended Actions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...recommendations.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• ${entry.value}'),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class _SafeWidgetWrapper extends StatefulWidget {
  final Widget child;
  final Function(Object error, StackTrace stackTrace)? onError;

  const _SafeWidgetWrapper({
    required this.child,
    this.onError,
  });

  @override
  State<_SafeWidgetWrapper> createState() => _SafeWidgetWrapperState();
}

class _SafeWidgetWrapperState extends State<_SafeWidgetWrapper> {
  @override
  Widget build(BuildContext context) {
    try {
      return widget.child;
    } catch (error, stackTrace) {
      widget.onError?.call(error, stackTrace);
      return const SizedBox.shrink();
    }
  }
}

enum ErrorDisplayMode {
  minimal,
  detailed,
  debug,
}

enum ErrorType {
  serialization,
  network,
  permission,
  unknown,
}