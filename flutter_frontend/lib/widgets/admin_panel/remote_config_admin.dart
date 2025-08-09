import 'package:flutter/material.dart';
import '../../firebase/remote_config_service.dart';
import '../../core/theme/dark_theme.dart';

class RemoteConfigAdminPanel extends StatefulWidget {
  const RemoteConfigAdminPanel({super.key});

  @override
  State<RemoteConfigAdminPanel> createState() => _RemoteConfigAdminPanelState();
}

class _RemoteConfigAdminPanelState extends State<RemoteConfigAdminPanel> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isLoading = false;
  String? _status;
  Map<String, dynamic> _currentConfig = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final config = RemoteConfigService.instance.getAllConfigValues();
      final weatherConfig = RemoteConfigService.instance.getWeatherConfig();
      
      setState(() {
        _currentConfig = config;
        _isLoading = false;
        _status = 'Configuration loaded successfully';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Failed to load configuration: $e';
      });
    }
  }

  Future<void> _refreshConfig() async {
    setState(() {
      _isLoading = true;
      _status = null;
    });

    try {
      final success = await RemoteConfigService.instance.refreshConfig();
      if (success) {
        await _loadCurrentConfig();
        setState(() {
          _status = 'Configuration refreshed from Firebase';
        });
      } else {
        setState(() {
          _isLoading = false;
          _status = 'Failed to refresh configuration';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error refreshing configuration: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        'Firebase Remote Config Admin',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status
              if (_status != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _status!.contains('success') || _status!.contains('refreshed')
                        ? DarkThemeData.accentColor.withOpacity(0.1)
                        : DarkThemeData.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _status!.contains('success') || _status!.contains('refreshed')
                          ? DarkThemeData.accentColor.withOpacity(0.3)
                          : DarkThemeData.errorColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _status!.contains('success') || _status!.contains('refreshed')
                            ? Icons.check_circle
                            : Icons.error,
                        size: 16,
                        color: _status!.contains('success') || _status!.contains('refreshed')
                            ? DarkThemeData.accentColor
                            : DarkThemeData.errorColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _status!,
                          style: TextStyle(
                            color: _status!.contains('success') || _status!.contains('refreshed')
                                ? DarkThemeData.accentColor
                                : DarkThemeData.errorColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Firebase Remote Config Setup',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'To configure the weather API properly:\n\n'
                      '1. Go to Firebase Console → Remote Config\n'
                      '2. Add these parameters:\n'
                      '   • weather_api_key: Your OpenWeatherMap API key\n'
                      '   • weather_api_enabled: true\n'
                      '   • default_weather_units: metric\n'
                      '   • default_weather_language: en\n'
                      '3. Publish the configuration\n'
                      '4. Click "Refresh Config" below',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Current Configuration
              Text(
                'Current Configuration',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: DarkThemeData.accentColor,
                  ),
                )
              else if (_currentConfig.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._currentConfig.entries.map((entry) {
                        final value = entry.key == 'weather_api_key_set' && entry.value == true
                            ? 'API Key is configured'
                            : entry.value.toString();
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 120,
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: DarkThemeData.accentColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  value,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                )
              else
                Text(
                  'No configuration available',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),

              const SizedBox(height: 24),

              // Quick Links
              Text(
                'Quick Links',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildLinkChip(
                    'Firebase Console',
                    Icons.web,
                    'https://console.firebase.google.com',
                  ),
                  _buildLinkChip(
                    'OpenWeatherMap API',
                    Icons.api,
                    'https://openweathermap.org/api',
                  ),
                  _buildLinkChip(
                    'Remote Config Docs',
                    Icons.help,
                    'https://firebase.google.com/docs/remote-config',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loadCurrentConfig,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, size: 16),
              const SizedBox(width: 4),
              Text('Reload'),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _refreshConfig,
          style: ElevatedButton.styleFrom(
            backgroundColor: DarkThemeData.accentColor,
            foregroundColor: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(Icons.cloud_download, size: 16),
              const SizedBox(width: 4),
              Text(_isLoading ? 'Loading...' : 'Refresh Config'),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }

  Widget _buildLinkChip(String label, IconData icon, String url) {
    return InkWell(
      onTap: () {
        // In a real implementation, you would use url_launcher here
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Open: $url'),
            backgroundColor: DarkThemeData.accentColor,
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white.withOpacity(0.8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}