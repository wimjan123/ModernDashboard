import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/dark_theme.dart';

enum AppLogoMode {
  iconOnly,
  textOnly,
  iconAndText,
}

enum AppLogoVariant {
  light,
  dark,
  auto,
}

class AppLogo extends StatelessWidget {
  final double size;
  final AppLogoMode mode;
  final AppLogoVariant variant;
  final bool enableAnimations;
  final bool enableShimmer;
  final Color? iconColor;
  final Color? textColor;
  final String? customText;
  final EdgeInsets? padding;

  const AppLogo({
    super.key,
    this.size = 48.0,
    this.mode = AppLogoMode.iconOnly,
    this.variant = AppLogoVariant.auto,
    this.enableAnimations = false,
    this.enableShimmer = false,
    this.iconColor,
    this.textColor,
    this.customText,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    
    // Determine colors based on variant and theme
    final resolvedIconColor = _resolveIconColor(context, isDark);
    final resolvedTextColor = _resolveTextColor(context, isDark);
    
    Widget content;
    
    switch (mode) {
      case AppLogoMode.iconOnly:
        content = _buildIconOnly(resolvedIconColor);
        break;
      case AppLogoMode.textOnly:
        content = _buildTextOnly(context, resolvedTextColor);
        break;
      case AppLogoMode.iconAndText:
        content = _buildIconAndText(context, resolvedIconColor, resolvedTextColor);
        break;
    }
    
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    
    // Apply animations if enabled
    if (enableAnimations) {
      content = content
          .animate()
          .fadeIn(duration: 600.ms, curve: Curves.easeOut)
          .scale(begin: const Offset(0.9, 0.9), curve: Curves.elasticOut);
    }
    
    if (enableShimmer) {
      content = content
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .shimmer(
            duration: 2000.ms,
            color: Colors.white.withValues(alpha: 0.2),
          );
    }
    
    return content;
  }
  
  Color _resolveIconColor(BuildContext context, bool isDark) {
    if (iconColor != null) return iconColor!;
    
    switch (variant) {
      case AppLogoVariant.light:
        return Colors.white;
      case AppLogoVariant.dark:
        return const Color(0xFF0F0F23); // DarkThemeData._backgroundDark
      case AppLogoVariant.auto:
        return isDark 
            ? Colors.white 
            : const Color(0xFF0F0F23);
    }
  }
  
  Color _resolveTextColor(BuildContext context, bool isDark) {
    if (textColor != null) return textColor!;
    
    switch (variant) {
      case AppLogoVariant.light:
        return const Color(0xFFF8FAFC); // DarkThemeData._textPrimary
      case AppLogoVariant.dark:
        return const Color(0xFF0F0F23); // DarkThemeData._backgroundDark
      case AppLogoVariant.auto:
        return isDark 
            ? const Color(0xFFF8FAFC)
            : const Color(0xFF0F0F23);
    }
  }
  
  Widget _buildIconOnly(Color color) {
    return _LogoContainer(
      size: size,
      child: Icon(
        Icons.dashboard_rounded,
        size: size * 0.55,
        color: color,
      ),
    );
  }
  
  Widget _buildTextOnly(BuildContext context, Color color) {
    return Text(
      customText ?? 'Modern Dashboard',
      style: _getTextStyle(context, color),
    );
  }
  
  Widget _buildIconAndText(BuildContext context, Color iconColor, Color textColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconOnly(iconColor),
        SizedBox(height: size * 0.2),
        Text(
          customText ?? 'Modern Dashboard',
          style: _getTextStyle(context, textColor).copyWith(
            fontSize: size * 0.25,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  TextStyle _getTextStyle(BuildContext context, Color color) {
    return Theme.of(context).textTheme.headlineMedium?.copyWith(
      color: color,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ) ?? TextStyle(
      color: color,
      fontSize: size * 0.3,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    );
  }
}

class _LogoContainer extends StatelessWidget {
  final double size;
  final Widget child;
  
  const _LogoContainer({
    required this.size,
    required this.child,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.2),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4F46E5), // DarkThemeData._primaryBlue
            Color(0xFF7C3AED), // DarkThemeData._accentPurple
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
            blurRadius: size * 0.3,
            spreadRadius: size * 0.02,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}

// Convenience constructors for common use cases
class AppLogoLarge extends AppLogo {
  const AppLogoLarge({
    super.key,
    AppLogoMode mode = AppLogoMode.iconAndText,
    bool enableAnimations = true,
    bool enableShimmer = false,
  }) : super(
    size: 120.0,
    mode: mode,
    enableAnimations: enableAnimations,
    enableShimmer: enableShimmer,
  );
}

class AppLogoMedium extends AppLogo {
  const AppLogoMedium({
    super.key,
    AppLogoMode mode = AppLogoMode.iconOnly,
    bool enableAnimations = false,
  }) : super(
    size: 64.0,
    mode: mode,
    enableAnimations: enableAnimations,
  );
}

class AppLogoSmall extends AppLogo {
  const AppLogoSmall({
    super.key,
    AppLogoMode mode = AppLogoMode.iconOnly,
  }) : super(
    size: 32.0,
    mode: mode,
  );
}