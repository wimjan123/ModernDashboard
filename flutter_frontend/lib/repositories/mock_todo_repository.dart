import 'dart:async';
import 'package:flutter/foundation.dart';
import 'todo_repository.dart';
import '../services/mock_data_service.dart';

/// Mock Todo Repository that provides functional offline experience
/// Uses MockDataService for realistic sample data and state management
class MockTodoRepository implements TodoRepository {
  final MockDataService _mockDataService = MockDataService();
  final StreamController<List<TodoItem>> _todosController = StreamController<List<TodoItem>>.broadcast();

  MockTodoRepository() {
    _mockDataService.initialize();
    _emitTodos();
  }
  /// Emit current todos to the stream
  void _emitTodos() {
    try {
      final todos = _mockDataService.todoItems.map((json) {
        // Convert mock data format to TodoItem format
        final todoJson = {
          'id': json['id'],
          'title': json['title'],
          'description': json['description'] ?? '',
          'category': json['category'],
          'priority': json['priority'],
          'status': json['completed'] == true ? 'completed' : 'pending',
          'created_at': json['createdAt'] != null 
              ? (json['createdAt'] as int) * 1000 // Convert from seconds to milliseconds
              : DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'due_date': json['dueDate'] != null 
              ? (json['dueDate'] as int) * 1000 // Convert from seconds to milliseconds
              : null,
          'tags': <String>[],
          'user_id': 'mock_user',
        };
        return TodoItem.fromJson(todoJson);
      }).toList();
      
      _todosController.add(todos);
      debugPrint('Emitted ${todos.length} todos to stream');
    } catch (e) {
      debugPrint('Error emitting todos: $e');
      _todosController.add([]);
    }
  }

  @override
  Stream<List<TodoItem>> getTodos() {
    return _todosController.stream;
  }

  @override
  Future<void> addTodo(TodoItem todo) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final newTodo = {
        'id': id,
        'title': todo.title,
        'description': todo.description,
        'category': todo.category,
        'priority': todo.priority,
        'completed': todo.status == 'completed',
        'createdAt': DateTime.now().millisecondsSinceEpoch ~/ 1000, // Store as seconds
        'dueDate': todo.dueDate != null ? todo.dueDate!.millisecondsSinceEpoch ~/ 1000 : null, // Store as seconds
      };
      
