import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'news_repository.dart';
import '../services/mock_data_service.dart';

/// Mock News Repository that provides realistic news data for offline mode
/// Uses MockDataService for base news data with realistic variations and feed simulation
class MockNewsRepository implements NewsRepository {
  final MockDataService _mockDataService = MockDataService();
  List<NewsItem> _cachedNews = [];
  final List<String> _mockFeeds = [];
  DateTime? _lastRefresh;
  final Random _random = Random();

  // Sample RSS feeds for simulation
  final List<String> _defaultFeeds = [
    'https://feeds.feedburner.com/TechCrunch',
    'https://www.theverge.com/rss/index.xml',
    'https://www.wired.com/feed/rss',
    'https://hacker-news.firebaseio.com/v0/topstories.json',
    'https://www.reddit.com/r/programming/.rss',
    'https://feeds.macrumors.com/MacRumors-All',
  ];

  MockNewsRepository() {
    _mockDataService.initialize();
    // Initialize with some default feeds
    _mockFeeds.addAll(_defaultFeeds.take(3));
  }

  @override
  Future<List<NewsItem>> getLatestNews() async {
    try {
      // Check if cached news is fresh (less than 30 minutes old)
      if (_lastRefresh != null && _cachedNews.isNotEmpty) {
        final refreshThreshold = _lastRefresh!.add(const Duration(minutes: 30));
        if (DateTime.now().isBefore(refreshThreshold)) {
          debugPrint('Returning cached news (${_cachedNews.length} articles)');
          return _cachedNews;
        }
      }

      // Generate fresh mock news
      await _generateFreshNews();
      debugPrint('Generated fresh news (${_cachedNews.length} articles)');
      return _cachedNews;
    } catch (e) {
      debugPrint('Error getting latest news: $e');
      return _cachedNews.isNotEmpty ? _cachedNews : [];
    }
  }

  @override
  Future<void> addFeed(String feedUrl) async {
    try {
      // Validate URL format (basic check)
      if (!_isValidFeedUrl(feedUrl)) {
        debugPrint('Invalid feed URL: $feedUrl');
        return;
      }

      if (!_mockFeeds.contains(feedUrl)) {
        _mockFeeds.add(feedUrl);
        // Generate some mock articles for this new feed
        await _generateMockArticlesForFeed(feedUrl);
        debugPrint('Added feed: $feedUrl');
      } else {
        debugPrint('Feed already exists: $feedUrl');
      }
    } catch (e) {
      debugPrint('Error adding feed: $e');
    }
  }

  @override
  Future<void> removeFeed(String feedUrl) async {
    try {
      final removed = _mockFeeds.remove(feedUrl);
      if (removed) {
        // Remove articles from this feed
        _cachedNews.removeWhere((article) => article.source.contains(_getFeedName(feedUrl)));
        debugPrint('Removed feed: $feedUrl');
      } else {
        debugPrint('Feed not found for removal: $feedUrl');
      }
    } catch (e) {
      debugPrint('Error removing feed: $e');
    }
  }

  @override
  Future<List<String>> getFeeds() async {
    try {
      debugPrint('Retrieved feeds: ${_mockFeeds.length}');
      return List<String>.from(_mockFeeds);
    } catch (e) {
      debugPrint('Error getting feeds: $e');
      return [];
    }
  }

