import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:crypto/crypto.dart';
import '../models/rss_feed.dart';

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

      final response = await http
          .get(Uri.parse(feed.url))
          .timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: Failed to fetch feed');
      }

      final articles = _parseRSSFeed(response.body, feed);
      
      // Cache the results
      _cache[feed.id] = articles;
      _cacheTimestamps[feed.id] = DateTime.now();

      return articles;
    } catch (e) {
      throw Exception('Failed to fetch RSS feed: $e');
    }
  }

  /// Parse RSS XML content
  static List<NewsArticle> _parseRSSFeed(String xmlContent, RSSFeed feed) {
    try {
      final document = XmlDocument.parse(xmlContent);
      final items = document.findAllElements('item');

      return items.map((item) {
        final title = item.findElements('title').first.innerText.trim();
        final description = _extractDescription(item);
        final link = item.findElements('link').first.innerText.trim();
        final pubDate = _parseDate(item.findElements('pubDate').isNotEmpty 
            ? item.findElements('pubDate').first.innerText 
            : '');
        final imageUrl = _extractImageUrl(item);

        // Generate unique ID for article
        final id = _generateArticleId(link, title);

        return NewsArticle(
          id: id,
          title: title,
          description: description,
          url: link,
          imageUrl: imageUrl,
          publishedAt: pubDate,
          feedId: feed.id,
          feedName: feed.name,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to parse RSS feed: $e');
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
      // Try different date formats
      final formats = [
        // RFC 2822 format (common in RSS)
        RegExp(r'\w+,\s+(\d{1,2})\s+(\w+)\s+(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})'),
        // ISO 8601 format
        RegExp(r'(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})'),
      ];

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

  /// Validate RSS feed URL
  static Future<bool> validateFeedUrl(String url) async {
    try {
      final response = await http
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get popular RSS feeds for suggestions
  static List<Map<String, String>> getPopularFeeds() {
    return [
      {
        'name': 'BBC News',
        'url': 'http://feeds.bbci.co.uk/news/rss.xml',
        'category': 'News',
      },
      {
        'name': 'CNN Top Stories',
        'url': 'http://rss.cnn.com/rss/edition.rss',
        'category': 'News',
      },
      {
        'name': 'Reuters World News',
        'url': 'https://feeds.reuters.com/reuters/worldNews',
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
        'name': 'ESPN',
        'url': 'https://www.espn.com/espn/rss/news',
        'category': 'Sports',
      },
      {
        'name': 'NASA News',
        'url': 'https://www.nasa.gov/rss/dyn/breaking_news.rss',
        'category': 'Science',
      },
    ];
  }
}