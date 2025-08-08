import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, String> fieldErrors;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.fieldErrors = const {},
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;

  String getErrorSummary() {
    if (!hasErrors) return 'No errors';
    return 'Errors: ${errors.join(', ')}';
  }
}

class FirebaseConfigValidator {
  static const List<String> _placeholderPatterns = [
    'YOUR_',
    'REPLACE_WITH_',
    'ADD_YOUR_',
    '<',
    '>',
    'CHANGE_THIS',
    'EXAMPLE_',
  ];

  static const Map<TargetPlatform, List<String>> _requiredFields = {
    TargetPlatform.android: ['apiKey', 'appId', 'messagingSenderId', 'projectId'],
    TargetPlatform.iOS: ['apiKey', 'appId', 'messagingSenderId', 'projectId', 'iosBundleId'],
    TargetPlatform.macOS: ['apiKey', 'appId', 'messagingSenderId', 'projectId', 'iosBundleId'],
    TargetPlatform.windows: ['apiKey', 'appId', 'messagingSenderId', 'projectId', 'authDomain'],
  };

  static const Map<TargetPlatform, List<String>> _webRequiredFields = {
    TargetPlatform.android: ['apiKey', 'appId', 'messagingSenderId', 'projectId', 'authDomain'],
    TargetPlatform.iOS: ['apiKey', 'appId', 'messagingSenderId', 'projectId', 'authDomain'],
    TargetPlatform.macOS: ['apiKey', 'appId', 'messagingSenderId', 'projectId', 'authDomain'],
    TargetPlatform.windows: ['apiKey', 'appId', 'messagingSenderId', 'projectId', 'authDomain'],
    TargetPlatform.linux: ['apiKey', 'appId', 'messagingSenderId', 'projectId', 'authDomain'],
  };

  static bool isValidConfigValue(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    
    for (final pattern in _placeholderPatterns) {
      if (value.contains(pattern)) return false;
    }
    
    return true;
  }

  static bool isValidProjectId(String projectId) {
    if (!isValidConfigValue(projectId)) return false;
    
    final regex = RegExp(r'^[a-z0-9-]+$');
    return regex.hasMatch(projectId) && 
           projectId.length >= 6 && 
           projectId.length <= 30 &&
           !projectId.startsWith('-') &&
           !projectId.endsWith('-');
  }

  static bool isValidAppId(String appId) {
    if (!isValidConfigValue(appId)) return false;
    
    final regex = RegExp(r'^\d+:\d+:(web|android|ios):[a-f0-9]+$');
    return regex.hasMatch(appId);
  }

  static bool isValidApiKey(String apiKey) {
    if (!isValidConfigValue(apiKey)) return false;
    
    return apiKey.length >= 20 && 
           apiKey.startsWith('AIza') &&
           RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(apiKey);
  }

  static String? extractProjectNumberFromAppId(String appId) {
    if (!isValidAppId(appId)) return null;
    
    final parts = appId.split(':');
    if (parts.length >= 2) {
      return parts[1];
    }
    return null;
  }

  static bool isPlatformSupported(TargetPlatform platform) {
    if (kIsWeb) {
      return _webRequiredFields.containsKey(platform);
    }
    return _requiredFields.containsKey(platform) || platform == TargetPlatform.linux;
  }

  static List<String> getSupportedPlatforms() {
    if (kIsWeb) {
      return _webRequiredFields.keys.map((p) => p.name).toList();
    }
    return _requiredFields.keys.map((p) => p.name).toList();
  }

  static String getPlatformConfigRequirements(TargetPlatform platform) {
    if (kIsWeb) {
      final fields = _webRequiredFields[platform] ?? [];
      return 'Web platform requires: ${fields.join(', ')}';
    }
    
    final fields = _requiredFields[platform] ?? [];
    if (fields.isEmpty) {
      return 'Platform $platform is not supported by Firebase';
    }
    return 'Platform ${platform.name} requires: ${fields.join(', ')}';
  }

  static ValidationResult validateFirebaseOptions(
    FirebaseOptions options,
    TargetPlatform platform,
  ) {
    final errors = <String>[];
    final warnings = <String>[];
    final fieldErrors = <String, String>{};

    List<String> requiredFields;
    if (kIsWeb) {
      requiredFields = _webRequiredFields[platform] ?? [];
    } else {
      requiredFields = _requiredFields[platform] ?? [];
    }

    if (requiredFields.isEmpty && platform != TargetPlatform.linux) {
      errors.add('Platform ${platform.name} is not supported');
      return ValidationResult(
        isValid: false,
        errors: errors,
        fieldErrors: fieldErrors,
      );
    }

    if (requiredFields.contains('projectId')) {
      if (!isValidConfigValue(options.projectId)) {
        errors.add('Invalid or missing projectId');
        fieldErrors['projectId'] = 'Project ID is empty, null, or contains placeholder text';
      } else if (!isValidProjectId(options.projectId)) {
        errors.add('Invalid projectId format');
        fieldErrors['projectId'] = 'Project ID must be lowercase letters, numbers, and hyphens only (6-30 chars)';
      }
    }

    if (requiredFields.contains('apiKey')) {
      if (!isValidConfigValue(options.apiKey)) {
        errors.add('Invalid or missing apiKey');
        fieldErrors['apiKey'] = 'API key is empty, null, or contains placeholder text';
      } else if (!isValidApiKey(options.apiKey)) {
        errors.add('Invalid apiKey format');
        fieldErrors['apiKey'] = 'API key must start with "AIza" and be at least 20 characters';
      }
    }

    if (requiredFields.contains('appId')) {
      if (!isValidConfigValue(options.appId)) {
        errors.add('Invalid or missing appId');
        fieldErrors['appId'] = 'App ID is empty, null, or contains placeholder text';
      } else if (!isValidAppId(options.appId)) {
        errors.add('Invalid appId format');
        fieldErrors['appId'] = 'App ID must follow format: "projectNumber:identifier:platform:hash"';
      }
    }

    if (requiredFields.contains('messagingSenderId')) {
      if (!isValidConfigValue(options.messagingSenderId)) {
        errors.add('Invalid or missing messagingSenderId');
        fieldErrors['messagingSenderId'] = 'Messaging sender ID is empty, null, or contains placeholder text';
      }
    }

    if (requiredFields.contains('iosBundleId')) {
      if (!isValidConfigValue(options.iosBundleId)) {
        errors.add('Invalid or missing iosBundleId');
        fieldErrors['iosBundleId'] = 'iOS bundle ID is required for iOS/macOS platforms';
      }
    }

    if (requiredFields.contains('authDomain')) {
      if (!isValidConfigValue(options.authDomain)) {
        errors.add('Invalid or missing authDomain');
        fieldErrors['authDomain'] = 'Auth domain is required for web platforms';
      }
    }

    if (isValidConfigValue(options.appId) && 
        isValidConfigValue(options.messagingSenderId)) {
      final projectNumber = extractProjectNumberFromAppId(options.appId);
      if (projectNumber != null && projectNumber != options.messagingSenderId) {
        warnings.add('Project number in appId does not match messagingSenderId');
        fieldErrors['consistency'] = 'App ID project number ($projectNumber) should match messaging sender ID (${options.messagingSenderId})';
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      fieldErrors: fieldErrors,
    );
  }
}