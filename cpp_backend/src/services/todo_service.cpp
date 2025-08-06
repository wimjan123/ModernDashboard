#include "services/todo_service.h"
#include <iostream>
#include <sstream>
#include <algorithm>
#include <regex>
#include <iomanip>
#include <set>
#include <cctype>

namespace dashboard {
namespace services {

// SQL schema for todos table
const char* CREATE_TODOS_TABLE_SQL = R"(
    CREATE TABLE IF NOT EXISTS todos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT,
        priority INTEGER DEFAULT 2,
        status INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        due_date INTEGER,
        completed_at INTEGER,
        tags TEXT
    );
)";

const char* CREATE_INDEX_SQL = R"(
    CREATE INDEX IF NOT EXISTS idx_todos_status ON todos(status);
    CREATE INDEX IF NOT EXISTS idx_todos_priority ON todos(priority);
    CREATE INDEX IF NOT EXISTS idx_todos_category ON todos(category);
    CREATE INDEX IF NOT EXISTS idx_todos_due_date ON todos(due_date);
    CREATE INDEX IF NOT EXISTS idx_todos_created_at ON todos(created_at);
)";

TodoService::TodoService() 
    : db_(nullptr)
    , initialized_(false) {
}

TodoService::~TodoService() {
    if (db_) {
        sqlite3_close(db_);
        db_ = nullptr;
    }
}

bool TodoService::initialize(const std::string& db_path) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    
    if (initialized_) {
        return true; // Already initialized
    }
    
    db_path_ = db_path;
    
    // Open SQLite database
    int result = sqlite3_open(db_path_.c_str(), &db_);
    if (result != SQLITE_OK) {
        std::cerr << "TodoService: Failed to open database: " << sqlite3_errmsg(db_) << std::endl;
        if (db_) {
            sqlite3_close(db_);
            db_ = nullptr;
        }
        return false;
    }
    
    // Enable foreign keys and WAL mode for better performance
    sqlite3_exec(db_, "PRAGMA foreign_keys = ON;", nullptr, nullptr, nullptr);
    sqlite3_exec(db_, "PRAGMA journal_mode = WAL;", nullptr, nullptr, nullptr);
    sqlite3_exec(db_, "PRAGMA synchronous = NORMAL;", nullptr, nullptr, nullptr);
    
    // Create schema
    if (!createSchema()) {
        sqlite3_close(db_);
        db_ = nullptr;
        return false;
    }
    
    initialized_ = true;
    std::cout << "TodoService: Successfully initialized with database: " << db_path_ << std::endl;
    return true;
}

bool TodoService::createSchema() {
    char* error_msg = nullptr;
    
    // Create todos table
    int result = sqlite3_exec(db_, CREATE_TODOS_TABLE_SQL, nullptr, nullptr, &error_msg);
    if (result != SQLITE_OK) {
        std::cerr << "TodoService: Failed to create todos table: " << error_msg << std::endl;
        sqlite3_free(error_msg);
        return false;
    }
    
    // Create indexes
    result = sqlite3_exec(db_, CREATE_INDEX_SQL, nullptr, nullptr, &error_msg);
    if (result != SQLITE_OK) {
        std::cerr << "TodoService: Failed to create indexes: " << error_msg << std::endl;
        sqlite3_free(error_msg);
        return false;
    }
    
    return true;
}

