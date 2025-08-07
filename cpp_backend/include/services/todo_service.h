#ifndef TODO_SERVICE_H
#define TODO_SERVICE_H

#include "core/widget_interface.h"
#include <string>
#include <vector>
#include <memory>
#include <mutex>
#include <ctime>
#include <functional>
#include <sqlite3.h>
#include <nlohmann/json.hpp>

namespace dashboard {
namespace services {

/**
 * @brief TodoService provides persistent task management with SQLite storage
 * 
 * Features:
 * - SQLite database persistence
 * - CRUD operations (Create, Read, Update, Delete)
 * - Task priorities and categories
 * - Due dates and completion tracking
 * - Search and filtering capabilities
 * - JSON export/import functionality
 * - Thread-safe operations
 * - Database migration support
 */
class TodoService {
public:
    /**
     * @brief Priority levels for todo items
     */
    enum class Priority {
        LOW = 1,
        MEDIUM = 2,
        HIGH = 3,
        URGENT = 4
    };

    /**
     * @brief Status of todo items
     */
    enum class Status {
        PENDING = 0,
        IN_PROGRESS = 1,
        COMPLETED = 2,
        CANCELLED = 3
    };

    /**
     * @brief Todo item structure
     */
    struct TodoItem {
        int id;
        std::string title;
        std::string description;
        std::string category;
        Priority priority;
        Status status;
        std::time_t created_at;
        std::time_t updated_at;
        std::time_t due_date;
        std::time_t completed_at;
        std::string tags;  // Comma-separated tags
        
        TodoItem() 
            : id(-1)
            , priority(Priority::MEDIUM)
            , status(Status::PENDING)
            , created_at(0)
            , updated_at(0)
            , due_date(0)
            , completed_at(0) {}
    };

    /**
     * @brief Filter options for querying todos
     */
    struct FilterOptions {
        std::vector<Status> statuses;
        std::vector<Priority> priorities;
        std::vector<std::string> categories;
        std::vector<std::string> tags;
        std::time_t due_before;
        std::time_t due_after;
        std::string search_text;
        std::string sort_by;  // "created", "updated", "due", "priority", "title"
        bool ascending;
        int limit;
        int offset;
        
        FilterOptions() 
            : due_before(0)
            , due_after(0)
            , sort_by("created")
            , ascending(false)
            , limit(100)
            , offset(0) {}
    };

    /**
     * @brief Database operation result
     */
    struct OperationResult {
        bool success;
        std::string error_message;
        int affected_rows;
        int last_insert_id;
        
        OperationResult() 
            : success(false)
            , affected_rows(0)
            , last_insert_id(-1) {}
    };

private:
    sqlite3* db_;
    std::string db_path_;
    mutable std::mutex db_mutex_;
    bool initialized_;

public:
    /**
     * @brief Constructor
     */
    TodoService();
    
    /**
     * @brief Destructor - cleanup SQLite resources
     */
    ~TodoService();

    /**
     * @brief Initialize the todo service with database
     * @param db_path Path to SQLite database file (default: "./todos.db")
     * @return true if initialization successful
     */
    bool initialize(const std::string& db_path = "./todos.db");

    /**
     * @brief Create a new todo item
     * @param item TodoItem to create (id will be set automatically)
     * @return OperationResult with success status and new item ID
     */
    OperationResult createTodo(TodoItem& item);

    /**
     * @brief Get todo item by ID
     * @param id Todo item ID
     * @return TodoItem if found, or empty item with id=-1 if not found
     */
    TodoItem getTodoById(int id) const;

    /**
     * @brief Update an existing todo item
     * @param item TodoItem with updated data (must have valid ID)
     * @return OperationResult with success status
     */
    OperationResult updateTodo(const TodoItem& item);

    /**
     * @brief Delete a todo item by ID
     * @param id Todo item ID to delete
     * @return OperationResult with success status
     */
    OperationResult deleteTodo(int id);

    /**
     * @brief Get filtered list of todo items
     * @param filter FilterOptions for querying
     * @return Vector of TodoItem objects matching filter
     */
    std::vector<TodoItem> getTodos(const FilterOptions& filter = FilterOptions()) const;

