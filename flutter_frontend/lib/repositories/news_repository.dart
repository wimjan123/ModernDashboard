abstract class NewsRepository {
  /// Get latest news articles
  Future<List<NewsItem>> getLatestNews();
  
  /// Add RSS/Atom feed for the user
  Future<void> addFeed(String feedUrl);
  
  /// Remove RSS/Atom feed for the user
  Future<void> removeFeed(String feedUrl);
  
  /// Get user's configured feeds
  Future<List<String>> getFeeds();
  
  /// Force refresh all feeds
  Future<void> refreshFeeds();
  
  /// Clear cached articles
  Future<void> clearCache();
}

class NewsItem {
  final String id;
  final String title;
  final String description;
  final String link;
  final String source;
  final String? author;
  final String category;
  final DateTime publishedDate;
  final DateTime? cachedAt;
  final DateTime? expiresAt;
  final String? userId;
  final String? imageUrl;
  final List<String> tags;

  NewsItem({
    required this.id,
    required this.title,
    required this.description,
    required this.link,
    required this.source,
    this.author,
    this.category = 'general',
    required this.publishedDate,
    this.cachedAt,
    this.expiresAt,
    this.userId,
    this.imageUrl,
    this.tags = const [],
  });

  /// Create NewsItem from JSON (RSS feed or Firestore document)
  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      link: json['link'] ?? '',
      source: json['source'] ?? '',
      author: json['author'],
      category: json['category'] ?? 'general',
      publishedDate: json['published_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['published_date'])
          : DateTime.now(),
      cachedAt: json['cached_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['cached_at'])
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['expires_at'])
          : null,
      userId: json['user_id'],
      imageUrl: json['image_url'],
      tags: List<String>.from(json['tags'] ?? []),
    );
  }

  /// Convert NewsItem to JSON (for caching in Firestore)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'link': link,
      'source': source,
      'author': author,
      'category': category,
      'published_date': publishedDate.millisecondsSinceEpoch,
      'cached_at': cachedAt?.millisecondsSinceEpoch,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'user_id': userId,
      'image_url': imageUrl,
      'tags': tags,
    };
  }

  /// Create a copy with updated fields
  NewsItem copyWith({
    String? id,
    String? title,
    String? description,
    String? link,
    String? source,
    String? author,
    String? category,
    DateTime? publishedDate,
    DateTime? cachedAt,
    DateTime? expiresAt,
    String? userId,
    String? imageUrl,
    List<String>? tags,
  }) {
    return NewsItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      link: link ?? this.link,
      source: source ?? this.source,
      author: author ?? this.author,
      category: category ?? this.category,
      publishedDate: publishedDate ?? this.publishedDate,
      cachedAt: cachedAt ?? this.cachedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      userId: userId ?? this.userId,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
    );
  }

  /// Check if news item is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Check if news item is fresh (less than 30 minutes old cache)
  bool get isFresh {
    if (cachedAt == null) return false;
    final now = DateTime.now();
    final cacheThreshold = cachedAt!.add(const Duration(minutes: 30));
    return now.isBefore(cacheThreshold);
  }

  /// Get time since published
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(publishedDate);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  /// Get shortened description
  String getShortDescription({int maxLength = 150}) {
    if (description.length <= maxLength) return description;
    return '${description.substring(0, maxLength)}...';
  }

  @override
  String toString() {
    return 'NewsItem(title: $title, source: $source, publishedDate: $publishedDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NewsItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class NewsFeed {
  final String id;
  final String url;
  final String name;
  final String category;
  final bool isActive;
  final DateTime addedAt;
  final DateTime? lastFetched;
  final String? userId;

  NewsFeed({
    required this.id,
    required this.url,
    required this.name,
    this.category = 'general',
    this.isActive = true,
    required this.addedAt,
    this.lastFetched,
    this.userId,
  });

  /// Create NewsFeed from JSON
  factory NewsFeed.fromJson(Map<String, dynamic> json) {
    return NewsFeed(
      id: json['id'] ?? '',
      url: json['url'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'general',
      isActive: json['is_active'] ?? true,
      addedAt: json['added_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['added_at'])
          : DateTime.now(),
      lastFetched: json['last_fetched'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['last_fetched'])
          : null,
      userId: json['user_id'],
    );
  }

  /// Convert NewsFeed to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'name': name,
      'category': category,
      'is_active': isActive,
      'added_at': addedAt.millisecondsSinceEpoch,
      'last_fetched': lastFetched?.millisecondsSinceEpoch,
      'user_id': userId,
    };
  }
}