TodoService::OperationResult TodoService::createTodo(TodoItem& item) {
    OperationResult result;
    
    if (!initialized_) {
        result.error_message = "Service not initialized";
        return result;
    }
    
    std::string validation_error = validateTodoItem(item);
    if (!validation_error.empty()) {
        result.error_message = validation_error;
        return result;
    }
    
    std::lock_guard<std::mutex> lock(db_mutex_);
    
    const char* sql = R"(
        INSERT INTO todos (title, description, category, priority, status, created_at, updated_at, due_date, tags)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    )";
    
    sqlite3_stmt* stmt = nullptr;
    int rc = sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr);
    
    if (rc != SQLITE_OK) {
        result.error_message = "Failed to prepare statement: " + std::string(sqlite3_errmsg(db_));
        return result;
    }
    
    std::time_t now = time(nullptr);
    item.created_at = now;
    item.updated_at = now;
    
    // Bind parameters
    sqlite3_bind_text(stmt, 1, item.title.c_str(), -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 2, item.description.c_str(), -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 3, item.category.c_str(), -1, SQLITE_STATIC);
    sqlite3_bind_int(stmt, 4, static_cast<int>(item.priority));
    sqlite3_bind_int(stmt, 5, static_cast<int>(item.status));
    sqlite3_bind_int64(stmt, 6, item.created_at);
    sqlite3_bind_int64(stmt, 7, item.updated_at);
    
    if (item.due_date > 0) {
        sqlite3_bind_int64(stmt, 8, item.due_date);
    } else {
        sqlite3_bind_null(stmt, 8);
    }
    
    sqlite3_bind_text(stmt, 9, item.tags.c_str(), -1, SQLITE_STATIC);
    
    rc = sqlite3_step(stmt);
    if (rc == SQLITE_DONE) {
        result.success = true;
        result.last_insert_id = sqlite3_last_insert_rowid(db_);
        result.affected_rows = sqlite3_changes(db_);
        item.id = result.last_insert_id;
    } else {
        result.error_message = "Failed to execute statement: " + std::string(sqlite3_errmsg(db_));
    }
    
    sqlite3_finalize(stmt);
    return result;
}

TodoService::TodoItem TodoService::getTodoById(int id) const {
    TodoItem item;
    item.id = -1; // Mark as invalid by default
    
    if (!initialized_ || id <= 0) {
        return item;
    }
    
    std::lock_guard<std::mutex> lock(db_mutex_);
    
    const char* sql = R"(
        SELECT id, title, description, category, priority, status, created_at, updated_at, due_date, completed_at, tags
        FROM todos WHERE id = ?
    )";
    
    sqlite3_stmt* stmt = nullptr;
    int rc = sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr);
    
    if (rc != SQLITE_OK) {
        return item;
    }
    
    sqlite3_bind_int(stmt, 1, id);
    
    rc = sqlite3_step(stmt);
    if (rc == SQLITE_ROW) {
        item.id = sqlite3_column_int(stmt, 0);
        item.title = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1));
        
        const char* desc = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2));
        if (desc) item.description = desc;
        
        const char* cat = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 3));
        if (cat) item.category = cat;
        
        item.priority = static_cast<Priority>(sqlite3_column_int(stmt, 4));
        item.status = static_cast<Status>(sqlite3_column_int(stmt, 5));
        item.created_at = sqlite3_column_int64(stmt, 6);
        item.updated_at = sqlite3_column_int64(stmt, 7);
        item.due_date = sqlite3_column_int64(stmt, 8);
        item.completed_at = sqlite3_column_int64(stmt, 9);
        
        const char* tags = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 10));
        if (tags) item.tags = tags;
    }
    
    sqlite3_finalize(stmt);
    return item;
}

TodoService::OperationResult TodoService::updateTodo(const TodoItem& item) {
    OperationResult result;
    
    if (!initialized_) {
        result.error_message = "Service not initialized";
        return result;
    }
    
    if (item.id <= 0) {
        result.error_message = "Invalid todo ID";
        return result;
    }
    
    std::string validation_error = validateTodoItem(item);
    if (!validation_error.empty()) {
        result.error_message = validation_error;
        return result;
    }
    
    std::lock_guard<std::mutex> lock(db_mutex_);
    
    const char* sql = R"(
        UPDATE todos SET 
            title = ?, description = ?, category = ?, priority = ?, status = ?, 
            updated_at = ?, due_date = ?, completed_at = ?, tags = ?
        WHERE id = ?
    )";
    
    sqlite3_stmt* stmt = nullptr;
    int rc = sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr);
    
    if (rc != SQLITE_OK) {
        result.error_message = "Failed to prepare statement: " + std::string(sqlite3_errmsg(db_));
        return result;
    }
    
    std::time_t now = time(nullptr);
    std::time_t completed_at = (item.status == Status::COMPLETED && item.completed_at == 0) ? now : item.completed_at;
    
    // Bind parameters
    sqlite3_bind_text(stmt, 1, item.title.c_str(), -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 2, item.description.c_str(), -1, SQLITE_STATIC);
    sqlite3_bind_text(stmt, 3, item.category.c_str(), -1, SQLITE_STATIC);
    sqlite3_bind_int(stmt, 4, static_cast<int>(item.priority));
    sqlite3_bind_int(stmt, 5, static_cast<int>(item.status));
    sqlite3_bind_int64(stmt, 6, now);
    
    if (item.due_date > 0) {
        sqlite3_bind_int64(stmt, 7, item.due_date);
    } else {
        sqlite3_bind_null(stmt, 7);
    }
    
    if (completed_at > 0) {
        sqlite3_bind_int64(stmt, 8, completed_at);
    } else {
        sqlite3_bind_null(stmt, 8);
    }
    
    sqlite3_bind_text(stmt, 9, item.tags.c_str(), -1, SQLITE_STATIC);
    sqlite3_bind_int(stmt, 10, item.id);
    
    rc = sqlite3_step(stmt);
    if (rc == SQLITE_DONE) {
        result.success = true;
        result.affected_rows = sqlite3_changes(db_);
    } else {
        result.error_message = "Failed to execute statement: " + std::string(sqlite3_errmsg(db_));
    }
    
    sqlite3_finalize(stmt);
    return result;
}

