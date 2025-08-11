import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/dark_theme.dart';
import '../../core/services/error_reporting_service.dart';
import '../../repositories/repository_provider.dart';
import '../../firebase/firebase_service.dart';

class DebugInfoPanel extends StatefulWidget {
  final VoidCallback? onClose;
  
  const DebugInfoPanel({super.key, this.onClose});

  @override
  State<DebugInfoPanel> createState() => _DebugInfoPanelState();
}

class _DebugInfoPanelState extends State<DebugInfoPanel> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink(); // Only show in debug mode
    }

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: DarkThemeData.cardColor,
      child: Container(
        width: _isExpanded ? 600 : 400,
        height: _isExpanded ? 500 : 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            if (_isExpanded) _buildExpandedContent() else _buildCompactContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.bug_report,
          color: DarkThemeData.accentColor,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          'Debug Info',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: DarkThemeData.accentColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          icon: Icon(_isExpanded ? Icons.compress : Icons.expand),
          color: DarkThemeData.textSecondary,
          iconSize: 18,
        ),
        IconButton(
          onPressed: widget.onClose,
          icon: const Icon(Icons.close),
          color: DarkThemeData.textSecondary,
          iconSize: 18,
        ),
      ],
    );
  }

  Widget _buildCompactContent() {
    final repositoryProvider = RepositoryProvider.instance;
    final errorSummary = ErrorReportingService.instance.getErrorSummary();

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusRow('Online Mode', !repositoryProvider.offlineModeActive),
          _buildStatusRow('Firebase Init', FirebaseService.instance.isInitialized),
          _buildStatusRow('Repositories', repositoryProvider.isInitialized),
          _buildStatusRow('Auth Required', repositoryProvider.requiresAuthentication),
          const SizedBox(height: 12),
          Text(
            'Errors (24h): ${errorSummary['total_errors_24h']}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DarkThemeData.errorColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: _toggleOfflineMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: repositoryProvider.offlineModeActive
                      ? DarkThemeData.successColor
                      : DarkThemeData.warningColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: Text(
                  repositoryProvider.offlineModeActive ? 'Go Online' : 'Go Offline',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _clearErrors,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DarkThemeData.errorColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: Text(
                  'Clear Errors',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Expanded(
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'System'),
              Tab(text: 'Errors'),
              Tab(text: 'Repos'),
              Tab(text: 'Actions'),
            ],
            labelColor: DarkThemeData.accentColor,
            unselectedLabelColor: DarkThemeData.textMuted,
            indicatorColor: DarkThemeData.accentColor,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSystemTab(),
                _buildErrorsTab(),
                _buildRepositoriesTab(),
                _buildActionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemTab() {
    final repositoryProvider = RepositoryProvider.instance;
    final firebaseService = FirebaseService.instance;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoGroup('Platform', [
            'Type: ${kIsWeb ? 'Web' : defaultTargetPlatform.name}',
            'Debug Mode: $kDebugMode',
            'Profile Mode: $kProfileMode',
            'Release Mode: $kReleaseMode',
          ]),
          _buildInfoGroup('Firebase', [
            'Initialized: ${firebaseService.isInitialized}',
            'Authenticated: ${firebaseService.isAuthenticated()}',
            'Anonymous Auth: ${firebaseService.isAnonymousAuthEnabled}',
            'Offline Mode: ${firebaseService.isOfflineMode}',
          ]),
          _buildInfoGroup('Repository Provider', [
            'Initialized: ${repositoryProvider.isInitialized}',
            'Offline Mode: ${repositoryProvider.offlineModeActive}',
            'Auth Required: ${repositoryProvider.requiresAuthentication}',
            'Using Firebase: ${repositoryProvider.isUsingFirebase}',
            'Using Mocks: ${repositoryProvider.isUsingMockRepositories}',
          ]),
        ],
      ),
    );
  }

  Widget _buildErrorsTab() {
    final errorService = ErrorReportingService.instance;
    final errorSummary = errorService.getErrorSummary();
    final recentErrors = errorService.getRecentErrors();
    final errorTracking = RepositoryProvider.instance.getErrorTrackingInfo();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoGroup('Error Summary', [
            'Total (24h): ${errorSummary['total_errors_24h']}',
            'Most Common: ${errorSummary['most_common_error'] ?? 'None'}',
          ]),
          _buildInfoGroup('Error Tracking', [
            'Consecutive: ${errorTracking['consecutive_errors']}',
            'Max Threshold: ${errorTracking['max_consecutive_errors']}',
            'Last Error: ${errorTracking['last_error_time'] ?? 'None'}',
            'Auto Offline: ${errorTracking['auto_offline_enabled']}',
          ]),
          if (recentErrors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Recent Errors:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: DarkThemeData.errorColor,
              ),
            ),
            const SizedBox(height: 8),
            ...recentErrors.take(5).map((error) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DarkThemeData.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${error.type}: ${error.error.toString().length > 50 ? error.error.toString().substring(0, 50) + '...' : error.error}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildRepositoriesTab() {
    final repositoryInfo = RepositoryProvider.instance.getRepositoryInfo();
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoGroup('Repository Types', [
            'Todo: ${repositoryInfo['todo']}',
            'Weather: ${repositoryInfo['weather']}',
            'News: ${repositoryInfo['news']}',
          ]),
          _buildInfoGroup('Configuration', [
            'Cloud Functions: ${repositoryInfo['cloud_functions']}',
            'Offline Enabled: ${repositoryInfo['offline_mode_enabled']}',
            'Current Mode: ${repositoryInfo['repository_type']}',
          ]),
          _buildInfoGroup('Health Check', [
            'Click "Run Health Check" to test repository connectivity',
          ]),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _runHealthCheck,
            style: ElevatedButton.styleFrom(
              backgroundColor: DarkThemeData.accentColor,
            ),
            child: const Text('Run Health Check'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionButton(
            'Toggle Offline Mode',
            _toggleOfflineMode,
            DarkThemeData.warningColor,
          ),
          _buildActionButton(
            'Clear Error Logs',
            _clearErrors,
            DarkThemeData.errorColor,
          ),
          _buildActionButton(
            'Export Debug Info',
            _exportDebugInfo,
            DarkThemeData.accentColor,
          ),
          _buildActionButton(
            'Test Firebase Connection',
            _testFirebaseConnection,
            DarkThemeData.successColor,
          ),
          _buildActionButton(
            'Simulate Error',
            _simulateError,
            Colors.purple,
          ),
          const SizedBox(height: 16),
          Text(
            'Debug Actions',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: DarkThemeData.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These actions are only available in debug mode and help test error handling and recovery mechanisms.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DarkThemeData.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            color: status ? DarkThemeData.successColor : DarkThemeData.errorColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGroup(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: DarkThemeData.accentColor,
          ),
        ),
        const SizedBox(height: 4),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 2),
          child: Text(
            item,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        )),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _toggleOfflineMode() async {
    final repositoryProvider = RepositoryProvider.instance;
    try {
      if (repositoryProvider.offlineModeActive) {
        await repositoryProvider.switchToOnlineMode();
      } else {
        await repositoryProvider.switchToOfflineMode();
      }
      setState(() {}); // Refresh UI
    } catch (e) {
      _showSnackBar('Failed to toggle mode: $e', isError: true);
    }
  }

  void _clearErrors() {
    ErrorReportingService.instance.clearErrors();
    _showSnackBar('Error logs cleared');
    setState(() {}); // Refresh UI
  }

  void _exportDebugInfo() async {
    final info = _generateDebugInfo();
    await Clipboard.setData(ClipboardData(text: info));
    _showSnackBar('Debug info copied to clipboard');
  }

  void _testFirebaseConnection() async {
    try {
      final isInitialized = FirebaseService.instance.isInitialized;
      final isAuth = FirebaseService.instance.isAuthenticated();
      
      if (isInitialized) {
        _showSnackBar('Firebase connection: OK (Auth: $isAuth)');
      } else {
        _showSnackBar('Firebase connection: Failed - Not initialized', isError: true);
      }
    } catch (e) {
      _showSnackBar('Firebase test failed: $e', isError: true);
    }
  }

  void _simulateError() {
    // Simulate a JavaScript interop error for testing
    final simulatedError = kIsWeb 
        ? "TypeError: '_TypeError' is not a subtype of type 'JavaScriptObject'"
        : "Simulated repository error for testing";
    
    ErrorReportingService.instance.reportError(
      'simulated_error',
      simulatedError,
      StackTrace.current,
      context: {'source': 'debug_panel'},
      severity: ErrorSeverity.medium,
    );
    
    _showSnackBar('Simulated error reported');
    setState(() {}); // Refresh UI
  }

  void _runHealthCheck() async {
    try {
      final health = await RepositoryProvider.instance.checkHealth();
      final healthyCount = health.values.where((v) => v == true).length;
      final totalCount = health.length;
      
      _showSnackBar('Health Check: $healthyCount/$totalCount systems healthy');
    } catch (e) {
      _showSnackBar('Health check failed: $e', isError: true);
    }
  }

  String _generateDebugInfo() {
    final buffer = StringBuffer();
    buffer.writeln('=== Debug Information ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Platform: ${kIsWeb ? 'Web' : defaultTargetPlatform.name}');
    buffer.writeln();
    
    // System info
    buffer.writeln('--- System ---');
    final repositoryProvider = RepositoryProvider.instance;
    final repositoryInfo = repositoryProvider.getRepositoryInfo();
    repositoryInfo.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    buffer.writeln();
    
    // Error summary
    buffer.writeln('--- Errors ---');
    final errorSummary = ErrorReportingService.instance.getErrorSummary();
    errorSummary.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    buffer.writeln();
    
    // Error tracking
    buffer.writeln('--- Error Tracking ---');
    final errorTracking = repositoryProvider.getErrorTrackingInfo();
    errorTracking.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    
    return buffer.toString();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? DarkThemeData.errorColor : DarkThemeData.successColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}