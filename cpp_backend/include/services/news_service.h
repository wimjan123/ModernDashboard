#ifndef NEWS_SERVICE_H
#define NEWS_SERVICE_H

#include "core/widget_interface.h"
#include <string>
#include <vector>
#include <memory>
#include <map>
#include <mutex>
#include <ctime>
#include <tinyxml2.h>
#include <curl/curl.h>
#include <nlohmann/json.hpp>

namespace dashboard {
namespace services {

/**
 * @brief NewsService provides RSS/Atom feed parsing and news aggregation
 * 
 * Features:
 * - Multiple RSS/Atom feed support with automatic detection
 * - Article deduplication by title and URL
 * - Content caching with configurable TTL
 * - Feed management (add/remove/update)
 * - Error handling with graceful fallbacks
 * - JSON output for Flutter integration
 */
class NewsService {
public:
    /**
     * @brief HTTP response structure for feed requests
     */
    struct HttpResponse {
        std::string data;
        long status_code;
        bool success;
        
        HttpResponse() : status_code(0), success(false) {}
    };

    /**
     * @brief News article structure
     */
    struct NewsArticle {
        std::string id;
        std::string title;
        std::string description;
        std::string link;
        std::string source;
        std::string author;
        std::string category;
        std::time_t published_date;
        std::time_t cached_at;
        
        NewsArticle() : published_date(0), cached_at(0) {}
    };

    /**
     * @brief RSS/Atom feed information
     */
    struct Feed {
        std::string url;
        std::string title;
        std::string description;
        std::string last_error;
        std::time_t last_updated;
        std::time_t last_fetch_attempt;
        bool is_active;
        
        Feed(const std::string& feed_url) 
            : url(feed_url), last_updated(0), last_fetch_attempt(0), is_active(true) {}
    };

    /**
     * @brief Feed type detection result
     */
    enum class FeedType {
        RSS_2_0,
        ATOM_1_0,
        RSS_1_0,
        UNKNOWN
    };

    /**
     * @brief News cache entry
     */
    struct CacheEntry {
        std::vector<NewsArticle> articles;
        std::time_t cached_at;
        std::time_t expires_at;
        
        bool is_expired() const {
            return time(nullptr) > expires_at;
        }
    };

private:
    std::vector<Feed> feeds_;
    std::map<std::string, CacheEntry> news_cache_;
    CURL* curl_handle_;
    int cache_ttl_seconds_;
    int max_articles_per_feed_;
    mutable std::mutex feeds_mutex_;
    mutable std::mutex cache_mutex_;

public:
    /**
     * @brief Constructor
     */
    NewsService();
    
    /**
     * @brief Destructor - cleanup cURL resources
     */
    ~NewsService();

    /**
     * @brief Initialize the news service
     * @param cache_ttl_seconds Cache time-to-live in seconds (default: 1800 = 30 minutes)
     * @param max_articles_per_feed Maximum articles to keep per feed (default: 50)
     * @return true if initialization successful
     */
    bool initialize(int cache_ttl_seconds = 1800, int max_articles_per_feed = 50);

    /**
     * @brief Add a new RSS/Atom feed
     * @param feed_url URL of the RSS/Atom feed
     * @return true if feed was added successfully
     */
    bool addFeed(const std::string& feed_url);

    /**
     * @brief Remove an RSS/Atom feed
     * @param feed_url URL of the feed to remove
     * @return true if feed was removed successfully
     */
    bool removeFeed(const std::string& feed_url);

    /**
     * @brief Get list of all configured feeds
     * @return JSON string with feed information
     */
    std::string getFeeds() const;

    /**
     * @brief Get latest news from all feeds
     * @param force_refresh Force refresh all feeds (ignore cache)
     * @return JSON string with news articles
     */
    std::string getLatestNews(bool force_refresh = false);

    /**
     * @brief Refresh all feeds manually
     * @return Number of feeds successfully updated
     */
    int refreshAllFeeds();

    /**
     * @brief Clear all cached news data
     */
    void clearCache();

    /**
     * @brief Set cache TTL for news data
     * @param ttl_seconds Time to live in seconds (minimum: 300 = 5 minutes)
     */
    void setCacheTTL(int ttl_seconds);

    /**
     * @brief Get service status and configuration info
     * @return JSON string with service status
     */
    std::string getStatus() const;

private:
    /**
     * @brief Perform HTTP GET request
     * @param url Full URL to request
     * @return HttpResponse with data and status
     */
    HttpResponse performHttpRequest(const std::string& url) const;

