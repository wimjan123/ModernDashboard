import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../firebase/firebase_service.dart';
import '../models/rss_feed.dart';
import '../services/rss_service.dart';

abstract class RSSFeedRepository {
  Future<List<RSSFeed>> getFeeds();
  Future<RSSFeed> addFeed(RSSFeed feed);
  Future<RSSFeed> updateFeed(RSSFeed feed);
  Future<void> deleteFeed(String feedId);
  Future<List<NewsArticle>> getFeedArticles(String feedId);
  Future<List<NewsArticle>> getAllArticles();
  Stream<List<RSSFeed>> watchFeeds();
}

class FirestoreRSSFeedRepository implements RSSFeedRepository {
  static const String _collection = 'rss_feeds';
  
  CollectionReference get _feedsCollection => 
      FirebaseService.instance.getUserCollection(_collection);

  @override
  Future<List<RSSFeed>> getFeeds() async {
    try {
      final snapshot = await _feedsCollection
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => RSSFeed.fromMap({
                ...doc.data() as Map<String, dynamic>,
                'id': doc.id,
              }))
          .toList();
    } catch (e) {
      debugPrint('Error getting feeds: $e');
      return [];
    }
  }

  @override
  Future<RSSFeed> addFeed(RSSFeed feed) async {
    try {
      final docRef = await _feedsCollection.add(feed.toMap());
      return feed.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('Failed to add RSS feed: $e');
    }
  }

  @override
  Future<RSSFeed> updateFeed(RSSFeed feed) async {
    try {
      await _feedsCollection.doc(feed.id).update(
        feed.copyWith(updatedAt: DateTime.now()).toMap(),
      );
      return feed.copyWith(updatedAt: DateTime.now());
    } catch (e) {
      throw Exception('Failed to update RSS feed: $e');
    }
  }

  @override
  Future<void> deleteFeed(String feedId) async {
    try {
      await _feedsCollection.doc(feedId).delete();
    } catch (e) {
      throw Exception('Failed to delete RSS feed: $e');
    }
  }

  @override
  Future<List<NewsArticle>> getFeedArticles(String feedId) async {
    try {
      final feeds = await getFeeds();
      final feed = feeds.firstWhere(
        (f) => f.id == feedId,
        orElse: () => throw Exception('Feed not found'),
      );

      if (!feed.isActive) {
        return [];
      }

      return await RSSService.fetchFeed(feed);
    } catch (e) {
      debugPrint('Error getting feed articles: $e');
      return [];
    }
  }

  @override
  Future<List<NewsArticle>> getAllArticles() async {
    try {
      final feeds = await getFeeds();
      final activeFeeds = feeds.where((f) => f.isActive).toList();
      
      final List<NewsArticle> allArticles = [];
      
      // Fetch articles from all active feeds
      await Future.wait(
        activeFeeds.map((feed) async {
          try {
            final articles = await RSSService.fetchFeed(feed);
            allArticles.addAll(articles);
          } catch (e) {
            debugPrint('Error fetching feed ${feed.name}: $e');
          }
        }),
      );

      // Sort by publication date
      allArticles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      
      return allArticles;
    } catch (e) {
      debugPrint('Error getting all articles: $e');
      return [];
    }
  }

  @override
  Stream<List<RSSFeed>> watchFeeds() {
    return _feedsCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => RSSFeed.fromMap({
                    ...doc.data() as Map<String, dynamic>,
                    'id': doc.id,
                  }))
              .toList();
        });
  }
}

class MockRSSFeedRepository implements RSSFeedRepository {
  static final List<RSSFeed> _feeds = [
    RSSFeed(
      id: '1',
      name: 'Tech News',
      url: 'https://techcrunch.com/feed/',
      category: 'Technology',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    RSSFeed(
      id: '2',
      name: 'BBC News',
      url: 'http://feeds.bbci.co.uk/news/rss.xml',
      category: 'News',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  static final List<NewsArticle> _mockArticles = [
    NewsArticle(
      id: '1',
      title: 'Breaking: New Technology Breakthrough',
      description: 'Scientists have discovered a new way to process data that could revolutionize computing.',
      url: 'https://example.com/article1',
      publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      feedId: '1',
      feedName: 'Tech News',
    ),
    NewsArticle(
      id: '2',
      title: 'Global Markets Update',
      description: 'Stock markets around the world show mixed signals as investors await economic data.',
      url: 'https://example.com/article2',
      publishedAt: DateTime.now().subtract(const Duration(hours: 4)),
      feedId: '2',
      feedName: 'BBC News',
    ),
    NewsArticle(
      id: '3',
      title: 'Climate Change Initiative Launched',
      description: 'International collaboration aims to reduce carbon emissions by 50% in the next decade.',
      url: 'https://example.com/article3',
      publishedAt: DateTime.now().subtract(const Duration(hours: 6)),
      feedId: '2',
      feedName: 'BBC News',
    ),
  ];

  @override
  Future<List<RSSFeed>> getFeeds() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.from(_feeds);
  }

  @override
  Future<RSSFeed> addFeed(RSSFeed feed) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final newFeed = feed.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    _feeds.add(newFeed);
    return newFeed;
  }

  @override
  Future<RSSFeed> updateFeed(RSSFeed feed) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _feeds.indexWhere((f) => f.id == feed.id);
    if (index != -1) {
      _feeds[index] = feed.copyWith(updatedAt: DateTime.now());
      return _feeds[index];
    }
    throw Exception('Feed not found');
  }

  @override
  Future<void> deleteFeed(String feedId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _feeds.removeWhere((f) => f.id == feedId);
  }

  @override
  Future<List<NewsArticle>> getFeedArticles(String feedId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockArticles.where((a) => a.feedId == feedId).toList();
  }

  @override
  Future<List<NewsArticle>> getAllArticles() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.from(_mockArticles);
  }

  @override
  Stream<List<RSSFeed>> watchFeeds() {
    return Stream.value(_feeds);
  }
}