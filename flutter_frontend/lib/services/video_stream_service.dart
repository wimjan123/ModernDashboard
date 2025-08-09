import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video_stream.dart';

class VideoStreamService {
  static const int _timeoutSeconds = 10;
  
  /// Validate stream URL
  static Future<bool> validateStreamUrl(String url, String type) async {
    try {
      switch (type) {
        case StreamTypes.youtube:
          return _validateYouTubeUrl(url);
        case StreamTypes.twitch:
          return _validateTwitchUrl(url);
        case StreamTypes.hls:
          return await _validateHLSUrl(url);
        case StreamTypes.rtmp:
          // RTMP validation is complex, just check URL format
          return _validateRTMPUrl(url);
        default:
          return await _validateGenericUrl(url);
      }
    } catch (e) {
      return false;
    }
  }

  /// Validate YouTube URL
  static bool _validateYouTubeUrl(String url) {
    final youtubePatterns = [
      RegExp(r'youtube\.com/watch\?v=[\w-]+'),
      RegExp(r'youtube\.com/embed/[\w-]+'),
      RegExp(r'youtu\.be/[\w-]+'),
      RegExp(r'youtube\.com/channel/[\w-]+'),
      RegExp(r'youtube\.com/user/[\w-]+'),
      RegExp(r'youtube\.com/c/[\w-]+'),
    ];

    return youtubePatterns.any((pattern) => pattern.hasMatch(url));
  }

  /// Validate Twitch URL
  static bool _validateTwitchUrl(String url) {
    final twitchPatterns = [
      RegExp(r'twitch\.tv/[\w-]+'),
      RegExp(r'player\.twitch\.tv/\?channel=[\w-]+'),
    ];

    return twitchPatterns.any((pattern) => pattern.hasMatch(url));
  }

  /// Validate HLS URL
  static Future<bool> _validateHLSUrl(String url) async {
    try {
      if (!url.contains('.m3u8')) return false;

      final response = await http
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: _timeoutSeconds));

      return response.statusCode == 200 &&
          ((response.headers['content-type']?.contains('application/vnd.apple.mpegurl') ?? false) ||
           (response.headers['content-type']?.contains('application/x-mpegURL') ?? false));
    } catch (e) {
      return false;
    }
  }

  /// Validate RTMP URL
  static bool _validateRTMPUrl(String url) {
    return url.startsWith('rtmp://') || url.startsWith('rtmps://');
  }

  /// Validate generic URL
  static Future<bool> _validateGenericUrl(String url) async {
    try {
      final response = await http
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: _timeoutSeconds));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Extract stream info from URL
  static Future<Map<String, String?>> extractStreamInfo(String url) async {
    try {
      if (_validateYouTubeUrl(url)) {
        return await _extractYouTubeInfo(url);
      } else if (_validateTwitchUrl(url)) {
        return await _extractTwitchInfo(url);
      } else {
        return {
          'title': _extractTitleFromUrl(url),
          'thumbnail': null,
          'type': _detectStreamType(url),
        };
      }
    } catch (e) {
      return {
        'title': _extractTitleFromUrl(url),
        'thumbnail': null,
        'type': _detectStreamType(url),
      };
    }
  }

  /// Extract YouTube video info
  static Future<Map<String, String?>> _extractYouTubeInfo(String url) async {
    try {
      final videoId = _extractYouTubeVideoId(url);
      if (videoId == null) {
        return {
          'title': 'YouTube Stream',
          'thumbnail': null,
          'type': StreamTypes.youtube,
        };
      }

      // Use YouTube oEmbed API for basic info
      final oembedUrl = 'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json';
      
      final response = await http
          .get(Uri.parse(oembedUrl))
          .timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'title': data['title'] as String?,
          'thumbnail': data['thumbnail_url'] as String?,
          'type': StreamTypes.youtube,
        };
      }
    } catch (e) {
      // Fallback
    }

    return {
      'title': 'YouTube Stream',
      'thumbnail': null,
      'type': StreamTypes.youtube,
    };
  }

  /// Extract Twitch stream info
  static Future<Map<String, String?>> _extractTwitchInfo(String url) async {
    final channelName = _extractTwitchChannelName(url);
    
    return {
      'title': channelName != null ? 'Twitch - $channelName' : 'Twitch Stream',
      'thumbnail': null, // Would need Twitch API for thumbnail
      'type': StreamTypes.twitch,
    };
  }

  /// Extract YouTube video ID from URL
  static String? _extractYouTubeVideoId(String url) {
    final patterns = [
      RegExp(r'youtube\.com/watch\?v=([\w-]+)'),
      RegExp(r'youtube\.com/embed/([\w-]+)'),
      RegExp(r'youtu\.be/([\w-]+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Extract Twitch channel name from URL
  static String? _extractTwitchChannelName(String url) {
    final patterns = [
      RegExp(r'twitch\.tv/([\w-]+)'),
      RegExp(r'player\.twitch\.tv/\?channel=([\w-]+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Extract title from URL
  static String _extractTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final segments = path.split('/');
      final lastSegment = segments.isNotEmpty ? segments.last : '';
      
      if (lastSegment.isNotEmpty && lastSegment != '/') {
        return lastSegment.split('.').first.replaceAll('-', ' ').replaceAll('_', ' ');
      }
      
      return uri.host;
    } catch (e) {
      return 'Unknown Stream';
    }
  }

  /// Detect stream type from URL
  static String _detectStreamType(String url) {
    if (url.contains('.m3u8')) return StreamTypes.hls;
    if (url.startsWith('rtmp')) return StreamTypes.rtmp;
    if (_validateYouTubeUrl(url)) return StreamTypes.youtube;
    if (_validateTwitchUrl(url)) return StreamTypes.twitch;
    return StreamTypes.generic;
  }

  /// Get popular streams for suggestions
  static List<Map<String, String>> getPopularStreams() {
    return [
      {
        'name': 'NASA Live',
        'url': 'https://www.youtube.com/watch?v=21X5lGlDOfg',
        'type': StreamTypes.youtube,
        'category': 'Science',
      },
      {
        'name': 'Lofi Hip Hop Radio',
        'url': 'https://www.youtube.com/watch?v=jfKfPfyJRdk',
        'type': StreamTypes.youtube,
        'category': 'Music',
      },
      {
        'name': 'BBC News Live',
        'url': 'https://www.youtube.com/watch?v=9Auq9mYxFEE',
        'type': StreamTypes.youtube,
        'category': 'News',
      },
      {
        'name': 'Earth from Space',
        'url': 'https://www.youtube.com/watch?v=DDU-rZs-Ic4',
        'type': StreamTypes.youtube,
        'category': 'Science',
      },
    ];
  }

  /// Convert YouTube URL to embed URL
  static String? convertToEmbedUrl(String url, String type) {
    switch (type) {
      case StreamTypes.youtube:
        final videoId = _extractYouTubeVideoId(url);
        if (videoId != null) {
          return 'https://www.youtube.com/embed/$videoId?autoplay=1&mute=1';
        }
        break;
      case StreamTypes.twitch:
        final channelName = _extractTwitchChannelName(url);
        if (channelName != null) {
          return 'https://player.twitch.tv/?channel=$channelName&parent=localhost';
        }
        break;
    }
    return url;
  }
}