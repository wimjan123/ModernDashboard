import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/dark_theme.dart';
import '../core/models/initialization_status.dart';

class SplashScreen extends StatefulWidget {
  final Stream<InitializationStatus?> initializationStream;
  final VoidCallback? onTimeout;

  const SplashScreen({
    super.key,
    required this.initializationStream,
    this.onTimeout,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _shouldTransition = false;
  bool _hasTimeout = false;

  @override
  void initState() {
    super.initState();
    _startTimeoutTimer();
    _listenToInitialization();
  }

  void _startTimeoutTimer() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_shouldTransition) {
        setState(() => _hasTimeout = true);
        widget.onTimeout?.call();
      }
    });
  }

  void _listenToInitialization() {
    widget.initializationStream.listen((status) {
      if (mounted && status != null && !_shouldTransition) {
        setState(() => _shouldTransition = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F23), // _backgroundDark from theme
              Color(0xFF1A1B3A), // _surfaceDark from theme
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                
                // Logo Container
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF4F46E5), // _primaryBlue
                        Color(0xFF7C3AED), // _accentPurple
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                        blurRadius: 32,
                        spreadRadius: 4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.dashboard_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                )
                .animate()
                .fadeIn(duration: 800.ms, curve: Curves.easeOut)
                .scale(begin: const Offset(0.8, 0.8), curve: Curves.elasticOut)
                .shimmer(
                  duration: 2000.ms,
                  delay: 1000.ms,
                  color: Colors.white.withValues(alpha: 0.3),
                ),

                const SizedBox(height: 32),
                
                // App Name
                Text(
                  'Modern Dashboard',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                )
                .animate()
                .fadeIn(delay: 400.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),

                const SizedBox(height: 12),
                
                // Tagline
                Text(
                  'Your Digital Command Center',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF94A3B8), // _textMuted
                  ),
                  textAlign: TextAlign.center,
                )
                .animate()
                .fadeIn(delay: 800.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),

                const Spacer(flex: 2),
                
                // Loading indicator (only show if initialization has started)
                if (_shouldTransition || _hasTimeout) ...[
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF4F46E5), // _primaryBlue
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 300.ms),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    'Initializing...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF94A3B8), // _textMuted
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms),
                ],
                
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}