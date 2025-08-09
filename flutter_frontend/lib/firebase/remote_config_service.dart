import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import '../models/weather.dart';

class RemoteConfigService {
  static RemoteConfigService? _instance;
  static RemoteConfigService get instance => _instance ??= RemoteConfigService._();
  
  RemoteConfigService._();
  
  FirebaseRemoteConfig? _remoteConfig;
  bool _isInitialized = false;
  
  // Configuration keys
  static const String _weatherApiKeyConfig = 'weather_api_key';
  static const String _weatherApiEnabledConfig = 'weather_api_enabled';
  static const String _defaultWeatherUnitsConfig = 'default_weather_units';
  static const String _defaultWeatherLanguageConfig = 'default_weather_language';
  
  /// Initialize Firebase Remote Config
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;
      
      // Set default values
      await _remoteConfig!.setDefaults({
        _weatherApiKeyConfig: '', // Set your OpenWeatherMap API key here
        _weatherApiEnabledConfig: true,
        _defaultWeatherUnitsConfig: 'metric',
        _defaultWeatherLanguageConfig: 'en',
      });
      
      // Configure fetch settings
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode 
            ? const Duration(minutes: 1)  // Shorter interval for development
            : const Duration(hours: 1),   // Longer interval for production
      ));
      
      // Fetch and activate config
      await _fetchAndActivate();
      
      _isInitialized = true;
      debugPrint('RemoteConfigService: Initialized successfully');
    } catch (e) {
      debugPrint('RemoteConfigService: Failed to initialize: $e');
      // Continue without Remote Config - app should still work with local defaults
      _isInitialized = false;
    }
  }
  
  /// Fetch and activate remote configuration
  Future<void> _fetchAndActivate() async {
    try {
      final updated = await _remoteConfig!.fetchAndActivate();
      if (updated) {
        debugPrint('RemoteConfigService: Configuration updated');
      } else {
        debugPrint('RemoteConfigService: Using cached configuration');
      }
    } catch (e) {
      debugPrint('RemoteConfigService: Failed to fetch config: $e');
    }
  }
  
  /// Get weather API configuration from Firebase Remote Config
  WeatherApiConfig getWeatherConfig() {
    if (!_isInitialized || _remoteConfig == null) {
      // Return default configuration if Remote Config is not available
      return WeatherApiConfig(
        apiKey: '',
        units: 'metric',
        language: 'en',
        isEnabled: false, // Disabled by default without API key
        updatedAt: DateTime.now(),
      );
    }
    
    try {
      final apiKey = _remoteConfig!.getString(_weatherApiKeyConfig);
      final isEnabled = _remoteConfig!.getBool(_weatherApiEnabledConfig) && apiKey.isNotEmpty;
      final units = _remoteConfig!.getString(_defaultWeatherUnitsConfig);
      final language = _remoteConfig!.getString(_defaultWeatherLanguageConfig);
      
      return WeatherApiConfig(
        apiKey: apiKey,
        units: units.isNotEmpty ? units : 'metric',
        language: language.isNotEmpty ? language : 'en',
        isEnabled: isEnabled,
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('RemoteConfigService: Error reading weather config: $e');
      return WeatherApiConfig(
        apiKey: '',
        units: 'metric',
        language: 'en',
        isEnabled: false,
        updatedAt: DateTime.now(),
      );
    }
  }
  
  /// Get weather API key from Remote Config
  String getWeatherApiKey() {
    if (!_isInitialized || _remoteConfig == null) {
      return '';
    }
    
    try {
      return _remoteConfig!.getString(_weatherApiKeyConfig);
    } catch (e) {
      debugPrint('RemoteConfigService: Error reading weather API key: $e');
      return '';
    }
  }
  
  /// Check if weather API is enabled via Remote Config
  bool isWeatherApiEnabled() {
    if (!_isInitialized || _remoteConfig == null) {
      return false;
    }
    
    try {
      final apiKey = _remoteConfig!.getString(_weatherApiKeyConfig);
      final isEnabled = _remoteConfig!.getBool(_weatherApiEnabledConfig);
      return isEnabled && apiKey.isNotEmpty;
    } catch (e) {
      debugPrint('RemoteConfigService: Error checking weather API status: $e');
      return false;
    }
  }
  
  /// Get default weather units from Remote Config
  String getDefaultWeatherUnits() {
    if (!_isInitialized || _remoteConfig == null) {
      return 'metric';
    }
    
    try {
      final units = _remoteConfig!.getString(_defaultWeatherUnitsConfig);
      return units.isNotEmpty ? units : 'metric';
    } catch (e) {
      debugPrint('RemoteConfigService: Error reading default weather units: $e');
      return 'metric';
    }
  }
  
  /// Get default weather language from Remote Config
  String getDefaultWeatherLanguage() {
    if (!_isInitialized || _remoteConfig == null) {
      return 'en';
    }
    
    try {
      final language = _remoteConfig!.getString(_defaultWeatherLanguageConfig);
      return language.isNotEmpty ? language : 'en';
    } catch (e) {
      debugPrint('RemoteConfigService: Error reading default weather language: $e');
      return 'en';
    }
  }
  
  /// Manually refresh configuration (useful for admin panel or testing)
  Future<bool> refreshConfig() async {
    if (!_isInitialized || _remoteConfig == null) {
      return false;
    }
    
    try {
      await _fetchAndActivate();
      debugPrint('RemoteConfigService: Configuration refreshed manually');
      return true;
    } catch (e) {
      debugPrint('RemoteConfigService: Failed to refresh config: $e');
      return false;
    }
  }
  
  /// Get all current Remote Config values (for debugging)
  Map<String, dynamic> getAllConfigValues() {
    if (!_isInitialized || _remoteConfig == null) {
      return {};
    }
    
    try {
      return {
        'weather_api_key_set': _remoteConfig!.getString(_weatherApiKeyConfig).isNotEmpty,
        'weather_api_enabled': _remoteConfig!.getBool(_weatherApiEnabledConfig),
        'default_weather_units': _remoteConfig!.getString(_defaultWeatherUnitsConfig),
        'default_weather_language': _remoteConfig!.getString(_defaultWeatherLanguageConfig),
        'last_fetch_time': _remoteConfig!.lastFetchTime.toString(),
        'last_fetch_status': _remoteConfig!.lastFetchStatus.toString(),
      };
    } catch (e) {
      debugPrint('RemoteConfigService: Error getting all config values: $e');
      return {};
    }
  }
  
  /// Check if Remote Config is properly initialized and working
  bool get isInitialized => _isInitialized;
  
  /// Get the fetch status for debugging
  RemoteConfigFetchStatus get lastFetchStatus => 
      _remoteConfig?.lastFetchStatus ?? RemoteConfigFetchStatus.noFetchYet;
}