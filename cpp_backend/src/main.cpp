#include "core/dashboard_engine.h"
#include <memory>
#include <mutex>

using namespace dashboard;

namespace {
    std::unique_ptr<core::DashboardEngine> g_engine;
    std::mutex g_engine_mutex;
}

extern "C" {

int initialize_dashboard_engine() {
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

int shutdown_dashboard_engine() {
    std::lock_guard<std::mutex> lock(g_engine_mutex);
    
    if (g_engine) {
        g_engine->Shutdown();
        g_engine.reset();
    }
    
    return 1;
}

const char* get_news_data() {
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

int add_news_feed(const char* url) {
    // TODO: Implement news feed management
    return url ? 1 : 0;
}

int remove_news_feed(const char* url) {
    // TODO: Implement news feed management  
    return url ? 1 : 0;
}

int start_stream(const char* /*url*/) { 
    // TODO: Implement stream service
    return 0; 
}

int stop_stream(const char* /*stream_id*/) {
    // TODO: Implement stream service
    return 0;
}

const char* get_stream_data(const char* /*stream_id*/) {
    static const char* empty_json = "{}";
    return empty_json;
}

const char* get_weather_data() {
    static const char* sample_data = "{\"location\":\"City\",\"temperature\":22,\"conditions\":\"Sunny\"}";
    return sample_data;
}

int update_weather_location(const char* /*location*/) {
    // TODO: Implement weather service
    return 1;
}

const char* get_todo_data() {
    static const char* sample_data = "[{\"id\":\"1\",\"title\":\"Sample task\",\"completed\":false}]";
    return sample_data;
}

int add_todo_item(const char* /*json_data*/) {
    // TODO: Implement todo service
    return 1;
}

int update_todo_item(const char* /*json_data*/) {
    // TODO: Implement todo service
    return 1;
}

int delete_todo_item(const char* /*item_id*/) {
    // TODO: Implement todo service
    return 1;
}

const char* get_mail_data() {
    static const char* sample_data = "[{\"from\":\"sender@example.com\",\"subject\":\"Test\",\"read\":false}]";
    return sample_data;
}

int configure_mail_account(const char* /*json_config*/) {
    // TODO: Implement mail service
    return 1;
}

int update_widget_config(const char* widget_id, const char* config_json) {
    std::lock_guard<std::mutex> lock(g_engine_mutex);
    
    if (!g_engine || !widget_id || !config_json) {
        return 0;
    }
    
    return g_engine->SetWidgetConfig(widget_id, config_json) ? 1 : 0;
}

}

int main() {
    // Initialize the dashboard engine
    if (!initialize_dashboard_engine()) {
        return 1;
    }
    
    // Keep the engine running (in a real app, this would be an event loop)
    // For testing purposes, we'll just initialize and exit
    
    // Cleanup
    shutdown_dashboard_engine();
    return 0;
}
