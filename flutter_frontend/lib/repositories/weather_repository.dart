abstract class WeatherRepository {
  /// Get current weather for a location
  Future<WeatherData> getCurrentWeather(String location);
  
  /// Get weather forecast for a location
  Future<List<WeatherData>> getForecast(String location);
  
  /// Update user's default location
  Future<void> updateLocation(String location);
  
  /// Clear cached weather data
  Future<void> clearCache();
}

class WeatherData {
  final String id;
  final String location;
  final double temperature;
  final double humidity;
  final String conditions;
  final String iconCode;
  final DateTime updatedAt;
  final DateTime? cachedAt;
  final DateTime? expiresAt;
  final String? userId;
  final double? windSpeed;
  final double? pressure;
  final double? visibility;
  final int? uvIndex;

  WeatherData({
    required this.id,
    required this.location,
    required this.temperature,
    required this.humidity,
    required this.conditions,
    required this.iconCode,
    required this.updatedAt,
    this.cachedAt,
    this.expiresAt,
    this.userId,
    this.windSpeed,
    this.pressure,
    this.visibility,
    this.uvIndex,
  });

  /// Create WeatherData from JSON (API response or Firestore document)
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      id: json['id'] ?? '',
      location: json['location'] ?? '',
      temperature: (json['temperature'] ?? 0).toDouble(),
      humidity: (json['humidity'] ?? 0).toDouble(),
      conditions: json['conditions'] ?? '',
      iconCode: json['icon_code'] ?? '',
      updatedAt: json['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updated_at'])
          : DateTime.now(),
      cachedAt: json['cached_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['cached_at'])
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['expires_at'])
          : null,
      userId: json['user_id'],
      windSpeed: json['wind_speed']?.toDouble(),
      pressure: json['pressure']?.toDouble(),
      visibility: json['visibility']?.toDouble(),
      uvIndex: json['uv_index']?.toInt(),
    );
  }

  /// Convert WeatherData to JSON (for caching in Firestore)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'location': location,
      'temperature': temperature,
      'humidity': humidity,
      'conditions': conditions,
      'icon_code': iconCode,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'cached_at': cachedAt?.millisecondsSinceEpoch,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'user_id': userId,
      'wind_speed': windSpeed,
      'pressure': pressure,
      'visibility': visibility,
      'uv_index': uvIndex,
    };
  }

  /// Create a copy with updated fields
  WeatherData copyWith({
    String? id,
    String? location,
    double? temperature,
    double? humidity,
    String? conditions,
    String? iconCode,
    DateTime? updatedAt,
    DateTime? cachedAt,
    DateTime? expiresAt,
    String? userId,
    double? windSpeed,
    double? pressure,
    double? visibility,
    int? uvIndex,
  }) {
    return WeatherData(
      id: id ?? this.id,
      location: location ?? this.location,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      conditions: conditions ?? this.conditions,
      iconCode: iconCode ?? this.iconCode,
      updatedAt: updatedAt ?? this.updatedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      userId: userId ?? this.userId,
      windSpeed: windSpeed ?? this.windSpeed,
      pressure: pressure ?? this.pressure,
      visibility: visibility ?? this.visibility,
      uvIndex: uvIndex ?? this.uvIndex,
    );
  }

  /// Check if weather data is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Check if weather data is fresh (less than 10 minutes old)
  bool get isFresh {
    final now = DateTime.now();
    final updateThreshold = updatedAt.add(const Duration(minutes: 10));
    return now.isBefore(updateThreshold);
  }

  /// Get temperature in Fahrenheit
  double get temperatureFahrenheit => (temperature * 9 / 5) + 32;

  /// Get formatted temperature string
  String getTemperatureString({bool celsius = true}) {
    final temp = celsius ? temperature : temperatureFahrenheit;
    final unit = celsius ? '°C' : '°F';
    return '${temp.round()}$unit';
  }

  @override
  String toString() {
    return 'WeatherData(location: $location, temperature: $temperature°C, conditions: $conditions)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeatherData && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}