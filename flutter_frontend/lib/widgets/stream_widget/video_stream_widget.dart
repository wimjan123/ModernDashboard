import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../common/glass_card.dart';
import '../../core/theme/dark_theme.dart';
import '../../repositories/repository_provider.dart';
import '../../models/video_stream.dart';
import 'video_stream_management_dialog.dart';

class VideoStreamWidget extends StatefulWidget {
  const VideoStreamWidget({super.key});

  @override
  State<VideoStreamWidget> createState() => _VideoStreamWidgetState();
}

class _VideoStreamWidgetState extends State<VideoStreamWidget> {
  final TextEditingController _quickAddController = TextEditingController();
  List<VideoStream> _streams = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _quickAddController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);
      if (!repositoryProvider.isInitialized) {
        throw Exception('Repository not initialized');
      }

      final streams = await repositoryProvider.videoStreamRepository.getStreams();

      if (mounted) {
        setState(() {
          _streams = streams;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load streams: $e';
        });
      }
    }
  }

  Future<void> _refreshStreams() async {
    if (_isRefreshing || !mounted) return;
    
    setState(() {
      _isRefreshing = true;
      _error = null;
    });

    try {
      await _loadData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to refresh: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _quickAddStream() async {
    final url = _quickAddController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _error = null;
    });

    try {
      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);
      
      // Determine stream type based on URL
      String streamType = StreamTypes.generic;
      String? thumbnailUrl;
      
      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        streamType = StreamTypes.youtube;
        final videoId = _extractYouTubeVideoId(url);
        if (videoId != null) {
          thumbnailUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
        }
      } else if (url.contains('twitch.tv')) {
        streamType = StreamTypes.twitch;
      } else if (url.endsWith('.m3u8')) {
        streamType = StreamTypes.hls;
      }

      final newStream = VideoStream(
        id: '', // Will be set by repository
        name: _extractStreamName(url),
        url: url,
        type: streamType,
        category: 'General',
        isLive: true,
        thumbnailUrl: thumbnailUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repositoryProvider.videoStreamRepository.addStream(newStream);
      _quickAddController.clear();
      
      // Reload data
      await _loadData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stream added successfully'),
          backgroundColor: DarkThemeData.accentColor,
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to add stream: $e';
      });
    }
  }

  String? _extractYouTubeVideoId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  String _extractStreamName(String url) {
    try {
      final uri = Uri.parse(url);
      
      if (uri.host.contains('youtube.com')) {
        return 'YouTube Stream';
      } else if (uri.host.contains('twitch.tv')) {
        return 'Twitch Stream';
      } else {
        return uri.host.replaceFirst('www.', '').split('.').first;
      }
    } catch (e) {
      return 'Live Stream';
    }
  }

  Future<void> _openManageStreamsDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VideoStreamManagementDialog(streams: _streams),
    );
    
    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _openStream(VideoStream stream) async {
    try {
      final uri = Uri.parse(stream.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Cannot open stream URL');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open stream: $e'),
            backgroundColor: DarkThemeData.errorColor,
          ),
        );
      }
    }
  }

  List<VideoStream> get _filteredStreams {
    if (_selectedCategory == 'All') return _streams;
    return _streams.where((s) => s.category == _selectedCategory).toList();
  }

  List<String> get _categories {
    final categories = _streams.map((s) => s.category).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  @override
  Widget build(BuildContext context) {
    return GlassInfoCard(
      title: 'Live Streams',
      icon: Icon(
        Icons.play_circle_rounded,
        color: DarkThemeData.accentColor,
        size: 20,
      ),
      accentColor: DarkThemeData.accentColor,
      child: Consumer<RepositoryProvider>(
        builder: (context, repositoryProvider, child) {
          if (!repositoryProvider.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DarkThemeData.accentColor,
              ),
            );
          }

          if (_isLoading && _streams.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DarkThemeData.accentColor,
              ),
            );
          }

          return Column(
            children: [
              // Control bar
              _buildControlBar(),
              
              if (_error != null) _buildErrorBanner(),
              
              if (_streams.isEmpty) 
                _buildEmptyState()
              else if (_filteredStreams.isEmpty)
                _buildNoStreamsState()
              else
                _buildStreamsGrid(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControlBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Quick add and controls row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quickAddController,
                  decoration: InputDecoration(
                    hintText: 'Add stream URL...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: DarkThemeData.accentColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onSubmitted: (_) => _quickAddStream(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _quickAddStream,
                icon: const Icon(Icons.add_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: DarkThemeData.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _openManageStreamsDialog,
                icon: const Icon(Icons.settings_rounded, size: 18),
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.7),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                ),
                tooltip: 'Manage streams',
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _isRefreshing ? null : _refreshStreams,
                icon: _isRefreshing 
                    ? SizedBox(
                        width: 16, 
                        height: 16, 
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DarkThemeData.accentColor,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                style: IconButton.styleFrom(
                  foregroundColor: DarkThemeData.accentColor,
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                ),
                tooltip: 'Refresh',
              ),
            ],
          ),
          
          // Category filter
          if (_categories.length > 2) ...[ 
            const SizedBox(height: 12),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;
                  
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = category),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? DarkThemeData.accentColor.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected 
                              ? DarkThemeData.accentColor 
                              : Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected 
                              ? DarkThemeData.accentColor
                              : Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DarkThemeData.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DarkThemeData.errorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_rounded,
            size: 16,
            color: DarkThemeData.errorColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: DarkThemeData.errorColor,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _error = null),
            icon: const Icon(Icons.close_rounded, size: 16),
            style: IconButton.styleFrom(
              foregroundColor: DarkThemeData.errorColor,
              padding: const EdgeInsets.all(4),
              minimumSize: const Size(24, 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No video streams configured',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a stream URL above to get started',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoStreamsState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list_off_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No streams in this category',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try selecting a different category',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamsGrid() {
    return Expanded(
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 16 / 10,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _filteredStreams.length,
        itemBuilder: (context, index) => _buildStreamCard(_filteredStreams[index]),
      ),
    );
  }

  Widget _buildStreamCard(VideoStream stream) {
    return InkWell(
      onTap: () => _openStream(stream),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.05),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Thumbnail/background
              if (stream.thumbnailUrl != null)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: stream.thumbnailUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: DarkThemeData.accentColor.withValues(alpha: 0.1),
                      child: Center(
                        child: Icon(
                          _getStreamTypeIcon(stream.type),
                          color: DarkThemeData.accentColor.withValues(alpha: 0.5),
                          size: 32,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: DarkThemeData.accentColor.withValues(alpha: 0.1),
                      child: Center(
                        child: Icon(
                          _getStreamTypeIcon(stream.type),
                          color: DarkThemeData.accentColor.withValues(alpha: 0.5),
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: Container(
                    color: DarkThemeData.accentColor.withValues(alpha: 0.1),
                    child: Center(
                      child: Icon(
                        _getStreamTypeIcon(stream.type),
                        color: DarkThemeData.accentColor.withValues(alpha: 0.5),
                        size: 32,
                      ),
                    ),
                  ),
                ),

              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Content
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stream.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (stream.isLive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStreamTypeColor(stream.type).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            stream.type.toUpperCase(),
                            style: TextStyle(
                              color: _getStreamTypeColor(stream.type),
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            stream.category,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Play button overlay
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStreamTypeIcon(String type) {
    switch (type) {
      case StreamTypes.youtube:
        return Icons.play_circle_rounded;
      case StreamTypes.twitch:
        return Icons.videocam_rounded;
      case StreamTypes.hls:
        return Icons.live_tv_rounded;
      case StreamTypes.rtmp:
        return Icons.cast_rounded;
      default:
        return Icons.play_circle_outline_rounded;
    }
  }

  Color _getStreamTypeColor(String type) {
    switch (type) {
      case StreamTypes.youtube:
        return const Color(0xFFFF0000);
      case StreamTypes.twitch:
        return const Color(0xFF9146FF);
      case StreamTypes.hls:
        return const Color(0xFF00BCD4);
      case StreamTypes.rtmp:
        return const Color(0xFFFF9800);
      default:
        return DarkThemeData.accentColor;
    }
  }
}