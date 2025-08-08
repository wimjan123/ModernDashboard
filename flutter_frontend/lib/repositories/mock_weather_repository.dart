import 'dart:math';
import 'package:flutter/foundation.dart';
import 'weather_repository.dart';
import '../services/mock_data_service.dart';

/// Mock Weather Repository that provides realistic weather data for offline mode
/// Uses MockDataService for base weather data with realistic variations
class MockWeatherRepository implements WeatherRepository {
  final MockDataService _mockDataService = MockDataService();
  final Map<String, WeatherData> _weatherCache = {};
  String _defaultLocation = 'San Francisco, CA';
  final Random _random = Random();

  MockWeatherRepository() {
    _mockDataService.initialize();
  }

  @override
  Future<WeatherData> getCurrentWeather(String location) async {
    try {
      // Check if weather data exists in cache and is fresh
      if (_weatherCache.containsKey(location)) {
        final cachedData = _weatherCache[location]!;
        if (cachedData.isFresh) {
          debugPrint('Returning cached weather for $location');
          return cachedData;
        }
      }

      // Generate new weather data
      final weatherData = await _generateMockWeatherData(location);
      _weatherCache[location] = weatherData;
      
      debugPrint('Generated new weather data for $location: ${weatherData.temperature}°C, ${weatherData.conditions}');
      return weatherData;
    } catch (e) {
      debugPrint('Error getting current weather: $e');
      // Return fallback weather data
      return _createFallbackWeatherData(location);
    }
  }

  @override
  Future<List<WeatherData>> getForecast(String location) async {
    try {
      final forecast = <WeatherData>[];
      final baseWeather = await getCurrentWeather(location);
      final now = DateTime.now();
      
      // Generate 5-day forecast with realistic variations
      for (int i = 0; i < 5; i++) {
        final forecastDate = now.add(Duration(days: i));
        final temperatureVariation = _random.nextDouble() * 6 - 3; // ±3°C variation
        final conditionsVariation = _getRandomWeatherCondition();
        
        final forecastData = WeatherData(
          id: '${location.hashCode}_${forecastDate.day}',
          location: location,
          temperature: (baseWeather.temperature + temperatureVariation).clamp(-20, 50),
          humidity: _adjustHumidity(baseWeather.humidity, conditionsVariation),
          conditions: i == 0 ? baseWeather.conditions : conditionsVariation,
          iconCode: _getIconForCondition(i == 0 ? baseWeather.conditions : conditionsVariation),
          updatedAt: forecastDate,
          cachedAt: now,
          expiresAt: now.add(const Duration(hours: 6)),
          userId: 'mock_user',
          windSpeed: baseWeather.windSpeed != null 
              ? (baseWeather.windSpeed! + (_random.nextDouble() * 4 - 2)).clamp(0, 50)
              : _random.nextDouble() * 15 + 5,
          pressure: baseWeather.pressure != null
              ? (baseWeather.pressure! + (_random.nextDouble() * 20 - 10)).clamp(980, 1040)
              : _random.nextDouble() * 40 + 1000,
          visibility: (_random.nextDouble() * 15 + 5).toDouble(), // 5-20 km
          uvIndex: _getUVIndex(conditionsVariation),
        );
        
        forecast.add(forecastData);
      }
      
      debugPrint('Generated ${forecast.length}-day forecast for $location');
      return forecast;
    } catch (e) {
      debugPrint('Error getting forecast: $e');
      return [];
    }
  }

