#include "export.h"
#include "core/dashboard_engine.h"
#include "services/weather_service.h"
#include "services/news_service.h"
#include "services/todo_service.h"
#include "services/mail_service.h"
#include "services/stream_service.h"
#include "ffi_interface.h"
#include <memory>
#include <mutex>
#include <string>
#include <ctime>
#include <cstdlib>

using namespace dashboard;

namespace {
    std::unique_ptr<core::DashboardEngine> g_engine;
    std::unique_ptr<dashboard::services::WeatherService> g_weather_service;
    std::unique_ptr<dashboard::services::NewsService> g_news_service;
    std::unique_ptr<dashboard::services::TodoService> g_todo_service;
    std::unique_ptr<dashboard::services::MailService> g_mail_service;
    std::unique_ptr<dashboard::services::StreamService> g_stream_service;
    std::string g_current_weather_location = "San Francisco,CA,US";
    std::mutex g_engine_mutex;
    std::mutex g_weather_mutex;
    std::mutex g_news_mutex;
    std::mutex g_todo_mutex;
    std::mutex g_mail_mutex;
    std::mutex g_stream_mutex;
    
    // Initialize weather service if not already done
    void ensure_weather_service_initialized() {
        if (!g_weather_service) {
            g_weather_service = std::make_unique<dashboard::services::WeatherService>();
            
            // Try to initialize with API key from environment or use demo key
            const char* api_key = getenv("OPENWEATHER_API_KEY");
            if (!api_key || strlen(api_key) == 0) {
                // For demo purposes, we'll use a placeholder that returns mock data
                // In production, this should fail gracefully and return cached/mock data
                api_key = "demo_key_replace_with_real_key";
            }
            
            if (!g_weather_service->initialize(api_key, 
                                              dashboard::services::WeatherService::Units::METRIC, 
                                              "en")) {
                // If initialization fails, keep service for graceful error handling
                // The service will return appropriate error responses
            }
        }
    }
    
    // Initialize news service if not already done
    void ensure_news_service_initialized() {
        if (!g_news_service) {
            g_news_service = std::make_unique<dashboard::services::NewsService>();
            
            if (!g_news_service->initialize()) {
                // If initialization fails, keep service for graceful error handling
                // The service will return appropriate error responses
            }
        }
    }

    // Initialize todo service if not already done
    void ensure_todo_service_initialized() {
        if (!g_todo_service) {
            g_todo_service = std::make_unique<dashboard::services::TodoService>();
            if (!g_todo_service->initialize("todos.db")) {
                // Handle initialization failure
            }
        }
    }

    void ensure_mail_service_initialized() {
        if (!g_mail_service) {
            g_mail_service = std::make_unique<dashboard::services::MailService>();
            // In a real application, you would load the account from a secure store.
            dashboard::services::MailService::MailAccount account;
            account.email_address = "user@example.com";
            account.password = "password";
            account.imap_server = "imap.example.com";
            account.imap_port = 993;
            account.use_ssl = true;
            if (!g_mail_service->initialize(account)) {
                // Handle initialization failure
            }
        }
    }

    void ensure_stream_service_initialized() {
        if (!g_stream_service) {
            g_stream_service = std::make_unique<dashboard::services::StreamService>();
        }
    }
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
    g_engine->StartWidget("todo");


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
    std::lock_guard<std::mutex> lock(g_news_mutex);
    
    ensure_news_service_initialized();
    
    if (!g_news_service) {
        // Fallback to mock data if service creation failed
        static std::string news_json = R"([
            {
                "id": "1",
                "title": "Technology News Update",
                "description": "Latest developments in technology and innovation",
                "link": "https://example.com/tech-news",
                "source": "Tech News",
                "author": "Tech Reporter",
                "category": "Technology",
                "published_date": )" + std::to_string(time(nullptr) - 3600) + R"(,
                "cached_at": )" + std::to_string(time(nullptr)) + R"(
            },
            {
                "id": "2", 
                "title": "Global Market Analysis",
                "description": "Current market trends and financial insights",
                "link": "https://example.com/market-analysis",
                "source": "Finance Today",
                "author": "Market Analyst",
                "category": "Finance", 
                "published_date": )" + std::to_string(time(nullptr) - 7200) + R"(,
                "cached_at": )" + std::to_string(time(nullptr)) + R"(
            }
        ])";
        return news_json.c_str();
    }
    
    // Get latest news from the service
    static std::string cached_news_data;
    cached_news_data = g_news_service->getLatestNews(false);
    
    return cached_news_data.c_str();
}

MD_API int add_news_feed(const char* url) {
    if (!url) {
        return 0;
    }
    
    std::lock_guard<std::mutex> lock(g_news_mutex);
    
    ensure_news_service_initialized();
    
    if (!g_news_service) {
        return 0;
    }
    
    return g_news_service->addFeed(std::string(url)) ? 1 : 0;
}

MD_API int remove_news_feed(const char* url) {
    if (!url) {
        return 0;
    }
    
    std::lock_guard<std::mutex> lock(g_news_mutex);
    
    ensure_news_service_initialized();
    
    if (!g_news_service) {
        return 0;
    }
    
    return g_news_service->removeFeed(std::string(url)) ? 1 : 0;
}

MD_API int start_stream(const char* url) {
    std::lock_guard<std::mutex> lock(g_stream_mutex);
    ensure_stream_service_initialized();
    if (!g_stream_service || !url) {
        return 0;
    }
    return g_stream_service->startStream(url) ? 1 : 0;
}

