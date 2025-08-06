import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../news_widget/news_widget.dart';
import '../weather_widget/weather_widget.dart';
import '../todo_widget/todo_widget.dart';
import '../mail_widget/mail_widget.dart';
import '../common/glass_card.dart';
import '../../services/cpp_bridge.dart';
import '../../core/theme/dark_theme.dart';

// Conditional import for FFI (web uses stub)
import '../../services/ffi_bridge.dart' if (dart.library.html) '../../services/ffi_bridge_web.dart';

class WidgetConfig {
  final String id;
  final String title;
  final IconData icon;
  final Color accentColor;
  
  const WidgetConfig({
    required this.id,
    required this.title, 
    required this.icon,
    required this.accentColor,
  });
}

class DashboardLayout extends StatefulWidget {
  const DashboardLayout({super.key});

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

// Make the state class accessible for refresh functionality
typedef DashboardLayoutState = _DashboardLayoutState;

class _DashboardLayoutState extends State<DashboardLayout> 
    with TickerProviderStateMixin {
  final List<WidgetConfig> _widgets = const [
    WidgetConfig(
      id: 'news', 
      title: 'Latest News', 
      icon: Icons.article_rounded,
      accentColor: DarkThemeData.accentColor,
    ),
    WidgetConfig(
      id: 'weather', 
      title: 'Weather', 
      icon: Icons.wb_sunny_rounded,
      accentColor: DarkThemeData.warningColor,
    ),
    WidgetConfig(
      id: 'todo', 
      title: 'Tasks', 
      icon: Icons.checklist_rounded,
      accentColor: DarkThemeData.successColor,
    ),
    WidgetConfig(
      id: 'mail', 
      title: 'Messages', 
      icon: Icons.mail_rounded,
      accentColor: Color(0xFF8B5CF6),
    ),
  ];
  
  Timer? _updateTimer;
  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;
  bool _isInitialized = false;
  bool _isRefreshing = false;
  
  final StreamController<bool> _refreshController = StreamController<bool>.broadcast();
  Stream<bool> get refreshStream => _refreshController.stream;

  @override
  void initState() {
    super.initState();
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _initializeBackend();
    _startPeriodicUpdates();
    
    // Start slide animation
    _slideAnimationController.forward();
  }

  void _initializeBackend() async {
    try {
      bool success = false;
      
      if (kIsWeb) {
        // On web, use FFI stub which now has rich data
        success = FfiBridge.initializeEngine();
        debugPrint('Web platform initialized with FFI stub: $success');
      } else {
        // On native platforms, try FFI first, fallback to CppBridge
        try {
          success = FfiBridge.initializeEngine();
          if (success && FfiBridge.isSupported) {
            debugPrint('Native FFI Bridge initialized: $success');
          } else {
            success = CppBridge.initializeEngine();
            debugPrint('Using CppBridge fallback: $success');
          }
        } catch (e) {
          debugPrint('FFI Bridge failed: $e, using CppBridge fallback');
          success = CppBridge.initializeEngine();
        }
      }
      
      setState(() {
        _isInitialized = success;
      });
    } catch (e) {
      debugPrint('Failed to initialize backend: $e');
      setState(() {
        _isInitialized = false;
      });
    }
  }

  void _startPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) refreshData();
    });
  }

  Future<void> refreshData() async {
    if (!mounted) return;
    
    setState(() {
      _isRefreshing = true;
    });
    _refreshController.add(true);

    // Add a small delay to show the refresh animation
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Re-initialize backend to refresh data
    _initializeBackend();
    
    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
      _refreshController.add(false);
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _slideAnimationController.dispose();
    _refreshController.close();
    try {
      if (kIsWeb) {
        FfiBridge.shutdownEngine();
      } else {
        try {
          if (FfiBridge.isSupported) {
            FfiBridge.shutdownEngine();
          } else {
            CppBridge.shutdownEngine();
          }
        } catch (_) {
          CppBridge.shutdownEngine();
        }
      }
    } catch (e) {
      debugPrint('Failed to shutdown backend: $e');
    }
    super.dispose();
  }

  Widget _buildWidget(WidgetConfig cfg, int index) {
    Widget content;
    switch (cfg.id) {
      case 'news':
        content = const NewsWidget();
        break;
      case 'weather':
        content = const WeatherWidget();
        break;
      case 'todo':
        content = const TodoWidget();
        break;
      case 'mail':
        content = const MailWidget();
        break;
      default:
        content = GlassInfoCard(
          title: 'Unknown Widget',
          icon: Icon(Icons.error_outline_rounded, color: DarkThemeData.errorColor),
          accentColor: DarkThemeData.errorColor,
          child: Center(
            child: Text(
              'Widget ${cfg.id} not found',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        );
    }

    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 300 + (index * 100)),
        opacity: _isInitialized ? 1.0 : 0.7,
        child: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status indicator
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isInitialized 
                      ? DarkThemeData.successColor 
                      : DarkThemeData.errorColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _isInitialized ? 'Dashboard Online' : 'Connecting...',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _isInitialized 
                      ? DarkThemeData.successColor 
                      : DarkThemeData.errorColor,
                ),
              ),
              const Spacer(),
              Text(
                'Last updated: ${DateTime.now().toString().substring(11, 19)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Widget grid
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Enhanced responsive layout
                int crossAxisCount = 2;
                double childAspectRatio = 1.1;
                
                if (constraints.maxWidth > 1400) {
                  crossAxisCount = 4;
                  childAspectRatio = 1.2;
                } else if (constraints.maxWidth > 1000) {
                  crossAxisCount = 3;
                  childAspectRatio = 1.15;
                } else if (constraints.maxWidth < 600) {
                  crossAxisCount = 1;
                  childAspectRatio = 0.8;
                }

                return GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childAspectRatio,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: _widgets.length,
                  itemBuilder: (context, index) => _buildWidget(_widgets[index], index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
