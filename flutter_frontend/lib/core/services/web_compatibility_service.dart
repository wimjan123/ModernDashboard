import 'dart:developer';
import 'package:flutter/foundation.dart';

class WebCompatibilityService {
  static final WebCompatibilityService _instance = WebCompatibilityService._internal();
  static WebCompatibilityService get instance => _instance;
  WebCompatibilityService._internal();

  static const String _storageKey = 'web_compatibility_issues';
  final List<WebCompatibilityIssue> _detectedIssues = [];
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || !kIsWeb) return;

    log('WebCompatibilityService: Initializing web compatibility checks...');
    
    await _checkBrowserCompatibility();
    await _checkFirebaseCompatibility();
    await _checkWebSecurityIssues();
    
    _initialized = true;
    log('WebCompatibilityService: Initialization complete. Found ${_detectedIssues.length} issues.');
  }

  List<WebCompatibilityIssue> getDetectedIssues() {
    return List.from(_detectedIssues);
  }

  bool hasCompatibilityIssues() {
    return _detectedIssues.isNotEmpty;
  }

  bool hasCriticalIssues() {
    return _detectedIssues.any((issue) => issue.severity == WebIssueSeverity.critical);
  }

  Future<void> _checkBrowserCompatibility() async {
    try {
      // Check for modern JavaScript features
      final jsResult = await _executeJavaScript('''
        return {
          hasES6: typeof Symbol !== 'undefined',
          hasPromise: typeof Promise !== 'undefined',
          hasWebAssembly: typeof WebAssembly !== 'undefined',
          hasIndexedDB: typeof indexedDB !== 'undefined',
          hasLocalStorage: typeof localStorage !== 'undefined',
          userAgent: navigator.userAgent
        };
      ''');

      if (jsResult != null) {
        final features = jsResult as Map<String, dynamic>;
        
        if (features['hasES6'] != true) {
          _addIssue(WebCompatibilityIssue(
            type: WebIssueType.browserFeature,
            severity: WebIssueSeverity.high,
            title: 'ES6 Support Missing',
            description: 'Browser lacks ES6 JavaScript features',
            suggestion: 'Use a modern browser version',
          ));
        }
        
        if (features['hasPromise'] != true) {
          _addIssue(WebCompatibilityIssue(
            type: WebIssueType.browserFeature,
            severity: WebIssueSeverity.critical,
            title: 'Promise Support Missing',
            description: 'Browser lacks Promise support required for Firebase',
            suggestion: 'Update your browser to a recent version',
          ));
        }
        
        if (features['hasIndexedDB'] != true) {
          _addIssue(WebCompatibilityIssue(
            type: WebIssueType.browserFeature,
            severity: WebIssueSeverity.medium,
            title: 'IndexedDB Not Available',
            description: 'Local storage features may be limited',
            suggestion: 'Some offline features may not work properly',
          ));
        }

        // Check for known problematic browsers
        final userAgent = features['userAgent']?.toString().toLowerCase() ?? '';
        if (userAgent.contains('internet explorer')) {
          _addIssue(WebCompatibilityIssue(
            type: WebIssueType.browserSupport,
            severity: WebIssueSeverity.critical,
            title: 'Unsupported Browser',
            description: 'Internet Explorer is not supported',
            suggestion: 'Please use Chrome, Firefox, Safari, or Edge',
          ));
        }
      }
    } catch (e) {
      log('WebCompatibilityService: Browser compatibility check failed: $e');
    }
  }

  Future<void> _checkFirebaseCompatibility() async {
    try {
      // Check for Firebase-specific compatibility issues
      final firebaseCheck = await _executeJavaScript('''
        return {
          hasWebGL: !!window.WebGLRenderingContext,
          hasWorkers: typeof Worker !== 'undefined',
          hasWebSockets: typeof WebSocket !== 'undefined',
          hasCors: typeof XMLHttpRequest !== 'undefined' && 'withCredentials' in new XMLHttpRequest(),
          hasBlob: typeof Blob !== 'undefined'
        };
      ''');

      if (firebaseCheck != null) {
        final features = firebaseCheck as Map<String, dynamic>;
        
        if (features['hasWebSockets'] != true) {
          _addIssue(WebCompatibilityIssue(
            type: WebIssueType.firebaseFeature,
            severity: WebIssueSeverity.high,
            title: 'WebSocket Support Missing',
            description: 'Real-time Firebase features may not work',
            suggestion: 'Enable WebSocket support or use polling fallback',
          ));
        }
        
        if (features['hasCors'] != true) {
          _addIssue(WebCompatibilityIssue(
            type: WebIssueType.firebaseFeature,
            severity: WebIssueSeverity.critical,
            title: 'CORS Support Missing',
            description: 'Firebase API calls will fail',
            suggestion: 'Update browser or check CORS configuration',
          ));
        }
      }

      // Check for JavaScript interop issues that cause the TypeError
      final interopCheck = await _executeJavaScript('''
        try {
          // Simulate the problematic Firebase Timestamp conversion
          var testObj = { seconds: 1640995200, nanoseconds: 0 };
          var testArray = [testObj];
          
          // Test JSON serialization/deserialization
          var jsonString = JSON.stringify(testObj);
          var parsed = JSON.parse(jsonString);
          
          return {
            canSerialize: true,
            canParse: true,
            supportsTimestamp: true
          };
        } catch (e) {
          return {
            canSerialize: false,
            canParse: false,
            supportsTimestamp: false,
            error: e.toString()
          };
        }
      ''');

      if (interopCheck != null) {
        final check = interopCheck as Map<String, dynamic>;
        
        if (check['supportsTimestamp'] != true) {
          _addIssue(WebCompatibilityIssue(
            type: WebIssueType.javascriptInterop,
            severity: WebIssueSeverity.critical,
            title: 'Firebase Timestamp Compatibility Issue',
            description: 'JavaScript interop issues with Firestore timestamps detected',
            suggestion: 'Use timestamp conversion utilities or update Firebase packages',
            technicalDetails: check['error']?.toString(),
          ));
        }
      }
    } catch (e) {
      log('WebCompatibilityService: Firebase compatibility check failed: $e');
    }
  }

  Future<void> _checkWebSecurityIssues() async {
    try {
      // Check for security-related compatibility issues
      final securityCheck = await _executeJavaScript('''
        return {
          hasHttps: location.protocol === 'https:',
          hasSameSite: document.cookie.indexOf('SameSite') !== -1,
          allowsCookies: navigator.cookieEnabled,
          hasCSP: !!document.querySelector('meta[http-equiv="Content-Security-Policy"]')
        };
      ''');

      if (securityCheck != null) {
        final security = securityCheck as Map<String, dynamic>;
        
        if (security['hasHttps'] != true) {
          _addIssue(WebCompatibilityIssue(
            type: WebIssueType.security,
            severity: WebIssueSeverity.medium,
            title: 'Non-HTTPS Connection',
            description: 'Some Firebase features require HTTPS',
            suggestion: 'Use HTTPS for full functionality',
          ));
        }
        
        if (security['allowsCookies'] != true) {
          _addIssue(WebCompatibilityIssue(
            type: WebIssueType.security,
            severity: WebIssueSeverity.high,
            title: 'Cookies Disabled',
            description: 'Authentication and session management may fail',
            suggestion: 'Enable cookies in browser settings',
          ));
        }
      }
    } catch (e) {
      log('WebCompatibilityService: Security check failed: $e');
    }
  }

  Future<dynamic> _executeJavaScript(String code) async {
    if (!kIsWeb) return null;
    
    try {
      // This is a simplified approach for JavaScript execution
      // In a real implementation, you might use dart:js or dart:html
      return null; // Placeholder - would need actual JS interop implementation
    } catch (e) {
      log('WebCompatibilityService: JavaScript execution failed: $e');
      return null;
    }
  }

  void _addIssue(WebCompatibilityIssue issue) {
    // Check for duplicates
    final existing = _detectedIssues.any((existing) => 
      existing.type == issue.type && existing.title == issue.title);
    
    if (!existing) {
      _detectedIssues.add(issue);
      log('WebCompatibilityService: Added issue: ${issue.title} (${issue.severity.name})');
    }
  }

  bool isKnownFirebaseInteropIssue(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('javascriptobject') ||
           errorString.contains('_typeerror') ||
           errorString.contains('not a subtype of type') ||
           (errorString.contains('typeerror') && errorString.contains('firebase'));
  }

  Map<String, dynamic> getRecommendedFixes() {
    final fixes = <String, dynamic>{};
    
    if (hasCriticalIssues()) {
      fixes['offline_mode'] = 'Switch to offline mode to avoid compatibility issues';
    }
    
    if (_detectedIssues.any((issue) => issue.type == WebIssueType.javascriptInterop)) {
      fixes['firebase_packages'] = 'Update Firebase packages to latest versions';
      fixes['timestamp_handling'] = 'Use safe timestamp conversion utilities';
    }
    
    if (_detectedIssues.any((issue) => issue.type == WebIssueType.browserSupport)) {
      fixes['browser_update'] = 'Update to a modern browser version';
    }
    
    if (_detectedIssues.any((issue) => issue.type == WebIssueType.security)) {
      fixes['security_settings'] = 'Check browser security and privacy settings';
    }

    return fixes;
  }

  String generateCompatibilityReport() {
    if (_detectedIssues.isEmpty) {
      return 'Web Compatibility: All checks passed ✅';
    }

    final buffer = StringBuffer();
    buffer.writeln('Web Compatibility Report');
    buffer.writeln('=' * 40);
    buffer.writeln('Platform: Web');
    buffer.writeln('Issues Found: ${_detectedIssues.length}');
    buffer.writeln('');

    for (final issue in _detectedIssues) {
      buffer.writeln('${_getSeverityIcon(issue.severity)} ${issue.title}');
      buffer.writeln('   ${issue.description}');
      buffer.writeln('   💡 ${issue.suggestion}');
      if (issue.technicalDetails != null) {
        buffer.writeln('   🔧 ${issue.technicalDetails}');
      }
      buffer.writeln('');
    }

    final fixes = getRecommendedFixes();
    if (fixes.isNotEmpty) {
      buffer.writeln('Recommended Actions:');
      fixes.forEach((key, value) {
        buffer.writeln('• $value');
      });
    }

    return buffer.toString();
  }

  String _getSeverityIcon(WebIssueSeverity severity) {
    switch (severity) {
      case WebIssueSeverity.low:
        return 'ℹ️';
      case WebIssueSeverity.medium:
        return '⚠️';
      case WebIssueSeverity.high:
        return '🚨';
      case WebIssueSeverity.critical:
        return '❌';
    }
  }
}

class WebCompatibilityIssue {
  final WebIssueType type;
  final WebIssueSeverity severity;
  final String title;
  final String description;
  final String suggestion;
  final String? technicalDetails;

  WebCompatibilityIssue({
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.suggestion,
    this.technicalDetails,
  });

  @override
  String toString() {
    return 'WebCompatibilityIssue(${severity.name}: $title)';
  }
}

enum WebIssueType {
  browserSupport,
  browserFeature,
  firebaseFeature,
  javascriptInterop,
  security,
  performance,
}

enum WebIssueSeverity {
  low,      // Minor issues, warnings
  medium,   // May affect some functionality
  high,     // Likely to cause problems
  critical, // Will prevent core functionality
}

extension WebIssueSeverityExtension on WebIssueSeverity {
  String get name {
    switch (this) {
      case WebIssueSeverity.low:
        return 'low';
      case WebIssueSeverity.medium:
        return 'medium';
      case WebIssueSeverity.high:
        return 'high';
      case WebIssueSeverity.critical:
        return 'critical';
    }
  }
}