import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:developer';

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

  @override
  void initState() {
    super.initState();
    FlutterError.onError = _handleFlutterError;
  }

  void _handleFlutterError(FlutterErrorDetails details) {
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
              if (stackTrace != null) ...[
                const SizedBox(height: 16),
                const Text('Stack Trace:'),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Text(
                      stackTrace.toString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
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