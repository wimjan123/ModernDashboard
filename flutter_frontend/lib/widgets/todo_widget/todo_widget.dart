import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/cpp_bridge.dart';

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
      final todoJson = CppBridge.getTodoData();
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
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.checklist_outlined),
                SizedBox(width: 8),
                Text('Todo', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _todoItems.isEmpty
                      ? const Center(
                          child: Text(
                            'No tasks yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _todoItems.length,
                          itemBuilder: (context, i) {
                            final todo = _todoItems[i];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                todo.completed 
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: todo.completed 
                                    ? Colors.green 
                                    : Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              title: Text(
                                todo.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  decoration: todo.completed 
                                      ? TextDecoration.lineThrough 
                                      : null,
                                  color: todo.completed 
                                      ? Colors.grey 
                                      : null,
                                ),
                              ),
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