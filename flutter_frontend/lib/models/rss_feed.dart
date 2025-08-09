class RSSFeed {
  final String id;
  final String name;
  final String url;
  final String category;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RSSFeed({
    required this.id,
    required this.name,
    required this.url,
    this.category = 'General',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RSSFeed.fromMap(Map<String, dynamic> map) {
    return RSSFeed(
      id: map['id'] as String,
      name: map['name'] as String,
      url: map['url'] as String,
      category: map['category'] as String? ?? 'General',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'category': category,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  RSSFeed copyWith({
    String? id,
    String? name,
    String? url,
    String? category,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RSSFeed(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RSSFeed && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'RSSFeed(id: $id, name: $name, url: $url, category: $category, isActive: $isActive)';
  }
}

class NewsArticle {
  final String id;
  final String title;
  final String description;
  final String url;
  final String? imageUrl;
  final DateTime publishedAt;
  final String feedId;
  final String feedName;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    this.imageUrl,
    required this.publishedAt,
    required this.feedId,
    required this.feedName,
  });

  factory NewsArticle.fromMap(Map<String, dynamic> map) {
    return NewsArticle(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      url: map['url'] as String,
      imageUrl: map['imageUrl'] as String?,
      publishedAt: DateTime.fromMillisecondsSinceEpoch(map['publishedAt'] as int),
      feedId: map['feedId'] as String,
      feedName: map['feedName'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'url': url,
      'imageUrl': imageUrl,
      'publishedAt': publishedAt.millisecondsSinceEpoch,
      'feedId': feedId,
      'feedName': feedName,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NewsArticle && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}