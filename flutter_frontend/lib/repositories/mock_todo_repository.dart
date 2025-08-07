import 'package:flutter/foundation.dart';
import 'todo_repository.dart';

/// Mock Todo Repository for web platform (no FFI support)
/// This is used as a fallback when legacy FFI repositories can't be loaded
class LegacyFFITodoRepository implements TodoRepository {
  @override
  Stream<List<TodoItem>> getTodos() async* {
    // Return empty stream for web compatibility
    yield [];
  }

  @override
  Future<void> addTodo(TodoItem todo) async {
    // No-op for web compatibility
    debugPrint('Mock addTodo called: ${todo.title}');
  }

  @override
  Future<void> updateTodo(TodoItem todo) async {
    // No-op for web compatibility
    debugPrint('Mock updateTodo called: ${todo.title}');
  }

  @override
  Future<void> deleteTodo(String id) async {
    // No-op for web compatibility
    debugPrint('Mock deleteTodo called: $id');
  }

  @override
  Future<void> toggleTodo(String id) async {
    // No-op for web compatibility
    debugPrint('Mock toggleTodo called: $id');
  }

  @override
  Future<List<TodoItem>> searchTodos(String query) async {
    // Return empty list for web compatibility
    return [];
  }

  @override
  Future<Map<String, int>> getStatistics() async {
    // Return mock statistics
    return {
      'total': 0,
      'completed': 0,
      'pending': 0,
      'overdue': 0,
    };
  }

  @override
  Future<List<String>> getCategories() async {
    // Return mock categories
    return ['general', 'work', 'personal'];
  }

  @override
  Future<List<TodoItem>> getTodosByCategory(String category) async {
    // Return empty list for web compatibility
    return [];
  }

  @override
  Future<List<TodoItem>> getTodosByPriority(String priority) async {
    // Return empty list for web compatibility
    return [];
  }
}