TodoService::OperationResult TodoService::deleteTodo(int id) {
    OperationResult result;
    
    if (!initialized_) {
        result.error_message = "Service not initialized";
        return result;
    }
    
    if (id <= 0) {
        result.error_message = "Invalid todo ID";
        return result;
    }
    
    std::lock_guard<std::mutex> lock(db_mutex_);
    
    const char* sql = "DELETE FROM todos WHERE id = ?";
    
    sqlite3_stmt* stmt = nullptr;
    int rc = sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr);
    
    if (rc != SQLITE_OK) {
        result.error_message = "Failed to prepare statement: " + std::string(sqlite3_errmsg(db_));
        return result;
    }
    
    sqlite3_bind_int(stmt, 1, id);
    
    rc = sqlite3_step(stmt);
    if (rc == SQLITE_DONE) {
        result.success = true;
        result.affected_rows = sqlite3_changes(db_);
    } else {
        result.error_message = "Failed to execute statement: " + std::string(sqlite3_errmsg(db_));
    }
    
    sqlite3_finalize(stmt);
    return result;
}

std::vector<TodoService::TodoItem> TodoService::getTodos(const FilterOptions& filter) const {
    std::vector<TodoItem> todos;
    
    if (!initialized_) {
        return todos;
    }
    
    std::lock_guard<std::mutex> lock(db_mutex_);
    
    // Build query with WHERE clause and ORDER BY
    std::ostringstream query;
    query << "SELECT id, title, description, category, priority, status, created_at, updated_at, due_date, completed_at, tags FROM todos";
    
    std::function<void(sqlite3_stmt*)> bind_func;
    std::string where_clause = buildWhereClause(filter, bind_func);
    
    if (!where_clause.empty()) {
        query << " WHERE " << where_clause;
    }
    
    // Add ORDER BY
    query << " ORDER BY ";
    if (filter.sort_by == "title") {
        query << "title";
    } else if (filter.sort_by == "updated") {
        query << "updated_at";
    } else if (filter.sort_by == "due") {
        query << "due_date";
    } else if (filter.sort_by == "priority") {
        query << "priority";
    } else {
        query << "created_at";
    }
    
    query << (filter.ascending ? " ASC" : " DESC");
    
    // Add LIMIT and OFFSET
    if (filter.limit > 0) {
        query << " LIMIT " << filter.limit;
        if (filter.offset > 0) {
            query << " OFFSET " << filter.offset;
        }
    }
    
    std::string sql = query.str();
    sqlite3_stmt* stmt = nullptr;
    int rc = sqlite3_prepare_v2(db_, sql.c_str(), -1, &stmt, nullptr);
    
    if (rc != SQLITE_OK) {
        return todos;
    }
    
    // Bind parameters if needed
    if (bind_func) {
        bind_func(stmt);
    }
    
    // Process results
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        TodoItem item;
        item.id = sqlite3_column_int(stmt, 0);
        item.title = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1));
        
        const char* desc = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2));
        if (desc) item.description = desc;
        
        const char* cat = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 3));
        if (cat) item.category = cat;
        
        item.priority = static_cast<Priority>(sqlite3_column_int(stmt, 4));
        item.status = static_cast<Status>(sqlite3_column_int(stmt, 5));
        item.created_at = sqlite3_column_int64(stmt, 6);
        item.updated_at = sqlite3_column_int64(stmt, 7);
        item.due_date = sqlite3_column_int64(stmt, 8);
        item.completed_at = sqlite3_column_int64(stmt, 9);
        
        const char* tags = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 10));
        if (tags) item.tags = tags;
        
        todos.push_back(item);
    }
    
    sqlite3_finalize(stmt);
    return todos;
}

