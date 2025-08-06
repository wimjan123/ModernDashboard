import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/cpp_bridge.dart';
import '../common/glass_card.dart';
import '../../core/theme/dark_theme.dart';

// Conditional import for FFI (web uses stub)
import '../../services/ffi_bridge.dart' if (dart.library.html) '../../services/ffi_bridge_web.dart';

class TodoItem {
  final String id;
  final String title;
  final bool completed;
  
  const TodoItem({
    required this.id,
    required this.title,
    required this.completed,
  });
  
  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    completed: json['completed'] as bool? ?? false,
  );
}

class TodoWidget extends StatefulWidget {
  const TodoWidget({super.key});

  @override
  State<TodoWidget> createState() => _TodoWidgetState();
}

class _TodoWidgetState extends State<TodoWidget> {
  List<TodoItem> _todoItems = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    try {
      final todoJson = FfiBridge.isSupported ? FfiBridge.getTodoData() : CppBridge.getTodoData();
      final List<dynamic> jsonData = json.decode(todoJson) as List<dynamic>;
      
      setState(() {
        _todoItems = jsonData
            .whereType<Map<String, dynamic>>()
            .map(TodoItem.fromJson)
            .toList(growable: false);
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _todoItems = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassInfoCard(
      title: 'Tasks',
      icon: Icon(
        Icons.checklist_rounded,
        color: DarkThemeData.successColor,
        size: 20,
      ),
      accentColor: DarkThemeData.successColor,
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DarkThemeData.successColor,
              ),
            )
          : _todoItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.task_alt_rounded,
                        size: 32,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No tasks yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _todoItems.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFF334155),
                  ),
                  itemBuilder: (context, i) {
                    final todo = _todoItems[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: todo.completed
                                  ? DarkThemeData.successColor.withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: todo.completed
                                    ? DarkThemeData.successColor
                                    : Theme.of(context).colorScheme.outline,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              todo.completed
                                  ? Icons.check_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: todo.completed
                                  ? DarkThemeData.successColor
                                  : Theme.of(context).colorScheme.outline,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              todo.title,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                decoration: todo.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: todo.completed
                                    ? Theme.of(context).textTheme.bodySmall?.color
                                    : Theme.of(context).textTheme.titleSmall?.color,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}