  @override
  Future<void> refreshFeeds() async {
    try {
      // Generate new mock articles for each feed
      _cachedNews.clear();
      for (final feedUrl in _mockFeeds) {
        await _generateMockArticlesForFeed(feedUrl);
      }
      _lastRefresh = DateTime.now();
      debugPrint('Refreshed all feeds, generated ${_cachedNews.length} articles');
    } catch (e) {
      debugPrint('Error refreshing feeds: $e');
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      _cachedNews.clear();
      _lastRefresh = null;
      debugPrint('News cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Generate fresh mock news from all feeds
  Future<void> _generateFreshNews() async {
    _cachedNews.clear();
    
    // Use base news data from MockDataService
    final mockNewsJson = _mockDataService.getNewsData();
    final baseNews = jsonDecode(mockNewsJson) as List<dynamic>;
    
    // Convert base news to NewsItem objects
    final now = DateTime.now();
    for (int i = 0; i < baseNews.length; i++) {
      final newsData = baseNews[i] as Map<String, dynamic>;
      final newsItem = NewsItem(
        id: '${newsData['title'].hashCode}_${now.millisecondsSinceEpoch}',
        title: newsData['title'] ?? '',
        description: newsData['description'] ?? '',
        link: newsData['url'] ?? '',
        source: newsData['source'] ?? 'Mock News',
        publishedDate: newsData['date'] != null 
            ? DateTime.parse(newsData['date'])
            : now.subtract(Duration(hours: i * 2)),
        cachedAt: now,
        expiresAt: now.add(const Duration(hours: 2)),
        userId: 'mock_user',
        category: _getRandomCategory(),
        tags: _getRandomTags(),
      );
      _cachedNews.add(newsItem);
    }

    // Generate additional articles for variety
    await _generateAdditionalArticles();
    
    // Sort by published date (newest first)
    _cachedNews.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
    
    _lastRefresh = now;
  }

  /// Generate mock articles for a specific feed
  Future<void> _generateMockArticlesForFeed(String feedUrl) async {
    try {
      final feedName = _getFeedName(feedUrl);
      final category = _getCategoryForFeed(feedUrl);
      final now = DateTime.now();
      final articleCount = _random.nextInt(5) + 3; // 3-7 articles per feed

      for (int i = 0; i < articleCount; i++) {
        final publishedTime = now.subtract(Duration(
          hours: _random.nextInt(24),
          minutes: _random.nextInt(60),
        ));

        final article = NewsItem(
          id: '${feedUrl.hashCode}_${publishedTime.millisecondsSinceEpoch}_$i',
          title: _generateMockTitle(category),
          description: _generateMockDescription(category),
          link: _generateMockLink(feedUrl),
          source: feedName,
          author: _getRandomAuthor(),
          category: category,
          publishedDate: publishedTime,
          cachedAt: now,
          expiresAt: now.add(const Duration(hours: 2)),
          userId: 'mock_user',
          tags: _getRandomTags(),
        );

        _cachedNews.add(article);
      }

      debugPrint('Generated $articleCount articles for feed: $feedName');
    } catch (e) {
      debugPrint('Error generating articles for feed: $e');
    }
  }

  /// Generate additional varied articles for more content
  Future<void> _generateAdditionalArticles() async {
    final categories = ['Technology', 'Business', 'Science', 'Health', 'Sports', 'Entertainment'];
    final now = DateTime.now();

    for (final category in categories) {
      final articleCount = _random.nextInt(3) + 1; // 1-3 articles per category
      
      for (int i = 0; i < articleCount; i++) {
        final publishedTime = now.subtract(Duration(
          hours: _random.nextInt(48),
          minutes: _random.nextInt(60),
        ));

        final article = NewsItem(
          id: '${category}_${publishedTime.millisecondsSinceEpoch}_$i',
          title: _generateMockTitle(category),
          description: _generateMockDescription(category),
          link: 'https://example.com/news/${category.toLowerCase()}/$i',
          source: '${category} Daily',
          author: _getRandomAuthor(),
          category: category.toLowerCase(),
          publishedDate: publishedTime,
          cachedAt: now,
          expiresAt: now.add(const Duration(hours: 2)),
          userId: 'mock_user',
          tags: _getRandomTags(),
        );

        _cachedNews.add(article);
      }
    }
  }

  /// Validate feed URL format
  bool _isValidFeedUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && 
           (uri.scheme == 'http' || uri.scheme == 'https') &&
           uri.host.isNotEmpty;
  }

  /// Extract feed name from URL
  String _getFeedName(String feedUrl) {
    try {
      final uri = Uri.parse(feedUrl);
      final host = uri.host;
      
      if (host.contains('techcrunch.com')) return 'TechCrunch';
      if (host.contains('theverge.com')) return 'The Verge';
      if (host.contains('wired.com')) return 'Wired';
      if (host.contains('hackernews') || host.contains('ycombinator')) return 'Hacker News';
      if (host.contains('reddit.com')) return 'Reddit Programming';
      if (host.contains('macrumors.com')) return 'MacRumors';
      
      // Extract domain name as fallback
      return host.replaceAll('www.', '').split('.').first.toUpperCase();
    } catch (e) {
      return 'Unknown Feed';
    }
  }

  /// Get category based on feed URL
  String _getCategoryForFeed(String feedUrl) {
    final feedName = _getFeedName(feedUrl).toLowerCase();
    
    if (feedName.contains('tech') || feedName.contains('hacker') || feedName.contains('programming')) {
      return 'technology';
    }
    if (feedName.contains('business') || feedName.contains('finance')) {
      return 'business';
    }
    if (feedName.contains('science')) {
      return 'science';
    }
    if (feedName.contains('health')) {
      return 'health';
    }
    if (feedName.contains('sports')) {
      return 'sports';
    }
    if (feedName.contains('entertainment')) {
      return 'entertainment';
    }
    
    return 'general';
  }

  /// Generate mock article title based on category
  String _generateMockTitle(String category) {
    final titleTemplates = {
      'technology': [
        'New AI breakthrough promises to revolutionize {}',
        'Major {} update brings improved security features', 
        'Tech giant announces {} integration with cloud services',
        'Startup develops innovative {} solution for enterprises',
        'Study reveals {} adoption trends in modern workplaces',
      ],
      'business': [
        'Company reports {} growth in quarterly earnings',
        'Market analysts predict {} surge in upcoming quarter',
        'New partnership announced between {} companies',
        'Industry leader unveils {} strategy for global expansion',
        'Economic indicators show {} trends in consumer spending',
      ],
      'science': [
        'Researchers discover {} breakthrough in medical field',
        'New study reveals {} impact on climate change',
        'Scientists develop {} technology for space exploration',
        'Clinical trials show promising {} results',
        'Environmental research indicates {} correlation',
      ],
      'general': [
        'Breaking: {} development affects millions',
        'Latest {} report shows significant changes',
        'Experts weigh in on {} implications',
        'New {} guidelines announced by authorities',
        'Community responds to {} initiatives',
      ],
    };

    final templates = titleTemplates[category] ?? titleTemplates['general']!;
    final template = templates[_random.nextInt(templates.length)];
    
    final placeholders = ['significant', 'major', 'important', 'groundbreaking', 'innovative'];
    final placeholder = placeholders[_random.nextInt(placeholders.length)];
    
    return template.replaceFirst('{}', placeholder);
  }

  /// Generate mock article description based on category
  String _generateMockDescription(String category) {
    final descriptions = {
      'technology': [
        'This development represents a significant advancement in the field, with potential applications across multiple industries.',
        'Early adopters are already seeing benefits from this implementation, with more organizations expected to follow suit.',
        'The new features address longstanding concerns while introducing innovative capabilities for users.',
        'Industry experts believe this could be a game-changer for how businesses approach digital transformation.',
      ],
      'business': [
        'The announcement comes amid growing market uncertainty, providing stakeholders with renewed confidence.',
        'This strategic move is expected to strengthen the company\'s position in an increasingly competitive landscape.',
        'Financial analysts view this development as a positive indicator for future growth potential.',
        'The initiative demonstrates the organization\'s commitment to innovation and customer satisfaction.',
      ],
      'science': [
        'The findings could have far-reaching implications for our understanding of this complex phenomenon.',
        'Researchers utilized advanced methodologies to achieve these unprecedented results.',
        'The study builds upon previous work while opening new avenues for investigation.',
        'These discoveries may lead to practical applications that benefit society as a whole.',
      ],
      'general': [
        'Community leaders are working together to address the various aspects of this developing situation.',
        'The initiative aims to create positive change while addressing concerns raised by stakeholders.',
        'Officials are monitoring the situation closely and will provide updates as more information becomes available.',
        'Public response has been generally positive, with many expressing support for the proposed changes.',
      ],
    };

    final categoryDescriptions = descriptions[category] ?? descriptions['general']!;
    return categoryDescriptions[_random.nextInt(categoryDescriptions.length)];
  }

  /// Generate mock link for article
  String _generateMockLink(String feedUrl) {
    try {
      final uri = Uri.parse(feedUrl);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return '${uri.scheme}://${uri.host}/article/${timestamp}';
    } catch (e) {
      return 'https://example.com/news/article';
    }
  }

  /// Get random category
  String _getRandomCategory() {
    final categories = ['technology', 'business', 'science', 'health', 'sports', 'entertainment', 'general'];
    return categories[_random.nextInt(categories.length)];
  }

  /// Get random author name
  String _getRandomAuthor() {
    final authors = [
      'Alex Johnson', 'Sarah Davis', 'Michael Chen', 'Emma Wilson',
      'David Rodriguez', 'Lisa Thompson', 'James Kim', 'Rachel Brown',
      'Tom Anderson', 'Jennifer Lee', 'Chris Taylor', 'Amanda Garcia',
    ];
    return authors[_random.nextInt(authors.length)];
  }

  /// Get random tags for article
  List<String> _getRandomTags() {
    final allTags = [
      'breaking', 'trending', 'analysis', 'update', 'exclusive',
      'research', 'innovation', 'development', 'announcement', 'report',
    ];
    
    final tagCount = _random.nextInt(3) + 1; // 1-3 tags
    final selectedTags = <String>[];
    
    while (selectedTags.length < tagCount && selectedTags.length < allTags.length) {
      final tag = allTags[_random.nextInt(allTags.length)];
      if (!selectedTags.contains(tag)) {
        selectedTags.add(tag);
      }
    }
    
    return selectedTags;
  }
}