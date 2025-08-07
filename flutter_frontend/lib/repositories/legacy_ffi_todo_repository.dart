import 'dart:convert';
import '../services/ffi_bridge.dart';
import '../services/cpp_bridge.dart';
import 'todo_repository.dart';

class LegacyFfiTodoRepository implements TodoRepository {
  @override
  Stream<List<TodoItem>> getTodos() async* {
    // Since FFI doesn't provide real-time streams, poll periodically
    while (true) {
      try {
        final todos = await _fetchTodos();
        yield todos;
        
        // Wait 5 seconds before next poll
        await Future.delayed(const Duration(seconds: 5));
      } catch (e) {
        // Continue polling even if one request fails
        yield [];
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  Future<List<TodoItem>> _fetchTodos() async {
    try {
      String jsonData;
      
      if (FfiBridge.isSupported) {
        jsonData = FfiBridge.getTodoData();
      } else {
        jsonData = CppBridge.getTodoData();
      }
      
      if (jsonData.isEmpty) {
        return [];
      }
      
      final decoded = json.decode(jsonData);
      if (decoded is! Map<String, dynamic>) {
        return [];
      }
      
      final items = decoded['items'] as List<dynamic>? ?? [];
      return items.map((item) => _convertFromLegacyFormat(item)).toList();
    } catch (e) {
      throw Exception('Failed to fetch todos from FFI: $e');
    }
  }

  @override
  Future<void> addTodo(TodoItem todo) async {
    try {
      final legacyFormat = _convertToLegacyFormat(todo);
      final jsonData = json.encode(legacyFormat);
      
      bool success;
      if (FfiBridge.isSupported) {
        success = FfiBridge.addTodoItem(jsonData);
      } else {
        success = CppBridge.addTodoItem(jsonData);
      }
      
      if (!success) {
        throw Exception('Failed to add todo via FFI');
      }
    } catch (e) {
      throw Exception('Failed to add todo: $e');
    }
  }

  @override
  Future<void> updateTodo(TodoItem todo) async {
    try {
      final legacyFormat = _convertToLegacyFormat(todo);
      final jsonData = json.encode(legacyFormat);
      
      bool success;
      if (FfiBridge.isSupported) {
        success = FfiBridge.updateTodoItem(jsonData);
      } else {
        success = CppBridge.updateTodoItem(jsonData);
      }
      
      if (!success) {
        throw Exception('Failed to update todo via FFI');
      }
    } catch (e) {
      throw Exception('Failed to update todo: $e');
    }
  }

  @override
  Future<void> deleteTodo(String id) async {
    try {
      bool success;
      if (FfiBridge.isSupported) {
        success = FfiBridge.deleteTodoItem(id);
      } else {
        success = CppBridge.deleteTodoItem(id);
      }
      
      if (!success) {
        throw Exception('Failed to delete todo via FFI');
      }
    } catch (e) {
      throw Exception('Failed to delete todo: $e');
    }
  }

  @override
  Future<void> toggleTodo(String id) async {
    try {
      // Get current todos to find the one to toggle
      final todos = await _fetchTodos();
      final todo = todos.where((t) => t.id == id).firstOrNull;
      
      if (todo == null) {
        throw Exception('Todo not found');
      }
      
      // Toggle status
      final newStatus = todo.status == 'completed' ? 'pending' : 'completed';
      final updatedTodo = todo.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      
      await updateTodo(updatedTodo);
    } catch (e) {
      throw Exception('Failed to toggle todo: $e');
    }
  }

  @override
  Future<List<String>> getCategories() async {
    try {
      final todos = await _fetchTodos();
      final categories = <String>{};
      
      for (final todo in todos) {
        if (todo.category.isNotEmpty) {
          categories.add(todo.category);
        }
      }
      
      return categories.toList()..sort();
    } catch (e) {
      throw Exception('Failed to get categories: $e');
    }
  }

  @override
  Future<Map<String, int>> getStatistics() async {
    try {
      final todos = await _fetchTodos();
      int total = todos.length;
      int completed = 0;
      int pending = 0;
      int overdue = 0;
      final now = DateTime.now();
      
      for (final todo in todos) {
        if (todo.status == 'completed') {
          completed++;
        } else {
          pending++;
          
          if (todo.dueDate != null && now.isAfter(todo.dueDate!)) {
            overdue++;
          }
        }
      }
      
      return {
        'total': total,
        'completed': completed,
        'pending': pending,
        'overdue': overdue,
      };
    } catch (e) {
      throw Exception('Failed to get statistics: $e');
    }
  }

  /// Convert from legacy C++ format to new TodoItem model
  TodoItem _convertFromLegacyFormat(dynamic item) {
    if (item is! Map<String, dynamic>) {
      throw Exception('Invalid todo item format');
    }
    
    return TodoItem(
      id: item['id']?.toString() ?? '',
      title: item['title']?.toString() ?? '',
      description: item['description']?.toString() ?? '',
      category: item['category']?.toString() ?? 'general',
      priority: item['priority']?.toString() ?? 'medium',
      status: item['status']?.toString() ?? 'pending',
      createdAt: item['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(item['created_at'])
          : DateTime.now(),
      updatedAt: item['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(item['updated_at'])
          : DateTime.now(),
      dueDate: item['due_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(item['due_date'])
          : null,
      tags: item['tags'] != null
          ? List<String>.from(item['tags'])
          : [],
    );
  }

  /// Convert to legacy C++ format from TodoItem model
  Map<String, dynamic> _convertToLegacyFormat(TodoItem todo) {
    return {
      'id': todo.id,
      'title': todo.title,
      'description': todo.description,
      'category': todo.category,
      'priority': todo.priority,
      'status': todo.status,
      'created_at': todo.createdAt.millisecondsSinceEpoch,
      'updated_at': todo.updatedAt.millisecondsSinceEpoch,
      'due_date': todo.dueDate?.millisecondsSinceEpoch,
      'tags': todo.tags,
    };
  }
}

extension on List<TodoItem> {
  TodoItem? get firstOrNull => isEmpty ? null : first;
}