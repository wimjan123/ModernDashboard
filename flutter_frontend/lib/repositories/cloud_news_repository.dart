import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../firebase/firebase_service.dart';
import '../core/exceptions/feed_validation_exception.dart';
import '../core/services/cors_proxy_service.dart';
import '../core/utils/url_validator.dart';
import '../services/rss_service.dart';
import 'news_repository.dart';

class CloudNewsRepository implements NewsRepository {
  final FirebaseService _firebaseService = FirebaseService.instance;
  
  CollectionReference get _newsCacheCollection => 
      _firebaseService.getUserCollection('news_cache');
      
  CollectionReference get _newsFeedsCollection => 
      _firebaseService.getUserCollection('news_feeds');

  @override
  Future<List<NewsItem>> getLatestNews() async {
    try {
      // Get cached articles
      final cachedNews = await _getCachedNews();
      
      // Check if cache is fresh
      final now = DateTime.now();
      final freshCutoff = now.subtract(const Duration(minutes: 30));
      
      final freshNews = cachedNews
          .where((article) => 
              article.cachedAt != null && 
              article.cachedAt!.isAfter(freshCutoff))
          .toList();
      
      // If we have fresh cached news, return it
      if (freshNews.isNotEmpty) {
        return freshNews;
      }
      
      // Otherwise, refresh feeds and return updated news
      await refreshFeeds();
      return await _getCachedNews();
    } catch (e) {
      // If refresh fails, return whatever cached news we have
      final cachedNews = await _getCachedNews();
      if (cachedNews.isNotEmpty) {
        return cachedNews;
      }
      
      throw Exception('Failed to get news: $e');
    }
  }

  @override
  Future<void> addFeed(String feedUrl) async {
    try {
      if (feedUrl.trim().isEmpty) {
        throw FeedValidationException.invalidUrl(feedUrl, suggestion: 'Please enter a valid RSS feed URL');
      }
      
      final userId = _firebaseService.getUserId();
      if (userId == null) throw Exception('User not authenticated');
      
      // Validate the feed URL using enhanced validation
      await RSSService.validateFeedUrl(feedUrl);
      
      // Check if feed already exists
      final existingFeeds = await _newsFeedsCollection
          .where('url', isEqualTo: feedUrl)
          .get();
      
      if (existingFeeds.docs.isNotEmpty) {
        throw FeedValidationException(
          'duplicate_feed',
          'Feed already exists',
          suggestion: 'This RSS feed has already been added to your collection',
        );
      }
      
      // Try to fetch the feed to validate it and get name
      final feedName = await _validateAndGetFeedName(feedUrl);
      
      final feed = NewsFeed(
        id: '', // Will be set by Firestore
        url: feedUrl,
        name: feedName,
        addedAt: DateTime.now(),
        userId: userId,
      );
      
      await _newsFeedsCollection.add(feed.toJson());
      
      // Fetch articles from the new feed
      await _fetchFeedArticles(feedUrl, feedName);
    } on FeedValidationException {
      rethrow;
    } catch (e) {
      throw FeedValidationException.networkError(feedUrl, details: e.toString());
    }
  }

  @override
  Future<void> removeFeed(String feedUrl) async {
    try {
      // Remove feed document
      final feedDocs = await _newsFeedsCollection
          .where('url', isEqualTo: feedUrl)
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      
      for (final doc in feedDocs.docs) {
        batch.delete(doc.reference);
      }
      
      // Remove cached articles from this feed
      final articleDocs = await _newsCacheCollection
          .where('source', isEqualTo: feedUrl)
          .get();
      
      for (final doc in articleDocs.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to remove feed: $e');
    }
  }

  @override
  Future<List<String>> getFeeds() async {
    try {
      final snapshot = await _newsFeedsCollection
          .where('is_active', isEqualTo: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['url'] as String;
      }).toList();
    } catch (e) {
      throw Exception('Failed to get feeds: $e');
    }
  }

  @override
  Future<void> refreshFeeds() async {
    try {
      final feeds = await _getActiveFeedsData();
      
      for (final feed in feeds) {
        try {
          await _fetchFeedArticles(feed.url, feed.name);
          
          // Update last fetched time
          await _newsFeedsCollection.doc(feed.id).update({
            'last_fetched': DateTime.now().millisecondsSinceEpoch,
          });
        } catch (e) {
          debugPrint('Warning: Failed to refresh feed ${feed.url}: $e');
        }
      }
      
      // Clean up old articles
      await _cleanupOldArticles();
    } catch (e) {
      throw Exception('Failed to refresh feeds: $e');
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      final snapshot = await _newsCacheCollection.get();
      final batch = FirebaseFirestore.instance.batch();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to clear news cache: $e');
    }
  }

