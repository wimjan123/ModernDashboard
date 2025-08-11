import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../exceptions/feed_validation_exception.dart';
import '../../firebase/remote_config_service.dart';

/// Configuration for CORS proxy settings
class CorsProxyConfig {
  final String primaryProxyUrl;
  final List<String> fallbackProxyUrls;
  final Duration proxyTimeout;
  final Duration healthCheckInterval;

  const CorsProxyConfig({
    required this.primaryProxyUrl,
    required this.fallbackProxyUrls,
    required this.proxyTimeout,
    required this.healthCheckInterval,
  });

  factory CorsProxyConfig.defaults() {
    return const CorsProxyConfig(
      primaryProxyUrl: 'https://corsproxy.io/?',
      fallbackProxyUrls: [
        'https://cors-anywhere.herokuapp.com/',
        'https://api.allorigins.win/get?url=',
        'https://thingproxy.freeboard.io/fetch/',
      ],
      proxyTimeout: Duration(seconds: 10),
      healthCheckInterval: Duration(minutes: 15),
    );
  }
}

/// Service to handle CORS proxy functionality for web RSS feed access
class CorsProxyService {
  static CorsProxyService? _instance;
  static CorsProxyService get instance => _instance ??= CorsProxyService._();
  
  CorsProxyService._();

  final Map<String, bool> _proxyHealthStatus = {};
  Timer? _healthCheckTimer;
  CorsProxyConfig _config = CorsProxyConfig.defaults();

  /// Initialize the CORS proxy service with remote configuration
  Future<void> initialize() async {
    try {
      // Get proxy configuration from Firebase Remote Config
      await _loadProxyConfig();
      
      // Start health check timer
      _startHealthCheckTimer();
      
      // Initial health check for all proxies
      await _performHealthCheck();
      
      debugPrint('CorsProxyService: Initialized successfully');
    } catch (e) {
      debugPrint('CorsProxyService: Failed to initialize: $e');
      // Continue with default configuration
    }
  }

  /// Load proxy configuration from Firebase Remote Config
  Future<void> _loadProxyConfig() async {
    try {
      final remoteConfig = RemoteConfigService.instance;
      final config = remoteConfig.getProxyConfig();
      if (config != null) {
        _config = config;
        debugPrint('CorsProxyService: Using remote proxy configuration');
      }
    } catch (e) {
      debugPrint('CorsProxyService: Using default proxy configuration: $e');
    }
  }

