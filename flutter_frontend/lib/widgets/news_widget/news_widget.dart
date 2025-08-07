import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../common/glass_card.dart';
import '../../core/theme/dark_theme.dart';
import '../../repositories/repository_provider.dart';
import '../../repositories/news_repository.dart';

class NewsWidget extends StatefulWidget {
  const NewsWidget({super.key});

  @override
  State<NewsWidget> createState() => _NewsWidgetState();
}

class _NewsWidgetState extends State<NewsWidget> {
  final TextEditingController _feedController = TextEditingController();
  String? _error;
  List<NewsItem> _newsItems = [];
  bool _isLoadingNews = false;
  bool _isRefreshing = false;

  @override
  void dispose() {
    _feedController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    if (_isLoadingNews) return;
    
    setState(() {
      _isLoadingNews = true;
      _error = null;
    });

    try {
      final newsRepository = Provider.of<RepositoryProvider>(context, listen: false).newsRepository;
      final news = await newsRepository.getLatestNews();
      
      setState(() {
        _newsItems = news;
        _isLoadingNews = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoadingNews = false;
        _error = 'Failed to load news: $e';
        _newsItems = [];
      });
    }
  }

  Future<void> _refreshNews() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
      _error = null;
    });

    try {
      final newsRepository = Provider.of<RepositoryProvider>(context, listen: false).newsRepository;
      await newsRepository.refreshFeeds();
      final news = await newsRepository.getLatestNews();
      
      setState(() {
        _newsItems = news;
        _isRefreshing = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isRefreshing = false;
        _error = 'Failed to refresh news: $e';
      });
    }
  }

  Future<void> _addFeed() async {
    final feedUrl = _feedController.text.trim();
    if (feedUrl.isEmpty) return;

    try {
      final newsRepository = Provider.of<RepositoryProvider>(context, listen: false).newsRepository;
      await newsRepository.addFeed(feedUrl);
      _feedController.clear();
      
      setState(() {
        _error = null;
      });
      
      // Refresh news after adding feed
      await _loadNews();
    } catch (e) {
      setState(() {
        _error = 'Failed to add feed: $e';
      });
    }
  }

  Future<void> _openArticle(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        setState(() {
          _error = 'Could not open article link';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to open article: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassInfoCard(
      title: 'Latest News',
      icon: const Icon(
        Icons.article_rounded,
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

          if (_isLoadingNews && _newsItems.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DarkThemeData.accentColor,
              ),
            );
          }

          if (_error != null && _newsItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 32,
                    color: DarkThemeData.errorColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: DarkThemeData.errorColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadNews,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DarkThemeData.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (_newsItems.isEmpty) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.newspaper_outlined,
                  size: 32,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'No news feeds configured',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _feedController,
                        decoration: InputDecoration(
                          hintText: 'Add RSS feed URL...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: DarkThemeData.accentColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onSubmitted: (_) => _addFeed(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addFeed,
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: DarkThemeData.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Column(
            children: [
              // Add feed input and refresh at top
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _feedController,
                        decoration: InputDecoration(
                          hintText: 'Add RSS feed...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: DarkThemeData.accentColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onSubmitted: (_) => _addFeed(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addFeed,
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: DarkThemeData.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _isRefreshing ? null : _refreshNews,
                      icon: _isRefreshing 
                          ? const SizedBox(
                              width: 16, 
                              height: 16, 
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: DarkThemeData.accentColor,
                              )
                            )
                          : const Icon(Icons.refresh_rounded),
                      style: IconButton.styleFrom(
                        foregroundColor: DarkThemeData.accentColor,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),

              // Error display if there are items but error occurred
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: DarkThemeData.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DarkThemeData.errorColor,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _error = null),
                        icon: const Icon(Icons.close_rounded),
                        iconSize: 16,
                        style: IconButton.styleFrom(
                          foregroundColor: DarkThemeData.errorColor,
                          padding: const EdgeInsets.all(4),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // News list
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _newsItems.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFF334155),
                  ),
                  itemBuilder: (context, i) {
                    final article = _newsItems[i];
                    return InkWell(
                      onTap: () => _openArticle(article.link),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              article.title,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (article.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                article.getShortDescription(maxLength: 100),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: DarkThemeData.accentColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    article.source,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: DarkThemeData.accentColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  article.getTimeAgo(),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 16,
                                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
