import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/weather.dart';

class WeatherService {
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  static const String _geocodingUrl = 'https://api.openweathermap.org/geo/1.0';
  static const int _timeoutSeconds = 10;
  
  // Cache management
  static final Map<String, WeatherData> _weatherCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 10);

  /// Get current weather for a location
  static Future<WeatherData> getCurrentWeather(
    WeatherLocation location,
    WeatherApiConfig config,
  ) async {
    if (!config.isConfigured || !config.isEnabled) {
      // Return mock data if API is not configured
      return _getMockWeatherData(location, config.units);
    }

    // Check cache first
    final cacheKey = '${location.latitude}_${location.longitude}_${config.units}';
    if (_isCacheValid(cacheKey)) {
      return _weatherCache[cacheKey]!;
    }

    // For web platform, use mock data to avoid CORS issues
    if (kIsWeb) {
      return _getMockWeatherData(location, config.units);
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/weather?lat=${location.latitude}&lon=${location.longitude}&appid=${config.apiKey}&units=${config.units}&lang=${config.language}',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: _timeoutSeconds),
      );

      if (response.statusCode != 200) {
        throw WeatherException(
          'HTTP ${response.statusCode}: Failed to fetch weather data',
          'API_ERROR',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final weatherData = WeatherData.fromOpenWeatherMapJson(data, config.units);

      // Cache the result
      _weatherCache[cacheKey] = weatherData;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return weatherData;
    } catch (e) {
      if (e is WeatherException) {
        rethrow;
      }
      throw WeatherException(
        'Failed to fetch weather data: $e',
        'NETWORK_ERROR',
      );
    }
  }

  /// Search for locations by name
  static Future<List<WeatherLocation>> searchLocations(
    String query,
    String apiKey, {
    int limit = 5,
  }) async {
    if (apiKey.isEmpty) {
      // Return mock locations if no API key
      return _getMockLocations(query);
    }

    // For web platform, return mock data to avoid CORS issues
    if (kIsWeb) {
      return _getMockLocations(query);
    }

    try {
      final url = Uri.parse(
        '$_geocodingUrl/direct?q=${Uri.encodeComponent(query)}&limit=$limit&appid=$apiKey',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: _timeoutSeconds),
      );

      if (response.statusCode != 200) {
        throw WeatherException(
          'HTTP ${response.statusCode}: Failed to search locations',
          'API_ERROR',
        );
      }

      final data = json.decode(response.body) as List;
      return data.map((item) {
        final location = item as Map<String, dynamic>;
        return WeatherLocation(
          id: '${location['lat']}_${location['lon']}',
          name: location['name'] ?? '',
          country: location['country'] ?? '',
          state: location['state'] ?? '',
          latitude: (location['lat'] as num).toDouble(),
          longitude: (location['lon'] as num).toDouble(),
          createdAt: DateTime.now(),
        );
      }).toList();
    } catch (e) {
      if (e is WeatherException) {
        rethrow;
      }
      throw WeatherException(
        'Failed to search locations: $e',
        'NETWORK_ERROR',
      );
    }
  }

  /// Get weather by coordinates
  static Future<WeatherData> getWeatherByCoordinates(
    double latitude,
    double longitude,
    WeatherApiConfig config,
  ) async {
    final location = WeatherLocation(
      id: '${latitude}_$longitude',
      name: 'Current Location',
      country: '',
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.now(),
    );

    return getCurrentWeather(location, config);
  }

  /// Validate API key
  static Future<bool> validateApiKey(String apiKey) async {
    if (apiKey.isEmpty) return false;

    // For web platform, assume valid to avoid CORS issues
    if (kIsWeb) {
      return true;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/weather?q=London&appid=$apiKey&units=metric',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get mock weather data for demonstration/web platform
  static WeatherData _getMockWeatherData(WeatherLocation location, String units) {
    final random = Random();
    
    // Generate realistic temperature based on location and time
    final baseTemp = _getBaseTemperatureForLocation(location.latitude);
    final tempVariation = random.nextDouble() * 10 - 5; // ±5 degrees variation
    final temperature = baseTemp + tempVariation;

    // Convert temperature based on units
    final convertedTemp = _convertTemperature(temperature, 'celsius', units);
    final feelsLikeTemp = convertedTemp + (random.nextDouble() * 6 - 3); // ±3 degrees

    final weatherConditions = [
      {'description': 'clear sky', 'icon': '01d'},
      {'description': 'few clouds', 'icon': '02d'},
      {'description': 'scattered clouds', 'icon': '03d'},
      {'description': 'broken clouds', 'icon': '04d'},
      {'description': 'light rain', 'icon': '10d'},
      {'description': 'overcast clouds', 'icon': '04d'},
    ];

    final condition = weatherConditions[random.nextInt(weatherConditions.length)];

    return WeatherData(
      id: 'mock_${location.id}',
      location: location.name.isNotEmpty ? location.name : 'Mock Location',
      latitude: location.latitude,
      longitude: location.longitude,
      temperature: convertedTemp,
      feelsLike: feelsLikeTemp,
      humidity: 40 + random.nextInt(40), // 40-80%
      pressure: 1000 + random.nextDouble() * 50, // 1000-1050 hPa
      description: condition['description']!,
      icon: condition['icon']!,
      windSpeed: random.nextDouble() * 10, // 0-10 m/s
      windDirection: random.nextInt(360),
      cloudiness: random.nextInt(100),
      visibility: 8000 + random.nextInt(2000), // 8-10 km
      timestamp: DateTime.now(),
      units: units,
    );
  }

  /// Get base temperature for latitude (rough approximation)
  static double _getBaseTemperatureForLocation(double latitude) {
    // Simple temperature model based on latitude
    final absLat = latitude.abs();
    
    if (absLat < 23.5) {
      // Tropical zone
      return 28.0;
    } else if (absLat < 66.5) {
      // Temperate zone
      return 20.0 - (absLat - 23.5) * 0.3;
    } else {
      // Arctic/Antarctic zone
      return -5.0;
    }
  }

  /// Convert temperature between units
  static double _convertTemperature(double temp, String from, String to) {
    // Convert from source to Celsius first
    double celsius;
    switch (from) {
      case 'fahrenheit':
        celsius = (temp - 32) * 5 / 9;
        break;
      case 'kelvin':
        celsius = temp - 273.15;
        break;
      case 'celsius':
      default:
        celsius = temp;
    }

    // Convert from Celsius to target
    switch (to) {
      case 'imperial':
        return celsius * 9 / 5 + 32; // Fahrenheit
      case 'standard':
        return celsius + 273.15; // Kelvin
      case 'metric':
      default:
        return celsius;
    }
  }

  /// Get mock locations for search
  static List<WeatherLocation> _getMockLocations(String query) {
    final mockCities = [
      {'name': 'London', 'country': 'GB', 'state': '', 'lat': 51.5074, 'lon': -0.1278},
      {'name': 'New York', 'country': 'US', 'state': 'NY', 'lat': 40.7128, 'lon': -74.0060},
      {'name': 'Tokyo', 'country': 'JP', 'state': '', 'lat': 35.6762, 'lon': 139.6503},
      {'name': 'Paris', 'country': 'FR', 'state': '', 'lat': 48.8566, 'lon': 2.3522},
      {'name': 'Sydney', 'country': 'AU', 'state': 'NSW', 'lat': -33.8688, 'lon': 151.2093},
      {'name': 'Berlin', 'country': 'DE', 'state': '', 'lat': 52.5200, 'lon': 13.4050},
      {'name': 'Toronto', 'country': 'CA', 'state': 'ON', 'lat': 43.6532, 'lon': -79.3832},
      {'name': 'Mumbai', 'country': 'IN', 'state': 'MH', 'lat': 19.0760, 'lon': 72.8777},
      {'name': 'Singapore', 'country': 'SG', 'state': '', 'lat': 1.3521, 'lon': 103.8198},
      {'name': 'Dubai', 'country': 'AE', 'state': '', 'lat': 25.2048, 'lon': 55.2708},
    ];

    final filtered = mockCities.where((city) {
      final name = city['name'] as String;
      final country = city['country'] as String;
      return name.toLowerCase().contains(query.toLowerCase()) ||
             country.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return filtered.take(5).map((city) => WeatherLocation(
      id: '${city['lat']}_${city['lon']}',
      name: city['name'] as String,
      country: city['country'] as String,
      state: city['state'] as String,
      latitude: city['lat'] as double,
      longitude: city['lon'] as double,
      createdAt: DateTime.now(),
    )).toList();
  }

  /// Check if cached data is still valid
  static bool _isCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null || !_weatherCache.containsKey(cacheKey)) {
      return false;
    }
    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  /// Clear cache for specific location
  static void clearCache(String cacheKey) {
    _weatherCache.remove(cacheKey);
    _cacheTimestamps.remove(cacheKey);
  }

  /// Clear all cache
  static void clearAllCache() {
    _weatherCache.clear();
    _cacheTimestamps.clear();
  }

  /// Get available units
  static List<Map<String, String>> getAvailableUnits() {
    return [
      {'value': 'metric', 'label': 'Metric (°C, m/s)', 'temp': '°C'},
      {'value': 'imperial', 'label': 'Imperial (°F, mph)', 'temp': '°F'},
      {'value': 'standard', 'label': 'Standard (K, m/s)', 'temp': 'K'},
    ];
  }

  /// Get available languages (subset of supported languages)
  static List<Map<String, String>> getAvailableLanguages() {
    return [
      {'value': 'en', 'label': 'English'},
      {'value': 'es', 'label': 'Spanish'},
      {'value': 'fr', 'label': 'French'},
      {'value': 'de', 'label': 'German'},
      {'value': 'it', 'label': 'Italian'},
      {'value': 'pt', 'label': 'Portuguese'},
      {'value': 'ru', 'label': 'Russian'},
      {'value': 'ja', 'label': 'Japanese'},
      {'value': 'zh', 'label': 'Chinese'},
    ];
  }
}

class WeatherException implements Exception {
  final String message;
  final String code;
  
  const WeatherException(this.message, this.code);
  
  @override
  String toString() => 'WeatherException($code): $message';
}