import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models/initialization_status.dart';

class InitializationProgressScreen extends StatefulWidget {
  final InitializationStatus? status;
  final VoidCallback? onCancel;
  final VoidCallback? onSkipToOffline;
  final bool showOfflineOption;

  const InitializationProgressScreen({
    super.key,
    this.status,
    this.onCancel,
    this.onSkipToOffline,
    this.showOfflineOption = false,
  });

  @override
  State<InitializationProgressScreen> createState() => _InitializationProgressScreenState();
}

class _InitializationProgressScreenState extends State<InitializationProgressScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(InitializationProgressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status?.progress != null) {
      _progressController.animateTo(widget.status!.progress!);
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _getPhaseMessage(InitializationPhase? phase) {
    switch (phase) {
      case InitializationPhase.networkCheck:
        return 'Checking network connectivity...';
      case InitializationPhase.configValidation:
        return 'Validating Firebase configuration...';
      case InitializationPhase.firebaseInit:
        return 'Initializing Firebase services...';
      case InitializationPhase.authentication:
        return 'Setting up authentication...';
      case InitializationPhase.repositoryInit:
        return 'Initializing data repositories...';
      case InitializationPhase.success:
        return 'Initialization completed successfully';
      case InitializationPhase.error:
        return 'Initialization failed';
      case InitializationPhase.retrying:
        return 'Preparing to retry...';
      case null:
        return 'Starting initialization...';
    }
  }

  String _formatCountdown(Duration duration) {
    if (duration.inMinutes > 0) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      return '${minutes}m ${seconds}s';
    }
    return '${duration.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final progress = status?.progress ?? 0.0;
    final isRetrying = status?.isRetrying ?? false;
    final nextRetryIn = status?.nextRetryIn;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo/icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.1),
                  child: Icon(
                    Icons.dashboard,
                    color: Colors.blue.withValues(alpha: 0.8 + (_pulseController.value * 0.2)),
                    size: 80,
                  ),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            // Progress circle
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, child) {
                      return CircularProgressIndicator(
                        value: _progressController.value,
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isRetrying ? Colors.orange : Colors.blue,
                        ),
                      );
                    },
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Status message
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                status?.displayMessage ?? _getPhaseMessage(status?.phase),
                key: ValueKey(status?.phase.toString() ?? 'default'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Progress bar
            Container(
              width: 300,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progressController.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isRetrying ? Colors.orange : Colors.blue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Attempt indicator
            if (status != null && status.currentAttempt > 1) ...[
              const SizedBox(height: 16),
              Text(
                'Attempt ${status.currentAttempt} of ${status.maxAttempts}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
            
            // Countdown timer
            if (nextRetryIn != null && nextRetryIn.inSeconds > 0) ...[
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1 + (_pulseController.value * 0.1)),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3 + (_pulseController.value * 0.2)),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Retrying in ${_formatCountdown(nextRetryIn)}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ],
            
            const SizedBox(height: 40),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.onSkipToOffline != null && (widget.showOfflineOption || isRetrying)) ...[
                  ElevatedButton(
                    onPressed: widget.onSkipToOffline,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Skip to Offline'),
                  ),
                  const SizedBox(width: 16),
                ],
                if (widget.onCancel != null && isRetrying)
                  ElevatedButton(
                    onPressed: widget.onCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Additional info
            Text(
              'Initializing Modern Dashboard...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}