import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/dark_theme.dart';

class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? blurStrength;
  final bool enableHover;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.blurStrength,
    this.enableHover = true,
    this.onTap,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(16);
    final backgroundColor = widget.backgroundColor ?? DarkThemeData.glassBackground;
    final borderColor = widget.borderColor ?? DarkThemeData.glassBorder;

    return MouseRegion(
      onEnter: widget.enableHover ? (_) => _onHoverChange(true) : null,
      onExit: widget.enableHover ? (_) => _onHoverChange(false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(
                  color: _isHovered 
                      ? borderColor.withOpacity(0.3)
                      : borderColor.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: DarkThemeData.accentColor.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: borderRadius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.blurStrength ?? 10,
                    sigmaY: widget.blurStrength ?? 10,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          backgroundColor.withOpacity(0.8),
                          backgroundColor.withOpacity(0.6),
                        ],
                      ),
                    ),
                    padding: widget.padding ?? const EdgeInsets.all(16),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onHoverChange(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });

    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }
}

// Specialized glass cards for different use cases
class GlassInfoCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const GlassInfoCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || icon != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor?.withOpacity(0.1) ?? 
                               Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: icon!,
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// Glass action button
class GlassActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsets? padding;

  const GlassActionButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.primary.withOpacity(0.1),
      onTap: onPressed,
      child: DefaultTextStyle(
        style: TextStyle(
          color: foregroundColor ?? Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
        child: child,
      ),
    );
  }
}