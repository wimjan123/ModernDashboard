import 'package:flutter/material.dart';
import '../widgets/dashboard/dashboard_layout.dart';
import '../core/theme/dark_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Data',
            onPressed: () {
              // TODO: Implement refresh functionality
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
          child: const SafeArea(
            child: DashboardLayout(),
          ),
        ),
      ),
    );
  }
}
