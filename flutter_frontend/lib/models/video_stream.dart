class VideoStream {
  final String id;
  final String name;
  final String url;
  final String type; // 'hls', 'rtmp', 'youtube', 'twitch', 'generic'
  final String? thumbnailUrl;
  final String category;
  final bool isActive;
  final bool isLive;
  final String? quality; // '720p', '1080p', 'auto'
  final DateTime createdAt;
  final DateTime updatedAt;

  const VideoStream({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.thumbnailUrl,
    this.category = 'Entertainment',
    this.isActive = true,
    this.isLive = false,
    this.quality = 'auto',
    required this.createdAt,
    required this.updatedAt,
  });

  factory VideoStream.fromMap(Map<String, dynamic> map) {
    return VideoStream(
      id: map['id'] as String,
      name: map['name'] as String,
      url: map['url'] as String,
      type: map['type'] as String,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      category: map['category'] as String? ?? 'Entertainment',
      isActive: map['isActive'] as bool? ?? true,
      isLive: map['isLive'] as bool? ?? false,
      quality: map['quality'] as String? ?? 'auto',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type,
      'thumbnailUrl': thumbnailUrl,
      'category': category,
      'isActive': isActive,
      'isLive': isLive,
      'quality': quality,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  VideoStream copyWith({
    String? id,
    String? name,
    String? url,
    String? type,
    String? thumbnailUrl,
    String? category,
    bool? isActive,
    bool? isLive,
    String? quality,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VideoStream(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      type: type ?? this.type,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      isLive: isLive ?? this.isLive,
      quality: quality ?? this.quality,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayQuality => quality ?? 'auto';

  bool get isYouTube => type == 'youtube' || url.contains('youtube.com') || url.contains('youtu.be');
  bool get isTwitch => type == 'twitch' || url.contains('twitch.tv');
  bool get isHLS => type == 'hls' || url.contains('.m3u8');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoStream && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'VideoStream(id: $id, name: $name, type: $type, isLive: $isLive)';
  }
}

// Predefined stream categories
class StreamCategories {
  static const List<String> all = [
    'Entertainment',
    'News',
    'Sports',
    'Gaming',
    'Music',
    'Technology',
    'Education',
    'Lifestyle',
    'Custom',
  ];
}

// Common stream types
class StreamTypes {
  static const String hls = 'hls';
  static const String rtmp = 'rtmp';
  static const String youtube = 'youtube';
  static const String twitch = 'twitch';
  static const String generic = 'generic';

  static const List<String> all = [
    hls,
    rtmp,
    youtube,
    twitch,
    generic,
  ];

  static String getDisplayName(String type) {
    switch (type) {
      case hls:
        return 'HLS Stream';
      case rtmp:
        return 'RTMP Stream';
      case youtube:
        return 'YouTube';
      case twitch:
        return 'Twitch';
      case generic:
        return 'Generic Stream';
      default:
        return 'Unknown';
    }
  }
}