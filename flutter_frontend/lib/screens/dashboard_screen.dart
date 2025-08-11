import 'package:flutter/material.dart';
import '../widgets/dashboard/dashboard_layout.dart';
import '../widgets/common/account_menu.dart';
import '../core/theme/dark_theme.dart';
import 'settings_screen.dart';

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
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
              ],
            ),
          ),
        ),
        actions: [
          StreamBuilder<bool>(
            stream: _dashboardKey.currentState?.refreshStream ?? Stream.value(false),
            builder: (context, snapshot) {
              final isRefreshing = snapshot.data ?? false;
              return RepaintBoundary(
                key: const ValueKey('refresh_button'),
                child: IconButton(
                  icon: isRefreshing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: RepaintBoundary(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  tooltip: isRefreshing ? 'Refreshing...' : 'Refresh Data',
                  onPressed: isRefreshing ? null : () {
                    _dashboardKey.currentState?.refreshData();
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_rounded),
            tooltip: 'Account',
            onPressed: () {
              _showAccountMenu(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
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
              DarkThemeData.accentColor.withValues(alpha: 0.05),
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface,
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
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.03),
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

  /// Show account management menu in a modal bottom sheet
  void _showAccountMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Account menu content
                  const AccountMenu(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
