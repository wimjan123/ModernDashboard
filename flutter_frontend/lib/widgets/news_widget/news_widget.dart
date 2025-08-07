import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/cpp_bridge.dart';
import '../common/glass_card.dart';
import '../../core/theme/dark_theme.dart';

// Conditional import for FFI (web uses stub)
import '../../services/ffi_bridge.dart' if (dart.library.html) '../../services/ffi_bridge_web.dart';

class NewsItem {
  final String title;
  final String source;
  const NewsItem({required this.title, required this.source});
  factory NewsItem.fromJson(Map<String, dynamic> j) =>
      NewsItem(title: j['title'] as String? ?? '', source: j['source'] as String? ?? '');
}

class NewsWidget extends StatefulWidget {
  const NewsWidget({super.key});

  @override
  State<NewsWidget> createState() => _NewsWidgetState();
}

class _NewsWidgetState extends State<NewsWidget> {
  List<NewsItem> _newsItems = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    try {
      String newsData;
      if (kIsWeb) {
        newsData = CppBridge.getNewsData();
      } else {
        newsData = FfiBridge.isSupported ? FfiBridge.getNewsData() : CppBridge.getNewsData();
      }
      final List<dynamic> jsonData = json.decode(newsData) as List<dynamic>;
      setState(() {
        _isLoading = false;
        _newsItems = jsonData
            .whereType<Map<String, dynamic>>()
            .map(NewsItem.fromJson)
            .toList(growable: false);
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _newsItems = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassInfoCard(
      title: 'Latest News',
      icon: Icon(
        Icons.article_rounded,
        color: DarkThemeData.accentColor,
        size: 20,
      ),
      accentColor: DarkThemeData.accentColor,
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DarkThemeData.accentColor,
              ),
            )
          : _newsItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.newspaper_outlined,
                        size: 32,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No news available',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _newsItems.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFF334155),
                  ),
                  itemBuilder: (context, i) {
                    final n = _newsItems[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: DarkThemeData.accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  n.source,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: DarkThemeData.accentColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Now',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