    /**
     * @brief Detect the type of RSS/Atom feed
     * @param xml_content XML content to analyze
     * @return FeedType enumeration
     */
    FeedType detectFeedType(const std::string& xml_content) const;

    /**
     * @brief Parse RSS 2.0 feed content
     * @param xml_content XML content of RSS feed
     * @param feed_info Feed information structure
     * @return Vector of parsed news articles
     */
    std::vector<NewsArticle> parseRSSFeed(const std::string& xml_content, const Feed& feed_info) const;

    /**
     * @brief Parse Atom 1.0 feed content
     * @param xml_content XML content of Atom feed
     * @param feed_info Feed information structure
     * @return Vector of parsed news articles
     */
    std::vector<NewsArticle> parseAtomFeed(const std::string& xml_content, const Feed& feed_info) const;

    /**
     * @brief Generate unique article ID from title and link
     * @param title Article title
     * @param link Article URL
     * @return Unique article identifier
     */
    std::string generateArticleId(const std::string& title, const std::string& link) const;

    /**
     * @brief Parse RFC822/ISO8601 date string to time_t
     * @param date_str Date string from RSS/Atom feed
     * @return Parsed time_t value, or 0 if parsing fails
     */
    std::time_t parseDate(const std::string& date_str) const;

    /**
     * @brief Clean HTML tags from text content
     * @param text Text content that may contain HTML
     * @return Plain text with HTML tags removed
     */
    std::string stripHtmlTags(const std::string& text) const;

    /**
     * @brief URL encode a string for safe transmission
     * @param value String to encode
     * @return URL-encoded string
     */
    std::string urlEncode(const std::string& value) const;

    /**
     * @brief Generate cache key for feed data
     * @param feed_url Feed URL to generate key for
     * @return Unique cache key string
     */
    std::string generateCacheKey(const std::string& feed_url) const;

    /**
     * @brief Get cached news data if available and not expired
     * @param cache_key Cache key to lookup
     * @return Cached articles vector, empty if not found/expired
     */
    std::vector<NewsArticle> getCachedNews(const std::string& cache_key) const;

    /**
     * @brief Store news data in cache with TTL
     * @param cache_key Cache key to store under
     * @param articles Articles to cache
     */
    void setCachedNews(const std::string& cache_key, const std::vector<NewsArticle>& articles) const;

    /**
     * @brief Convert articles vector to JSON string
     * @param articles Vector of NewsArticle objects
     * @return JSON string representation
     */
    std::string articlesToJson(const std::vector<NewsArticle>& articles) const;

    /**
     * @brief Deduplicate articles by title similarity and URL
     * @param articles Vector of articles to deduplicate
     * @return Deduplicated vector of articles
     */
    std::vector<NewsArticle> deduplicateArticles(const std::vector<NewsArticle>& articles) const;

    /**
     * @brief cURL write callback function
     * @param contents Response data
     * @param size Size of each data element
     * @param nmemb Number of data elements
     * @param user_data Pointer to std::string for storage
     * @return Number of bytes processed
     */
    static size_t writeCallback(void* contents, size_t size, size_t nmemb, std::string* user_data);

    /**
     * @brief Extract text content from XML element
     * @param element TinyXML2 element pointer
     * @return Text content as string, empty if not found
     */
    static std::string getElementText(const tinyxml2::XMLElement* element);

    /**
     * @brief Extract attribute value from XML element
     * @param element TinyXML2 element pointer
     * @param attr_name Attribute name to extract
     * @return Attribute value as string, empty if not found
     */
    static std::string getElementAttribute(const tinyxml2::XMLElement* element, const char* attr_name);
};

/**
 * @brief Widget wrapper for NewsService that implements IWidget interface
 */
class NewsWidget : public core::IWidget {
private:
    std::unique_ptr<NewsService> news_service_;

public:
    NewsWidget();
    virtual ~NewsWidget() = default;
    
    // IWidget implementation
    bool Initialize() override;
    void Update() override;
    std::string GetData() const override;
    void SetConfig(const std::string& config) override;
    void Cleanup() override;
    std::string GetId() const override { return "news"; }
    bool IsActive() const override;
    
    // Direct access to NewsService for advanced operations
    NewsService* getService() { return news_service_.get(); }
};

} // namespace services
} // namespace dashboard

#endif // NEWS_SERVICE_H