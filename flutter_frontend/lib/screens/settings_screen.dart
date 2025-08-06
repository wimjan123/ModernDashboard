import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/dark_theme.dart';
import '../widgets/common/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _refreshInterval = 30; // seconds
  bool _enableNews = true;
  bool _enableWeather = true;
  bool _enableTodos = true;
  bool _enableMail = true;
  bool _useMockData = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _refreshInterval = prefs.getInt('refresh_interval') ?? 30;
      _enableNews = prefs.getBool('enable_news') ?? true;
      _enableWeather = prefs.getBool('enable_weather') ?? true;
      _enableTodos = prefs.getBool('enable_todos') ?? true;
      _enableMail = prefs.getBool('enable_mail') ?? true;
      _useMockData = prefs.getBool('use_mock_data') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('refresh_interval', _refreshInterval);
    await prefs.setBool('enable_news', _enableNews);
    await prefs.setBool('enable_weather', _enableWeather);
    await prefs.setBool('enable_todos', _enableTodos);
    await prefs.setBool('enable_mail', _enableMail);
    await prefs.setBool('use_mock_data', _useMockData);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Settings saved successfully'),
          backgroundColor: DarkThemeData.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
              DarkThemeData.accentColor.withOpacity(0.05),
              Theme.of(context).colorScheme.background,
              Theme.of(context).colorScheme.background,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Data Source Settings
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.storage_rounded,
                            color: DarkThemeData.accentColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Data Source',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Use Mock Data'),
                        subtitle: const Text('Enable for testing without C++ backend'),
                        value: _useMockData,
                        onChanged: (value) {
                          setState(() {
                            _useMockData = value;
                          });
                        },
                        activeColor: DarkThemeData.accentColor,
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
                
                // Debug Info
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: DarkThemeData.infoColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Debug Information',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Version: 1.0.1+2\nPlatform: Native FFI\nData Source: ${_useMockData ? 'Mock Service' : 'C++ Backend'}\nRefresh: ${_refreshInterval}s intervals',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
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