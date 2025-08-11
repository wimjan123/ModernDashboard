import '../core/utils/timestamp_converter.dart';

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
    // Validate required fields
    if (!_validateRequiredFields(json)) {
      throw ArgumentError('Missing required fields in TodoItem JSON');
    }

    return TodoItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'general',
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'pending',
      createdAt: TimestampConverter.parseTimestamp(json['created_at']) ?? DateTime.now(),
      updatedAt: TimestampConverter.parseTimestamp(json['updated_at']) ?? DateTime.now(),
      dueDate: TimestampConverter.parseTimestamp(json['due_date']),
      tags: List<String>.from(json['tags'] ?? []),
      userId: json['user_id'],
    );
  }

  /// Validate required fields are present in JSON
  static bool _validateRequiredFields(Map<String, dynamic> json) {
    final requiredFields = ['id', 'title'];
    for (final field in requiredFields) {
      if (!json.containsKey(field) || json[field] == null || json[field] == '') {
        return false;
      }
    }
    return true;
  }

  /// Convert TodoItem to JSON (for Firestore storage)
  Map<String, dynamic> toJson() {
    try {
      return {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'priority': priority,
        'status': status,
        'created_at': TimestampConverter.dateTimeToMilliseconds(createdAt) ?? DateTime.now().millisecondsSinceEpoch,
        'updated_at': TimestampConverter.dateTimeToMilliseconds(updatedAt) ?? DateTime.now().millisecondsSinceEpoch,
        'due_date': TimestampConverter.dateTimeToMilliseconds(dueDate),
        'tags': tags,
        'user_id': userId,
      };
    } catch (e) {
      // Fallback to basic serialization if timestamp conversion fails
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