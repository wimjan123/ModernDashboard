#include "services/news_service.h"
#include "../../../shared/constants.h"
#include <sstream>
#include <algorithm>

namespace dashboard {
namespace services {

NewsService::NewsService() : initialized_(false) {
    LoadDefaultFeeds();
}

void NewsService::LoadDefaultFeeds() {
    rss_feeds_.clear();
    
    // Load default RSS feeds from constants
    const char* const* feeds = dashboard::DEFAULT_NEWS_FEEDS;
    for (int i = 0; feeds[i] != nullptr; ++i) {
        rss_feeds_.emplace_back(feeds[i]);
    }
}

bool NewsService::Initialize() {
    if (initialized_.load()) {
        return true;  // Already initialized
    }
    
    std::lock_guard<std::mutex> lock(data_mutex_);
    
    // Initialize with some sample data for now
    cached_news_.clear();
    cached_news_.emplace_back("Sample News Title 1", "Sample content 1", "Reuters", "https://example.com/1");
    cached_news_.emplace_back("Sample News Title 2", "Sample content 2", "CNN", "https://example.com/2");
    
    last_update_ = std::chrono::steady_clock::now();
    initialized_ = true;
    
    return true;
}

void NewsService::Update() {
    if (!initialized_.load()) {
        return;
    }
    
    auto now = std::chrono::steady_clock::now();
    auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - last_update_);
    
    if (elapsed.count() >= dashboard::NEWS_UPDATE_INTERVAL) {
        std::lock_guard<std::mutex> lock(data_mutex_);
        
        // In a real implementation, this would fetch from RSS feeds
        // For now, just update timestamp to show the system is working
        last_update_ = now;
    }
}

std::string NewsService::GetData() const {
    if (!initialized_.load()) {
        return "[]";
    }
    
    std::lock_guard<std::mutex> lock(data_mutex_);
    return FormatNewsAsJson();
}

std::string NewsService::FormatNewsAsJson() const {
    std::ostringstream json;
    json << "[";
    
    for (size_t i = 0; i < cached_news_.size(); ++i) {
        if (i > 0) json << ",";
        
        const auto& item = cached_news_[i];
        json << "{"
             << "\"title\":\"" << item.title << "\","
             << "\"content\":\"" << item.content << "\","
             << "\"source\":\"" << item.source << "\","
             << "\"url\":\"" << item.url << "\""
             << "}";
    }
    
    json << "]";
    return json.str();
}

void NewsService::SetConfig(const std::string& config) {
    // In a real implementation, this would parse JSON config
    // and update RSS feeds, refresh intervals, etc.
    // For now, we'll just acknowledge the config change
    std::lock_guard<std::mutex> lock(data_mutex_);
    // Config parsing would go here
}

void NewsService::Cleanup() {
    initialized_ = false;
    
    std::lock_guard<std::mutex> lock(data_mutex_);
    cached_news_.clear();
    rss_feeds_.clear();
}

void NewsService::AddRssFeed(const std::string& url) {
    if (url.empty()) return;
    
    std::lock_guard<std::mutex> lock(data_mutex_);
    
    // Check if feed already exists
    if (std::find(rss_feeds_.begin(), rss_feeds_.end(), url) == rss_feeds_.end()) {
        rss_feeds_.push_back(url);
    }
}

void NewsService::RemoveRssFeed(const std::string& url) {
    std::lock_guard<std::mutex> lock(data_mutex_);
    
    rss_feeds_.erase(
        std::remove(rss_feeds_.begin(), rss_feeds_.end(), url),
        rss_feeds_.end()
    );
}

std::vector<NewsItem> NewsService::FetchFromFeeds() {
    // This would implement actual RSS fetching
    // For now, return sample data
    std::vector<NewsItem> items;
    items.emplace_back("Breaking: Tech News Update", "Latest technology developments", "TechCrunch", "https://example.com/tech");
    items.emplace_back("Market Analysis Today", "Financial market insights", "Bloomberg", "https://example.com/market");
    return items;
}

}  // namespace services
}  // namespace dashboard