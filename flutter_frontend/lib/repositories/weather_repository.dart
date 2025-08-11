import '../models/weather.dart';

abstract class WeatherRepository {
  /// Get current weather for a location
  Future<WeatherData> getCurrentWeather(String location);
  
  /// Get weather forecast for a location
  Future<List<WeatherData>> getForecast(String location);
  
  /// Update user's default location
  Future<void> updateLocation(String location);
  
  /// Clear cached weather data
  Future<void> clearCache();
  
  /// Get weather configuration
  Future<WeatherApiConfig> getConfig();
  
  /// Update weather configuration
  Future<void> updateConfig(WeatherApiConfig config);
  
  /// Get all saved locations
  Future<List<WeatherLocation>> getLocations();
  
  /// Add a new location
  Future<void> addLocation(WeatherLocation location);
  
  /// Remove a location
  Future<void> removeLocation(String locationId);
  
  /// Set default location
  Future<void> setDefaultLocation(String locationId);
  
  /// Get default location
  Future<WeatherLocation?> getDefaultLocation();
  
  /// Get current weather for a weather location
  Future<WeatherData> getCurrentWeatherForLocation(WeatherLocation location);
  
  /// Get current weather for default location
  Future<WeatherData?> getCurrentWeatherForDefault();
  
  /// Search for locations
  Future<List<WeatherLocation>> searchLocations(String query);
  
  /// Validate API key
  Future<bool> validateApiKey(String apiKey);
}