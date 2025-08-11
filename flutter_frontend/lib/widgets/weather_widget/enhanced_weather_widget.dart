import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../common/glass_card.dart';
import '../../core/theme/dark_theme.dart';
import '../../repositories/repository_provider.dart';
import '../../models/weather.dart';
import 'weather_config_dialog.dart';
import 'weather_location_dialog.dart';

class EnhancedWeatherWidget extends StatefulWidget {
  const EnhancedWeatherWidget({super.key});

  @override
  State<EnhancedWeatherWidget> createState() => _EnhancedWeatherWidgetState();
}

class _EnhancedWeatherWidgetState extends State<EnhancedWeatherWidget> {
  WeatherApiConfig? _config;
  List<WeatherLocation> _locations = [];
  WeatherLocation? _defaultLocation;
  WeatherData? _currentWeather;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);
      if (!repositoryProvider.isInitialized) {
        throw Exception('Repository not initialized');
      }

      // Load configuration, locations, and weather data in parallel
      final results = await Future.wait([
        repositoryProvider.weatherRepository.getConfig(),
        repositoryProvider.weatherRepository.getLocations(),
        repositoryProvider.weatherRepository.getDefaultLocation(),
      ]);

      if (mounted) {
        final config = results[0] as WeatherApiConfig;
        final locations = results[1] as List<WeatherLocation>;
        final defaultLocation = results[2] as WeatherLocation?;

        setState(() {
          _config = config;
          _locations = locations;
          _defaultLocation = defaultLocation;
        });

        // Load current weather for default location
        if (defaultLocation != null) {
          await _loadCurrentWeather();
        }

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load weather data: $e';
        });
      }
    }
  }

  Future<void> _loadCurrentWeather() async {
    if (_defaultLocation == null) return;

    try {
      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);
      final weatherData = await repositoryProvider.weatherRepository
          .getCurrentWeatherForLocation(_defaultLocation!);
      
      if (mounted) {
        setState(() {
          _currentWeather = weatherData;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load weather: $e';
        });
      }
    }
  }

  Future<void> _refreshWeather() async {
    await _loadCurrentWeather();
  }

  Future<void> _openConfigDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WeatherConfigDialog(initialConfig: _config),
    );
    
    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _openLocationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WeatherLocationDialog(locations: _locations),
    );
    
    if (result == true) {
      await _loadData();
    }
  }

  String _getWeatherIconUrl(String iconCode) {
    return 'https://openweathermap.org/img/wn/$iconCode@2x.png';
  }

  Widget _buildWeatherIcon(String iconCode) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: DarkThemeData.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _getWeatherIconUrl(iconCode),
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.wb_sunny,
            size: 40,
            color: DarkThemeData.accentColor,
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Icon(
              Icons.wb_sunny,
              size: 40,
              color: DarkThemeData.accentColor.withValues(alpha: 0.5),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassInfoCard(
      title: 'Weather',
      icon: Icon(
        Icons.wb_sunny_rounded,
        color: DarkThemeData.accentColor,
        size: 20,
      ),
      accentColor: DarkThemeData.accentColor,
      child: Consumer<RepositoryProvider>(
        builder: (context, repositoryProvider, child) {
          if (!repositoryProvider.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DarkThemeData.accentColor,
              ),
            );
          }

          if (_isLoading && _currentWeather == null) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DarkThemeData.accentColor,
              ),
            );
          }

          return Column(
            children: [
              // Control bar
              _buildControlBar(),
              
              if (_error != null) _buildErrorBanner(),
              
              if (_config == null || !_config!.isConfigured)
                _buildConfigurationPrompt()
              else if (_defaultLocation == null)
                _buildLocationPrompt()
              else if (_currentWeather == null && !_isLoading)
                _buildNoDataState()
              else
                _buildWeatherDisplay(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControlBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: _defaultLocation != null
                ? Text(
                    _defaultLocation!.displayName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : Text(
                    'No location selected',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _openLocationDialog,
            icon: const Icon(Icons.location_on_rounded, size: 18),
            style: IconButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.7),
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(36, 36),
            ),
            tooltip: 'Manage locations',
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _openConfigDialog,
            icon: const Icon(Icons.settings_rounded, size: 18),
            style: IconButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.7),
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(36, 36),
            ),
            tooltip: 'Weather settings',
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _isLoading ? null : _refreshWeather,
            icon: _isLoading 
                ? SizedBox(
                    width: 16, 
                    height: 16, 
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DarkThemeData.accentColor,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            style: IconButton.styleFrom(
              foregroundColor: DarkThemeData.accentColor,
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(36, 36),
            ),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DarkThemeData.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DarkThemeData.errorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_rounded,
            size: 16,
            color: DarkThemeData.errorColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: DarkThemeData.errorColor,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _error = null),
            icon: const Icon(Icons.close_rounded, size: 16),
            style: IconButton.styleFrom(
              foregroundColor: DarkThemeData.errorColor,
              padding: const EdgeInsets.all(4),
              minimumSize: const Size(24, 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationPrompt() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Configure Weather API',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your OpenWeatherMap API key to get live weather data',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openConfigDialog,
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text('Configure API'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DarkThemeData.accentColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPrompt() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Add Weather Locations',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search and add locations to see weather data',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openLocationDialog,
              icon: const Icon(Icons.location_on_rounded, size: 18),
              label: const Text('Add Locations'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DarkThemeData.accentColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Weather Data',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try refreshing to load weather data',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherDisplay() {
    if (_currentWeather == null) return const SizedBox.shrink();
    
    return Expanded(
      child: Column(
        children: [
          // Main weather info
          Row(
            children: [
              _buildWeatherIcon(_currentWeather!.iconCode),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentWeather!.formattedTemperature,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _currentWeather!.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_currentWeather!.windSpeed != null)
                      Text(
                        'Feels like ${_currentWeather!.formattedFeelsLike}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Weather details
          Row(
            children: [
              _buildWeatherDetail(
                Icons.water_drop_rounded,
                'Humidity',
                '${_currentWeather!.humidity.round()}%',
              ),
              const SizedBox(width: 16),
              if (_currentWeather!.windSpeed != null)
                _buildWeatherDetail(
                  Icons.air_rounded,
                  'Wind',
                  '${_currentWeather!.windSpeed!.toStringAsFixed(1)} ${_config?.units == 'imperial' ? 'mph' : 'm/s'}',
                ),
            ],
          ),
          
          if (_currentWeather!.pressure != null || _currentWeather!.visibility != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (_currentWeather!.pressure != null)
                  _buildWeatherDetail(
                    Icons.speed_rounded,
                    'Pressure',
                    '${_currentWeather!.pressure!.round()} hPa',
                  ),
                if (_currentWeather!.pressure != null && _currentWeather!.visibility != null)
                  const SizedBox(width: 16),
                if (_currentWeather!.visibility != null)
                  _buildWeatherDetail(
                    Icons.visibility_rounded,
                    'Visibility',
                    '${(_currentWeather!.visibility! / 1000).toStringAsFixed(1)} km',
                  ),
              ],
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Last updated
          Text(
            'Updated ${_getTimeAgo(_currentWeather!.updatedAt)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetail(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 16,
              color: DarkThemeData.accentColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}