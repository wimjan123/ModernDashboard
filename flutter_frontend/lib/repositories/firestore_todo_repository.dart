import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/firebase_service.dart';
import 'todo_repository.dart';

class FirestoreTodoRepository implements TodoRepository {
  final FirebaseService _firebaseService = FirebaseService.instance;
  
  CollectionReference get _todosCollection => 
      _firebaseService.getUserCollection('todos');

  @override
  Stream<List<TodoItem>> getTodos() {
    try {
      return _todosCollection
          .orderBy('updated_at', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Ensure ID is set from document ID
          return TodoItem.fromJson(data);
        }).toList();
      });
    } catch (e) {
      throw Exception('Failed to get todos stream: $e');
    }
  }

  @override
  Future<void> addTodo(TodoItem todo) async {
    try {
      final userId = _firebaseService.getUserId();
      if (userId == null) throw Exception('User not authenticated');
      
      final todoData = todo.copyWith(
        userId: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ).toJson();
      
      // Remove ID from data since Firestore will generate it
      todoData.remove('id');
      
      await _todosCollection.add(todoData);
    } catch (e) {
      throw Exception('Failed to add todo: $e');
    }
  }

  @override
  Future<void> updateTodo(TodoItem todo) async {
    try {
      if (todo.id.isEmpty) throw Exception('Todo ID is required for update');
      
      final todoData = todo.copyWith(
        updatedAt: DateTime.now(),
      ).toJson();
      
      // Remove ID from data since it's the document ID
      todoData.remove('id');
      
      await _todosCollection.doc(todo.id).update(todoData);
    } catch (e) {
      throw Exception('Failed to update todo: $e');
    }
  }

  @override
  Future<void> deleteTodo(String id) async {
    try {
      if (id.isEmpty) throw Exception('Todo ID is required for deletion');
      
      await _todosCollection.doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete todo: $e');
    }
  }

  @override
  Future<void> toggleTodo(String id) async {
    try {
      if (id.isEmpty) throw Exception('Todo ID is required for toggle');
      
      final doc = await _todosCollection.doc(id).get();
      if (!doc.exists) throw Exception('Todo not found');
      
      final data = doc.data() as Map<String, dynamic>;
      final currentStatus = data['status'] ?? 'pending';
      final newStatus = currentStatus == 'completed' ? 'pending' : 'completed';
      
      await _todosCollection.doc(id).update({
        'status': newStatus,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception('Failed to toggle todo: $e');
    }
  }

  @override
  Future<List<String>> getCategories() async {
    try {
      final snapshot = await _todosCollection.get();
      final categories = <String>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final category = data['category'] as String?;
        if (category != null && category.isNotEmpty) {
          categories.add(category);
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
      final snapshot = await _todosCollection.get();
      int total = 0;
      int completed = 0;
      int pending = 0;
      int overdue = 0;
      final now = DateTime.now();
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total++;
        
        final status = data['status'] ?? 'pending';
        if (status == 'completed') {
          completed++;
        } else {
          pending++;
          
          // Check if overdue
          final dueDateMs = data['due_date'] as int?;
          if (dueDateMs != null) {
            final dueDate = DateTime.fromMillisecondsSinceEpoch(dueDateMs);
            if (now.isAfter(dueDate)) {
              overdue++;
            }
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

  /// Get todos by category
  Future<List<TodoItem>> getTodosByCategory(String category) async {
    try {
      final snapshot = await _todosCollection
          .where('category', isEqualTo: category)
          .orderBy('updated_at', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return TodoItem.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get todos by category: $e');
    }
  }

  /// Get todos by status
  Future<List<TodoItem>> getTodosByStatus(String status) async {
    try {
      final snapshot = await _todosCollection
          .where('status', isEqualTo: status)
          .orderBy('updated_at', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return TodoItem.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get todos by status: $e');
    }
  }

  /// Search todos by title or description
  Future<List<TodoItem>> searchTodos(String query) async {
    try {
      final snapshot = await _todosCollection.get();
      final todos = <TodoItem>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final todo = TodoItem.fromJson(data);
        
        if (todo.title.toLowerCase().contains(query.toLowerCase()) ||
            todo.description.toLowerCase().contains(query.toLowerCase())) {
          todos.add(todo);
        }
      }
      
      // Sort by relevance (title matches first, then description matches)
      todos.sort((a, b) {
        final aTitle = a.title.toLowerCase().contains(query.toLowerCase());
        final bTitle = b.title.toLowerCase().contains(query.toLowerCase());
        
        if (aTitle && !bTitle) return -1;
        if (!aTitle && bTitle) return 1;
        
        return b.updatedAt.compareTo(a.updatedAt);
      });
      
      return todos;
    } catch (e) {
      throw Exception('Failed to search todos: $e');
    }
  }

  /// Batch update multiple todos
  Future<void> batchUpdateTodos(List<TodoItem> todos) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (final todo in todos) {
        if (todo.id.isEmpty) continue;
        
        final todoData = todo.copyWith(
          updatedAt: DateTime.now(),
        ).toJson();
        todoData.remove('id');
        
        batch.update(_todosCollection.doc(todo.id), todoData);
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to batch update todos: $e');
    }
  }
}