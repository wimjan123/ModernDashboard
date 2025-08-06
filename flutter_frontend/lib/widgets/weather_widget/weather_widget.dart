import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/cpp_bridge.dart';

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
      final weatherJson = CppBridge.getWeatherData();
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
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud_outlined),
                SizedBox(width: 8),
                Text('Weather', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _weatherData == null
                      ? const Center(child: Text('No weather data'))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getWeatherIcon(_weatherData!.conditions),
                              size: 48,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_weatherData!.temperature.round()}°C',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            Text(
                              _weatherData!.conditions,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _weatherData!.location,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}