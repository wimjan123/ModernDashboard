import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firebase_service.dart';
import '../firebase/remote_config_service.dart';
import '../models/weather.dart';
import 'weather_repository.dart';
import 'mock_weather_repository.dart';

class CloudWeatherRepository implements WeatherRepository {
  final FirebaseService _firebaseService = FirebaseService.instance;
  final RemoteConfigService _remoteConfigService = RemoteConfigService.instance;
  final String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  
  CollectionReference get _weatherCacheCollection => 
      _firebaseService.getUserCollection('weather_cache');
      
  DocumentReference get _userPreferencesDoc =>
      _firebaseService.getUserDocument();

  @override
  Future<WeatherData> getCurrentWeather(String location) async {
    try {
      // Check cache first
      final cachedWeather = await _getCachedWeather(location);
      if (cachedWeather != null && cachedWeather.isRecent) {
        return cachedWeather;
      }
      
      // Fetch fresh data from API
      final weatherData = await _fetchWeatherFromAPI(location);
      
      // Cache the result
      await _cacheWeatherData(weatherData);
      
      return weatherData;
    } catch (e) {
      // If API fails, return cached data if available
      final cachedWeather = await _getCachedWeather(location);
      if (cachedWeather != null) {
        return cachedWeather;
      }
      
      throw Exception('Failed to get weather data: $e');
    }
  }

  @override
  Future<List<WeatherData>> getForecast(String location) async {
    try {
      // Check cache for forecast data
      final cachedForecast = await _getCachedForecast(location);
      if (cachedForecast.isNotEmpty && cachedForecast.first.isRecent) {
        return cachedForecast;
      }
      
      // Fetch fresh forecast from API
      final forecastData = await _fetchForecastFromAPI(location);
      
      // Cache forecast data
      await _cacheForecastData(forecastData, location);
      
      return forecastData;
    } catch (e) {
      // Return cached forecast if API fails
      final cachedForecast = await _getCachedForecast(location);
      if (cachedForecast.isNotEmpty) {
        return cachedForecast;
      }
      
      throw Exception('Failed to get weather forecast: $e');
    }
  }

  @override
  Future<void> updateLocation(String location) async {
    try {
      final userId = _firebaseService.getUserId();
      if (userId == null) throw Exception('User not authenticated');
      
      await _userPreferencesDoc.set({
        'weather_location': location,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
      
      // Pre-fetch weather for the new location
      await getCurrentWeather(location);
    } catch (e) {
      throw Exception('Failed to update location: $e');
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      final snapshot = await _weatherCacheCollection.get();
      final batch = FirebaseFirestore.instance.batch();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to clear weather cache: $e');
    }
  }

  /// Fetch weather data from OpenWeatherMap API
  Future<WeatherData> _fetchWeatherFromAPI(String location) async {
    final apiKey = _remoteConfigService.getWeatherApiKey();
    if (apiKey.isEmpty) {
      throw Exception('Weather API key not configured in Firebase Remote Config');
    }
    
    final units = _remoteConfigService.getDefaultWeatherUnits();
    final language = _remoteConfigService.getDefaultWeatherLanguage();
    
    final url = '$_baseUrl/weather?q=$location&appid=$apiKey&units=$units&lang=$language';
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode != 200) {
      throw Exception('Weather API error: ${response.statusCode}');
    }
    
    final data = json.decode(response.body);
    return _parseWeatherResponse(data, location);
  }

  /// Fetch forecast data from OpenWeatherMap API
  Future<List<WeatherData>> _fetchForecastFromAPI(String location) async {
    final apiKey = _remoteConfigService.getWeatherApiKey();
    if (apiKey.isEmpty) {
      throw Exception('Weather API key not configured in Firebase Remote Config');
    }
    
    final units = _remoteConfigService.getDefaultWeatherUnits();
    final language = _remoteConfigService.getDefaultWeatherLanguage();
    
    final url = '$_baseUrl/forecast?q=$location&appid=$apiKey&units=$units&lang=$language';
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode != 200) {
      throw Exception('Weather API error: ${response.statusCode}');
    }
    
    final data = json.decode(response.body);
    return _parseForecastResponse(data, location);
  }

