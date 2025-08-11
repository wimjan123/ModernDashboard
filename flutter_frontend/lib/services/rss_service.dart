import 'dart:convert';
import 'package:flutter/foundation.dart';
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

      // For web platform, we need to use CORS proxy or return mock data
      if (kIsWeb) {
        return _getMockArticlesForFeed(feed);
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