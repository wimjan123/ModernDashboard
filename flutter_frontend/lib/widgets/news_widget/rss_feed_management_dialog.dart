import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../common/glass_card.dart';
import '../../core/theme/dark_theme.dart';
import '../../repositories/repository_provider.dart';
import '../../models/rss_feed.dart';
import '../../services/rss_service.dart';

class RSSFeedManagementDialog extends StatefulWidget {
  final List<RSSFeed> feeds;

  const RSSFeedManagementDialog({
    super.key,
    required this.feeds,
  });

  @override
  State<RSSFeedManagementDialog> createState() => _RSSFeedManagementDialogState();
}

class _RSSFeedManagementDialogState extends State<RSSFeedManagementDialog> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  
  List<RSSFeed> _feeds = [];
  bool _isLoading = false;
  String? _error;
  RSSFeed? _editingFeed;
  bool _showAddForm = false;

  @override
  void initState() {
    super.initState();
    _feeds = List.from(widget.feeds);
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
    _editingFeed = null;
  }

  void _showAddFeedForm() {
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

  void _editFeed(RSSFeed feed) {
    setState(() {
      _editingFeed = feed;
      _showAddForm = true;
      _urlController.text = feed.url;
      _nameController.text = feed.name;
      _categoryController.text = feed.category;
      _error = null;
    });
  }

  Future<void> _saveFeed() async {
    final url = _urlController.text.trim();
    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();

    if (url.isEmpty) {
      setState(() {
        _error = 'RSS URL is required';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Validate URL first
      if (!await RSSService.validateFeedUrl(url)) {
        throw Exception('Invalid RSS feed URL');
      }

      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);

      if (_editingFeed != null) {
        // Update existing feed
        final updatedFeed = _editingFeed!.copyWith(
          url: url,
          name: name.isNotEmpty ? name : _extractFeedName(url),
          category: category.isNotEmpty ? category : 'General',
          updatedAt: DateTime.now(),
        );

        await repositoryProvider.rssFeedRepository.updateFeed(updatedFeed);
        
        final index = _feeds.indexWhere((f) => f.id == _editingFeed!.id);
        if (index != -1) {
          _feeds[index] = updatedFeed;
        }
      } else {
        // Add new feed
        final newFeed = RSSFeed(
          id: '', // Will be set by repository
          name: name.isNotEmpty ? name : _extractFeedName(url),
          url: url,
          category: category.isNotEmpty ? category : 'General',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final addedFeed = await repositoryProvider.rssFeedRepository.addFeed(newFeed);
        _feeds.add(addedFeed);
      }

      _hideAddForm();
    } catch (e) {
      setState(() {
        _error = 'Failed to save feed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteFeed(RSSFeed feed) async {
    final confirmed = await _showDeleteConfirmation(feed.name);
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);
      await repositoryProvider.rssFeedRepository.deleteFeed(feed.id);
      
      setState(() {
        _feeds.removeWhere((f) => f.id == feed.id);
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to delete feed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _showDeleteConfirmation(String feedName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete RSS Feed',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "$feedName"?',
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

  String _extractFeedName(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '').split('.').first;
    } catch (e) {
      return 'RSS Feed';
    }
  }

  void _addPopularFeed(Map<String, String> feedData) {
    setState(() {
      _showAddForm = true;
      _clearForm();
      _urlController.text = feedData['url']!;
      _nameController.text = feedData['name']!;
      _categoryController.text = feedData['category'] ?? 'General';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        height: 700,
        decoration: BoxDecoration(
          color: DarkThemeData.cardColor.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
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
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.rss_feed_rounded,
                    color: DarkThemeData.accentColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Manage RSS Feeds',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!_showAddForm)
                    IconButton(
                      onPressed: _showAddFeedForm,
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: DarkThemeData.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(36, 36),
                      ),
                      tooltip: 'Add RSS Feed',
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.7),
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
                  color: DarkThemeData.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DarkThemeData.errorColor.withOpacity(0.3)),
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
              child: _showAddForm ? _buildAddForm() : _buildFeedsList(),
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
                  _editingFeed != null ? 'Edit RSS Feed' : 'Add New RSS Feed',
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
            'RSS URL *',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'https://example.com/rss.xml',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
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
              color: Colors.white.withOpacity(0.8),
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
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
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
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _categoryController,
            decoration: InputDecoration(
              hintText: 'e.g., Tech, News, Sports (defaults to General)',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: DarkThemeData.accentColor),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveFeed,
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
                  : Text(_editingFeed != null ? 'Update Feed' : 'Add Feed'),
            ),
          ),
          const SizedBox(height: 20),

          // Popular feeds section
          if (!_isLoading && _editingFeed == null) ...[
            Divider(color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text(
              'Popular RSS Feeds',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ...RSSService.getPopularFeeds().map((feed) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _addPopularFeed(feed),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feed['name']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              feed['url']!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.add_rounded,
                        color: DarkThemeData.accentColor,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            )).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedsList() {
    if (_feeds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rss_feed_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No RSS feeds configured',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first RSS feed to get started',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _feeds.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 0.5,
        color: Colors.white.withOpacity(0.1),
      ),
      itemBuilder: (context, index) {
        final feed = _feeds[index];
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
                  color: feed.isActive ? DarkThemeData.accentColor : Colors.grey,
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
                            feed.name,
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
                            color: DarkThemeData.accentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            feed.category,
                            style: TextStyle(
                              color: DarkThemeData.accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feed.url,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Updated ${_getTimeAgo(feed.updatedAt)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _editFeed(feed),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.7),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                    tooltip: 'Edit feed',
                  ),
                  IconButton(
                    onPressed: () => _deleteFeed(feed),
                    icon: const Icon(Icons.delete_rounded, size: 18),
                    style: IconButton.styleFrom(
                      foregroundColor: DarkThemeData.errorColor.withOpacity(0.8),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                    tooltip: 'Delete feed',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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