import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/cpp_bridge.dart';

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
      final newsData = CppBridge.getNewsData();
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
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.article_outlined),
                SizedBox(width: 8),
                Text('News', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : ListView.builder(
                      itemCount: _newsItems.length,
                      itemBuilder: (context, i) {
                        final n = _newsItems[i];
                        return ListTile(
                          dense: true,
                          title: Text(n.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(n.source, maxLines: 1, overflow: TextOverflow.ellipsis),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