  /// Get cached news articles
  Future<List<NewsItem>> _getCachedNews() async {
    try {
      final snapshot = await _newsCacheCollection
          .orderBy('published_date', descending: true)
          .limit(50)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return NewsItem.fromJson(data);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get active feeds data
  Future<List<NewsFeed>> _getActiveFeedsData() async {
    try {
      final snapshot = await _newsFeedsCollection
          .where('is_active', isEqualTo: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return NewsFeed.fromJson(data);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Validate feed URL and get feed name
  Future<String> _validateAndGetFeedName(String feedUrl) async {
    try {
      String content;
      
      // Use appropriate fetching method based on platform
      if (kIsWeb) {
        try {
          final corsProxy = CorsProxyService.instance;
          content = await corsProxy.fetchWithProxy(feedUrl);
        } catch (e) {
          // If CORS proxy fails, try direct request (might work for some feeds)
          final response = await http.get(Uri.parse(feedUrl));
          
          if (response.statusCode != 200) {
            throw FeedValidationException.serverError(feedUrl, response.statusCode);
          }
          
          content = response.body;
        }
      } else {
        // Direct fetch for non-web platforms
        final response = await http.get(Uri.parse(feedUrl));
        
        if (response.statusCode != 200) {
          throw FeedValidationException.serverError(feedUrl, response.statusCode);
        }
        
        content = response.body;
      }
      
      // Validate RSS/Atom content
      final lowerContent = content.toLowerCase();
      if (!lowerContent.contains('<rss') && 
          !lowerContent.contains('<feed') && 
          !lowerContent.contains('<atom') &&
          !lowerContent.contains('<?xml')) {
        throw FeedValidationException.notRssFeed(feedUrl);
      }
      
      // Extract feed title with better parsing
      String? feedName;
      
      // Try channel/feed title first
      final channelTitleMatch = RegExp(r'<channel[^>]*>.*?<title[^>]*>([^<]+)</title>', 
          dotAll: true, caseSensitive: false).firstMatch(content);
      if (channelTitleMatch != null) {
        feedName = channelTitleMatch.group(1)?.trim();
      }
      
      // Try direct title if no channel title found
      if (feedName == null || feedName.isEmpty) {
        final titleMatch = RegExp(r'<title[^>]*>([^<]+)</title>', 
            caseSensitive: false).firstMatch(content);
        feedName = titleMatch?.group(1)?.trim();
      }
      
      // Clean up the feed name
      if (feedName != null) {
        feedName = feedName.replaceAll(RegExp(r'\s+'), ' ').trim();
        // Remove HTML entities
        feedName = feedName
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'");
      }
      
      // Fallback to domain name
      return feedName?.isNotEmpty == true ? feedName! : Uri.parse(feedUrl).host;
      
    } on FeedValidationException {
      rethrow;
    } catch (e) {
      throw FeedValidationException.networkError(feedUrl, details: e.toString());
    }
  }

  /// Fetch articles from a specific feed
  Future<void> _fetchFeedArticles(String feedUrl, String feedName) async {
    try {
      String content;
      
      // Use appropriate fetching method based on platform
      if (kIsWeb) {
        try {
          final corsProxy = CorsProxyService.instance;
          content = await corsProxy.fetchWithProxy(feedUrl);
        } catch (e) {
          debugPrint('CloudNewsRepository: CORS proxy failed for $feedUrl: $e');
          // Don't throw error, just skip fetching articles for this feed
          return;
        }
      } else {
        // Direct fetch for non-web platforms with retry logic
        http.Response response;
        int retryCount = 0;
        const maxRetries = 3;
        
        while (retryCount < maxRetries) {
          try {
            response = await http.get(Uri.parse(feedUrl))
                .timeout(const Duration(seconds: 10));
            
            if (response.statusCode == 200) {
              content = response.body;
              break;
            } else if (response.statusCode >= 500 && retryCount < maxRetries - 1) {
              // Server error, retry after delay
              await Future.delayed(Duration(seconds: (retryCount + 1) * 2));
              retryCount++;
              continue;
            } else {
              throw FeedValidationException.serverError(feedUrl, response.statusCode);
            }
          } catch (e) {
            if (retryCount >= maxRetries - 1) {
              if (e is FeedValidationException) rethrow;
              throw FeedValidationException.networkError(feedUrl, details: e.toString());
            }
            retryCount++;
            await Future.delayed(Duration(seconds: retryCount * 2));
          }
        }
      }
      
      final articles = _parseFeedContent(content, feedUrl, feedName);
      await _cacheArticles(articles);
    } on FeedValidationException catch (e) {
      debugPrint('CloudNewsRepository: Feed validation error for $feedUrl: $e');
      // Don't rethrow, just log the error - other feeds should still work
    } catch (e) {
      debugPrint('CloudNewsRepository: Error fetching articles from $feedUrl: $e');
      // Don't rethrow, just log the error - other feeds should still work
    }
  }

  /// Parse RSS/Atom feed content into NewsItem objects
  List<NewsItem> _parseFeedContent(String content, String feedUrl, String feedName) {
    final articles = <NewsItem>[];
    final now = DateTime.now();
    final userId = _firebaseService.getUserId();
    
    try {
      // Simple regex-based RSS parsing (for production, consider using xml package)
      final itemMatches = RegExp(r'<item[^>]*>(.*?)</item>', dotAll: true)
          .allMatches(content);
      
      for (final itemMatch in itemMatches) {
        final itemContent = itemMatch.group(1) ?? '';
        
        final titleMatch = RegExp(r'<title[^>]*>([^<]+)</title>').firstMatch(itemContent);
        final descMatch = RegExp(r'<description[^>]*>([^<]+)</description>').firstMatch(itemContent);
        final linkMatch = RegExp(r'<link[^>]*>([^<]+)</link>').firstMatch(itemContent);
        final pubDateMatch = RegExp(r'<pubDate[^>]*>([^<]+)</pubDate>').firstMatch(itemContent);
        final authorMatch = RegExp(r'<author[^>]*>([^<]+)</author>').firstMatch(itemContent);
        
        final title = titleMatch?.group(1)?.trim() ?? 'No Title';
        final description = descMatch?.group(1)?.trim() ?? '';
        final link = linkMatch?.group(1)?.trim() ?? '';
        final pubDateStr = pubDateMatch?.group(1)?.trim() ?? '';
        final author = authorMatch?.group(1)?.trim();
        
        // Parse publication date
        DateTime publishedDate;
        try {
          publishedDate = DateTime.parse(pubDateStr);
        } catch (e) {
          publishedDate = now;
        }
        
        // Generate unique ID based on title + link
        final idContent = '$title$link';
        final bytes = utf8.encode(idContent);
        final digest = sha256.convert(bytes);
        final articleId = digest.toString().substring(0, 16);
        
        final article = NewsItem(
          id: articleId,
          title: title,
          description: description,
          link: link,
          source: feedName,
          author: author,
          publishedDate: publishedDate,
          cachedAt: now,
          expiresAt: now.add(const Duration(hours: 2)),
          userId: userId,
        );
        
        articles.add(article);
      }
    } catch (e) {
      debugPrint('Warning: Failed to parse some articles from $feedUrl: $e');
    }
    
    return articles;
  }

  /// Cache articles in Firestore
  Future<void> _cacheArticles(List<NewsItem> articles) async {
    if (articles.isEmpty) return;
    
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (final article in articles) {
        // Check if article already exists
        final existingDoc = await _newsCacheCollection.doc(article.id).get();
        
        if (!existingDoc.exists) {
          final articleData = article.toJson();
          articleData.remove('id'); // ID is used as document ID
          
          batch.set(_newsCacheCollection.doc(article.id), articleData);
        }
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Warning: Failed to cache some articles: $e');
    }
  }

  /// Clean up old cached articles
  Future<void> _cleanupOldArticles() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      
      final snapshot = await _newsCacheCollection
          .where('cached_at', isLessThan: cutoff.millisecondsSinceEpoch)
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Warning: Failed to cleanup old articles: $e');
    }
  }

  /// Get news by category
  Future<List<NewsItem>> getNewsByCategory(String category) async {
    try {
      final snapshot = await _newsCacheCollection
          .where('category', isEqualTo: category)
          .orderBy('published_date', descending: true)
          .limit(20)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return NewsItem.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get news by category: $e');
    }
  }

  /// Search news articles
  Future<List<NewsItem>> searchNews(String query) async {
    try {
      final snapshot = await _newsCacheCollection.get();
      final articles = <NewsItem>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final article = NewsItem.fromJson(data);
        
        if (article.title.toLowerCase().contains(query.toLowerCase()) ||
            article.description.toLowerCase().contains(query.toLowerCase())) {
          articles.add(article);
        }
      }
      
      // Sort by relevance and date
      articles.sort((a, b) {
        final aTitle = a.title.toLowerCase().contains(query.toLowerCase());
        final bTitle = b.title.toLowerCase().contains(query.toLowerCase());
        
        if (aTitle && !bTitle) return -1;
        if (!aTitle && bTitle) return 1;
        
        return b.publishedDate.compareTo(a.publishedDate);
      });
      
      return articles;
    } catch (e) {
      throw Exception('Failed to search news: $e');
    }
  }
}