TodoService::OperationResult TodoService::completeTodo(int id) {
    TodoItem item = getTodoById(id);
    if (item.id == -1) {
        OperationResult result;
        result.error_message = "Todo not found";
        return result;
    }
    
    item.status = Status::COMPLETED;
    item.completed_at = time(nullptr);
    
    return updateTodo(item);
}

std::vector<std::string> TodoService::getCategories() const {
    std::vector<std::string> categories;
    
    if (!initialized_) {
        return categories;
    }
    
    std::lock_guard<std::mutex> lock(db_mutex_);
    
    const char* sql = "SELECT DISTINCT category FROM todos WHERE category IS NOT NULL AND category != '' ORDER BY category";
    
    sqlite3_stmt* stmt = nullptr;
    int rc = sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr);
    
    if (rc != SQLITE_OK) {
        return categories;
    }
    
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        const char* category = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0));
        if (category) {
            categories.push_back(category);
        }
    }
    
    sqlite3_finalize(stmt);
    return categories;
}

std::vector<std::string> TodoService::getTags() const {
    std::vector<std::string> all_tags;
    std::set<std::string> unique_tags;
    
    if (!initialized_) {
        return all_tags;
    }
    
    std::lock_guard<std::mutex> lock(db_mutex_);
    
    const char* sql = "SELECT DISTINCT tags FROM todos WHERE tags IS NOT NULL AND tags != ''";
    
    sqlite3_stmt* stmt = nullptr;
    int rc = sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr);
    
    if (rc != SQLITE_OK) {
        return all_tags;
    }
    
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        const char* tags_str = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0));
        if (tags_str) {
            auto tags = parseTags(tags_str);
            for (const auto& tag : tags) {
                unique_tags.insert(tag);
            }
        }
    }
    
    sqlite3_finalize(stmt);
    
    // Convert set to vector
    all_tags.assign(unique_tags.begin(), unique_tags.end());
    return all_tags;
}

std::string TodoService::getStatistics() const {
    nlohmann::json stats;
    
    if (!initialized_) {
        stats["error"] = "Service not initialized";
        return stats.dump();
    }
    
    std::lock_guard<std::mutex> lock(db_mutex_);
    
    // Count by status
    const char* status_sql = R"(
        SELECT status, COUNT(*) as count FROM todos GROUP BY status ORDER BY status
    )";
    
    sqlite3_stmt* stmt = nullptr;
    int rc = sqlite3_prepare_v2(db_, status_sql, -1, &stmt, nullptr);
    
    if (rc == SQLITE_OK) {
        nlohmann::json status_counts = nlohmann::json::object();
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            int status = sqlite3_column_int(stmt, 0);
            int count = sqlite3_column_int(stmt, 1);
            status_counts[statusToString(static_cast<Status>(status))] = count;
        }
        stats["by_status"] = status_counts;
        sqlite3_finalize(stmt);
    }
    
    // Count by priority
    const char* priority_sql = R"(
        SELECT priority, COUNT(*) as count FROM todos GROUP BY priority ORDER BY priority
    )";
    
    rc = sqlite3_prepare_v2(db_, priority_sql, -1, &stmt, nullptr);
    if (rc == SQLITE_OK) {
        nlohmann::json priority_counts = nlohmann::json::object();
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            int priority = sqlite3_column_int(stmt, 0);
            int count = sqlite3_column_int(stmt, 1);
            priority_counts[priorityToString(static_cast<Priority>(priority))] = count;
        }
        stats["by_priority"] = priority_counts;
        sqlite3_finalize(stmt);
    }
    
    // Total count
    const char* total_sql = "SELECT COUNT(*) FROM todos";
    rc = sqlite3_prepare_v2(db_, total_sql, -1, &stmt, nullptr);
    if (rc == SQLITE_OK) {
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            stats["total"] = sqlite3_column_int(stmt, 0);
        }
        sqlite3_finalize(stmt);
    }
    
    // Overdue count
    std::time_t now = time(nullptr);
    const char* overdue_sql = "SELECT COUNT(*) FROM todos WHERE due_date > 0 AND due_date < ? AND status != 2";
    rc = sqlite3_prepare_v2(db_, overdue_sql, -1, &stmt, nullptr);
    if (rc == SQLITE_OK) {
        sqlite3_bind_int64(stmt, 1, now);
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            stats["overdue"] = sqlite3_column_int(stmt, 0);
        }
        sqlite3_finalize(stmt);
    }
    
    return stats.dump();
}

