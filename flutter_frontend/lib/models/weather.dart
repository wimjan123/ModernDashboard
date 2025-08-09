
class WeatherData {
  final String id;
  final String location;
  final double latitude;
  final double longitude;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double pressure;
  final String description;
  final String icon;
  final double windSpeed;
  final int windDirection;
  final int cloudiness;
  final int visibility;
  final DateTime timestamp;
  final String units; // 'metric', 'imperial', 'standard'

  const WeatherData({
    required this.id,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.pressure,
    required this.description,
    required this.icon,
    required this.windSpeed,
    required this.windDirection,
    required this.cloudiness,
    required this.visibility,
    required this.timestamp,
    required this.units,
  });

  /// Create WeatherData from OpenWeatherMap API response
  factory WeatherData.fromOpenWeatherMapJson(Map<String, dynamic> json, String units) {
    final main = json['main'] as Map<String, dynamic>;
    final weather = (json['weather'] as List).first as Map<String, dynamic>;
    final wind = json['wind'] as Map<String, dynamic>? ?? {};
    final clouds = json['clouds'] as Map<String, dynamic>? ?? {};
    final coord = json['coord'] as Map<String, dynamic>;

    return WeatherData(
      id: json['id']?.toString() ?? 'unknown',
      location: json['name'] ?? 'Unknown Location',
      latitude: (coord['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (coord['lon'] as num?)?.toDouble() ?? 0.0,
      temperature: (main['temp'] as num?)?.toDouble() ?? 0.0,
      feelsLike: (main['feels_like'] as num?)?.toDouble() ?? 0.0,
      humidity: (main['humidity'] as int?) ?? 0,
      pressure: (main['pressure'] as num?)?.toDouble() ?? 0.0,
      description: weather['description'] ?? '',
      icon: weather['icon'] ?? '01d',
      windSpeed: (wind['speed'] as num?)?.toDouble() ?? 0.0,
      windDirection: (wind['deg'] as int?) ?? 0,
      cloudiness: (clouds['all'] as int?) ?? 0,
      visibility: (json['visibility'] as int?) ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        ((json['dt'] as int?) ?? 0) * 1000,
      ),
      units: units,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'temperature': temperature,
      'feels_like': feelsLike,
      'humidity': humidity,
      'pressure': pressure,
      'description': description,
      'icon': icon,
      'wind_speed': windSpeed,
      'wind_direction': windDirection,
      'cloudiness': cloudiness,
      'visibility': visibility,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'units': units,
    };
  }

  /// Create from JSON
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      id: json['id'] ?? 'unknown',
      location: json['location'] ?? 'Unknown Location',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      feelsLike: (json['feels_like'] as num?)?.toDouble() ?? 0.0,
      humidity: (json['humidity'] as int?) ?? 0,
      pressure: (json['pressure'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] ?? '',
      icon: json['icon'] ?? '01d',
      windSpeed: (json['wind_speed'] as num?)?.toDouble() ?? 0.0,
      windDirection: (json['wind_direction'] as int?) ?? 0,
      cloudiness: (json['cloudiness'] as int?) ?? 0,
      visibility: (json['visibility'] as int?) ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      units: json['units'] ?? 'metric',
    );
  }

  /// Get temperature unit string
  String get temperatureUnit {
    switch (units) {
      case 'imperial':
        return '°F';
      case 'standard':
        return 'K';
      case 'metric':
      default:
        return '°C';
    }
  }

  /// Get wind speed unit string
  String get windSpeedUnit {
    switch (units) {
      case 'imperial':
        return 'mph';
      case 'standard':
      case 'metric':
      default:
        return 'm/s';
    }
  }

  /// Get formatted temperature
  String get formattedTemperature => '${temperature.round()}$temperatureUnit';

  /// Get formatted feels like temperature
  String get formattedFeelsLike => '${feelsLike.round()}$temperatureUnit';

  /// Get formatted wind speed
  String get formattedWindSpeed => '${windSpeed.toStringAsFixed(1)} $windSpeedUnit';

  /// Get formatted pressure
  String get formattedPressure => '${pressure.round()} hPa';

  /// Get formatted humidity
  String get formattedHumidity => '$humidity%';

  /// Get weather icon URL
  String get iconUrl => 'https://openweathermap.org/img/wn/$icon@2x.png';

  /// Get wind direction as compass direction
  String get windDirectionCompass {
    const directions = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 
                       'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    final index = ((windDirection + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }

  /// Check if weather data is recent (within last hour)
  bool get isRecent {
    final now = DateTime.now();
    return now.difference(timestamp).inHours < 1;
  }

  /// Backward compatibility alias for isRecent
  bool get isFresh => isRecent;

  @override
  String toString() {
    return 'WeatherData(location: $location, temperature: $formattedTemperature, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeatherData && other.id == id && other.timestamp == timestamp;
  }

  @override
  int get hashCode => id.hashCode ^ timestamp.hashCode;
}

class WeatherLocation {
  final String id;
  final String name;
  final String country;
  final String state;
  final double latitude;
  final double longitude;
  final bool isDefault;
  final DateTime createdAt;

  const WeatherLocation({
    required this.id,
    required this.name,
    required this.country,
    this.state = '',
    required this.latitude,
    required this.longitude,
    this.isDefault = false,
    required this.createdAt,
  });

  /// Create from JSON
  factory WeatherLocation.fromJson(Map<String, dynamic> json) {
    return WeatherLocation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      country: json['country'] ?? '',
      state: json['state'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      isDefault: json['is_default'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['created_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'country': country,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Get display name
  String get displayName {
    if (state.isNotEmpty) {
      return '$name, $state, $country';
    }
    return '$name, $country';
  }

  /// Copy with updated fields
  WeatherLocation copyWith({
    String? id,
    String? name,
    String? country,
    String? state,
    double? latitude,
    double? longitude,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return WeatherLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'WeatherLocation(name: $displayName, lat: $latitude, lon: $longitude)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeatherLocation && 
           other.latitude == latitude && 
           other.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

class WeatherApiConfig {
  final String apiKey;
  final String units; // 'metric', 'imperial', 'standard'
  final String language;
  final bool isEnabled;
  final DateTime updatedAt;

  const WeatherApiConfig({
    required this.apiKey,
    this.units = 'metric',
    this.language = 'en',
    this.isEnabled = true,
    required this.updatedAt,
  });

  /// Create from JSON
  factory WeatherApiConfig.fromJson(Map<String, dynamic> json) {
    return WeatherApiConfig(
      apiKey: json['api_key'] ?? '',
      units: json['units'] ?? 'metric',
      language: json['language'] ?? 'en',
      isEnabled: json['is_enabled'] ?? true,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'api_key': apiKey,
      'units': units,
      'language': language,
      'is_enabled': isEnabled,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Check if API key is configured
  bool get isConfigured => apiKey.isNotEmpty;

  /// Copy with updated fields
  WeatherApiConfig copyWith({
    String? apiKey,
    String? units,
    String? language,
    bool? isEnabled,
    DateTime? updatedAt,
  }) {
    return WeatherApiConfig(
      apiKey: apiKey ?? this.apiKey,
      units: units ?? this.units,
      language: language ?? this.language,
      isEnabled: isEnabled ?? this.isEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'WeatherApiConfig(hasKey: ${apiKey.isNotEmpty}, units: $units, enabled: $isEnabled)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeatherApiConfig && 
           other.apiKey == apiKey &&
           other.units == units &&
           other.language == language &&
           other.isEnabled == isEnabled;
  }

  @override
  int get hashCode => apiKey.hashCode ^ units.hashCode ^ language.hashCode ^ isEnabled.hashCode;
}