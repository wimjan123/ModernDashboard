#pragma once

#include "core/widget_interface.h"
#include "../../../shared/data_models.h"
#include <vector>
#include <chrono>
#include <atomic>
#include <mutex>

namespace dashboard {
namespace services {

class NewsService : public core::IWidget {
private:
    std::vector<std::string> rss_feeds_;
    std::vector<NewsItem> cached_news_;
    std::chrono::steady_clock::time_point last_update_;
    std::atomic<bool> initialized_;
    mutable std::mutex data_mutex_;
    
    void LoadDefaultFeeds();
    std::vector<NewsItem> FetchFromFeeds();
    std::string FormatNewsAsJson() const;
    
public:
    NewsService();
    virtual ~NewsService() = default;
    
    // IWidget implementation
    bool Initialize() override;
    void Update() override;
    std::string GetData() const override;
    void SetConfig(const std::string& config) override;
    void Cleanup() override;
    std::string GetId() const override { return "news"; }
    bool IsActive() const override { return initialized_.load(); }
    
    // News-specific methods
    void AddRssFeed(const std::string& url);
    void RemoveRssFeed(const std::string& url);
};

}  // namespace services
}  // namespace dashboard