      _mockDataService.todoItems.add(newTodo);
      _emitTodos();
      debugPrint('Added todo: ${todo.title}');
    } catch (e) {
      debugPrint('Error adding todo: $e');
    }
  }

  @override
  Future<void> updateTodo(TodoItem todo) async {
    try {
      final index = _mockDataService.todoItems.indexWhere((item) => item['id'] == todo.id);
      if (index != -1) {
        _mockDataService.todoItems[index] = {
          'id': todo.id,
          'title': todo.title,
          'description': todo.description,
          'category': todo.category,
          'priority': todo.priority,
          'completed': todo.status == 'completed',
          'createdAt': todo.createdAt.millisecondsSinceEpoch ~/ 1000, // Store as seconds
          'dueDate': todo.dueDate != null ? todo.dueDate!.millisecondsSinceEpoch ~/ 1000 : null, // Store as seconds
        };
        _emitTodos();
        debugPrint('Updated todo: ${todo.title}');
      } else {
        debugPrint('Todo not found for update: ${todo.id}');
      }
    } catch (e) {
      debugPrint('Error updating todo: $e');
    }
  }

  @override
  Future<void> deleteTodo(String id) async {
    try {
      final initialLength = _mockDataService.todoItems.length;
      _mockDataService.todoItems.removeWhere((item) => item['id'] == id);
      
      if (_mockDataService.todoItems.length < initialLength) {
        _emitTodos();
        debugPrint('Deleted todo: $id');
      } else {
        debugPrint('Todo not found for deletion: $id');
      }
    } catch (e) {
      debugPrint('Error deleting todo: $e');
    }
  }

  @override
  Future<void> toggleTodo(String id) async {
    try {
      final index = _mockDataService.todoItems.indexWhere((item) => item['id'] == id);
      if (index != -1) {
        final currentCompleted = _mockDataService.todoItems[index]['completed'] == true;
        _mockDataService.todoItems[index]['completed'] = !currentCompleted;
        _emitTodos();
        debugPrint('Toggled todo: $id to ${!currentCompleted ? "completed" : "pending"}');
      } else {
        debugPrint('Todo not found for toggle: $id');
      }
    } catch (e) {
      debugPrint('Error toggling todo: $e');
    }
  }

  Future<List<TodoItem>> searchTodos(String query) async {
    try {
      final queryLower = query.toLowerCase();
      final filteredItems = _mockDataService.todoItems.where((item) {
        final title = (item['title'] ?? '').toString().toLowerCase();
        final description = (item['description'] ?? '').toString().toLowerCase();
        return title.contains(queryLower) || description.contains(queryLower);
      });
      
      final todos = filteredItems.map((json) {
        final todoJson = {
          'id': json['id'],
          'title': json['title'],
          'description': json['description'] ?? '',
          'category': json['category'],
          'priority': json['priority'],
          'status': json['completed'] == true ? 'completed' : 'pending',
          'created_at': json['createdAt'] != null 
              ? (json['createdAt'] as int) * 1000
              : DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'due_date': json['dueDate'] != null 
              ? (json['dueDate'] as int) * 1000
              : null,
          'tags': <String>[],
          'user_id': 'mock_user',
        };
        return TodoItem.fromJson(todoJson);
      }).toList();
      
      debugPrint('Search "$query" returned ${todos.length} results');
      return todos;
    } catch (e) {
      debugPrint('Error searching todos: $e');
      return [];
    }
  }

  @override
  Future<Map<String, int>> getStatistics() async {
    try {
      final total = _mockDataService.todoItems.length;
      final completed = _mockDataService.todoItems.where((item) => item['completed'] == true).length;
      final pending = total - completed;
      
      // Calculate overdue items
      final now = DateTime.now();
      final overdue = _mockDataService.todoItems.where((item) {
        if (item['completed'] == true) return false; // Completed todos can't be overdue
        if (item['dueDate'] == null) return false;
        final dueDate = DateTime.fromMillisecondsSinceEpoch((item['dueDate'] as int) * 1000);
        return dueDate.isBefore(now);
      }).length;
      
      final stats = {
        'total': total,
        'completed': completed,
        'pending': pending,
        'overdue': overdue,
      };
      
      debugPrint('Todo statistics: $stats');
      return stats;
    } catch (e) {
      debugPrint('Error getting statistics: $e');
      return {
        'total': 0,
        'completed': 0,
        'pending': 0,
        'overdue': 0,
      };
    }
  }

  @override
  Future<List<String>> getCategories() async {
    try {
      final categories = _mockDataService.todoItems
          .map((item) => item['category']?.toString() ?? 'general')
          .toSet()
          .toList();
      
      // Add default categories if none exist
      if (categories.isEmpty) {
        categories.addAll(['general', 'work', 'personal']);
      }
      
      categories.sort();
      debugPrint('Available categories: $categories');
      return categories;
    } catch (e) {
      debugPrint('Error getting categories: $e');
      return ['general', 'work', 'personal'];
    }
  }

  Future<List<TodoItem>> getTodosByCategory(String category) async {
    try {
      final filteredItems = _mockDataService.todoItems.where((item) {
        return (item['category']?.toString() ?? 'general') == category;
      });
      
      final todos = filteredItems.map((json) {
        final todoJson = {
          'id': json['id'],
          'title': json['title'],
          'description': json['description'] ?? '',
          'category': json['category'],
          'priority': json['priority'],
          'status': json['completed'] == true ? 'completed' : 'pending',
          'created_at': json['createdAt'] != null 
              ? (json['createdAt'] as int) * 1000
              : DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'due_date': json['dueDate'] != null 
              ? (json['dueDate'] as int) * 1000
              : null,
          'tags': <String>[],
          'user_id': 'mock_user',
        };
        return TodoItem.fromJson(todoJson);
      }).toList();
      
      debugPrint('Category "$category" has ${todos.length} todos');
      return todos;
    } catch (e) {
      debugPrint('Error getting todos by category: $e');
      return [];
    }
  }

  Future<List<TodoItem>> getTodosByPriority(String priority) async {
    try {
      final filteredItems = _mockDataService.todoItems.where((item) {
        return (item['priority']?.toString() ?? 'medium') == priority;
      });
      
      final todos = filteredItems.map((json) {
        final todoJson = {
          'id': json['id'],
          'title': json['title'],
          'description': json['description'] ?? '',
          'category': json['category'],
          'priority': json['priority'],
          'status': json['completed'] == true ? 'completed' : 'pending',
          'created_at': json['createdAt'] != null 
              ? (json['createdAt'] as int) * 1000
              : DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'due_date': json['dueDate'] != null 
              ? (json['dueDate'] as int) * 1000
              : null,
          'tags': <String>[],
          'user_id': 'mock_user',
        };
        return TodoItem.fromJson(todoJson);
      }).toList();
      
      debugPrint('Priority "$priority" has ${todos.length} todos');
      return todos;
    } catch (e) {
      debugPrint('Error getting todos by priority: $e');
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
    _todosController.close();
    debugPrint('MockTodoRepository disposed');
  }
}