std::string TodoService::exportTodos() const {
    auto todos = getTodos();
    nlohmann::json json_array = nlohmann::json::array();
    
    for (const auto& todo : todos) {
        json_array.push_back(todoItemToJson(todo));
    }
    
    return json_array.dump();
}

int TodoService::importTodos(const std::string& json_data) {
    int imported_count = 0;
    
    try {
        nlohmann::json json_array = nlohmann::json::parse(json_data);
        
        if (!json_array.is_array()) {
            return 0;
        }
        
        for (const auto& json_item : json_array) {
            TodoItem item = jsonToTodoItem(json_item);
            if (!item.title.empty()) {
                item.id = -1; // Reset ID for import
                OperationResult result = createTodo(item);
                if (result.success) {
                    imported_count++;
                }
            }
        }
    } catch (const std::exception& e) {
        std::cerr << "TodoService: Import error: " << e.what() << std::endl;
    }
    
    return imported_count;
}

TodoService::OperationResult TodoService::clearAllTodos() {
    OperationResult result;
    
    if (!initialized_) {
        result.error_message = "Service not initialized";
        return result;
    }
    
    std::lock_guard<std::mutex> lock(db_mutex_);
    
    const char* sql = "DELETE FROM todos";
    
    char* error_msg = nullptr;
    int rc = sqlite3_exec(db_, sql, nullptr, nullptr, &error_msg);
    
    if (rc == SQLITE_OK) {
        result.success = true;
        result.affected_rows = sqlite3_changes(db_);
    } else {
        result.error_message = "Failed to clear todos: " + std::string(error_msg);
        sqlite3_free(error_msg);
    }
    
    return result;
}

bool TodoService::isInitialized() const {
    return initialized_ && db_ != nullptr;
}

std::string TodoService::getDatabasePath() const {
    return db_path_;
}

// Private helper methods implementation

nlohmann::json TodoService::todoItemToJson(const TodoItem& item) const {
    nlohmann::json json;
    json["id"] = item.id;
    json["title"] = item.title;
    json["description"] = item.description;
    json["category"] = item.category;
    json["priority"] = priorityToString(item.priority);
    json["status"] = statusToString(item.status);
    json["created_at"] = item.created_at;
    json["updated_at"] = item.updated_at;
    json["due_date"] = item.due_date;
    json["completed_at"] = item.completed_at;
    
    if (!item.tags.empty()) {
        json["tags"] = parseTags(item.tags);
    } else {
        json["tags"] = nlohmann::json::array();
    }
    
    return json;
}

TodoService::TodoItem TodoService::jsonToTodoItem(const nlohmann::json& json) const {
    TodoItem item;
    
    if (json.contains("id") && json["id"].is_number()) {
        item.id = json["id"].get<int>();
    }
    
    if (json.contains("title") && json["title"].is_string()) {
        item.title = json["title"].get<std::string>();
    }
    
    if (json.contains("description") && json["description"].is_string()) {
        item.description = json["description"].get<std::string>();
    }
    
    if (json.contains("category") && json["category"].is_string()) {
        item.category = json["category"].get<std::string>();
    }
    
    if (json.contains("priority") && json["priority"].is_string()) {
        item.priority = stringToPriority(json["priority"].get<std::string>());
    }
    
    if (json.contains("status") && json["status"].is_string()) {
        item.status = stringToStatus(json["status"].get<std::string>());
    }
    
    if (json.contains("created_at") && json["created_at"].is_number()) {
        item.created_at = json["created_at"].get<std::time_t>();
    }
    
    if (json.contains("updated_at") && json["updated_at"].is_number()) {
        item.updated_at = json["updated_at"].get<std::time_t>();
    }
    
    if (json.contains("due_date") && json["due_date"].is_number()) {
        item.due_date = json["due_date"].get<std::time_t>();
    }
    
    if (json.contains("completed_at") && json["completed_at"].is_number()) {
        item.completed_at = json["completed_at"].get<std::time_t>();
    }
    
    if (json.contains("tags") && json["tags"].is_array()) {
        std::vector<std::string> tags;
        for (const auto& tag : json["tags"]) {
            if (tag.is_string()) {
                tags.push_back(tag.get<std::string>());
            }
        }
        item.tags = joinTags(tags);
    }
    
    return item;
}