  /// Parse OpenWeatherMap current weather response
  WeatherData _parseWeatherResponse(Map<String, dynamic> data, String location) {
    final main = data['main'] ?? {};
    final weather = (data['weather'] as List).isNotEmpty 
        ? data['weather'][0] 
        : {};
    final wind = data['wind'] ?? {};
    final now = DateTime.now();
    
    return WeatherData(
      id: '${location}_current_${now.millisecondsSinceEpoch}',
      location: location,
      latitude: 0.0,
      longitude: 0.0,
      temperature: (main['temp'] ?? 0).toDouble(),
      feelsLike: (main['feels_like'] ?? main['temp'] ?? 0).toDouble(),
      humidity: (main['humidity'] ?? 0).round(),
      description: weather['description'] ?? '',
      icon: weather['icon'] ?? '',
      timestamp: now,
      windSpeed: (wind['speed'] ?? 0).toDouble(),
      windDirection: (wind['deg'] ?? 0).round(),
      pressure: (main['pressure'] ?? 0).toDouble(),
      cloudiness: (data['clouds']?['all'] ?? 0).round(),
      visibility: ((data['visibility'] ?? 0).toDouble() / 1000).round(), // Convert to km
      units: 'metric',
    );
  }

  /// Parse OpenWeatherMap forecast response
  List<WeatherData> _parseForecastResponse(Map<String, dynamic> data, String location) {
    final list = data['list'] as List? ?? [];
    final forecastItems = <WeatherData>[];
    
    for (int i = 0; i < list.length && i < 5; i++) { // Limit to 5 days
      final item = list[i];
      final main = item['main'] ?? {};
      final weather = (item['weather'] as List).isNotEmpty 
          ? item['weather'][0] 
          : {};
      final wind = item['wind'] ?? {};
      final dtTxt = item['dt_txt'] ?? '';
      final forecastTime = DateTime.tryParse(dtTxt) ?? DateTime.now();
      
      forecastItems.add(WeatherData(
        id: '${location}_forecast_${item['dt']}',
        location: location,
        latitude: 0.0,
        longitude: 0.0,
        temperature: (main['temp'] ?? 0).toDouble(),
        feelsLike: (main['feels_like'] ?? main['temp'] ?? 0).toDouble(),
        humidity: (main['humidity'] ?? 0).round(),
        description: weather['description'] ?? '',
        icon: weather['icon'] ?? '',
        timestamp: forecastTime,
        windSpeed: (wind['speed'] ?? 0).toDouble(),
        windDirection: (wind['deg'] ?? 0).round(),
        pressure: (main['pressure'] ?? 0).toDouble(),
        cloudiness: (item['clouds']?['all'] ?? 0).round(),
        visibility: 10, // Default visibility for forecast
        units: 'metric',
      ));
    }
    
    return forecastItems;
  }

