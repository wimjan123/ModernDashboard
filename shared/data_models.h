#pragma once

#include <string>
#include <vector>
#include <chrono>

namespace dashboard {

struct NewsItem {
    std::string title;
    std::string content;
    std::string source;
    std::string url;
    std::chrono::system_clock::time_point timestamp;
    
    NewsItem() = default;
    NewsItem(const std::string& t, const std::string& c, const std::string& s, const std::string& u)
        : title(t), content(c), source(s), url(u), timestamp(std::chrono::system_clock::now()) {}
};

struct WeatherData {
    std::string location;
    double temperature;
    double humidity;
    std::string conditions;
    std::string icon_code;
    std::chrono::system_clock::time_point updated;
};

struct TodoItem {
    std::string id;
    std::string title;
    std::string description;
    bool completed;
    std::chrono::system_clock::time_point created;
    std::chrono::system_clock::time_point due_date;
};

struct MailMessage {
    std::string id;
    std::string from;
    std::string subject;
    std::string preview;
    bool read;
    std::chrono::system_clock::time_point timestamp;
};

struct StreamInfo {
    std::string id;
    std::string url;
    std::string title;
    bool is_active;
    int viewer_count;
};

}  // namespace dashboard