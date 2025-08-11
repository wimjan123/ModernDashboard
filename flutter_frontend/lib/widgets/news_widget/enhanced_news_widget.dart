import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../common/glass_card.dart';
import '../../core/theme/dark_theme.dart';
import '../../core/exceptions/feed_validation_exception.dart';
import '../../core/services/cors_proxy_service.dart';
import '../../repositories/repository_provider.dart';
import '../../models/rss_feed.dart';
import '../../services/rss_service.dart';
import 'rss_feed_management_dialog.dart';

class EnhancedNewsWidget extends StatefulWidget {
  const EnhancedNewsWidget({super.key});

  @override
  State<EnhancedNewsWidget> createState() => _EnhancedNewsWidgetState();
}

class _EnhancedNewsWidgetState extends State<EnhancedNewsWidget> {
  final TextEditingController _quickAddController = TextEditingController();
  List<RSSFeed> _feeds = [];
  List<NewsArticle> _articles = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;
  String _selectedCategory = 'All';
  FeedValidationException? _lastValidationError;

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

      // Load feeds and articles in parallel for better performance
      final results = await Future.wait([
        repositoryProvider.rssFeedRepository.getFeeds(),
        repositoryProvider.rssFeedRepository.getAllArticles(),
      ]);

      if (mounted) {
        setState(() {
          _feeds = results[0] as List<RSSFeed>;
          _articles = results[1] as List<NewsArticle>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load news: $e';
        });
      }
    }
  }

  Future<void> _refreshNews() async {
    if (_isRefreshing || !mounted) return;
    
    setState(() {
      _isRefreshing = true;
      _error = null;
    });

    try {
      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);
      
      // Clear RSS service cache to force fresh data
      RSSService.clearAllCache();
      
      // Reload articles
      final articles = await repositoryProvider.rssFeedRepository.getAllArticles();
      
      if (mounted) {
        setState(() {
          _articles = articles;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _error = 'Failed to refresh: $e';
        });
      }
    }
  }

  Future<void> _quickAddFeed() async {
    final url = _quickAddController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _error = null;
      _lastValidationError = null;
    });

    try {
      // Validate URL first using enhanced validation
      await RSSService.validateFeedUrl(url);

      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);
      final newFeed = RSSFeed(
        id: '', // Will be set by repository
        name: _extractFeedName(url),
        url: url,
        category: 'General',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repositoryProvider.rssFeedRepository.addFeed(newFeed);
      _quickAddController.clear();
      
      // Reload data
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('RSS feed added successfully'),
            backgroundColor: DarkThemeData.accentColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on FeedValidationException catch (e) {
      setState(() {
        _lastValidationError = e;
        _error = _getFriendlyErrorMessage(e);
      });
    } catch (e) {
      setState(() {
        _lastValidationError = null;
        _error = 'Failed to add feed: ${e.toString()}';
      });
    }
  }

  /// Convert FeedValidationException to user-friendly error message
  String _getFriendlyErrorMessage(FeedValidationException e) {
    switch (e.code) {
      case 'invalid_url':
        return '${e.userMessage}${e.suggestion != null ? '\n💡 ${e.suggestion}' : ''}';
      case 'cors_blocked':
        return '${e.userMessage}\n💡 This is a browser limitation. You can try using a CORS proxy service.';
      case 'not_rss_feed':
        return '${e.userMessage}\n💡 ${e.suggestion ?? 'Please verify the URL points to an RSS or Atom feed.'}';
      case 'network_error':
        return '${e.userMessage}\n💡 Check your internet connection and try again.';
      case 'timeout':
        return '${e.userMessage}\n💡 The server is taking too long to respond. Try again later.';
      case 'server_error':
        return '${e.userMessage}\n💡 ${e.suggestion ?? 'The server may be temporarily unavailable.'}';
      case 'duplicate_feed':
        return '${e.userMessage}\n💡 ${e.suggestion ?? 'This RSS feed is already in your collection.'}';
      default:
        return e.userMessage;
    }
  }

  /// Try adding feed using CORS proxy (for web platform)
  Future<void> _tryWithProxy() async {
    final url = _quickAddController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _error = null;
    });

    try {
      final corsProxy = CorsProxyService.instance;
      await corsProxy.forceProxyValidation(url);
      
      // If validation succeeds, add the feed
      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);
      final newFeed = RSSFeed(
        id: '', // Will be set by repository
        name: _extractFeedName(url),
        url: url,
        category: 'General',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repositoryProvider.rssFeedRepository.addFeed(newFeed);
      _quickAddController.clear();
      
      setState(() {
        _lastValidationError = null;
      });
      
      // Reload data
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('RSS feed added successfully via proxy'),
            backgroundColor: DarkThemeData.accentColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on FeedValidationException catch (e) {
      setState(() {
        _lastValidationError = e;
        _error = 'Proxy validation failed: ${_getFriendlyErrorMessage(e)}';
      });
    } catch (e) {
      setState(() {
        _lastValidationError = null;
        _error = 'Proxy validation failed: ${e.toString()}';
      });
    }
  }

  String _extractFeedName(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '').split('.').first;
    } catch (e) {
      return 'RSS Feed';
    }
  }

  Future<void> _openManageFeedsDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RSSFeedManagementDialog(feeds: _feeds),
    );
    
    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _openArticle(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Cannot open URL');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open article: $e'),
            backgroundColor: DarkThemeData.errorColor,
          ),
        );
      }
    }
  }

  List<NewsArticle> get _filteredArticles {
    if (_selectedCategory == 'All') return _articles;
    
    final feedsInCategory = _feeds.where((f) => f.category == _selectedCategory);
    final feedIds = feedsInCategory.map((f) => f.id).toSet();
    
    return _articles.where((a) => feedIds.contains(a.feedId)).toList();
  }

  List<String> get _categories {
    final categories = _feeds.map((f) => f.category).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  @override
  Widget build(BuildContext context) {
    return GlassInfoCard(
      title: 'RSS News Feeds',
      icon: Icon(
        Icons.rss_feed_rounded,
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

          if (_isLoading && _articles.isEmpty) {
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
              
              if (_feeds.isEmpty) 
                _buildEmptyState()
              else if (_filteredArticles.isEmpty)
                _buildNoArticlesState()
              else
                _buildArticlesList(),
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
                    hintText: 'Add RSS feed URL...',
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
                  onSubmitted: (_) => _quickAddFeed(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _quickAddFeed,
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
                onPressed: _openManageFeedsDialog,
                icon: const Icon(Icons.settings_rounded, size: 18),
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.7),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                ),
                tooltip: 'Manage feeds',
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _isRefreshing ? null : _refreshNews,
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
              Icons.rss_feed_outlined,
              size: 48,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No RSS feeds configured',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add an RSS feed URL above to get started',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _showPopularFeeds(),
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: const Text('Browse Popular Feeds'),
              style: OutlinedButton.styleFrom(
                foregroundColor: DarkThemeData.accentColor,
                side: const BorderSide(color: DarkThemeData.accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoArticlesState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 48,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No articles available',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try refreshing or check your feed URLs',
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

  Widget _buildArticlesList() {
    return Expanded(
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        itemCount: _filteredArticles.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 0.5,
          color: Colors.white.withValues(alpha: 0.1),
        ),
        itemBuilder: (context, index) => _buildArticleItem(_filteredArticles[index]),
      ),
    );
  }

  Widget _buildArticleItem(NewsArticle article) {
    return InkWell(
      onTap: () => _openArticle(article.url),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Article thumbnail or placeholder
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: DarkThemeData.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: article.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        article.imageUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.article_outlined,
                          color: DarkThemeData.accentColor.withValues(alpha: 0.5),
                          size: 24,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.article_outlined,
                      color: DarkThemeData.accentColor.withValues(alpha: 0.5),
                      size: 24,
                    ),
            ),
            
            const SizedBox(width: 12),
            
            // Article content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  if (article.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      article.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  
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
                          article.feedName,
                          style: TextStyle(
                            color: DarkThemeData.accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      
                      const Spacer(),
                      
                      Text(
                        _getTimeAgo(article.publishedAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                      
                      const SizedBox(width: 4),
                      
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return '${(difference.inDays / 7).floor()}w';
  }

  void _showPopularFeeds() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Popular RSS Feeds',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: RSSService.getPopularFeeds().length,
            itemBuilder: (context, index) {
              final feed = RSSService.getPopularFeeds()[index];
              return ListTile(
                title: Text(
                  feed['name']!,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  feed['url']!,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.add, color: DarkThemeData.accentColor),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    _quickAddController.text = feed['url']!;
                    await _quickAddFeed();
                  },
                ),
                dense: true,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}