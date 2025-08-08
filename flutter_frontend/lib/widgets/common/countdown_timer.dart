import 'dart:async';
import 'package:flutter/material.dart';

enum CountdownSize { small, medium, large }

class CountdownTimer extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onComplete;
  final ValueChanged<Duration>? onTick;
  final String Function(Duration)? formatter;
  final TextStyle? textStyle;
  final bool autoStart;
  final CountdownSize size;
  final Color? progressColor;
  final Color? backgroundColor;
  final bool showCircularProgress;
  final bool showCancelButton;
  final VoidCallback? onCancel;

  const CountdownTimer({
    super.key,
    required this.duration,
    this.onComplete,
    this.onTick,
    this.formatter,
    this.textStyle,
    this.autoStart = true,
    this.size = CountdownSize.medium,
    this.progressColor,
    this.backgroundColor,
    this.showCircularProgress = true,
    this.showCancelButton = false,
    this.onCancel,
  });

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer>
    with TickerProviderStateMixin {
  Timer? _timer;
  late Duration _remaining;
  late Duration _original;
  bool _isRunning = false;
  late AnimationController _pulseController;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _original = widget.duration;
    _remaining = widget.duration;
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    if (widget.autoStart) {
      start();
    }
  }

  @override
  void didUpdateWidget(CountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _original = widget.duration;
      reset();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void start() {
    if (_isRunning) return;
    
    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _remaining = Duration(
          milliseconds: _remaining.inMilliseconds - 100,
        );
      });

      widget.onTick?.call(_remaining);
      _updateProgress();

      if (_remaining.inMilliseconds <= 0) {
        _complete();
      } else if (_remaining.inSeconds <= 3) {
        // Start pulse animation in final seconds
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
      }
    });
  }

  void pause() {
    if (!_isRunning) return;
    
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
    _pulseController.stop();
  }

  void reset() {
    _timer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    _progressController.reset();
    
    setState(() {
      _remaining = _original;
      _isRunning = false;
    });
  }

  void stop() {
    pause();
    reset();
  }

  void addTime(Duration additionalTime) {
    setState(() {
      _remaining = Duration(
        milliseconds: _remaining.inMilliseconds + additionalTime.inMilliseconds,
      );
      _original = Duration(
        milliseconds: _original.inMilliseconds + additionalTime.inMilliseconds,
      );
    });
    _updateProgress();
  }

  void _complete() {
    _timer?.cancel();
    _pulseController.stop();
    
    setState(() {
      _remaining = Duration.zero;
      _isRunning = false;
    });
    
    widget.onComplete?.call();
  }

  void _updateProgress() {
    if (_original.inMilliseconds > 0) {
      final progress = 1.0 - (_remaining.inMilliseconds / _original.inMilliseconds);
      _progressController.animateTo(progress.clamp(0.0, 1.0));
    }
  }

  String _formatDuration(Duration duration) {
    if (widget.formatter != null) {
      return widget.formatter!(duration);
    }
    
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '${hours}h ${minutes}m';
    } else if (duration.inMinutes > 0) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      return '${minutes}m ${seconds}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  double _getSizeMultiplier() {
    switch (widget.size) {
      case CountdownSize.small:
        return 0.7;
      case CountdownSize.medium:
        return 1.0;
      case CountdownSize.large:
        return 1.5;
    }
  }

  Color _getProgressColor() {
    if (widget.progressColor != null) {
      return widget.progressColor!;
    }
    
    final progress = _original.inMilliseconds > 0 
        ? _remaining.inMilliseconds / _original.inMilliseconds 
        : 0.0;
    
    if (progress > 0.5) {
      return Colors.green;
    } else if (progress > 0.2) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizeMultiplier = _getSizeMultiplier();
    final textStyle = widget.textStyle ?? 
        TextStyle(
          fontSize: 16 * sizeMultiplier,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        );

    if (!widget.showCircularProgress) {
      // Simple text display
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_pulseController.value * 0.1),
            child: Text(
              _formatDuration(_remaining),
              style: textStyle.copyWith(
                color: textStyle.color?.withOpacity(
                  0.8 + (_pulseController.value * 0.2),
                ),
              ),
            ),
          );
        },
      );
    }

    // Circular progress with text
    return Stack(
      alignment: Alignment.center,
      children: [
        // Circular progress indicator
        SizedBox(
          width: 60 * sizeMultiplier,
          height: 60 * sizeMultiplier,
          child: AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              return CircularProgressIndicator(
                value: _progressController.value,
                strokeWidth: 4 * sizeMultiplier,
                backgroundColor: widget.backgroundColor ?? 
                    Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
              );
            },
          ),
        ),
        
        // Time text
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.05),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDuration(_remaining),
                    style: textStyle.copyWith(
                      fontSize: (textStyle.fontSize ?? 16) * 0.8,
                      color: textStyle.color?.withOpacity(
                        0.9 + (_pulseController.value * 0.1),
                      ),
                    ),
                  ),
                  if (widget.showProgressText && _original.inMilliseconds > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${(100 - (_remaining.inMilliseconds / _original.inMilliseconds * 100)).round()}%',
                      style: textStyle.copyWith(
                        fontSize: (textStyle.fontSize ?? 16) * 0.5,
                        color: textStyle.color?.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        
        // Cancel button overlay
        if (widget.showCancelButton && widget.onCancel != null)
          Positioned(
            top: -5,
            right: -5,
            child: GestureDetector(
              onTap: widget.onCancel,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Static formatters for convenience
  static String compactFormatter(Duration duration) {
    return duration.inSeconds.toString();
  }

  static String preciseFormatter(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    
    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }
}