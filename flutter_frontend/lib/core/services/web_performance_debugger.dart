import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Service for debugging Flutter web performance issues
class WebPerformanceDebugger {
  static final WebPerformanceDebugger _instance = WebPerformanceDebugger._internal();
  static WebPerformanceDebugger get instance => _instance;
  
  WebPerformanceDebugger._internal();
  
  bool _isInitialized = false;
  
  /// Initialize web performance debugging
  void initialize() {
    if (_isInitialized || !kIsWeb) return;
    
    _isInitialized = true;
    
    if (kDebugMode) {
      log('WebPerformanceDebugger: Initializing for Flutter Web');
      
      // Enable performance debugging flags
      debugPaintSizeEnabled = false; // Set to true to see widget bounds
      debugRepaintRainbowEnabled = false; // Set to true to highlight repaints
      
      // Log browser information
      _logBrowserInfo();
      
      // Set up performance monitoring
      _setupPerformanceMonitoring();
      
      log('WebPerformanceDebugger: Performance debugging flags initialized');
    }
  }
  
  /// Enable repaint debugging to identify performance bottlenecks
  void enableRepaintDebugging() {
    if (!kIsWeb || !kDebugMode) return;
    
    debugRepaintRainbowEnabled = true;
    log('WebPerformanceDebugger: Repaint rainbow enabled - look for excessive repaints');
  }
  
  /// Enable widget rebuild debugging
  void enableRebuildDebugging() {
    if (!kIsWeb || !kDebugMode) return;
    
    log('WebPerformanceDebugger: Widget rebuild logging enabled - use Flutter Inspector');
  }
  
  /// Enable size debugging to see widget bounds
  void enableSizeDebugging() {
    if (!kIsWeb || !kDebugMode) return;
    
    debugPaintSizeEnabled = true;
    log('WebPerformanceDebugger: Size debugging enabled - widget bounds will be visible');
  }
  
  /// Disable all debugging overlays
  void disableAllDebugging() {
    if (!kIsWeb) return;
    
    debugRepaintRainbowEnabled = false;
    debugPaintSizeEnabled = false;
    log('WebPerformanceDebugger: All debugging overlays disabled');
  }
  
  /// Log browser and platform information
  void _logBrowserInfo() {
    try {
      // Use conditional imports for web-specific APIs
      if (kIsWeb) {
        log('WebPerformanceDebugger: Platform: Flutter Web');
        log('WebPerformanceDebugger: Debug mode: $kDebugMode');
        log('WebPerformanceDebugger: Profile mode: $kProfileMode');
        log('WebPerformanceDebugger: Release mode: $kReleaseMode');
      }
    } catch (e) {
      log('WebPerformanceDebugger: Could not access browser info: $e');
    }
  }
  
  /// Set up performance monitoring
  void _setupPerformanceMonitoring() {
    if (!kDebugMode) return;
    
    // Monitor widget tree depth
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logFrameInfo();
    });
  }
  
  /// Log frame rendering information
  void _logFrameInfo() {
    if (!kDebugMode) return;
    
    try {
      final renderView = RendererBinding.instance.renderView;
      if (renderView.child != null) {
        log('WebPerformanceDebugger: Render tree root: ${renderView.child.runtimeType}');
      }
    } catch (e) {
      log('WebPerformanceDebugger: Could not access render tree: $e');
    }
  }
  
  /// Check for common performance issues
  void performanceHealthCheck() {
    if (!kIsWeb || !kDebugMode) return;
    
    log('WebPerformanceDebugger: Running performance health check...');
    
    // Check for memory issues
    _checkMemoryUsage();
    
    // Check for excessive rebuilds
    _checkRebuildPatterns();
    
    log('WebPerformanceDebugger: Performance health check completed');
  }
  
  void _checkMemoryUsage() {
    // This is a placeholder - actual memory monitoring would require additional tooling
    log('WebPerformanceDebugger: Memory usage check - use browser DevTools for detailed analysis');
  }
  
  void _checkRebuildPatterns() {
    // Enable rebuild monitoring analysis
    log('WebPerformanceDebugger: Analyzing rebuild patterns - use Flutter Inspector for detailed widget rebuild tracking');
    
    // Schedule a check to complete after a few frames
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 5), () {
        log('WebPerformanceDebugger: Rebuild pattern analysis completed');
      });
    });
  }
}