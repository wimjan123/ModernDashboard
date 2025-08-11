import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../news_widget/enhanced_news_widget.dart';
import '../weather_widget/weather_widget.dart';
import '../todo_widget/todo_widget.dart';
import '../mail_widget/mail_widget.dart';
import '../stream_widget/video_stream_widget.dart';
import '../common/glass_card.dart';
import '../../core/theme/dark_theme.dart';
import '../../firebase/firebase_service.dart';
import '../../repositories/repository_provider.dart';

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
      id: 'video', 
      title: 'Live Streams', 
      icon: Icons.play_circle_rounded,
      accentColor: Color(0xFFE91E63),
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
      // Check if Firebase and repositories are initialized
      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);
      final firebaseService = FirebaseService.instance;
      
      final success = firebaseService.isInitialized && 
                     repositoryProvider.isInitialized &&
                     firebaseService.isAuthenticated();
      
      setState(() {
        _isInitialized = success;
      });
      
      if (success) {
        debugPrint('Firebase backend initialized successfully');
      } else {
        debugPrint('Firebase backend not fully initialized');
      }
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
    // No need to shutdown Firebase services as they are managed globally
    debugPrint('Dashboard layout disposed');
    super.dispose();
  }

  Widget _buildWidget(WidgetConfig cfg, int index) {
    Widget content;
    switch (cfg.id) {
      case 'news':
        content = const EnhancedNewsWidget();
        break;
      case 'weather':
        content = const WeatherWidget();
        break;
      case 'todo':
        content = const TodoWidget();
        break;
      case 'video':
        content = const VideoStreamWidget();
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

    // Wrap each widget with RepaintBoundary to prevent unnecessary repaints
    return RepaintBoundary(
      key: ValueKey('widget_${cfg.id}_$index'),
      child: SlideTransition(
        position: _slideAnimation,
        child: AnimatedOpacity(
          duration: Duration(milliseconds: 300 + (index * 100)),
          opacity: _isInitialized ? 1.0 : 0.7,
          child: content,
        ),
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
                // Enhanced responsive layout with refresh indicator
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

                return Stack(
                  children: [
                    // Wrap GridView in RepaintBoundary for performance
                    RepaintBoundary(
                      key: const ValueKey('dashboard_grid'),
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        itemCount: _widgets.length,
                        itemBuilder: (context, index) => _buildWidget(_widgets[index], index),
                      ),
                    ),
                    // Isolate refresh indicator to prevent full screen repaints
                    if (_isRefreshing)
                      RepaintBoundary(
                        key: const ValueKey('refresh_overlay'),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.1),
                          child: const Center(
                            child: RepaintBoundary(
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
