import 'package:flutter/material.dart';
import '../core/theme/dark_theme.dart';
import '../widgets/common/glass_card.dart';
import '../firebase/firebase_service.dart';
import '../firebase/settings_service.dart';
import '../firebase/migration_service.dart';
import 'migration_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _refreshInterval = 30;
  bool _enableNews = true;
  bool _enableWeather = true;
  bool _enableTodos = true;
  bool _enableMail = true;
  String _themeMode = 'dark';
  bool _notificationsEnabled = true;
  String _weatherUnits = 'celsius';
  
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _userInfo;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final settings = await SettingsService.instance.loadSettings();
      final userInfo = await SettingsService.instance.getUserInfo();
      
      setState(() {
        _refreshInterval = settings['refresh_interval'] ?? 30;
        _enableNews = settings['enable_news'] ?? true;
        _enableWeather = settings['enable_weather'] ?? true;
        _enableTodos = settings['enable_todos'] ?? true;
        _enableMail = settings['enable_mail'] ?? true;
        _themeMode = settings['theme_mode'] ?? 'dark';
        _notificationsEnabled = settings['notifications_enabled'] ?? true;
        _weatherUnits = settings['weather_units'] ?? 'celsius';
        _userInfo = userInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load settings: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      final settings = {
        'refresh_interval': _refreshInterval,
        'enable_news': _enableNews,
        'enable_weather': _enableWeather,
        'enable_todos': _enableTodos,
        'enable_mail': _enableMail,
        'theme_mode': _themeMode,
        'notifications_enabled': _notificationsEnabled,
        'weather_units': _weatherUnits,
      };
      
      await SettingsService.instance.saveSettings(settings);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings synced to Firebase'),
            backgroundColor: DarkThemeData.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: DarkThemeData.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Dashboard Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded),
            tooltip: 'Save Settings',
            onPressed: _saveSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [
              DarkThemeData.accentColor.withValues(alpha: 0.05),
              Theme.of(context).colorScheme.background,
              Theme.of(context).colorScheme.background,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      
                      // Error display
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: DarkThemeData.errorColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: DarkThemeData.errorColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: DarkThemeData.errorColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: DarkThemeData.errorColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Firebase Account Info
                      if (_userInfo != null)
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.account_circle_rounded,
                                    color: DarkThemeData.accentColor,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Firebase Account',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow('User ID', _userInfo!['user_id'] ?? 'Unknown'),
                              _buildInfoRow('Account Type', _userInfo!['is_anonymous'] == true ? 'Anonymous' : 'Authenticated'),
                              if (_userInfo!['signed_in_at'] != null)
                                _buildInfoRow('Created', DateTime.parse(_userInfo!['signed_in_at']).toString().substring(0, 16)),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: DarkThemeData.successColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.sync_rounded,
                                      color: DarkThemeData.successColor,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Settings sync across devices enabled',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: DarkThemeData.successColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 20),
                      
                      // Refresh Settings
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.refresh_rounded,
                                  color: DarkThemeData.warningColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Refresh Settings',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Auto-refresh interval: ${_refreshInterval}s',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Slider(
                              value: _refreshInterval.toDouble(),
                              min: 10,
                              max: 300,
                              divisions: 29,
                              label: '${_refreshInterval}s',
                              onChanged: (value) {
                                setState(() {
                                  _refreshInterval = value.round();
                                });
                              },
                              activeColor: DarkThemeData.warningColor,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Widget Settings
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.dashboard_rounded,
                                  color: DarkThemeData.successColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Enabled Widgets',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('📰 News Widget'),
                              subtitle: const Text('Show latest news articles'),
                              value: _enableNews,
                              onChanged: (value) {
                                setState(() {
                                  _enableNews = value;
                                });
                              },
                              activeColor: DarkThemeData.accentColor,
                            ),
                            SwitchListTile(
                              title: const Text('🌤️ Weather Widget'),
                              subtitle: const Text('Display weather information'),
                              value: _enableWeather,
                              onChanged: (value) {
                                setState(() {
                                  _enableWeather = value;
                                });
                              },
                              activeColor: DarkThemeData.warningColor,
                            ),
                            SwitchListTile(
                              title: const Text('✅ Todo Widget'),
                              subtitle: const Text('Manage tasks and reminders'),
                              value: _enableTodos,
                              onChanged: (value) {
                                setState(() {
                                  _enableTodos = value;
                                });
                              },
                              activeColor: DarkThemeData.successColor,
                            ),
                            SwitchListTile(
                              title: const Text('📧 Mail Widget'),
                              subtitle: const Text('Show email notifications'),
                              value: _enableMail,
                              onChanged: (value) {
                                setState(() {
                                  _enableMail = value;
                                });
                              },
                              activeColor: const Color(0xFF8B5CF6),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Additional Settings
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  color: DarkThemeData.accentColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Additional Settings',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('🔔 Notifications'),
                              subtitle: const Text('Enable push notifications'),
                              value: _notificationsEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _notificationsEnabled = value;
                                });
                              },
                              activeColor: DarkThemeData.accentColor,
                            ),
                            ListTile(
                              title: const Text('🌡️ Weather Units'),
                              subtitle: Text('Temperature: ${_weatherUnits == 'celsius' ? 'Celsius' : 'Fahrenheit'}'),
                              trailing: DropdownButton<String>(
                                value: _weatherUnits,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _weatherUnits = value;
                                    });
                                  }
                                },
                                items: const [
                                  DropdownMenuItem(
                                    value: 'celsius',
                                    child: Text('°C'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'fahrenheit',
                                    child: Text('°F'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // System Information
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: DarkThemeData.warningColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'System Information',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Version: 1.1.0 (Firebase)\nPlatform: Flutter with Firebase\nData Source: Cloud Firestore\nSync Status: ${FirebaseService.instance.isInitialized ? "Connected" : "Offline"}\nRefresh: ${_refreshInterval}s intervals',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Settings Management
                      const SizedBox(height: 20),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.settings_backup_restore_rounded,
                                  color: DarkThemeData.errorColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Settings Management',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Reset Settings'),
                                          content: const Text('This will reset all settings to defaults. Are you sure?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Reset'),
                                            ),
                                          ],
                                        ),
                                      );
                                      
                                      if (confirmed == true) {
                                        try {
                                          await SettingsService.instance.resetToDefaults();
                                          _loadSettings();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Settings reset to defaults'),
                                              backgroundColor: DarkThemeData.successColor,
                                            ),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Failed to reset: $e'),
                                              backgroundColor: DarkThemeData.errorColor,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.restore_rounded),
                                    label: const Text('Reset to Defaults'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      // Check if migration is available
                                      final needsMigration = await MigrationService.instance.isMigrationNeeded();
                                      
                                      if (needsMigration) {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => const MigrationScreen(),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('No migration data found or migration already completed'),
                                            backgroundColor: DarkThemeData.warningColor,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.cloud_sync_rounded),
                                    label: const Text('Migrate Data'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}