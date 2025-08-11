import 'package:flutter/foundation.dart';

/// Result of URL validation with detailed feedback
class ValidationResult {
  final bool isValid;
  final String? error;
  final String? suggestion;
  final List<String> corrections;

  const ValidationResult({
    required this.isValid,
    this.error,
    this.suggestion,
    this.corrections = const [],
  });

  factory ValidationResult.valid() {
    return const ValidationResult(isValid: true);
  }

  factory ValidationResult.invalid({
    required String error,
    String? suggestion,
    List<String> corrections = const [],
  }) {
    return ValidationResult(
      isValid: false,
      error: error,
      suggestion: suggestion,
      corrections: corrections,
    );
  }
}

/// Comprehensive URL validation utility for RSS feeds
class UrlValidator {
  // Common RSS feed URL patterns
  static final RegExp _basicUrlPattern = RegExp(
    r'^https?:\/\/.+\..+',
    caseSensitive: false,
  );

  static final RegExp _strictUrlPattern = RegExp(
    r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    caseSensitive: false,
  );

  // Common RSS/Atom feed patterns
  static final List<RegExp> _feedPatterns = [
    RegExp(r'\.xml$', caseSensitive: false),
    RegExp(r'\.rss$', caseSensitive: false),
    RegExp(r'\.atom$', caseSensitive: false),
    RegExp(r'/feed/?$', caseSensitive: false),
    RegExp(r'/rss/?$', caseSensitive: false),
    RegExp(r'/atom/?$', caseSensitive: false),
    RegExp(r'/feeds?/', caseSensitive: false),
    RegExp(r'rss\.xml$', caseSensitive: false),
    RegExp(r'atom\.xml$', caseSensitive: false),
    RegExp(r'feed\.xml$', caseSensitive: false),
  ];

  // Common domain patterns for RSS feeds
  static final List<String> _commonFeedDomains = [
    'feedburner.google.com',
    'feeds.feedburner.com',
    'rss.cnn.com',
    'feeds.bbci.co.uk',
    'rss.reuters.com',
    'feeds.npr.org',
    'www.reddit.com',
    'feeds.washingtonpost.com',
  ];

  /// Validate URL format with comprehensive feedback
  static ValidationResult validateFormat(String url) {
    if (url.isEmpty) {
      return ValidationResult.invalid(
        error: 'URL cannot be empty',
        suggestion: 'Please enter a valid RSS feed URL',
      );
    }

    final trimmedUrl = url.trim();
    
    // Check if URL is missing protocol
    if (!trimmedUrl.startsWith('http://') && !trimmedUrl.startsWith('https://')) {
      return ValidationResult.invalid(
        error: 'URL must start with http:// or https://',
        suggestion: 'Add http:// or https:// at the beginning',
        corrections: [
          'https://$trimmedUrl',
          'http://$trimmedUrl',
        ],
      );
    }

    // Basic format validation
    if (!_basicUrlPattern.hasMatch(trimmedUrl)) {
      return ValidationResult.invalid(
        error: 'Invalid URL format',
        suggestion: 'Please check the URL format',
        corrections: _suggestUrlCorrections(trimmedUrl),
      );
    }

    // Strict format validation
    if (!_strictUrlPattern.hasMatch(trimmedUrl)) {
      return ValidationResult.invalid(
        error: 'URL contains invalid characters or format',
        suggestion: 'Please verify the URL is correct',
        corrections: _suggestUrlCorrections(trimmedUrl),
      );
    }

    return ValidationResult.valid();
  }

  /// Validate if URL looks like an RSS feed based on patterns
  static ValidationResult validateFeedFormat(String url) {
    final formatResult = validateFormat(url);
    if (!formatResult.isValid) {
      return formatResult;
    }

    final lowerUrl = url.toLowerCase();

    // Check if URL matches common RSS/Atom patterns
    final hasFeedPattern = _feedPatterns.any((pattern) => pattern.hasMatch(lowerUrl));
    
    if (hasFeedPattern) {
      return ValidationResult.valid();
    }

    // Check if it's a known feed domain
    final uri = Uri.tryParse(url);
    if (uri != null && _commonFeedDomains.any((domain) => uri.host.contains(domain))) {
      return ValidationResult.valid();
    }

    // If it doesn't match common patterns, suggest possible feed URLs
    return ValidationResult.invalid(
      error: 'URL does not appear to be an RSS feed',
      suggestion: 'Look for feed links on the website or try common RSS paths',
      corrections: _suggestFeedUrls(url),
    );
  }

  /// Lightweight validation for web platform (no network calls)
  static ValidationResult validateForWeb(String url) {
    // On web, we can only do format validation
    final formatResult = validateFormat(url);
    if (!formatResult.isValid) {
      return formatResult;
    }

    // Additional web-specific checks
    final uri = Uri.tryParse(url);
    if (uri != null) {
      // Check for localhost URLs that won't work on web
      if (uri.host == 'localhost' || uri.host.startsWith('127.') || uri.host.startsWith('192.168.')) {
        return ValidationResult.invalid(
          error: 'Local URLs are not accessible from web browsers',
          suggestion: 'Use a publicly accessible URL',
        );
      }

      // Check for non-standard ports that might be blocked
      if (uri.hasPort && uri.port != 80 && uri.port != 443) {
        return ValidationResult.invalid(
          error: 'Non-standard ports may be blocked on web platform',
          suggestion: 'Try using standard HTTP (80) or HTTPS (443) ports',
        );
      }
    }

    return ValidationResult.valid();
  }