std::string TodoService::priorityToString(Priority priority) {
    switch (priority) {
        case Priority::LOW: return "low";
        case Priority::MEDIUM: return "medium";
        case Priority::HIGH: return "high";
        case Priority::URGENT: return "urgent";
        default: return "medium";
    }
}

TodoService::Priority TodoService::stringToPriority(const std::string& priority_str) {
    if (priority_str == "low") return Priority::LOW;
    if (priority_str == "medium") return Priority::MEDIUM;
    if (priority_str == "high") return Priority::HIGH;
    if (priority_str == "urgent") return Priority::URGENT;
    return Priority::MEDIUM;
}

std::string TodoService::statusToString(Status status) {
    switch (status) {
        case Status::PENDING: return "pending";
        case Status::IN_PROGRESS: return "in_progress";
        case Status::COMPLETED: return "completed";
        case Status::CANCELLED: return "cancelled";
        default: return "pending";
    }
}

TodoService::Status TodoService::stringToStatus(const std::string& status_str) {
    if (status_str == "pending") return Status::PENDING;
    if (status_str == "in_progress") return Status::IN_PROGRESS;
    if (status_str == "completed") return Status::COMPLETED;
    if (status_str == "cancelled") return Status::CANCELLED;
    return Status::PENDING;
}

std::vector<std::string> TodoService::parseTags(const std::string& tags_str) {
    std::vector<std::string> tags;
    if (tags_str.empty()) return tags;
    
    std::istringstream ss(tags_str);
    std::string tag;
    
    while (std::getline(ss, tag, ',')) {
        // Trim whitespace
        tag.erase(tag.begin(), std::find_if(tag.begin(), tag.end(), [](unsigned char ch) {
            return !std::isspace(ch);
        }));
        tag.erase(std::find_if(tag.rbegin(), tag.rend(), [](unsigned char ch) {
            return !std::isspace(ch);
        }).base(), tag.end());
        
        if (!tag.empty()) {
            tags.push_back(tag);
        }
    }
    
    return tags;
}

std::string TodoService::joinTags(const std::vector<std::string>& tags) {
    std::ostringstream oss;
    for (size_t i = 0; i < tags.size(); ++i) {
        if (i > 0) oss << ",";
        oss << tags[i];
    }
    return oss.str();
}

std::string TodoService::validateTodoItem(const TodoItem& item) {
    if (item.title.empty()) {
        return "Title is required";
    }
    
    if (item.title.length() > 255) {
        return "Title is too long (max 255 characters)";
    }
    
    if (item.description.length() > 2000) {
        return "Description is too long (max 2000 characters)";
    }
    
    if (item.category.length() > 100) {
        return "Category is too long (max 100 characters)";
    }
    
    if (item.tags.length() > 500) {
        return "Tags string is too long (max 500 characters)";
    }
    
    return "";
}

