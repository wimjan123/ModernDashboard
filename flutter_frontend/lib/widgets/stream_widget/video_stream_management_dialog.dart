import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/dark_theme.dart';
import '../../repositories/repository_provider.dart';
import '../../models/video_stream.dart';

class VideoStreamManagementDialog extends StatefulWidget {
  final List<VideoStream> streams;

  const VideoStreamManagementDialog({
    super.key,
    required this.streams,
  });

  @override
  State<VideoStreamManagementDialog> createState() => _VideoStreamManagementDialogState();
}

class _VideoStreamManagementDialogState extends State<VideoStreamManagementDialog> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  
  List<VideoStream> _streams = [];
  bool _isLoading = false;
  String? _error;
  VideoStream? _editingStream;
  bool _showAddForm = false;
  String _selectedType = StreamTypes.generic;

  @override
  void initState() {
    super.initState();
    _streams = List.from(widget.streams);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _urlController.clear();
    _nameController.clear();
    _categoryController.clear();
    _selectedType = StreamTypes.generic;
    _editingStream = null;
  }

  void _showAddStreamForm() {
    setState(() {
      _showAddForm = true;
      _clearForm();
      _error = null;
    });
  }

  void _hideAddForm() {
    setState(() {
      _showAddForm = false;
      _clearForm();
      _error = null;
    });
  }

  void _editStream(VideoStream stream) {
    setState(() {
      _editingStream = stream;
      _showAddForm = true;
      _urlController.text = stream.url;
      _nameController.text = stream.name;
      _categoryController.text = stream.category;
      _selectedType = stream.type;
      _error = null;
    });
  }

  Future<void> _saveStream() async {
    final url = _urlController.text.trim();
    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();

    if (url.isEmpty) {
      setState(() {
        _error = 'Stream URL is required';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);
      
      // Auto-detect stream type if generic is selected
      String finalType = _selectedType;
      String? thumbnailUrl;
      
      if (_selectedType == StreamTypes.generic) {
        if (url.contains('youtube.com') || url.contains('youtu.be')) {
          finalType = StreamTypes.youtube;
          final videoId = _extractYouTubeVideoId(url);
          if (videoId != null) {
            thumbnailUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
          }
        } else if (url.contains('twitch.tv')) {
          finalType = StreamTypes.twitch;
        } else if (url.endsWith('.m3u8')) {
          finalType = StreamTypes.hls;
        } else if (url.contains('rtmp://')) {
          finalType = StreamTypes.rtmp;
        }
      }

      if (_editingStream != null) {
        // Update existing stream
        final updatedStream = _editingStream!.copyWith(
          url: url,
          name: name.isNotEmpty ? name : _extractStreamName(url),
          category: category.isNotEmpty ? category : 'General',
          type: finalType,
          thumbnailUrl: thumbnailUrl ?? _editingStream!.thumbnailUrl,
          updatedAt: DateTime.now(),
        );

        await repositoryProvider.videoStreamRepository.updateStream(updatedStream);
        
        final index = _streams.indexWhere((s) => s.id == _editingStream!.id);
        if (index != -1) {
          _streams[index] = updatedStream;
        }
      } else {
        // Add new stream
        final newStream = VideoStream(
          id: '', // Will be set by repository
          name: name.isNotEmpty ? name : _extractStreamName(url),
          url: url,
          type: finalType,
          category: category.isNotEmpty ? category : 'General',
          isLive: true,
          thumbnailUrl: thumbnailUrl,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final addedStream = await repositoryProvider.videoStreamRepository.addStream(newStream);
        _streams.add(addedStream);
      }

      _hideAddForm();
    } catch (e) {
      setState(() {
        _error = 'Failed to save stream: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  Future<void> _deleteStream(VideoStream stream) async {
    final confirmed = await _showDeleteConfirmation(stream.name);
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);
      await repositoryProvider.videoStreamRepository.deleteStream(stream.id);
      
      setState(() {
        _streams.removeWhere((s) => s.id == stream.id);
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to delete stream: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _showDeleteConfirmation(String streamName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Video Stream',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "$streamName"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: DarkThemeData.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        height: 700,
        decoration: BoxDecoration(
          color: DarkThemeData.cardColor.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_rounded,
                    color: DarkThemeData.accentColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Manage Video Streams',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!_showAddForm)
                    IconButton(
                      onPressed: _showAddStreamForm,
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: DarkThemeData.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(36, 36),
                      ),
                      tooltip: 'Add Video Stream',
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.7),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ],
              ),
            ),

            // Error display
            if (_error != null)
              Container(
                margin: const EdgeInsets.all(16),
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
              ),

            // Content
            Expanded(
              child: _showAddForm ? _buildAddForm() : _buildStreamsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _editingStream != null ? 'Edit Video Stream' : 'Add New Video Stream',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: _hideAddForm,
                child: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // URL field
          Text(
            'Stream URL *',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'https://youtube.com/watch?v=... or rtmp://...',
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Name field
          Text(
            'Display Name',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Friendly name (auto-generated if empty)',
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Category field
          Text(
            'Category',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _categoryController,
            decoration: InputDecoration(
              hintText: 'e.g., Gaming, Music, News (defaults to General)',
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Stream type field
          Text(
            'Stream Type',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: InputDecoration(
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            dropdownColor: Colors.grey[800],
            style: const TextStyle(color: Colors.white, fontSize: 14),
            items: [
              DropdownMenuItem(
                value: StreamTypes.generic,
                child: Text('Auto-detect', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: StreamTypes.youtube,
                child: Text('YouTube', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: StreamTypes.twitch,
                child: Text('Twitch', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: StreamTypes.hls,
                child: Text('HLS (.m3u8)', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: StreamTypes.rtmp,
                child: Text('RTMP', style: TextStyle(color: Colors.white)),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedType = value ?? StreamTypes.generic;
              });
            },
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveStream,
              style: ElevatedButton.styleFrom(
                backgroundColor: DarkThemeData.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_editingStream != null ? 'Update Stream' : 'Add Stream'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamsList() {
    if (_streams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              size: 64,
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
              'Add your first video stream to get started',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _streams.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 0.5,
        color: Colors.white.withValues(alpha: 0.1),
      ),
      itemBuilder: (context, index) {
        final stream = _streams[index];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, right: 12),
                decoration: BoxDecoration(
                  color: stream.isLive ? Colors.red : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stream.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStreamTypeColor(stream.type).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            stream.type.toUpperCase(),
                            style: TextStyle(
                              color: _getStreamTypeColor(stream.type),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stream.url,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: DarkThemeData.accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            stream.category,
                            style: TextStyle(
                              color: DarkThemeData.accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Updated ${_getTimeAgo(stream.updatedAt)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _editStream(stream),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.7),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                    tooltip: 'Edit stream',
                  ),
                  IconButton(
                    onPressed: () => _deleteStream(stream),
                    icon: const Icon(Icons.delete_rounded, size: 18),
                    style: IconButton.styleFrom(
                      foregroundColor: DarkThemeData.errorColor.withValues(alpha: 0.8),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                    tooltip: 'Delete stream',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${(difference.inDays / 7).floor()}w ago';
  }
}