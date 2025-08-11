import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:crypto/crypto.dart';
import '../models/rss_feed.dart';
import '../core/exceptions/feed_validation_exception.dart';
import '../core/services/cors_proxy_service.dart';
import '../core/utils/url_validator.dart';

class RSSService {
  static const int _timeoutSeconds = 10;
  static final Map<String, List<NewsArticle>> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 15);

  /// Fetch and parse RSS feed
  static Future<List<NewsArticle>> fetchFeed(RSSFeed feed) async {
    try {
      // Check cache first
      if (_isCacheValid(feed.id)) {
        return _cache[feed.id] ?? [];
      }

      String content;
      
      // For web platform, use CORS proxy or return mock data
      if (kIsWeb) {
        try {
          final corsProxy = CorsProxyService.instance;
          content = await corsProxy.fetchWithProxy(feed.url);
        } catch (e) {
          debugPrint('RSSService: CORS proxy failed, using mock data: $e');
          return _getMockArticlesForFeed(feed);
        }
      } else {
        // Direct fetch for non-web platforms
        final response = await http
            .get(Uri.parse(feed.url))
            .timeout(const Duration(seconds: _timeoutSeconds));

        if (response.statusCode != 200) {
          throw FeedValidationException.serverError(
            feed.url, 
            response.statusCode,
            statusMessage: response.reasonPhrase,
          );
        }
        
        content = response.body;
      }

      final articles = _parseRSSFeed(content, feed);
      
      // Cache the results
      _cache[feed.id] = articles;
      _cacheTimestamps[feed.id] = DateTime.now();

      return articles;
    } on FeedValidationException {
      rethrow;
    } on TimeoutException {
      throw FeedValidationException.timeout(feed.url);
    } on SocketException catch (e) {
      throw FeedValidationException.networkError(feed.url, details: e.message);
    } on HttpException catch (e) {
      throw FeedValidationException.networkError(feed.url, details: e.message);
    } catch (e) {
      debugPrint('RSSService: Unexpected error fetching feed: $e');
      throw FeedValidationException.networkError(feed.url, details: e.toString());
    }
  }

  /// Parse RSS XML content
  static List<NewsArticle> _parseRSSFeed(String xmlContent, RSSFeed feed) {
    try {
      final document = XmlDocument.parse(xmlContent);
      
      // Check for RSS or Atom format
      final rssItems = document.findAllElements('item');
      final atomEntries = document.findAllElements('entry');
      
      if (rssItems.isEmpty && atomEntries.isEmpty) {
        throw FeedValidationException.notRssFeed(feed.url);
      }
      
      // Parse RSS format
      if (rssItems.isNotEmpty) {
        return rssItems.map((item) {
          return _parseRSSItem(item, feed);
        }).toList();
      }
      
      // Parse Atom format
      return atomEntries.map((entry) {
        return _parseAtomEntry(entry, feed);
      }).toList();
      
    } on XmlParserException {
      throw FeedValidationException.notRssFeed(feed.url);
    } catch (e) {
      if (e is FeedValidationException) rethrow;
      throw FeedValidationException.notRssFeed(feed.url);
    }
  }
  
  /// Parse RSS item element
  static NewsArticle _parseRSSItem(XmlElement item, RSSFeed feed) {
    try {
      final title = _getElementText(item, 'title').trim();
      final description = _extractDescription(item);
      final link = _getElementText(item, 'link').trim();
      final pubDate = _parseDate(_getElementText(item, 'pubDate'));
      final imageUrl = _extractImageUrl(item);

      // Generate unique ID for article
      final id = _generateArticleId(link.isNotEmpty ? link : title, title);

      return NewsArticle(
        id: id,
        title: title.isNotEmpty ? title : 'No title',
        description: description,
        url: link.isNotEmpty ? link : 'https://example.com',
        imageUrl: imageUrl,
        publishedAt: pubDate,
        feedId: feed.id,
        feedName: feed.name,
      );
    } catch (e) {
      debugPrint('RSSService: Error parsing RSS item: $e');
      // Return a fallback article rather than failing completely
      return NewsArticle(
        id: _generateArticleId('fallback-${DateTime.now().millisecondsSinceEpoch}', 'Error'),
        title: 'Error parsing article',
        description: 'This article could not be parsed properly.',
        url: 'https://example.com',
        imageUrl: null,
        publishedAt: DateTime.now(),
        feedId: feed.id,
        feedName: feed.name,
      );
    }
  }
  
  /// Parse Atom entry element
  static NewsArticle _parseAtomEntry(XmlElement entry, RSSFeed feed) {
    try {
      final title = _getElementText(entry, 'title').trim();
      final description = _extractAtomSummary(entry);
      final link = _extractAtomLink(entry);
      final pubDate = _parseDate(_getElementText(entry, 'published', fallback: _getElementText(entry, 'updated')));
      final imageUrl = _extractImageUrl(entry);

      // Generate unique ID for article
      final id = _generateArticleId(link.isNotEmpty ? link : title, title);

      return NewsArticle(
        id: id,
        title: title.isNotEmpty ? title : 'No title',
        description: description,
        url: link.isNotEmpty ? link : 'https://example.com',
        imageUrl: imageUrl,
        publishedAt: pubDate,
        feedId: feed.id,
        feedName: feed.name,
      );
    } catch (e) {
      debugPrint('RSSService: Error parsing Atom entry: $e');
      // Return a fallback article rather than failing completely
      return NewsArticle(
        id: _generateArticleId('fallback-${DateTime.now().millisecondsSinceEpoch}', 'Error'),
        title: 'Error parsing article',
        description: 'This article could not be parsed properly.',
        url: 'https://example.com',
        imageUrl: null,
        publishedAt: DateTime.now(),
        feedId: feed.id,
        feedName: feed.name,
      );
    }
  }
  
  /// Safely get element text with fallback
  static String _getElementText(XmlElement parent, String elementName, {String fallback = ''}) {
    try {
      final elements = parent.findElements(elementName);
      return elements.isNotEmpty ? elements.first.innerText : fallback;
    } catch (e) {
      return fallback;
    }
  }
  
  /// Extract Atom summary/content
  static String _extractAtomSummary(XmlElement entry) {
    final summaryFields = ['summary', 'content'];
    
    for (final field in summaryFields) {
      final text = _getElementText(entry, field);
      if (text.isNotEmpty) {
        String cleaned = text.replaceAll(RegExp(r'<[^>]*>'), '');
        cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (cleaned.length > 300) {
          cleaned = '${cleaned.substring(0, 300)}...';
        }
        return cleaned;
      }
    }
    
    return 'No description available';
  }
  
  /// Extract Atom link
  static String _extractAtomLink(XmlElement entry) {
    try {
      final linkElements = entry.findElements('link');
      for (final link in linkElements) {
        final href = link.getAttribute('href');
        final rel = link.getAttribute('rel');
        if (href != null && (rel == null || rel == 'alternate')) {
          return href;
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  /// Extract description from RSS item
  static String _extractDescription(XmlElement item) {
    // Try different description fields
    final descriptionFields = ['description', 'summary', 'content:encoded'];
    
    for (final field in descriptionFields) {
      final elements = item.findElements(field);
      if (elements.isNotEmpty) {
        String description = elements.first.innerText.trim();
        // Remove HTML tags and clean up
        description = description.replaceAll(RegExp(r'<[^>]*>'), '');
        description = description.replaceAll(RegExp(r'\s+'), ' ');
        // Limit length
        if (description.length > 300) {
          description = '${description.substring(0, 300)}...';
        }
        return description;
      }
    }
    
    return 'No description available';
  }

  /// Extract image URL from RSS item
  static String? _extractImageUrl(XmlElement item) {
    // Try different image fields
    final imageFields = [
      'media:thumbnail',
      'media:content',
      'enclosure',
      'image',
    ];

    for (final field in imageFields) {
      final elements = item.findElements(field);
      if (elements.isNotEmpty) {
        final element = elements.first;
        
        // Check for URL attribute
        final urlAttr = element.getAttribute('url') ?? 
                       element.getAttribute('href') ?? 
                       element.getAttribute('src');
        
        if (urlAttr != null && urlAttr.isNotEmpty) {
          return urlAttr;
        }
        
        // Check inner text
        final innerText = element.innerText.trim();
        if (innerText.isNotEmpty && _isImageUrl(innerText)) {
          return innerText;
        }
      }
    }

    // Try to extract image from description
    final description = item.findElements('description');
    if (description.isNotEmpty) {
      final imgMatch = RegExp(r'<img[^>]+src="([^"]+)"').firstMatch(description.first.innerText);
      if (imgMatch != null) {
        return imgMatch.group(1);
      }
    }

    return null;
  }

  /// Check if URL is likely an image
  static bool _isImageUrl(String url) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final lowerUrl = url.toLowerCase();
    return imageExtensions.any((ext) => lowerUrl.contains(ext));
  }

  /// Parse date string to DateTime
  static DateTime _parseDate(String dateString) {
    if (dateString.isEmpty) return DateTime.now();

    try {
      // Try parsing with DateTime.parse first
      try {
        return DateTime.parse(dateString);
      } catch (_) {}

      // Try RFC 2822 format parsing
      if (dateString.contains(',')) {
        final parts = dateString.split(',');
        if (parts.length > 1) {
          try {
            return DateTime.parse(parts[1].trim());
          } catch (_) {}
        }
      }
    } catch (_) {}

    // If all parsing fails, return current time
    return DateTime.now();
  }

  /// Generate unique ID for article
  static String _generateArticleId(String url, String title) {
    final content = '$url-$title';
    final bytes = utf8.encode(content);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Check if cached data is still valid
  static bool _isCacheValid(String feedId) {
    final timestamp = _cacheTimestamps[feedId];
    if (timestamp == null) return false;
    
    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  /// Clear cache for specific feed
  static void clearCache(String feedId) {
    _cache.remove(feedId);
    _cacheTimestamps.remove(feedId);
  }

  /// Clear all cache
  static void clearAllCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  /// Validate RSS feed URL with comprehensive error handling
  static Future<void> validateFeedUrl(String url) async {
    // Step 1: Format validation
    final formatResult = kIsWeb ? UrlValidator.validateForWeb(url) : UrlValidator.validateFeedFormat(url);
    if (!formatResult.isValid) {
      throw FeedValidationException.invalidUrl(url, suggestion: formatResult.suggestion);
    }
    
    // Step 2: Network validation
    try {
      if (kIsWeb) {
        // Use CORS proxy service for web platform
        final corsProxy = CorsProxyService.instance;
        await corsProxy.testWithProxy(url);
      } else {
        // Direct validation for non-web platforms
        final response = await http
            .head(Uri.parse(url))
            .timeout(const Duration(seconds: 8));
        
        if (response.statusCode == 403 || response.statusCode == 405) {
          // Some servers block HEAD requests, try GET with limited range
          final getResponse = await http
              .get(Uri.parse(url), headers: {'Range': 'bytes=0-1023'})
              .timeout(const Duration(seconds: 8));
          
          if (getResponse.statusCode != 200 && getResponse.statusCode != 206) {
            throw FeedValidationException.serverError(url, getResponse.statusCode);
          }
          
          // Basic content validation
          final content = getResponse.body.toLowerCase();
          if (!content.contains('<rss') && !content.contains('<feed') && 
              !content.contains('<atom') && !content.contains('<?xml')) {
            throw FeedValidationException.notRssFeed(url);
          }
        } else if (response.statusCode != 200) {
          throw FeedValidationException.serverError(url, response.statusCode);
        }
      }
    } on FeedValidationException {
      rethrow;
    } on TimeoutException {
      throw FeedValidationException.timeout(url);
    } on SocketException catch (e) {
      throw FeedValidationException.networkError(url, details: e.message);
    } on HttpException catch (e) {
      throw FeedValidationException.networkError(url, details: e.message);
    } catch (e) {
      throw FeedValidationException.networkError(url, details: e.toString());
    }
  }
  
  /// Quick validation for UI feedback (returns bool for compatibility)
  static Future<bool> quickValidate(String url) async {
    try {
      await validateFeedUrl(url);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get popular RSS feeds for suggestions (with more reliable URLs)
  static List<Map<String, String>> getPopularFeeds() {
    return [
      {
        'name': 'BBC News',
        'url': 'https://feeds.bbci.co.uk/news/rss.xml',
        'category': 'News',
      },
      {
        'name': 'Reuters World News',
        'url': 'https://feeds.reuters.com/reuters/worldNews',
        'category': 'News',
      },
      {
        'name': 'Associated Press',
        'url': 'https://feeds.apnews.com/rss/apnews/home',
        'category': 'News',
      },
      {
        'name': 'TechCrunch',
        'url': 'https://techcrunch.com/feed/',
        'category': 'Technology',
      },
      {
        'name': 'Ars Technica',
        'url': 'https://feeds.arstechnica.com/arstechnica/index',
        'category': 'Technology',
      },
      {
        'name': 'The Verge',
        'url': 'https://www.theverge.com/rss/index.xml',
        'category': 'Technology',
      },
      {
        'name': 'Hacker News',
        'url': 'https://hnrss.org/frontpage',
        'category': 'Technology',
      },
      {
        'name': 'NASA Breaking News',
        'url': 'https://www.nasa.gov/news/releases/latest/index.html',
        'category': 'Science',
      },
      {
        'name': 'NPR News',
        'url': 'https://feeds.npr.org/1001/rss.xml',
        'category': 'News',
      },
      {
        'name': 'Reddit Technology',
        'url': 'https://www.reddit.com/r/technology/.rss',
        'category': 'Technology',
      },
    ];
  }
  
  /// Initialize the RSS service (setup CORS proxy if needed)
  static Future<void> initialize() async {
    try {
      if (kIsWeb) {
        await CorsProxyService.instance.initialize();
        debugPrint('RSSService: CORS proxy service initialized');
      }
      debugPrint('RSSService: Initialized successfully');
    } catch (e) {
      debugPrint('RSSService: Warning - initialization failed: $e');
      // Don't throw error, service should still work with limitations
    }
  }

  /// Get mock articles for web platform (CORS limitations)
  static Future<List<NewsArticle>> _getMockArticlesForFeed(RSSFeed feed) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    final now = DateTime.now();
    final mockArticles = <NewsArticle>[];
    
    // Generate 10 mock articles based on feed category
    for (int i = 0; i < 10; i++) {
      final id = _generateArticleId('mock-${feed.id}-$i', 'Mock Article $i');
      mockArticles.add(NewsArticle(
        id: id,
        title: _getMockTitle(feed.category, i),
        description: _getMockDescription(feed.category, i),
        url: 'https://example.com/article-$i',
        imageUrl: _getMockImageUrl(i),
        publishedAt: now.subtract(Duration(hours: i)),
        feedId: feed.id,
        feedName: feed.name,
      ));
    }
    
    // Cache mock data
    _cache[feed.id] = mockArticles;
    _cacheTimestamps[feed.id] = DateTime.now();
    
    return mockArticles;
  }

  /// Get mock title based on category
  static String _getMockTitle(String category, int index) {
    final titles = {
      'News': [
        'Breaking: Major Economic Developments',
        'Global Climate Summit Reaches Agreement',
        'New Technology Transforms Healthcare',
        'International Trade Relations Update',
        'Space Exploration Milestone Achieved',
        'Environmental Protection Initiatives',
        'Education Reform Proposals Announced',
        'Scientific Breakthrough in Medicine',
        'Cultural Festival Brings Communities Together',
        'Innovation in Renewable Energy'
      ],
      'Technology': [
        'AI Revolution: Latest Advances',
        'Quantum Computing Breakthrough',
        'Mobile Technology Trends 2024',
        'Cybersecurity Alert: New Threats',
        'Cloud Infrastructure Updates',
        'IoT Devices Transform Smart Homes',
        'Machine Learning Applications',
        'Blockchain Technology Adoption',
        'Virtual Reality Gaming Evolution',
        'Software Development Best Practices'
      ],
      'Sports': [
        'Championship Finals This Weekend',
        'Record-Breaking Performance',
        'Team Trades Shake Up League',
        'Olympic Preparation Updates',
        'Rookie Player Makes Headlines',
        'Stadium Renovation Complete',
        'Season Highlights Review',
        'Injury Recovery Success Story',
        'International Tournament Begins',
        'Training Camp Reports'
      ],
      'Science': [
        'Mars Mission Update',
        'Medical Research Findings',
        'Ocean Exploration Discovery',
        'Particle Physics Experiment',
        'Biodiversity Conservation Study',
        'Astronomical Observatory Data',
        'Genetic Engineering Progress',
        'Climate Research Results',
        'Archaeological Excavation',
        'Laboratory Innovation'
      ],
    };
    
    final categoryTitles = titles[category] ?? titles['News']!;
    return categoryTitles[index % categoryTitles.length];
  }

  /// Get mock description based on category
  static String _getMockDescription(String category, int index) {
    final descriptions = {
      'News': 'This is a sample news article description providing key information about current events and their impact on society.',
      'Technology': 'Exploring the latest technological innovations and their applications in various industries and everyday life.',
      'Sports': 'Coverage of athletic competitions, player performances, and sporting events from around the world.',
      'Science': 'Scientific discoveries, research findings, and breakthroughs that advance our understanding of the world.',
    };
    
    final base = descriptions[category] ?? descriptions['News']!;
    return '$base Updated ${index + 1} hour${index == 0 ? '' : 's'} ago with additional details.';
  }

  /// Get mock image URL
  static String _getMockImageUrl(int index) {
    final imageIds = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000];
    return 'https://picsum.photos/400/300?random=${imageIds[index % imageIds.length]}';
  }
}