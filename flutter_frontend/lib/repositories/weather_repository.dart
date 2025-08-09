import '../models/weather.dart';
import '../services/weather_service.dart';

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

class MockWeatherRepository implements WeatherRepository {
  WeatherApiConfig _config = WeatherApiConfig(
    apiKey: '',
    units: 'metric',
    language: 'en',
    isEnabled: false,
    updatedAt: DateTime.now(),
  );
  
  final List<WeatherLocation> _locations = [
    WeatherLocation(
      id: 'london',
      name: 'London',
      country: 'GB',
      latitude: 51.5074,
      longitude: -0.1278,
      isDefault: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    WeatherLocation(
      id: 'newyork',
      name: 'New York',
      country: 'US',
      state: 'NY',
      latitude: 40.7128,
      longitude: -74.0060,
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    WeatherLocation(
      id: 'tokyo',
      name: 'Tokyo',
      country: 'JP',
      latitude: 35.6762,
      longitude: 139.6503,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  @override
  Future<WeatherApiConfig> getConfig() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _config;
  }

  @override
  Future<void> updateConfig(WeatherApiConfig config) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _config = config.copyWith(updatedAt: DateTime.now());
  }

  @override
  Future<List<WeatherLocation>> getLocations() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return List.from(_locations);
  }

  @override
  Future<void> addLocation(WeatherLocation location) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    // If this is the first location or marked as default, make it default
    final shouldMakeDefault = _locations.isEmpty || location.isDefault;
    
    if (shouldMakeDefault) {
      // Remove default from other locations
      for (int i = 0; i < _locations.length; i++) {
        if (_locations[i].isDefault) {
          _locations[i] = _locations[i].copyWith(isDefault: false);
        }
      }
    }
    
    // Generate ID if not provided
    final locationWithId = location.id.isEmpty
        ? location.copyWith(
            id: '${location.latitude}_${location.longitude}_${DateTime.now().millisecondsSinceEpoch}',
            isDefault: shouldMakeDefault,
          )
        : location.copyWith(isDefault: shouldMakeDefault);
    
    _locations.add(locationWithId);
  }

  @override
  Future<void> removeLocation(String locationId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    final wasDefault = _locations.any((l) => l.id == locationId && l.isDefault);
    _locations.removeWhere((location) => location.id == locationId);
    
    // If we removed the default location, make the first remaining location default
    if (wasDefault && _locations.isNotEmpty) {
      _locations[0] = _locations[0].copyWith(isDefault: true);
    }
  }

  @override
  Future<void> setDefaultLocation(String locationId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    for (int i = 0; i < _locations.length; i++) {
      _locations[i] = _locations[i].copyWith(isDefault: _locations[i].id == locationId);
    }
  }

  @override
  Future<WeatherLocation?> getDefaultLocation() async {
    await Future.delayed(const Duration(milliseconds: 50));
    
    try {
      return _locations.firstWhere((location) => location.isDefault);
    } catch (e) {
      return _locations.isNotEmpty ? _locations.first : null;
    }
  }

  @override
  Future<WeatherData> getCurrentWeatherForLocation(WeatherLocation location) async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    final weatherData = await WeatherService.getCurrentWeather(location, _config);
    
    // Convert WeatherData to legacy WeatherData format
    return WeatherData(
      id: weatherData.id,
      location: weatherData.location,
      temperature: weatherData.temperature,
      humidity: weatherData.humidity.toDouble(),
      conditions: weatherData.description,
      iconCode: weatherData.icon,
      updatedAt: weatherData.timestamp,
      windSpeed: weatherData.windSpeed,
      pressure: weatherData.pressure,
      visibility: weatherData.visibility.toDouble(),
    );
  }

  @override
  Future<WeatherData?> getCurrentWeatherForDefault() async {
    final defaultLocation = await getDefaultLocation();
    if (defaultLocation == null) return null;
    
    return getCurrentWeatherForLocation(defaultLocation);
  }

  @override
  Future<List<WeatherLocation>> searchLocations(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return WeatherService.searchLocations(query, _config.apiKey);
  }

  @override
  Future<bool> validateApiKey(String apiKey) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return WeatherService.validateApiKey(apiKey);
  }

  // Legacy methods for compatibility
  @override
  Future<WeatherData> getCurrentWeather(String location) async {
    // Try to find existing location first
    final existingLocation = _locations
        .where((loc) => loc.name.toLowerCase() == location.toLowerCase())
        .firstOrNull;
    
    if (existingLocation != null) {
      return getCurrentWeatherForLocation(existingLocation);
    }
    
    // Search for location and use first result
    final searchResults = await searchLocations(location);
    if (searchResults.isNotEmpty) {
      return getCurrentWeatherForLocation(searchResults.first);
    }
    
    // Fallback: create a mock location
    final mockLocation = WeatherLocation(
      id: location.toLowerCase().replaceAll(' ', '_'),
      name: location,
      country: 'Unknown',
      latitude: 0.0,
      longitude: 0.0,
      createdAt: DateTime.now(),
    );
    
    return getCurrentWeatherForLocation(mockLocation);
  }

  @override
  Future<List<WeatherData>> getForecast(String location) async {
    // For now, return empty list as forecast is not implemented
    await Future.delayed(const Duration(milliseconds: 300));
    return [];
  }

  @override
  Future<void> updateLocation(String location) async {
    // Search for location and add as default if found
    final searchResults = await searchLocations(location);
    if (searchResults.isNotEmpty) {
      await addLocation(searchResults.first.copyWith(isDefault: true));
    }
  }

  @override
  Future<void> clearCache() async {
    WeatherService.clearAllCache();
  }
}