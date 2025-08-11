class FeedValidationException implements Exception {
  final String code;
  final String message;
  final String? details;
  final String? suggestion;
  final bool canRetryWithProxy;

  const FeedValidationException(
    this.code,
    this.message, {
    this.details,
    this.suggestion,
    this.canRetryWithProxy = false,
  });

  /// Creates an exception for invalid URL format
  factory FeedValidationException.invalidUrl(String url, {String? suggestion}) {
    return FeedValidationException(
      'invalid_url',
      'The provided URL is not valid: $url',
      suggestion: suggestion ?? 'Please check the URL format and ensure it starts with http:// or https://',
      canRetryWithProxy: false,
    );
  }

  /// Creates an exception for CORS blocking on web platform
  factory FeedValidationException.corsBlocked(String url) {
    return FeedValidationException(
      'cors_blocked',
      'Unable to access RSS feed due to CORS restrictions',
      details: 'URL: $url',
      suggestion: 'This is a web browser limitation. Try using a CORS proxy service.',
      canRetryWithProxy: true,
    );
  }

  /// Creates an exception when content is not a valid RSS feed
  factory FeedValidationException.notRssFeed(String url) {
    return FeedValidationException(
      'not_rss_feed',
      'The URL does not point to a valid RSS or Atom feed',
      details: 'URL: $url',
      suggestion: 'Please verify the URL points to an RSS or Atom feed. Look for feed links on the website.',
      canRetryWithProxy: false,
    );
  }

  /// Creates an exception for network connectivity issues
  factory FeedValidationException.networkError(String url, {String? details}) {
    return FeedValidationException(
      'network_error',
      'Network error while accessing RSS feed',
      details: details ?? 'URL: $url',
      suggestion: 'Please check your internet connection and try again.',
      canRetryWithProxy: true,
    );
  }

  /// Creates an exception for request timeouts
  factory FeedValidationException.timeout(String url) {
    return FeedValidationException(
      'timeout',
      'Request timed out while accessing RSS feed',
      details: 'URL: $url',
      suggestion: 'The server is taking too long to respond. Please try again later.',
      canRetryWithProxy: true,
    );
  }

  /// Creates an exception for server errors (4xx, 5xx)
  factory FeedValidationException.serverError(String url, int statusCode, {String? statusMessage}) {
    return FeedValidationException(
      'server_error',
      'Server error while accessing RSS feed',
      details: 'URL: $url, Status: $statusCode ${statusMessage ?? ''}',
      suggestion: statusCode >= 400 && statusCode < 500
          ? 'The feed URL may be incorrect or the feed may have moved.'
          : 'The server is experiencing issues. Please try again later.',
      canRetryWithProxy: statusCode == 403 || statusCode == 405,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('FeedValidationException($code): $message');
    
    if (details != null) {
      buffer.write('\nDetails: $details');
    }
    
    if (suggestion != null) {
      buffer.write('\nSuggestion: $suggestion');
    }
    
    if (canRetryWithProxy) {
      buffer.write('\nCan retry with proxy: true');
    }
    
    return buffer.toString();
  }

  /// Returns a user-friendly error message suitable for display in the UI
  String get userMessage {
    switch (code) {
      case 'invalid_url':
        return 'Invalid URL format. Please check the URL and try again.';
      case 'cors_blocked':
        return 'Unable to access feed due to browser security restrictions.';
      case 'not_rss_feed':
        return 'This URL does not contain a valid RSS feed.';
      case 'network_error':
        return 'Network error. Please check your connection and try again.';
      case 'timeout':
        return 'Request timed out. The server may be slow to respond.';
      case 'server_error':
        return 'Server error. The feed may be temporarily unavailable.';
      default:
        return message;
    }
  }
}