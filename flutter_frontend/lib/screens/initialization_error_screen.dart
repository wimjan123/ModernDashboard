import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/dark_theme.dart';
import '../core/exceptions/initialization_exception.dart';
import '../core/models/initialization_status.dart';
import '../firebase/firebase_service.dart';
import '../repositories/repository_provider.dart';
import '../screens/dashboard_screen.dart';
import '../widgets/common/app_logo.dart';

class InitializationErrorScreen extends StatefulWidget {
  final InitializationException? error;
  final bool configValidationFailed;
  final bool offlineModeActive;
  final VoidCallback? onRetry;
  final VoidCallback? onSkipToOffline;
  
  const InitializationErrorScreen({
    super.key, 
    this.error,
    this.configValidationFailed = false,
    this.offlineModeActive = false,
    this.onRetry,
    this.onSkipToOffline,
  });
  
  @override
  State<InitializationErrorScreen> createState() => _InitializationErrorScreenState();
}

class _InitializationErrorScreenState extends State<InitializationErrorScreen> {
  bool _isRetrying = false;
  bool _isSwitchingToOffline = false;
  StreamSubscription<InitializationStatus>? _statusSubscription;

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
  
  void _handleRetry() async {
    if (_isRetrying) return;
    
    setState(() => _isRetrying = true);
    
    try {
      // Listen to retry progress
      _statusSubscription = FirebaseService.instance.initializationStatusStream.listen(
        (status) {
          if (status.phase == InitializationPhase.success) {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
            }
          } else if (status.phase == InitializationPhase.error) {
            setState(() => _isRetrying = false);
          }
        },
      );
      
      // Execute custom retry callback or default retry
      if (widget.onRetry != null) {
        widget.onRetry!();
      } else {
        await FirebaseService.instance.retryInitialization();
        await RepositoryProvider.instance.initialize();
      }
      
    } catch (e) {
      if (mounted) {
        setState(() => _isRetrying = false);
        _showSnackBar('Retry failed: ${e.toString()}', Colors.red);
      }
    }
  }
  
  void _handleSkipToOffline() async {
    if (_isSwitchingToOffline) return;
    
    setState(() => _isSwitchingToOffline = true);
    
    try {
      // Execute custom offline callback or default behavior
      if (widget.onSkipToOffline != null) {
        widget.onSkipToOffline!();
      } else {
        await RepositoryProvider.instance.switchToOfflineMode();
      }
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSwitchingToOffline = false);
        _showSnackBar('Failed to switch to offline mode: ${e.toString()}', Colors.red);
      }
    }
  }

  void _copyErrorDetails() {
    final error = widget.error;
    if (error == null) return;
    
    final errorText = StringBuffer();
    errorText.writeln('Error Code: ${error.code}');
    errorText.writeln('Message: ${error.message}');
    if (error.details != null) {
      errorText.writeln('Details: ${error.details}');
    }
    errorText.writeln('Platform: ${defaultTargetPlatform.name}');
    errorText.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
    
    Clipboard.setData(ClipboardData(text: errorText.toString()));
    _showSnackBar('Error details copied to clipboard', DarkThemeData.accentColor);
  }
  
  void _reportIssue() async {
    final error = widget.error;
    if (error == null) return;
    
    final subject = 'Modern Dashboard Initialization Error - ${error.code}';
    final body = StringBuffer();
    body.writeln('Error Code: ${error.code}');
    body.writeln('Message: ${error.message}');
    if (error.details != null) {
      body.writeln('Details: ${error.details}');
    }
    body.writeln('Platform: ${defaultTargetPlatform.name}');
    body.writeln('Configuration Failed: ${widget.configValidationFailed}');
    body.writeln('Offline Mode Active: ${widget.offlineModeActive}');
    body.writeln('\n--- Please describe what you were doing when this error occurred ---');
    
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@moderndashboard.dev',
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body.toString())}',
    );
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnackBar('Could not open email client', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Failed to open email client', Colors.orange);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F0F23), // DarkThemeData._backgroundDark
              Color(0xFF1A1B3A), // DarkThemeData._surfaceDark
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  const AppLogoMedium(enableAnimations: true),
                  
                  const SizedBox(height: 24),
                  
                  // Status Icon
                  Icon(
                    widget.offlineModeActive 
                        ? Icons.cloud_off_rounded 
                        : Icons.error_outline_rounded,
                    color: widget.offlineModeActive 
                        ? DarkThemeData.warningColor 
                        : DarkThemeData.errorColor,
                    size: 48,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    _getTitle(),
                    style: Theme.of(context).textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Description
                  Text(
                    _getDescription(),
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  
                  // Error Details
                  if (widget.error != null) ...[
                    const SizedBox(height: 24),
                    _buildErrorDetails(),
                  ],
                  
                  // Configuration Diagnostics
                  if (widget.configValidationFailed) ...[
                    const SizedBox(height: 24),
                    _buildConfigurationDiagnostics(),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Action Buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getTitle() {
    if (widget.offlineModeActive) {
      return 'Running in Offline Mode';
    } else if (widget.configValidationFailed) {
      return 'Configuration Error';
    } else {
      return 'Initialization Failed';
    }
  }

  String _getDescription() {
    if (widget.offlineModeActive) {
      return 'Limited functionality available.\nTodo, Weather, and News features work offline.\nTry reconnecting when network is available.';
    } else if (widget.configValidationFailed) {
      return 'Please check your Firebase configuration files\nand ensure all values are properly set.';
    } else {
      return 'Unable to initialize the application.\nPlease check your connection and configuration.';
    }
  }

  Widget _buildErrorDetails() {
    final error = widget.error!;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DarkThemeData.errorColor.withValues(alpha: 0.1),
        border: Border.all(
          color: DarkThemeData.errorColor.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bug_report_outlined,
                color: DarkThemeData.errorColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Error Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: DarkThemeData.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Copy button
              IconButton(
                onPressed: _copyErrorDetails,
                icon: const Icon(Icons.copy_outlined, size: 20),
                tooltip: 'Copy error details',
                style: IconButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          _buildErrorField('Code', error.code),
          const SizedBox(height: 8),
          _buildErrorField('Message', error.message),
          
          if (error.details != null) ...[
            const SizedBox(height: 8),
            _buildErrorField('Details', error.details!),
          ],
          
          // Troubleshooting tips
          const SizedBox(height: 16),
          _buildTroubleshootingTip(error.code),
          
          // Action buttons for error details
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reportIssue,
                  icon: const Icon(Icons.email_outlined, size: 16),
                  label: const Text('Report Issue'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DarkThemeData.accentColor,
                    side: BorderSide(
                      color: DarkThemeData.accentColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildTroubleshootingTip(String errorCode) {
    String tip;
    switch (errorCode) {
      case 'no-network':
        tip = '💡 Check your internet connection and try again';
        break;
      case 'operation-not-allowed':
        tip = '💡 Authentication method may not be enabled in Firebase Console';
        break;
      case 'invalid-config':
        tip = '💡 Check firebase_options.dart for placeholder or invalid values';
        break;
      case 'unsupported-platform':
        tip = '💡 Run FlutterFire CLI to configure this platform';
        break;
      default:
        tip = '💡 Try restarting the application or checking your configuration';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DarkThemeData.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: DarkThemeData.warningColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DarkThemeData.warningColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationDiagnostics() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
        border: Border.all(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.settings_outlined,
                color: Color(0xFF4F46E5),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Configuration Diagnostics',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF4F46E5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          _buildDiagnosticItem('Platform', defaultTargetPlatform.name),
          _buildDiagnosticItem('Expected', 'firebase_options.dart with valid configuration values'),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DarkThemeData.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'To fix: Run "flutterfire configure" or check for placeholder values',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DarkThemeData.warningColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (widget.offlineModeActive) {
      return _buildOfflineModeButtons();
    } else if (widget.configValidationFailed) {
      return _buildConfigurationButtons();
    } else {
      return _buildRetryButtons();
    }
  }

  Widget _buildOfflineModeButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const DashboardScreen()),
                );
              }
            },
            icon: const Icon(Icons.offline_bolt_outlined),
            label: const Text('Continue Offline'),
            style: ElevatedButton.styleFrom(
              backgroundColor: DarkThemeData.successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              try {
                await RepositoryProvider.instance.switchToOnlineMode();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  _showSnackBar('Reconnection failed: $e', Colors.orange);
                }
              }
            },
            icon: const Icon(Icons.cloud_queue_outlined),
            label: const Text('Try Reconnect'),
          ),
        ),
      ],
    );
  }

  Widget _buildRetryButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isRetrying ? null : _handleRetry,
            icon: _isRetrying 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh_outlined),
            label: Text(_isRetrying ? 'Retrying...' : 'Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isSwitchingToOffline ? null : _handleSkipToOffline,
            icon: _isSwitchingToOffline
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  )
                : const Icon(Icons.offline_bolt_outlined),
            label: Text(_isSwitchingToOffline ? 'Switching...' : 'Skip to Offline Mode'),
            style: OutlinedButton.styleFrom(
              foregroundColor: DarkThemeData.successColor,
              side: BorderSide(color: DarkThemeData.successColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigurationButtons() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF232447), // DarkThemeData._cardGlass
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(Icons.help_outline, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 8),
                  Text(
                    'Configuration Help',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Text(
                  'To fix Firebase configuration:\n\n'
                  '1. Run: flutterfire configure\n'
                  '2. Select your Firebase project\n'
                  '3. Choose platforms to support\n'
                  '4. Restart the application\n\n'
                  'Or manually check firebase_options.dart for placeholder values.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.help_outline),
        label: const Text('Configuration Help'),
        style: ElevatedButton.styleFrom(
          backgroundColor: DarkThemeData.warningColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}