import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProgressButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? loadingText;
  final double? progress;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData? icon;
  final ButtonStyle? style;
  final Duration animationDuration;
  final bool showProgressText;
  final EdgeInsets? padding;

  const ProgressButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.loadingText,
    this.progress,
    this.backgroundColor,
    this.foregroundColor,
    this.icon,
    this.style,
    this.animationDuration = const Duration(milliseconds: 300),
    this.showProgressText = false,
    this.padding,
  });

  factory ProgressButton.primary({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    String? loadingText,
    double? progress,
    IconData? icon,
    Duration animationDuration = const Duration(milliseconds: 300),
    bool showProgressText = false,
    EdgeInsets? padding,
  }) {
    return ProgressButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      loadingText: loadingText,
      progress: progress,
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      icon: icon,
      animationDuration: animationDuration,
      showProgressText: showProgressText,
      padding: padding,
    );
  }

  factory ProgressButton.secondary({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    String? loadingText,
    double? progress,
    IconData? icon,
    Duration animationDuration = const Duration(milliseconds: 300),
    bool showProgressText = false,
    EdgeInsets? padding,
  }) {
    return ProgressButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      loadingText: loadingText,
      progress: progress,
      backgroundColor: Colors.grey[700],
      foregroundColor: Colors.white,
      icon: icon,
      animationDuration: animationDuration,
      showProgressText: showProgressText,
      padding: padding,
    );
  }

  factory ProgressButton.danger({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    String? loadingText,
    double? progress,
    IconData? icon,
    Duration animationDuration = const Duration(milliseconds: 300),
    bool showProgressText = false,
    EdgeInsets? padding,
  }) {
    return ProgressButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      loadingText: loadingText,
      progress: progress,
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      icon: icon,
      animationDuration: animationDuration,
      showProgressText: showProgressText,
      padding: padding,
    );
  }

  factory ProgressButton.success({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    String? loadingText,
    double? progress,
    IconData? icon,
    Duration animationDuration = const Duration(milliseconds: 300),
    bool showProgressText = false,
    EdgeInsets? padding,
  }) {
    return ProgressButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      loadingText: loadingText,
      progress: progress,
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      icon: icon,
      animationDuration: animationDuration,
      showProgressText: showProgressText,
      padding: padding,
    );
  }

  @override
  State<ProgressButton> createState() => _ProgressButtonState();
}

class _ProgressButtonState extends State<ProgressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _wasPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(ProgressButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePress() {
    if (widget.isLoading || widget.onPressed == null) return;
    
    // Provide haptic feedback
    HapticFeedback.lightImpact();
    
    // Prevent multiple rapid presses
    if (_wasPressed) return;
    _wasPressed = true;
    
    widget.onPressed!();
    
    // Reset press flag after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _wasPressed = false;
    });
  }

  Widget _buildButtonContent() {
    if (widget.isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.foregroundColor ?? Colors.white,
              ),
            ),
          ),
          if (widget.loadingText != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.loadingText!,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      );
    }

    if (widget.progress != null && widget.showProgressText) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              widget.text,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(widget.progress! * 100).round()}%',
            style: TextStyle(
              color: widget.foregroundColor?.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.text,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    
    return AnimatedContainer(
      duration: widget.animationDuration,
      child: Stack(
        children: [
          // Main button
          ElevatedButton(
            onPressed: isDisabled ? null : _handlePress,
            style: widget.style ?? 
                ElevatedButton.styleFrom(
                  backgroundColor: widget.backgroundColor,
                  foregroundColor: widget.foregroundColor,
                  padding: widget.padding,
                  disabledBackgroundColor: widget.backgroundColor?.withValues(alpha: 0.5),
                  disabledForegroundColor: widget.foregroundColor?.withValues(alpha: 0.5),
                ),
            child: AnimatedSwitcher(
              duration: widget.animationDuration,
              child: _buildButtonContent(),
            ),
          ),
          
          // Progress overlay
          if (widget.progress != null && !widget.isLoading)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.progress,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    (widget.foregroundColor ?? Colors.white).withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}