  /// Get cached weather data for a location
  Future<WeatherData?> _getCachedWeather(String location) async {
    try {
      final snapshot = await _weatherCacheCollection
          .where('location', isEqualTo: location)
          .where('type', isEqualTo: 'current')
          .orderBy('updated_at', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      
      final data = snapshot.docs.first.data() as Map<String, dynamic>;
      data['id'] = snapshot.docs.first.id;
      return WeatherData.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Get cached forecast data for a location
  Future<List<WeatherData>> _getCachedForecast(String location) async {
    try {
      final snapshot = await _weatherCacheCollection
          .where('location', isEqualTo: location)
          .where('type', isEqualTo: 'forecast')
          .orderBy('updated_at', descending: true)
          .limit(5)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return WeatherData.fromJson(data);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Cache weather data in Firestore
  Future<void> _cacheWeatherData(WeatherData weatherData) async {
    try {
      final cacheData = weatherData.toJson();
      cacheData['type'] = 'current';
      cacheData.remove('id'); // Let Firestore generate ID
      
      await _weatherCacheCollection.add(cacheData);
      
      // Clean up old cache entries for this location
      await _cleanupOldCache(weatherData.location, 'current');
    } catch (e) {
      // Cache errors shouldn't break the flow
      debugPrint('Warning: Failed to cache weather data: $e');
    }
  }

  /// Cache forecast data in Firestore
  Future<void> _cacheForecastData(List<WeatherData> forecastData, String location) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (final weather in forecastData) {
        final cacheData = weather.toJson();
        cacheData['type'] = 'forecast';
        cacheData.remove('id');
        
        batch.set(_weatherCacheCollection.doc(), cacheData);
      }
      
      await batch.commit();
      
      // Clean up old forecast cache
      await _cleanupOldCache(location, 'forecast');
    } catch (e) {
      debugPrint('Warning: Failed to cache forecast data: $e');
    }
  }

  /// Clean up old cache entries
  Future<void> _cleanupOldCache(String location, String type) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 1));
      
      final snapshot = await _weatherCacheCollection
          .where('location', isEqualTo: location)
          .where('type', isEqualTo: type)
          .where('cached_at', isLessThan: cutoff.millisecondsSinceEpoch)
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      // Cleanup errors shouldn't break the flow
      debugPrint('Warning: Failed to cleanup old weather cache: $e');
    }
  }


  // New interface methods - now using Firebase Remote Config
  @override
  Future<WeatherApiConfig> getConfig() async {
    try {
      // Get configuration from Firebase Remote Config instead of user input
      return _remoteConfigService.getWeatherConfig();
    } catch (e) {
      // Fallback configuration
      return WeatherApiConfig(
        apiKey: '',
        units: 'metric',
        language: 'en',
        isEnabled: false,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> updateConfig(WeatherApiConfig config) async {
    // Store user preferences (units, language) but API key is managed via Remote Config
    try {
      await _userPreferencesDoc.set({
        'weather_preferences': {
          'units': config.units,
          'language': config.language,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update weather preferences: $e');
    }
  }

  @override
  Future<List<WeatherLocation>> getLocations() async {
    // For now, delegate to mock implementation
    final mockRepo = MockWeatherRepository();
    return mockRepo.getLocations();
  }

  @override
  Future<void> addLocation(WeatherLocation location) async {
    // For now, delegate to mock implementation
    final mockRepo = MockWeatherRepository();
    return mockRepo.addLocation(location);
  }

  @override
  Future<void> removeLocation(String locationId) async {
    // For now, delegate to mock implementation
    final mockRepo = MockWeatherRepository();
    return mockRepo.removeLocation(locationId);
  }

  @override
  Future<void> setDefaultLocation(String locationId) async {
    // For now, delegate to mock implementation
    final mockRepo = MockWeatherRepository();
    return mockRepo.setDefaultLocation(locationId);
  }

  @override
  Future<WeatherLocation?> getDefaultLocation() async {
    // For now, delegate to mock implementation
    final mockRepo = MockWeatherRepository();
    return mockRepo.getDefaultLocation();
  }

  @override
  Future<WeatherData> getCurrentWeatherForLocation(WeatherLocation location) async {
    // For now, delegate to mock implementation
    final mockRepo = MockWeatherRepository();
    return mockRepo.getCurrentWeatherForLocation(location);
  }

  @override
  Future<WeatherData?> getCurrentWeatherForDefault() async {
    // For now, delegate to mock implementation
    final mockRepo = MockWeatherRepository();
    return mockRepo.getCurrentWeatherForDefault();
  }

  @override
  Future<List<WeatherLocation>> searchLocations(String query) async {
    // For now, delegate to mock implementation
    final mockRepo = MockWeatherRepository();
    return mockRepo.searchLocations(query);
  }

  @override
  Future<bool> validateApiKey(String apiKey) async {
    // For now, delegate to mock implementation
    final mockRepo = MockWeatherRepository();
    return mockRepo.validateApiKey(apiKey);
  }
}