std::string TodoService::buildWhereClause(const FilterOptions& filter,
                                         std::function<void(sqlite3_stmt*)>& bind_func) const {
    std::vector<std::string> conditions;
    int param_index = 1;
    
    // Status filter
    if (!filter.statuses.empty()) {
        std::ostringstream status_clause;
        status_clause << "status IN (";
        for (size_t i = 0; i < filter.statuses.size(); ++i) {
            if (i > 0) status_clause << ",";
            status_clause << "?";
        }
        status_clause << ")";
        conditions.push_back(status_clause.str());
    }
    
    // Priority filter
    if (!filter.priorities.empty()) {
        std::ostringstream priority_clause;
        priority_clause << "priority IN (";
        for (size_t i = 0; i < filter.priorities.size(); ++i) {
            if (i > 0) priority_clause << ",";
            priority_clause << "?";
        }
        priority_clause << ")";
        conditions.push_back(priority_clause.str());
    }
    
    // Category filter
    if (!filter.categories.empty()) {
        std::ostringstream category_clause;
        category_clause << "category IN (";
        for (size_t i = 0; i < filter.categories.size(); ++i) {
            if (i > 0) category_clause << ",";
            category_clause << "?";
        }
        category_clause << ")";
        conditions.push_back(category_clause.str());
    }
    
    // Due date filters
    if (filter.due_before > 0) {
        conditions.push_back("due_date < ?");
    }
    
    if (filter.due_after > 0) {
        conditions.push_back("due_date > ?");
    }
    
    // Search text
    if (!filter.search_text.empty()) {
        conditions.push_back("(title LIKE ? OR description LIKE ?)");
    }
    
    // Tags filter (simplified - checks if any tag matches)
    if (!filter.tags.empty()) {
        std::ostringstream tags_clause;
        tags_clause << "(";
        for (size_t i = 0; i < filter.tags.size(); ++i) {
            if (i > 0) tags_clause << " OR ";
            tags_clause << "tags LIKE ?";
        }
        tags_clause << ")";
        conditions.push_back(tags_clause.str());
    }
    
    // Create bind function
    bind_func = [this, &filter, param_index](sqlite3_stmt* stmt) mutable {
        // Bind status values
        for (const auto& status : filter.statuses) {
            sqlite3_bind_int(stmt, param_index++, static_cast<int>(status));
        }
        
        // Bind priority values
        for (const auto& priority : filter.priorities) {
            sqlite3_bind_int(stmt, param_index++, static_cast<int>(priority));
        }
        
        // Bind category values
        for (const auto& category : filter.categories) {
            sqlite3_bind_text(stmt, param_index++, category.c_str(), -1, SQLITE_STATIC);
        }
        
        // Bind due date filters
        if (filter.due_before > 0) {
            sqlite3_bind_int64(stmt, param_index++, filter.due_before);
        }
        
        if (filter.due_after > 0) {
            sqlite3_bind_int64(stmt, param_index++, filter.due_after);
        }
        
        // Bind search text
        if (!filter.search_text.empty()) {
            std::string search_pattern = "%" + filter.search_text + "%";
            sqlite3_bind_text(stmt, param_index++, search_pattern.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(stmt, param_index++, search_pattern.c_str(), -1, SQLITE_TRANSIENT);
        }
        
        // Bind tags
        for (const auto& tag : filter.tags) {
            std::string tag_pattern = "%" + tag + "%";
            sqlite3_bind_text(stmt, param_index++, tag_pattern.c_str(), -1, SQLITE_TRANSIENT);
        }
    };
    
    if (conditions.empty()) {
        bind_func = nullptr;
        return "";
    }
    
    std::ostringstream where_clause;
    for (size_t i = 0; i < conditions.size(); ++i) {
        if (i > 0) where_clause << " AND ";
        where_clause << conditions[i];
    }
    
    return where_clause.str();
}

// TodoWidget implementation

TodoWidget::TodoWidget() {
    todo_service_ = std::make_unique<TodoService>();
}

bool TodoWidget::Initialize() {
    return todo_service_->initialize();
}

void TodoWidget::Update() {
    // TodoService doesn't require periodic updates like news feeds
    // This could be used to clean up expired todos or perform maintenance
}

std::string TodoWidget::GetData() const {
    TodoService::FilterOptions filter;
    filter.limit = 50; // Limit to 50 recent todos
    auto todos = todo_service_->getTodos(filter);
    
    nlohmann::json json_array = nlohmann::json::array();
    for (const auto& todo : todos) {
        json_array.push_back(todo_service_->todoItemToJson(todo));
    }
    
    return json_array.dump();
}

void TodoWidget::SetConfig(const std::string& config) {
    // Parse config and apply to TodoService
    // Expected format: {"database_path": "/path/to/db", "default_filters": {...}}
    try {
        nlohmann::json config_json = nlohmann::json::parse(config);
        
        if (config_json.contains("database_path") && config_json["database_path"].is_string()) {
            std::string db_path = config_json["database_path"].get<std::string>();
            // Re-initialize with new database path
            todo_service_ = std::make_unique<TodoService>();
            todo_service_->initialize(db_path);
        }
        
        // Additional config options can be added here
        
    } catch (const std::exception& e) {
        std::cerr << "TodoWidget: Failed to parse config: " << e.what() << std::endl;
    }
}

void TodoWidget::Cleanup() {
    // TodoService cleanup is handled by destructor
}

bool TodoWidget::IsActive() const {
    return todo_service_ && todo_service_->isInitialized();
}

} // namespace services
} // namespace dashboard