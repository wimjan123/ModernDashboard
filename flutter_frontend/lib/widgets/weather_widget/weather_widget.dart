import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/cpp_bridge.dart';
import '../common/glass_card.dart';
import '../../core/theme/dark_theme.dart';

// Conditional import for FFI (web uses stub)
import '../../services/ffi_bridge.dart' if (dart.library.html) '../../services/ffi_bridge_web.dart';

class WeatherData {
  final String location;
  final double temperature;
  final String conditions;
  
  const WeatherData({
    required this.location,
    required this.temperature,
    required this.conditions,
  });
  
  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
    location: json['location'] as String? ?? 'Unknown',
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
    conditions: json['conditions'] as String? ?? 'Unknown',
  );
}

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  WeatherData? _weatherData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    try {
      String weatherJson;
      if (kIsWeb) {
        weatherJson = CppBridge.getWeatherData();
      } else {
        weatherJson = FfiBridge.isSupported ? FfiBridge.getWeatherData() : CppBridge.getWeatherData();
      }
      final Map<String, dynamic> jsonData = json.decode(weatherJson) as Map<String, dynamic>;
      
      setState(() {
        _weatherData = WeatherData.fromJson(jsonData);
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  IconData _getWeatherIcon(String conditions) {
    switch (conditions.toLowerCase()) {
      case 'sunny':
      case 'clear':
        return Icons.wb_sunny;
      case 'cloudy':
      case 'overcast':
        return Icons.cloud;
      case 'rainy':
      case 'rain':
        return Icons.grain;
      case 'snowy':
      case 'snow':
        return Icons.ac_unit;
      default:
        return Icons.wb_cloudy;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassInfoCard(
      title: 'Weather',
      icon: Icon(
        Icons.wb_sunny_rounded,
        color: DarkThemeData.warningColor,
        size: 20,
      ),
      accentColor: DarkThemeData.warningColor,
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DarkThemeData.warningColor,
              ),
            )
          : _weatherData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 32,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No weather data',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Main weather display
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: DarkThemeData.warningColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                _getWeatherIcon(_weatherData!.conditions),
                                size: 40,
                                color: DarkThemeData.warningColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${_weatherData!.temperature.round()}°C',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              _weatherData!.conditions,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: DarkThemeData.warningColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Location and additional info
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _weatherData!.location,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Now',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}