MD_API int stop_stream(const char* stream_id) {
    std::lock_guard<std::mutex> lock(g_stream_mutex);
    ensure_stream_service_initialized();
    if (!g_stream_service || !stream_id) {
        return 0;
    }
    g_stream_service->stopStream(stream_id);
    return 1;
}

MD_API const char* get_stream_data(const char* stream_id) {
    std::lock_guard<std::mutex> lock(g_stream_mutex);
    ensure_stream_service_initialized();
    if (!g_stream_service || !stream_id) {
        return "{}";
    }
    static std::string stream_json;
    stream_json = g_stream_service->getStreamData(stream_id);
    return stream_json.c_str();
}

MD_API const char* get_weather_data() {
    std::lock_guard<std::mutex> lock(g_weather_mutex);
    
    ensure_weather_service_initialized();
    
    if (!g_weather_service) {
        // Fallback to mock data if service creation failed
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
            "lastUpdated": ")" + std::to_string(time(nullptr)) + R"(",
            "source": "mock"
        })";
        return weather_json.c_str();
    }
    
    // Try to get weather data using the current location
    static std::string cached_weather_data;
    
    // Parse location string - assume format is "City,State,Country" or "City,Country"
    // For now, use city name method (we could enhance this to parse coordinates later)
    cached_weather_data = g_weather_service->getCurrentWeather(g_current_weather_location);
    
    return cached_weather_data.c_str();
}

MD_API int update_weather_location(const char* location) {
    if (!location) {
        return 0;
    }
    
    std::lock_guard<std::mutex> lock(g_weather_mutex);
    
    ensure_weather_service_initialized();
    
    if (!g_weather_service) {
        return 0;
    }
    
    // Update the current location and test it with a geocoding request
    std::string new_location(location);
    
    // Test if the location is valid by trying to geocode it
    std::string geocode_result = g_weather_service->geocodeLocation(new_location, 1);
    
    // Parse the result to see if we got valid coordinates
    try {
        nlohmann::json result = nlohmann::json::parse(geocode_result);
        
        // Check if it's an error response
        if (result.contains("error") && result["error"].get<bool>()) {
            return 0; // Location not found or API error
        }
        
        // Check if we got valid results (should be an array with at least one item)
        if (result.is_array() && !result.empty()) {
            g_current_weather_location = new_location;
            return 1; // Success
        }
    } catch (const std::exception&) {
        // JSON parsing failed, probably not a valid response
        return 0;
    }
    
    return 0; // Default failure
}

MD_API const char* get_todo_data() {
    std::lock_guard<std::mutex> lock(g_todo_mutex);
    ensure_todo_service_initialized();
    if (!g_todo_service) {
        return "[]";
    }
    static std::string todo_json;
    todo_json = g_todo_service->exportTodos();
    return todo_json.c_str();
}

MD_API int add_todo_item(const char* json_data) {
    std::lock_guard<std::mutex> lock(g_todo_mutex);
    ensure_todo_service_initialized();
    if (!g_todo_service || !json_data) {
        return 0;
    }
    try {
        nlohmann::json json = nlohmann::json::parse(json_data);
        auto item = g_todo_service->jsonToTodoItem(json);
        auto result = g_todo_service->createTodo(item);
        return result.success ? 1 : 0;
    } catch (const std::exception& e) {
        return 0;
    }
}

MD_API int update_todo_item(const char* json_data) {
    std::lock_guard<std::mutex> lock(g_todo_mutex);
    ensure_todo_service_initialized();
    if (!g_todo_service || !json_data) {
        return 0;
    }
    try {
        nlohmann::json json = nlohmann::json::parse(json_data);
        auto item = g_todo_service->jsonToTodoItem(json);
        auto result = g_todo_service->updateTodo(item);
        return result.success ? 1 : 0;
    } catch (const std::exception& e) {
        return 0;
    }
}

MD_API int delete_todo_item(const char* item_id) {
    std::lock_guard<std::mutex> lock(g_todo_mutex);
    ensure_todo_service_initialized();
    if (!g_todo_service || !item_id) {
        return 0;
    }
    try {
        int id = std::stoi(item_id);
        auto result = g_todo_service->deleteTodo(id);
        return result.success ? 1 : 0;
    } catch (const std::exception& e) {
        return 0;
    }
}

MD_API const char* get_mail_data() {
    std::lock_guard<std::mutex> lock(g_mail_mutex);
    ensure_mail_service_initialized();
    if (!g_mail_service) {
        return "[]";
    }
    static std::string mail_json;
    mail_json = g_mail_service->getMailData();
    return mail_json.c_str();
}

MD_API int configure_mail_account(const char* json_config) {
    std::lock_guard<std::mutex> lock(g_mail_mutex);
    ensure_mail_service_initialized();
    if (!g_mail_service || !json_config) {
        return 0;
    }
    try {
        nlohmann::json json = nlohmann::json::parse(json_config);
        dashboard::services::MailService::MailAccount account;
        account.email_address = json.value("email_address", "");
        account.password = json.value("password", "");
        account.imap_server = json.value("imap_server", "");
        account.imap_port = json.value("imap_port", 993);
        account.use_ssl = json.value("use_ssl", true);
        return g_mail_service->initialize(account) ? 1 : 0;
    } catch (const std::exception& e) {
        return 0;
    }
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
