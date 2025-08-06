import 'dart:async';
import 'package:flutter/material.dart';
import '../news_widget/news_widget.dart';
import '../weather_widget/weather_widget.dart';
import '../todo_widget/todo_widget.dart';
import '../mail_widget/mail_widget.dart';
import '../../services/cpp_bridge.dart';

class WidgetConfig {
  final String id;
  const WidgetConfig(this.id);
}

class DashboardLayout extends StatefulWidget {
  const DashboardLayout({super.key});

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  final List<WidgetConfig> _widgets = const [
    WidgetConfig('news'),
    WidgetConfig('weather'), 
    WidgetConfig('todo'),
    WidgetConfig('mail'),
  ];
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _initializeBackend();
    _startPeriodicUpdates();
  }

  void _initializeBackend() {
    try {
      CppBridge.initializeEngine();
    } catch (e) {
      debugPrint('Failed to initialize backend: $e');
    }
  }

  void _startPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    try {
      CppBridge.shutdownEngine();
    } catch (e) {
      debugPrint('Failed to shutdown backend: $e');
    }
    super.dispose();
  }

  Widget _buildWidget(WidgetConfig cfg) {
    switch (cfg.id) {
      case 'news':
        return const NewsWidget();
      case 'weather':
        return const WeatherWidget();
      case 'todo':
        return const TodoWidget();
      case 'mail':
        return const MailWidget();
      default:
        return Card(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                Text('Unknown widget: ${cfg.id}', 
                     style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive grid layout
            int crossAxisCount = 2;
            if (constraints.maxWidth > 1200) {
              crossAxisCount = 4;
            } else if (constraints.maxWidth > 800) {
              crossAxisCount = 3;
            }

            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 1.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _widgets.length,
              itemBuilder: (context, index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: _buildWidget(_widgets[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}
