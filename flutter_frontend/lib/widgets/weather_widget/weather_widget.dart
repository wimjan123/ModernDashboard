import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../common/glass_card.dart';
import '../../core/theme/dark_theme.dart';
import '../../models/weather.dart';
import '../../repositories/repository_provider.dart';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  final TextEditingController _locationController = TextEditingController();
  String? _error;
  WeatherData? _currentWeather;
  bool _isLoadingWeather = false;

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadWeather([String? location]) async {
    if (_isLoadingWeather) return;
    
    setState(() {
      _isLoadingWeather = true;
      _error = null;
    });

    try {
      final weatherRepository = Provider.of<RepositoryProvider>(context, listen: false).weatherRepository;
      
      // Use provided location or default location
      String searchLocation = location ?? 'London'; // Default location
      
      final weather = await weatherRepository.getCurrentWeather(searchLocation);
      
      setState(() {
        _currentWeather = weather;
        _isLoadingWeather = false;
        _error = null;
      });
      
      // Update user's location preference if a new location was searched
      if (location != null && location.isNotEmpty) {
        await weatherRepository.updateLocation(location);
      }
    } catch (e) {
      setState(() {
        _isLoadingWeather = false;
        _error = 'Failed to load weather: $e';
      });
    }
  }

  Future<void> _searchLocation() async {
    final location = _locationController.text.trim();
    if (location.isEmpty) return;

    await _loadWeather(location);
    _locationController.clear();
  }

  @override
  void initState() {
    super.initState();
    _loadWeather(); // Load default weather on init
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
      icon: const Icon(
        Icons.wb_sunny_rounded,
        color: DarkThemeData.warningColor,
        size: 20,
      ),
      accentColor: DarkThemeData.warningColor,
      child: Consumer<RepositoryProvider>(
        builder: (context, repositoryProvider, child) {
          if (!repositoryProvider.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DarkThemeData.warningColor,
              ),
            );
          }

          if (_isLoadingWeather) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DarkThemeData.warningColor,
              ),
            );
          }

          if (_error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 32,
                    color: DarkThemeData.errorColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DarkThemeData.errorColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _loadWeather(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DarkThemeData.warningColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (_currentWeather == null) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 32,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'No weather data',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          hintText: 'Enter city name...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: DarkThemeData.warningColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onSubmitted: (_) => _searchLocation(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _searchLocation,
                      icon: const Icon(Icons.search_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: DarkThemeData.warningColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Column(
            children: [
              // Location search at top
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          hintText: 'Search location...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: DarkThemeData.warningColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onSubmitted: (_) => _searchLocation(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _searchLocation,
                      icon: const Icon(Icons.search_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: DarkThemeData.warningColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),

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
                          color: DarkThemeData.warningColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _getWeatherIcon(_currentWeather!.description),
                          size: 40,
                          color: DarkThemeData.warningColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _currentWeather!.formattedTemperature,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        _currentWeather!.description,
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
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
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
                              _currentWeather!.location,
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
                            _currentWeather!.isRecent ? Icons.access_time_rounded : Icons.cached_rounded,
                            size: 14,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _currentWeather!.isRecent ? 'Live' : 'Cached',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}