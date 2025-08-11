import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/dark_theme.dart';
import '../../models/weather.dart';
import '../../repositories/repository_provider.dart';
import '../../services/weather_service.dart';

class WeatherConfigDialog extends StatefulWidget {
  final WeatherApiConfig? initialConfig;

  const WeatherConfigDialog({
    super.key,
    this.initialConfig,
  });

  @override
  State<WeatherConfigDialog> createState() => _WeatherConfigDialogState();
}

class _WeatherConfigDialogState extends State<WeatherConfigDialog> {
  final TextEditingController _apiKeyController = TextEditingController();
  String _selectedUnits = 'metric';
  String _selectedLanguage = 'en';
  bool _isEnabled = false;
  bool _isValidating = false;
  bool? _isApiKeyValid;
  String? _validationError;
  
  @override
  void initState() {
    super.initState();
    _loadInitialConfig();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _loadInitialConfig() {
    if (widget.initialConfig != null) {
      _apiKeyController.text = widget.initialConfig!.apiKey;
      _selectedUnits = widget.initialConfig!.units;
      _selectedLanguage = widget.initialConfig!.language;
      _isEnabled = widget.initialConfig!.isEnabled && widget.initialConfig!.isConfigured;
      _isApiKeyValid = widget.initialConfig!.isConfigured ? true : null;
    }
  }

  Future<void> _validateApiKey() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _isApiKeyValid = null;
        _validationError = null;
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _validationError = null;
      _isApiKeyValid = null;
    });

    try {
      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);
      final isValid = await repositoryProvider.weatherRepository.validateApiKey(apiKey);
      
      if (mounted) {
        setState(() {
          _isValidating = false;
          _isApiKeyValid = isValid;
          _validationError = isValid ? null : 'Invalid API key. Please check your OpenWeatherMap API key.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidating = false;
          _isApiKeyValid = false;
          _validationError = 'Failed to validate API key: $e';
        });
      }
    }
  }

  Future<void> _saveConfiguration() async {
    final apiKey = _apiKeyController.text.trim();
    
    final config = WeatherApiConfig(
      apiKey: apiKey,
      units: _selectedUnits,
      language: _selectedLanguage,
      isEnabled: _isEnabled && apiKey.isNotEmpty,
      updatedAt: DateTime.now(),
    );

    try {
      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);
      await repositoryProvider.weatherRepository.updateConfig(config);
      
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Weather configuration saved successfully'),
            backgroundColor: DarkThemeData.accentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save configuration: $e'),
            backgroundColor: DarkThemeData.errorColor,
          ),
        );
      }
    }
  }

  void _openApiKeyHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('OpenWeatherMap API Key', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To use live weather data, you need an API key from OpenWeatherMap:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
              '1. Go to openweathermap.org',
              style: TextStyle(color: Colors.white70),
            ),
            const Text(
              '2. Create a free account',
              style: TextStyle(color: Colors.white70),
            ),
            const Text(
              '3. Navigate to your API keys section',
              style: TextStyle(color: Colors.white70),
            ),
            const Text(
              '4. Copy your API key and paste it here',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DarkThemeData.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DarkThemeData.accentColor.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Note: The free tier includes 1,000 API calls per day, which is sufficient for personal use.',
                style: TextStyle(color: DarkThemeData.accentColor, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        'Weather API Configuration',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // API Key Section
              Text(
                'OpenWeatherMap API Key',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _apiKeyController,
                      decoration: InputDecoration(
                        hintText: 'Enter your API key...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: DarkThemeData.accentColor),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        suffixIcon: _isValidating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: DarkThemeData.accentColor,
                                  ),
                                ),
                              )
                            : _isApiKeyValid != null
                                ? Icon(
                                    _isApiKeyValid! ? Icons.check_circle : Icons.error,
                                    color: _isApiKeyValid! ? Colors.green : DarkThemeData.errorColor,
                                  )
                                : null,
                      ),
                      style: const TextStyle(color: Colors.white),
                      obscureText: true,
                      onChanged: (value) {
                        setState(() {
                          _isApiKeyValid = null;
                          _validationError = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _openApiKeyHelp,
                    icon: const Icon(Icons.help_outline, color: DarkThemeData.accentColor),
                    tooltip: 'Help',
                  ),
                ],
              ),
              
              if (_validationError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _validationError!,
                  style: TextStyle(color: DarkThemeData.errorColor, fontSize: 12),
                ),
              ],
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isValidating ? null : _validateApiKey,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DarkThemeData.accentColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Validate API Key'),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Units Selection
              Text(
                'Temperature Units',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedUnits,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: DarkThemeData.accentColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white),
                items: WeatherService.getAvailableUnits().map((unit) {
                  return DropdownMenuItem<String>(
                    value: unit['value']!,
                    child: Text(unit['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedUnits = value!;
                  });
                },
              ),
              
              const SizedBox(height: 16),
              
              // Language Selection
              Text(
                'Language',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: DarkThemeData.accentColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white),
                items: WeatherService.getAvailableLanguages().map((lang) {
                  return DropdownMenuItem<String>(
                    value: lang['value']!,
                    child: Text(lang['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLanguage = value!;
                  });
                },
              ),
              
              const SizedBox(height: 24),
              
              // Enable/Disable Toggle
              Row(
                children: [
                  Switch(
                    value: _isEnabled,
                    onChanged: (value) {
                      setState(() {
                        _isEnabled = value;
                      });
                    },
                    activeColor: DarkThemeData.accentColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Enable weather API',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              
              if (!_isEnabled) ...[
                const SizedBox(height: 8),
                Text(
                  'Weather will use mock data when API is disabled',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveConfiguration,
          style: ElevatedButton.styleFrom(
            backgroundColor: DarkThemeData.accentColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}