  /// Suggest URL corrections for common mistakes
  static List<String> _suggestUrlCorrections(String url) {
    final corrections = <String>[];
    
    try {
      // Fix common typos and mistakes
      String fixed = url.trim();
      
      // Fix protocol typos
      if (fixed.startsWith('htttp://')) {
        corrections.add(fixed.replaceFirst('htttp://', 'http://'));
      }
      if (fixed.startsWith('htttps://')) {
        corrections.add(fixed.replaceFirst('htttps://', 'https://'));
      }
      
      // Fix www typos
      if (fixed.contains('ww.') && !fixed.contains('www.')) {
        corrections.add(fixed.replaceFirst('ww.', 'www.'));
      }
      
      // Fix double slashes
      if (fixed.contains('///')) {
        corrections.add(fixed.replaceAll('///', '//'));
      }
      
      // Remove spaces
      if (fixed.contains(' ')) {
        corrections.add(fixed.replaceAll(' ', ''));
      }
      
      // Suggest HTTPS if HTTP is used
      if (fixed.startsWith('http://')) {
        corrections.add(fixed.replaceFirst('http://', 'https://'));
      }
    } catch (e) {
      debugPrint('UrlValidator: Error generating corrections: $e');
    }
    
    return corrections.take(3).toList(); // Limit to 3 suggestions
  }

  /// Suggest possible RSS feed URLs based on a website URL
  static List<String> _suggestFeedUrls(String url) {
    final suggestions = <String>[];
    
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return suggestions;
      
      final baseUrl = '${uri.scheme}://${uri.host}';
      final pathUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      
      // Common RSS feed paths
      suggestions.addAll([
        '$baseUrl/rss',
        '$baseUrl/feed',
        '$baseUrl/atom.xml',
        '$baseUrl/rss.xml',
        '$baseUrl/feed.xml',
        '$pathUrl/rss',
        '$pathUrl/feed',
        '$pathUrl/feed.xml',
      ]);
      
      // WordPress-specific paths
      suggestions.addAll([
        '$baseUrl/wp-rss.php',
        '$baseUrl/wp-rss2.php',
        '$baseUrl/wp-atom.php',
        '$baseUrl/?feed=rss',
        '$baseUrl/?feed=rss2',
        '$baseUrl/?feed=atom',
      ]);
      
      // Blogger/Blogspot feeds
      if (uri.host.contains('blogspot.') || uri.host.contains('blogger.')) {
        suggestions.add('$baseUrl/feeds/posts/default');
      }
      
      // Medium feeds
      if (uri.host.contains('medium.')) {
        suggestions.add('$baseUrl/feed');
      }
      
      // Reddit feeds
      if (uri.host.contains('reddit.')) {
        suggestions.add('$url.rss');
      }
      
    } catch (e) {
      debugPrint('UrlValidator: Error generating feed suggestions: $e');
    }
    
    return suggestions.take(5).toList(); // Limit to 5 suggestions
  }

  /// Check if a URL appears to be a valid RSS/Atom feed based on patterns only
  static bool looksLikeFeed(String url) {
    final lowerUrl = url.toLowerCase();
    
    // Check for feed patterns in URL
    final hasFeedPattern = _feedPatterns.any((pattern) => pattern.hasMatch(lowerUrl));
    if (hasFeedPattern) return true;
    
    // Check for known feed domains
    final uri = Uri.tryParse(url);
    if (uri != null && _commonFeedDomains.any((domain) => uri.host.contains(domain))) {
      return true;
    }
    
    // Check for feed keywords in path
    final feedKeywords = ['rss', 'feed', 'atom', 'xml'];
    return feedKeywords.any((keyword) => lowerUrl.contains(keyword));
  }

  /// Extract domain from URL for display purposes
  static String? extractDomain(String url) {
    try {
      final uri = Uri.tryParse(url);
      return uri?.host;
    } catch (e) {
      return null;
    }
  }

  /// Check if URL uses HTTPS (recommended for security)
  static bool isSecure(String url) {
    return url.toLowerCase().startsWith('https://');
  }

  /// Get a user-friendly description of what makes a good RSS URL
  static String getValidationTips() {
    return '''
Tips for valid RSS feed URLs:
• Start with http:// or https://
• Point to .xml, .rss, or .atom files
• Look for /feed, /rss, or /atom paths
• Check the website for feed links
• Try adding /feed to blog URLs
• Use HTTPS when available for security
''';
  }

  /// Validate multiple URLs at once
  static Map<String, ValidationResult> validateMultiple(List<String> urls) {
    final results = <String, ValidationResult>{};
    
    for (final url in urls) {
      if (kIsWeb) {
        results[url] = validateForWeb(url);
      } else {
        results[url] = validateFeedFormat(url);
      }
    }
    
    return results;
  }
}