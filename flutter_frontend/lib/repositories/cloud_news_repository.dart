import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../firebase/firebase_service.dart';
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
        throw Exception('Feed URL cannot be empty');
      }
      
      final userId = _firebaseService.getUserId();
      if (userId == null) throw Exception('User not authenticated');
      
      // Check if feed already exists
      final existingFeeds = await _newsFeedsCollection
          .where('url', isEqualTo: feedUrl)
          .get();
      
      if (existingFeeds.docs.isNotEmpty) {
        throw Exception('Feed already added');
      }
      
      // Try to fetch the feed to validate it
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
    } catch (e) {
      throw Exception('Failed to add feed: $e');
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
      final response = await http.get(Uri.parse(feedUrl));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch feed: ${response.statusCode}');
      }
      
      final content = response.body;
      
      // Simple RSS/Atom validation and name extraction
      if (!content.contains('<rss') && !content.contains('<feed')) {
        throw Exception('URL does not appear to be a valid RSS/Atom feed');
      }
      
      // Extract feed title
      final titleMatch = RegExp(r'<title[^>]*>([^<]+)</title>').firstMatch(content);
      final feedName = titleMatch?.group(1)?.trim() ?? Uri.parse(feedUrl).host;
      
      return feedName;
    } catch (e) {
      throw Exception('Invalid feed URL: $e');
    }
  }

  /// Fetch articles from a specific feed
  Future<void> _fetchFeedArticles(String feedUrl, String feedName) async {
    try {
      final response = await http.get(Uri.parse(feedUrl));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch feed: ${response.statusCode}');
      }
      
      final articles = _parseFeedContent(response.body, feedUrl, feedName);
      await _cacheArticles(articles);
    } catch (e) {
      throw Exception('Failed to fetch articles from $feedUrl: $e');
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