    /**
     * @brief Mark a todo item as completed
     * @param id Todo item ID
     * @return OperationResult with success status
     */
    OperationResult completeTodo(int id);

    /**
     * @brief Get all available categories
     * @return Vector of unique category names
     */
    std::vector<std::string> getCategories() const;

    /**
     * @brief Get all available tags
     * @return Vector of unique tag names
     */
    std::vector<std::string> getTags() const;

    /**
     * @brief Get todo statistics
     * @return JSON string with counts by status, priority, etc.
     */
    std::string getStatistics() const;

    /**
     * @brief Export all todos as JSON
     * @return JSON string with all todo items
     */
    std::string exportTodos() const;

    /**
     * @brief Import todos from JSON string
     * @param json_data JSON string with todo items
     * @return Number of items imported successfully
     */
    int importTodos(const std::string& json_data);

    /**
     * @brief Clear all todo items (for testing/reset)
     * @return OperationResult with success status
     */
    OperationResult clearAllTodos();

    /**
     * @brief Check if service is properly initialized
     * @return true if database is open and ready
     */
    bool isInitialized() const;

    /**
     * @brief Get database file path
     * @return Path to SQLite database file
     */
    std::string getDatabasePath() const;

    /**
     * @brief Convert TodoItem to JSON (public accessor for widgets)
     * @param item TodoItem to convert
     * @return nlohmann::json object
     */
    nlohmann::json todoItemToJson(const TodoItem& item) const;

    /**
     * @brief Convert JSON object to TodoItem
     * @param json JSON object to convert
     * @return TodoItem object
     */
    TodoItem jsonToTodoItem(const nlohmann::json& json) const;

private:
    /**
     * @brief Create database schema if it doesn't exist
     * @return true if schema creation/validation successful
     */
    bool createSchema();

    /**
     * @brief Convert Priority enum to string
     * @param priority Priority value
     * @return String representation
     */
    static std::string priorityToString(Priority priority);

    /**
     * @brief Convert string to Priority enum
     * @param priority_str String representation
     * @return Priority enum value
     */
    static Priority stringToPriority(const std::string& priority_str);

    /**
     * @brief Convert Status enum to string
     * @param status Status value
     * @return String representation
     */
    static std::string statusToString(Status status);

    /**
     * @brief Convert string to Status enum
     * @param status_str String representation
     * @return Status enum value
     */
    static Status stringToStatus(const std::string& status_str);

    /**
     * @brief Parse comma-separated tags string into vector
     * @param tags_str Comma-separated tags
     * @return Vector of individual tags
     */
    static std::vector<std::string> parseTags(const std::string& tags_str);

    /**
     * @brief Join vector of tags into comma-separated string
     * @param tags Vector of tag strings
     * @return Comma-separated string
     */
    static std::string joinTags(const std::vector<std::string>& tags);

    /**
     * @brief Validate TodoItem data
     * @param item TodoItem to validate
     * @return Empty string if valid, error message if invalid
     */
    static std::string validateTodoItem(const TodoItem& item);

    /**
     * @brief Build WHERE clause from FilterOptions
     * @param filter FilterOptions to convert
     * @param bind_func Output function to bind parameters
     * @return WHERE clause SQL string
     */
    std::string buildWhereClause(const FilterOptions& filter,
                                std::function<void(sqlite3_stmt*)>& bind_func) const;
};

/**
 * @brief Widget wrapper for TodoService that implements IWidget interface
 */
class TodoWidget : public core::IWidget {
private:
    std::unique_ptr<TodoService> todo_service_;

public:
    TodoWidget();
    virtual ~TodoWidget() = default;
    
    // IWidget implementation
    bool Initialize() override;
    void Update() override;
    std::string GetData() const override;
    void SetConfig(const std::string& config) override;
    void Cleanup() override;
    std::string GetId() const override { return "todo"; }
    bool IsActive() const override;
    
    // Direct access to TodoService for advanced operations
    TodoService* getService() { return todo_service_.get(); }
};

} // namespace services
} // namespace dashboard

#endif // TODO_SERVICE_H