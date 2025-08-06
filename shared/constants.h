#pragma once

namespace dashboard {

// Update intervals (in seconds)
constexpr int NEWS_UPDATE_INTERVAL = 300;     // 5 minutes
constexpr int WEATHER_UPDATE_INTERVAL = 900;  // 15 minutes
constexpr int MAIL_UPDATE_INTERVAL = 60;      // 1 minute
constexpr int STREAM_UPDATE_INTERVAL = 30;    // 30 seconds

// Network timeouts (in milliseconds)  
constexpr int HTTP_TIMEOUT_MS = 10000;        // 10 seconds
constexpr int WEBSOCKET_TIMEOUT_MS = 5000;    // 5 seconds

// Cache limits
constexpr size_t MAX_NEWS_ITEMS = 100;
constexpr size_t MAX_TODO_ITEMS = 500;
constexpr size_t MAX_MAIL_MESSAGES = 200;

// Database settings
constexpr const char* DATABASE_FILE = "dashboard.db";
constexpr int DATABASE_VERSION = 1;

// Widget configuration
constexpr const char* DEFAULT_NEWS_FEEDS[] = {
    "https://feeds.reuters.com/reuters/topNews",
    "https://rss.cnn.com/rss/edition.rss",
    nullptr
};

}  // namespace dashboard