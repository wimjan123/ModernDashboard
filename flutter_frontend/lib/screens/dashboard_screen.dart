import 'package:flutter/material.dart';
import '../widgets/dashboard/dashboard_layout.dart';
import '../core/theme/dark_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<DashboardLayoutState> _dashboardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Modern Dashboard'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.background.withOpacity(0.9),
                Theme.of(context).colorScheme.surface.withOpacity(0.8),
              ],
            ),
          ),
        ),
        actions: [
          StreamBuilder<bool>(
            stream: _dashboardKey.currentState?.refreshStream ?? Stream.value(false),
            builder: (context, snapshot) {
              final isRefreshing = snapshot.data ?? false;
              return IconButton(
                icon: isRefreshing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                tooltip: isRefreshing ? 'Refreshing...' : 'Refresh Data',
                onPressed: isRefreshing ? null : () {
                  _dashboardKey.currentState?.refreshData();
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () {
              // TODO: Implement settings
            },
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
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.bottomRight,
              radius: 1.2,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.03),
                Colors.transparent,
              ],
            ),
          ),
          child: SafeArea(
            child: DashboardLayout(key: _dashboardKey),
          ),
        ),
      ),
    );
  }
}