  /// Start periodic health checks for proxy services
  void _startHealthCheckTimer() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_config.healthCheckInterval, (timer) {
      _performHealthCheck();
    });
  }

  /// Perform health check on all proxy services
  Future<void> _performHealthCheck() async {
    final allProxies = [_config.primaryProxyUrl, ..._config.fallbackProxyUrls];
    
    for (final proxy in allProxies) {
      try {
        final isHealthy = await _checkProxyHealth(proxy);
        _proxyHealthStatus[proxy] = isHealthy;
        debugPrint('CorsProxyService: Proxy $proxy health: $isHealthy');
      } catch (e) {
        _proxyHealthStatus[proxy] = false;
        debugPrint('CorsProxyService: Proxy $proxy health check failed: $e');
      }
    }
  }

  /// Check if a specific proxy service is healthy
  Future<bool> _checkProxyHealth(String proxyUrl) async {
    try {
      // Use a simple test URL to check proxy health
      final testUrl = 'https://httpbin.org/status/200';
      final proxiedUrl = _wrapUrlWithProxy(testUrl, proxyUrl);
      
      final response = await http.get(
        Uri.parse(proxiedUrl),
        headers: {'User-Agent': 'ModernDashboard/1.0'},
      ).timeout(_config.proxyTimeout);
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get the best available proxy URL
  String? _getBestProxy() {
    // Check primary proxy first
    if (_proxyHealthStatus[_config.primaryProxyUrl] == true) {
      return _config.primaryProxyUrl;
    }
    
    // Check fallback proxies
    for (final proxy in _config.fallbackProxyUrls) {
      if (_proxyHealthStatus[proxy] == true) {
        return proxy;
      }
    }
    
    // If no proxy is marked as healthy, return primary proxy
    // (might be first run before health check completed)
    return _config.primaryProxyUrl;
  }

  /// Wrap a URL with proxy prefix based on proxy type
  String _wrapUrlWithProxy(String url, String proxyUrl) {
    if (proxyUrl.contains('allorigins.win')) {
      return '$proxyUrl${Uri.encodeComponent(url)}&format=raw';
    } else if (proxyUrl.contains('corsproxy.io')) {
      return '$proxyUrl${Uri.encodeComponent(url)}';
    } else {
      return '$proxyUrl$url';
    }
  }

  /// Test URL accessibility with proxy
  Future<void> testWithProxy(String url) async {
    if (!kIsWeb) {
      throw FeedValidationException(
        'not_web_platform',
        'CORS proxy is only needed on web platform',
      );
    }

    final proxy = _getBestProxy();
    if (proxy == null) {
      throw FeedValidationException.networkError(
        url,
        details: 'No healthy proxy services available',
      );
    }

    try {
      final proxiedUrl = _wrapUrlWithProxy(url, proxy);
      final response = await http.get(
        Uri.parse(proxiedUrl),
        headers: {
          'User-Agent': 'ModernDashboard/1.0',
          'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml',
        },
      ).timeout(_config.proxyTimeout);

      if (response.statusCode == 200) {
        // Basic validation that this looks like RSS/Atom content
        final content = response.body.toLowerCase();
        if (content.contains('<rss') || 
            content.contains('<feed') || 
            content.contains('<atom') ||
            content.contains('<?xml')) {
          return; // Success
        } else {
          throw FeedValidationException.notRssFeed(url);
        }
      } else if (response.statusCode == 403 || response.statusCode == 405) {
        throw FeedValidationException.corsBlocked(url);
      } else {
        throw FeedValidationException.serverError(
          url, 
          response.statusCode,
          statusMessage: response.reasonPhrase,
        );
      }
    } on TimeoutException {
      throw FeedValidationException.timeout(url);
    } on SocketException catch (e) {
      throw FeedValidationException.networkError(url, details: e.message);
    } on HttpException catch (e) {
      throw FeedValidationException.networkError(url, details: e.message);
    } catch (e) {
      if (e is FeedValidationException) rethrow;
      throw FeedValidationException.networkError(url, details: e.toString());
    }
  }

  /// Force validation using proxy (for user-initiated retry)
  Future<void> forceProxyValidation(String url) async {
    if (!kIsWeb) {
      throw FeedValidationException(
        'not_web_platform',
        'CORS proxy is only needed on web platform',
      );
    }

    // Try all available proxies, starting with the best one
    final allProxies = [
      if (_getBestProxy() != null) _getBestProxy()!,
      ..._config.fallbackProxyUrls.where((proxy) => proxy != _getBestProxy()),
    ];

    Exception? lastException;

    for (final proxy in allProxies) {
      try {
        final proxiedUrl = _wrapUrlWithProxy(url, proxy);
        final response = await http.get(
          Uri.parse(proxiedUrl),
          headers: {
            'User-Agent': 'ModernDashboard/1.0',
            'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml',
          },
        ).timeout(_config.proxyTimeout);

        if (response.statusCode == 200) {
          final content = response.body.toLowerCase();
          if (content.contains('<rss') || 
              content.contains('<feed') || 
              content.contains('<atom') ||
              content.contains('<?xml')) {
            // Update proxy health status on success
            _proxyHealthStatus[proxy] = true;
            return;
          } else {
            throw FeedValidationException.notRssFeed(url);
          }
        } else {
          _proxyHealthStatus[proxy] = false;
          lastException = FeedValidationException.serverError(
            url, 
            response.statusCode,
            statusMessage: response.reasonPhrase,
          );
        }
      } catch (e) {
        _proxyHealthStatus[proxy] = false;
        lastException = e is Exception ? e : Exception(e.toString());
        continue;
      }
    }

    // If all proxies failed, throw the last exception or a generic error
    if (lastException != null) {
      if (lastException is FeedValidationException) {
        throw lastException;
      } else {
        throw FeedValidationException.networkError(url, details: lastException.toString());
      }
    } else {
      throw FeedValidationException.networkError(
        url,
        details: 'All proxy services failed to access the URL',
      );
    }
  }

  /// Fetch RSS content through proxy
  Future<String> fetchWithProxy(String url) async {
    final proxy = _getBestProxy();
    if (proxy == null) {
      throw FeedValidationException.networkError(
        url,
        details: 'No healthy proxy services available',
      );
    }

    try {
      final proxiedUrl = _wrapUrlWithProxy(url, proxy);
      final response = await http.get(
        Uri.parse(proxiedUrl),
        headers: {
          'User-Agent': 'ModernDashboard/1.0',
          'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml',
        },
      ).timeout(_config.proxyTimeout);

      if (response.statusCode == 200) {
        String content = response.body;
        
        // Handle AllOrigins response format
        if (proxy.contains('allorigins.win') && !proxy.contains('format=raw')) {
          try {
            final jsonResponse = json.decode(content);
            content = jsonResponse['contents'] ?? content;
          } catch (e) {
            // If JSON parsing fails, use content as-is
          }
        }
        
        return content;
      } else {
        throw FeedValidationException.serverError(
          url, 
          response.statusCode,
          statusMessage: response.reasonPhrase,
        );
      }
    } on TimeoutException {
      throw FeedValidationException.timeout(url);
    } on SocketException catch (e) {
      throw FeedValidationException.networkError(url, details: e.message);
    } on HttpException catch (e) {
      throw FeedValidationException.networkError(url, details: e.message);
    } catch (e) {
      if (e is FeedValidationException) rethrow;
      throw FeedValidationException.networkError(url, details: e.toString());
    }
  }

  /// Get proxy health status for debugging
  Map<String, bool> get proxyHealthStatus => Map.from(_proxyHealthStatus);

  /// Get current proxy configuration
  CorsProxyConfig get config => _config;

  /// Check if any proxy is currently healthy
  bool get hasHealthyProxy => _proxyHealthStatus.values.any((isHealthy) => isHealthy);

  /// Dispose resources
  void dispose() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }
}

/// Extension to add proxy configuration to RemoteConfigService
extension ProxyConfigExtension on RemoteConfigService {
  // Configuration keys for CORS proxy
  static const String _primaryProxyUrlConfig = 'cors_primary_proxy_url';
  static const String _fallbackProxyUrlsConfig = 'cors_fallback_proxy_urls';
  static const String _proxyTimeoutConfig = 'cors_proxy_timeout_seconds';
  static const String _healthCheckIntervalConfig = 'cors_health_check_minutes';

  /// Get CORS proxy configuration from Remote Config
  CorsProxyConfig? getProxyConfig() {
    try {
      // This would typically be implemented in the actual RemoteConfigService
      // For now, we'll return null to use defaults
      return null;
    } catch (e) {
      debugPrint('RemoteConfigService: Error reading proxy config: $e');
      return null;
    }
  }
}