  @override
  Future<void> updateLocation(String location) async {
    try {
      _defaultLocation = location;
      // Pre-generate weather data for the new location
      await getCurrentWeather(location);
      debugPrint('Updated default location to: $location');
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      _weatherCache.clear();
      debugPrint('Weather cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Generate mock weather data with realistic variations
  Future<WeatherData> _generateMockWeatherData(String location) async {

    // Apply location-specific temperature adjustments
    final baseTemp = _adjustTemperatureForLocation(location);
    final tempVariation = _random.nextDouble() * 8 - 4; // ±4°C variation
    final finalTemp = (baseTemp + tempVariation).clamp(-30, 50).toDouble();

    final conditions = _getRandomWeatherCondition();
    final now = DateTime.now();

    return WeatherData(
      id: '${location.hashCode}_${now.millisecondsSinceEpoch}',
      location: location,
      temperature: finalTemp,
      humidity: _random.nextDouble() * 40 + 30, // 30-70%
      conditions: conditions,
      iconCode: _getIconForCondition(conditions),
      updatedAt: now,
      cachedAt: now,
      expiresAt: now.add(const Duration(minutes: 10)),
      userId: 'mock_user',
      windSpeed: _random.nextDouble() * 20 + 2, // 2-22 km/h
      pressure: _random.nextDouble() * 50 + 1000, // 1000-1050 hPa
      visibility: (_random.nextDouble() * 15 + 5).toDouble(), // 5-20 km
      uvIndex: _getUVIndex(conditions),
    );
  }

  /// Adjust temperature based on location and seasonal variations
  double _adjustTemperatureForLocation(String location) {
    final locationLower = location.toLowerCase();
    final currentMonth = DateTime.now().month;
    
    // Base temperature by location
    double baseTemp;
    if (locationLower.contains('miami') || locationLower.contains('florida')) {
      baseTemp = 28.0; // Warmer
    } else if (locationLower.contains('seattle') || locationLower.contains('washington')) {
      baseTemp = 15.0; // Cooler
    } else if (locationLower.contains('phoenix') || locationLower.contains('arizona')) {
      baseTemp = 35.0; // Hot
    } else if (locationLower.contains('denver') || locationLower.contains('colorado')) {
      baseTemp = 18.0; // Mountain climate
    } else if (locationLower.contains('chicago') || locationLower.contains('illinois')) {
      baseTemp = 12.0; // Continental climate
    } else if (locationLower.contains('los angeles') || locationLower.contains('california')) {
      baseTemp = 22.0; // Mediterranean climate
    } else {
      baseTemp = 20.0; // Default moderate temperature
    }
    
    // Apply seasonal adjustments based on current month
    double seasonalOffset = _getSeasonalOffset(currentMonth, locationLower);
    
    return baseTemp + seasonalOffset;
  }
  
  /// Get seasonal temperature offset based on month and location type
  double _getSeasonalOffset(int month, String locationLower) {
    // Determine if location is in Northern or Southern hemisphere
    bool isNorthernHemisphere = !_isSouthernHemisphere(locationLower);
    
    // Define seasonal months (adjusted for hemisphere)
    List<int> winterMonths, summerMonths;
    if (isNorthernHemisphere) {
      winterMonths = [12, 1, 2]; // Dec, Jan, Feb
      summerMonths = [6, 7, 8];  // Jun, Jul, Aug
    } else {
      winterMonths = [6, 7, 8];  // Jun, Jul, Aug (Southern winter)
      summerMonths = [12, 1, 2]; // Dec, Jan, Feb (Southern summer)
    }
    
    // Apply seasonal adjustments
    if (winterMonths.contains(month)) {
      // Winter: cooler temperatures
      if (locationLower.contains('phoenix') || locationLower.contains('arizona')) {
        return -12.0; // Desert regions get much cooler in winter
      } else if (locationLower.contains('miami') || locationLower.contains('florida')) {
        return -8.0; // Subtropical regions moderate cooling
      } else if (locationLower.contains('chicago') || locationLower.contains('denver')) {
        return -15.0; // Continental/mountain climates get very cold
      } else {
        return -10.0; // General winter cooling
      }
    } else if (summerMonths.contains(month)) {
      // Summer: warmer temperatures
      if (locationLower.contains('phoenix') || locationLower.contains('arizona')) {
        return 8.0; // Desert regions get much hotter
      } else if (locationLower.contains('miami') || locationLower.contains('florida')) {
        return 5.0; // Humid subtropical warming
      } else if (locationLower.contains('seattle') || locationLower.contains('washington')) {
        return 8.0; // Pacific Northwest gets warmer but not extremely hot
      } else {
        return 6.0; // General summer warming
      }
    } else if ([3, 4, 5].contains(month) || [9, 10, 11].contains(month)) {
      // Spring/Fall: moderate adjustments (Northern hemisphere months)
      if (isNorthernHemisphere) {
        if ([3, 4, 5].contains(month)) {
          return -2.0; // Spring: slightly cooler than base
        } else {
          return 2.0; // Fall: slightly warmer than base
        }
      } else {
        // Reverse for Southern hemisphere
        if ([3, 4, 5].contains(month)) {
          return 2.0; // Fall in Southern hemisphere
        } else {
          return -2.0; // Spring in Southern hemisphere
        }
      }
    }
    
    return 0.0; // No adjustment
  }
  
  /// Determine if location is in Southern hemisphere
  bool _isSouthernHemisphere(String locationLower) {
    return locationLower.contains('sydney') ||
           locationLower.contains('melbourne') ||
           locationLower.contains('australia') ||
           locationLower.contains('sydney') ||
           locationLower.contains('cape town') ||
           locationLower.contains('south africa') ||
           locationLower.contains('rio de janeiro') ||
           locationLower.contains('brazil') ||
           locationLower.contains('buenos aires') ||
           locationLower.contains('argentina') ||
           locationLower.contains('lima') ||
           locationLower.contains('peru');
  }

  /// Get random weather condition
  String _getRandomWeatherCondition() {
    final conditions = [
      'Clear',
      'Partly Cloudy',
      'Cloudy',
      'Overcast',
      'Light Rain',
      'Rain',
      'Heavy Rain',
      'Thunderstorms',
      'Snow',
      'Fog',
      'Windy',
    ];
    
    // Weight conditions to make some more common
    final weights = [20, 25, 15, 10, 8, 5, 2, 3, 4, 3, 5]; // Clear and Partly Cloudy are most common
    final totalWeight = weights.reduce((a, b) => a + b);
    final randomValue = _random.nextInt(totalWeight);
    
    int currentWeight = 0;
    for (int i = 0; i < conditions.length; i++) {
      currentWeight += weights[i];
      if (randomValue < currentWeight) {
        return conditions[i];
      }
    }
    
    return 'Partly Cloudy'; // Fallback
  }

  /// Get weather icon for condition
  String _getIconForCondition(String condition) {
    final iconMap = {
      'Clear': 'clear-day',
      'Partly Cloudy': 'partly-cloudy-day',
      'Cloudy': 'cloudy',
      'Overcast': 'cloudy',
      'Light Rain': 'rain',
      'Rain': 'rain',
      'Heavy Rain': 'rain',
      'Thunderstorms': 'thunderstorm',
      'Snow': 'snow',
      'Fog': 'fog',
      'Windy': 'wind',
    };
    
    return iconMap[condition] ?? 'partly-cloudy-day';
  }

  /// Adjust humidity based on weather conditions
  double _adjustHumidity(double baseHumidity, String conditions) {
    switch (conditions) {
      case 'Rain':
      case 'Heavy Rain':
      case 'Thunderstorms':
        return (baseHumidity + 20).clamp(70, 95);
      case 'Snow':
      case 'Fog':
        return (baseHumidity + 15).clamp(65, 90);
      case 'Clear':
        return (baseHumidity - 10).clamp(25, 60);
      default:
        return baseHumidity.clamp(30, 80);
    }
  }

  /// Get UV index based on conditions
  int _getUVIndex(String conditions) {
    switch (conditions) {
      case 'Clear':
        return _random.nextInt(4) + 7; // 7-10 (high)
      case 'Partly Cloudy':
        return _random.nextInt(3) + 5; // 5-7 (moderate to high)
      case 'Cloudy':
      case 'Overcast':
        return _random.nextInt(3) + 2; // 2-4 (low to moderate)
      case 'Rain':
      case 'Heavy Rain':
      case 'Thunderstorms':
      case 'Snow':
      case 'Fog':
        return _random.nextInt(2) + 1; // 1-2 (low)
      default:
        return _random.nextInt(5) + 3; // 3-7 (moderate)
    }
  }

  /// Create fallback weather data when generation fails
  WeatherData _createFallbackWeatherData(String location) {
    final now = DateTime.now();
    return WeatherData(
      id: '${location.hashCode}_fallback',
      location: location,
      temperature: 20.0,
      humidity: 50.0,
      conditions: 'Partly Cloudy',
      iconCode: 'partly-cloudy-day',
      updatedAt: now,
      cachedAt: now,
      expiresAt: now.add(const Duration(minutes: 10)),
      userId: 'mock_user',
      windSpeed: 8.0,
      pressure: 1013.25,
      visibility: 10.0,
      uvIndex: 5,
    );
  }
}