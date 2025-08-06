#include "core/dashboard_engine.h"
#include "ffi_interface.h"
#include <memory>
#include <mutex>
#include <string>
#include <ctime>

using namespace dashboard;

namespace {
    std::unique_ptr<core::DashboardEngine> g_engine;
    std::mutex g_engine_mutex;
}

// Implement the C ABI declared in shared/ffi_interface.h
extern "C" {

MD_API int initialize_dashboard_engine() {
    std::lock_guard<std::mutex> lock(g_engine_mutex);

    if (g_engine) {
        return 1;  // Already initialized
    }

    g_engine = std::make_unique<core::DashboardEngine>();
    if (!g_engine->Initialize()) {
        g_engine.reset();
        return 0;
    }

    // Start the news widget by default
    g_engine->StartWidget("news");

    return 1;
}

MD_API int shutdown_dashboard_engine() {
    std::lock_guard<std::mutex> lock(g_engine_mutex);

    if (g_engine) {
        g_engine->Shutdown();
        g_engine.reset();
    }

    return 1;
}

MD_API const char* get_news_data() {
    std::lock_guard<std::mutex> lock(g_engine_mutex);

    if (!g_engine) {
        // Auto-initialize if not done yet
        g_engine = std::make_unique<core::DashboardEngine>();
        if (g_engine->Initialize()) {
            g_engine->StartWidget("news");
        }
    }

    if (g_engine) {
        static std::string cached_data;
        cached_data = g_engine->GetWidgetData("news");
        return cached_data.c_str();
    }

    static const char* empty_json = "[]";
    return empty_json;
}

MD_API int add_news_feed(const char* url) {
    // TODO: Implement news feed management
    return url ? 1 : 0;
}

MD_API int remove_news_feed(const char* url) {
    // TODO: Implement news feed management
    return url ? 1 : 0;
}

MD_API int start_stream(const char* /*url*/) {
    // TODO: Implement stream service
    return 0;
}

MD_API int stop_stream(const char* /*stream_id*/) {
    // TODO: Implement stream service
    return 0;
}

MD_API const char* get_stream_data(const char* /*stream_id*/) {
    static const char* empty_json = "{}";
    return empty_json;
}

MD_API const char* get_weather_data() {
    static std::string weather_json = R"({
        "location": "San Francisco, CA",
        "temperature": 18.5,
        "conditions": "Partly Cloudy",
        "humidity": 72,
        "windSpeed": 12.3,
        "pressure": 1013.2,
        "visibility": 16.1,
        "uvIndex": 4,
        "icon": "partly-cloudy-day",
        "lastUpdated": ")" + std::to_string(time(nullptr)) + R"("
    })";
    return weather_json.c_str();
}

MD_API int update_weather_location(const char* /*location*/) {
    // TODO: Implement weather service
    return 1;
}

MD_API const char* get_todo_data() {
    static std::string todo_json = R"([
        {
            "id": "1",
            "title": "Complete dashboard redesign",
            "completed": false,
            "priority": "high",
            "category": "Development",
            "dueDate": ")" + std::to_string(time(nullptr) + 86400) + R"(",
            "createdAt": ")" + std::to_string(time(nullptr) - 3600) + R"(",
            "description": "Implement modern glassmorphism UI with better UX"
        },
        {
            "id": "2",
            "title": "Integrate real weather API",
            "completed": false,
            "priority": "medium",
            "category": "Features",
            "dueDate": ")" + std::to_string(time(nullptr) + 172800) + R"(",
            "createdAt": ")" + std::to_string(time(nullptr) - 7200) + R"(",
            "description": "Replace mock weather data with OpenWeatherMap API"
        },
        {
            "id": "3",
            "title": "Test FFI integration",
            "completed": true,
            "priority": "high",
            "category": "Testing",
            "dueDate": ")" + std::to_string(time(nullptr) - 3600) + R"(",
            "createdAt": ")" + std::to_string(time(nullptr) - 14400) + R"(",
            "description": "Verify C++ backend connects properly to Flutter frontend"
        }
    ])";
    return todo_json.c_str();
}

MD_API int add_todo_item(const char* /*json_data*/) {
    // TODO: Implement todo service
    return 1;
}

MD_API int update_todo_item(const char* /*json_data*/) {
    // TODO: Implement todo service
    return 1;
}

MD_API int delete_todo_item(const char* /*item_id*/) {
    // TODO: Implement todo service
    return 1;
}

MD_API const char* get_mail_data() {
    static std::string mail_json = R"([
        {
            "id": "1",
            "from": "team@moderndashboard.io",
            "fromName": "Modern Dashboard Team",
            "subject": "🎉 Welcome to Your New Dashboard!",
            "read": false,
            "priority": "normal",
            "timestamp": ")" + std::to_string(time(nullptr) - 900) + R"(",
            "preview": "Your dashboard is now connected and ready to use. Explore the new features...",
            "category": "updates",
            "hasAttachments": false
        },
        {
            "id": "2",
            "from": "notifications@github.com",
            "fromName": "GitHub",
            "subject": "New release available: Modern Dashboard v2.0",
            "read": true,
            "priority": "low",
            "timestamp": ")" + std::to_string(time(nullptr) - 7200) + R"(",
            "preview": "A new version of Modern Dashboard is now available with improved...",
            "category": "notifications",
            "hasAttachments": true
        },
        {
            "id": "3",
            "from": "api@openweathermap.org",
            "fromName": "OpenWeather API",
            "subject": "API Usage Summary - Weather Data",
            "read": true,
            "priority": "low",
            "timestamp": ")" + std::to_string(time(nullptr) - 25200) + R"(",
            "preview": "Your monthly API usage report for weather data integration...",
            "category": "api",
            "hasAttachments": false
        }
    ])";
    return mail_json.c_str();
}

MD_API int configure_mail_account(const char* /*json_config*/) {
    // TODO: Implement mail service
    return 1;
}

MD_API int update_widget_config(const char* widget_id, const char* config_json) {
    std::lock_guard<std::mutex> lock(g_engine_mutex);

    if (!g_engine || !widget_id || !config_json) {
        return 0;
    }

    return g_engine->SetWidgetConfig(widget_id, config_json) ? 1 : 0;
}

} // extern "C"

// Keep minimal CLI test that links against the moderndash library's C API
int main() {
    if (!initialize_dashboard_engine()) {
        return 1;
    }
    shutdown_dashboard_engine();
    return 0;
}
