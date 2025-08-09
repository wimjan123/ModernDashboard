abstract class TodoRepository {
  /// Get real-time stream of todos for the current user
  Stream<List<TodoItem>> getTodos();
  
  /// Add a new todo item
  Future<void> addTodo(TodoItem todo);
  
  /// Update an existing todo item
  Future<void> updateTodo(TodoItem todo);
  
  /// Delete a todo by ID
  Future<void> deleteTodo(String id);
  
  /// Toggle completion status of a todo
  Future<void> toggleTodo(String id);
  
  /// Get unique categories used in todos
  Future<List<String>> getCategories();
  
  /// Get todo statistics (total, completed, pending, etc.)
  Future<Map<String, int>> getStatistics();
}

class TodoItem {
  final String id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueDate;
  final List<String> tags;
  final String? userId;

  TodoItem({
    required this.id,
    required this.title,
    this.description = '',
    this.category = 'general',
    this.priority = 'medium',
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
    this.tags = const [],
    this.userId,
  });

  /// Create TodoItem from JSON (Firestore document)
  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'general',
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'pending',
      createdAt: _parseTimestamp(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(json['updated_at']) ?? DateTime.now(),
      dueDate: _parseTimestamp(json['due_date']),
      tags: List<String>.from(json['tags'] ?? []),
      userId: json['user_id'],
    );
  }

  /// Helper method to parse timestamps from various formats
  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    
    try {
      // Handle Firestore Timestamp
      if (timestamp is Map && timestamp.containsKey('_seconds')) {
        final seconds = timestamp['_seconds'] as int?;
        final nanoseconds = timestamp['_nanoseconds'] as int? ?? 0;
        if (seconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            (seconds * 1000) + (nanoseconds ~/ 1000000),
          );
        }
      }
      
      // Handle milliseconds since epoch
      if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      
      // Handle string timestamp
      if (timestamp is String) {
        return DateTime.parse(timestamp);
      }
      
      // Handle DateTime objects directly
      if (timestamp is DateTime) {
        return timestamp;
      }
    } catch (e) {
      // If parsing fails, return current time for required fields
      // or null for optional fields like dueDate
    }
    
    return null;
  }

  /// Convert TodoItem to JSON (for Firestore storage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'status': status,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'due_date': dueDate?.millisecondsSinceEpoch,
      'tags': tags,
      'user_id': userId,
    };
  }

  /// Create a copy with updated fields
  TodoItem copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? priority,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dueDate,
    List<String>? tags,
    String? userId,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueDate: dueDate ?? this.dueDate,
      tags: tags ?? this.tags,
      userId: userId ?? this.userId,
    );
  }

  /// Check if todo is completed
  bool get isCompleted => status == 'completed';

  /// Check if todo is overdue
  bool get isOverdue {
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!) && !isCompleted;
  }

  @override
  String toString() {
    return 'TodoItem(id: $id, title: $title, status: $status, category: $category, priority: $priority)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TodoItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}