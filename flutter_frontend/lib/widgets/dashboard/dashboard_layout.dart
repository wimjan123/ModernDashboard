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

// PERFORMANCE OPTIMIZATIONS:
// 1. RepaintBoundary widgets isolate expensive repaints during scrolling
// 2. Periodic refresh timer is paused during active scrolling to prevent interference
// 3. Dynamic cache extent based on screen height for optimal memory usage
// 4. Scroll notification listeners contain only lightweight operations
// 5. Debounced scroll end detection prevents rapid pause/resume cycles
// WARNING: Do not add heavy operations to scroll notification listeners!

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
  bool _isScrolling = false;
  DateTime _lastScrollTime = DateTime.now();
  
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
    // Increased refresh interval from 30 seconds to 2 minutes to reduce interference
    _updateTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted && !_isScrolling && !_isRefreshing) {
        // Only refresh if not currently scrolling and enough time has passed
        final timeSinceLastScroll = DateTime.now().difference(_lastScrollTime);
        if (timeSinceLastScroll.inSeconds > 5) {
          refreshData();
        }
      }
    });
  }

  void _pausePeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  void _resumePeriodicUpdates() {
    if (_updateTimer == null) {
      _startPeriodicUpdates();
    }
  }

  Timer? _debounceTimer;
  Timer? _scrollEndTimer;
  
  Future<void> refreshData() async {
    if (!mounted || _isRefreshing || _isScrolling) return;
    
    // Cancel previous debounce timer if it exists
    _debounceTimer?.cancel();
    
    // Debounce refresh calls to prevent rapid successive refreshes
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || _isRefreshing || _isScrolling) return;
      
      setState(() {
        _isRefreshing = true;
      });
      _refreshController.add(true);

      try {
        // Reduced delay to minimize UI blocking
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Re-initialize backend to refresh data
        _initializeBackend();
        
        if (mounted) {
          setState(() {
            _isRefreshing = false;
          });
          _refreshController.add(false);
        }
      } catch (e) {
        // Handle refresh errors gracefully
        debugPrint('Refresh error: $e');
        if (mounted) {
          setState(() {
            _isRefreshing = false;
          });
          _refreshController.add(false);
        }
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _debounceTimer?.cancel();
    _scrollEndTimer?.cancel();
    _slideAnimationController.dispose();
    _refreshController.close();
    // No need to shutdown Firebase services as they are managed globally
    debugPrint('Dashboard layout disposed');
    super.dispose();
  }

  void _onScrollStart() {
    _isScrolling = true;
    _lastScrollTime = DateTime.now();
    // Pause periodic updates during scrolling
    _pausePeriodicUpdates();
    // Cancel any pending scroll end timer to debounce rapid scroll gestures
    _scrollEndTimer?.cancel();
  }
  
  void _onScrollEnd() {
    _lastScrollTime = DateTime.now();
    // Debounce scroll end to avoid rapid pause/resume cycles
    _scrollEndTimer?.cancel();
    _scrollEndTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        _isScrolling = false;
        // Resume periodic updates after a delay to avoid immediate refresh
        _resumePeriodicUpdates();
      }
    });
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

    // Optimized widget wrapping with reduced animation complexity
    return RepaintBoundary(
      key: ValueKey('widget_${cfg.id}_$index'),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200), // Reduced animation duration
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
          // Header with status indicator wrapped in RepaintBoundary for performance
          RepaintBoundary(
            key: const ValueKey('header_boundary'),
            child: Row(
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
                    // Wrap entire scroll listener in RepaintBoundary for maximum performance isolation
                    RepaintBoundary(
                      key: const ValueKey('scroll_listener_boundary'),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          // Lightweight scroll detection - only boolean assignments, no heavy operations
                          if (notification is ScrollStartNotification) {
                            _onScrollStart();
                          } else if (notification is ScrollEndNotification) {
                            _onScrollEnd();
                          }
                          return false; // Allow notification to bubble up
                        },
                        child: GridView.builder(
                          // Optimized scroll physics for better mobile performance
                          physics: const ClampingScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: childAspectRatio,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                          itemCount: _widgets.length,
                          itemBuilder: (context, index) => _buildWidget(_widgets[index], index),
                          // Dynamic cache extent based on screen height for optimal performance
                          cacheExtent: constraints.maxHeight * 1.5,
                          // Optimize memory usage for off-screen widgets
                          addAutomaticKeepAlives: false,
                          // Explicit repaint boundaries for grid items (should be true by default)
                          addRepaintBoundaries: true,
                        ),
                      ),
                    ),
                    // Refresh indicator overlay wrapped in RepaintBoundary
                    if (_isRefreshing)
                      RepaintBoundary(
                        key: const ValueKey('refresh_overlay_boundary'),
                        child: Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
