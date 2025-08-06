#include "services/news_service.h"
#include <iostream>
#include <sstream>
#include <iomanip>
#include <algorithm>
#include <regex>
#include <functional>
#include <set>
#include <cstring>

namespace dashboard {
namespace services {

// cURL write callback implementation
size_t NewsService::writeCallback(void* contents, size_t size, size_t nmemb, std::string* user_data) {
    size_t real_size = size * nmemb;
    user_data->append(static_cast<char*>(contents), real_size);
    return real_size;
}

NewsService::NewsService() 
    : curl_handle_(nullptr)
    , cache_ttl_seconds_(1800) // 30 minutes default cache
    , max_articles_per_feed_(50)
{
    // Initialize cURL
    curl_handle_ = curl_easy_init();
    if (!curl_handle_) {
        std::cerr << "NewsService: Failed to initialize cURL" << std::endl;
    }
}

NewsService::~NewsService() {
    if (curl_handle_) {
        curl_easy_cleanup(curl_handle_);
    }
}

bool NewsService::initialize(int cache_ttl_seconds, int max_articles_per_feed) {
    if (!curl_handle_) {
        std::cerr << "NewsService: cURL not initialized" << std::endl;
        return false;
    }

    cache_ttl_seconds_ = std::max(300, cache_ttl_seconds); // Minimum 5 minutes
    max_articles_per_feed_ = std::max(1, std::min(max_articles_per_feed, 200)); // 1-200 range

    // Add some default feeds for demo purposes
    std::lock_guard<std::mutex> lock(feeds_mutex_);
    feeds_.clear();
    
    // Add popular RSS feeds
    feeds_.emplace_back("https://rss.cnn.com/rss/edition.rss");
    feeds_.emplace_back("https://feeds.bbci.co.uk/news/world/rss.xml");
    feeds_.emplace_back("https://techcrunch.com/feed/");
    feeds_.emplace_back("https://www.reddit.com/r/technology/.rss");
    
    std::cout << "NewsService: Successfully initialized with " << feeds_.size() << " default feeds" << std::endl;
    return true;
}

bool NewsService::addFeed(const std::string& feed_url) {
    if (feed_url.empty()) {
        return false;
    }

    std::lock_guard<std::mutex> lock(feeds_mutex_);
    
    // Check if feed already exists
    for (const auto& feed : feeds_) {
        if (feed.url == feed_url) {
            return false; // Already exists
        }
    }

    // Test the feed by trying to fetch it
    HttpResponse response = performHttpRequest(feed_url);
    if (!response.success || response.status_code != 200) {
        std::cerr << "NewsService: Failed to validate feed: " << feed_url << std::endl;
        return false;
    }

    // Detect feed type
    FeedType type = detectFeedType(response.data);
    if (type == FeedType::UNKNOWN) {
        std::cerr << "NewsService: Unknown feed format: " << feed_url << std::endl;
        return false;
    }

    // Add the feed
    feeds_.emplace_back(feed_url);
    std::cout << "NewsService: Added feed: " << feed_url << std::endl;
    return true;
}

bool NewsService::removeFeed(const std::string& feed_url) {
    std::lock_guard<std::mutex> lock(feeds_mutex_);
    
    auto it = std::find_if(feeds_.begin(), feeds_.end(),
        [&feed_url](const Feed& feed) {
            return feed.url == feed_url;
        });
    
    if (it != feeds_.end()) {
        feeds_.erase(it);
        
        // Clear cached data for this feed
        std::lock_guard<std::mutex> cache_lock(cache_mutex_);
        std::string cache_key = generateCacheKey(feed_url);
        news_cache_.erase(cache_key);
        
        return true;
    }
    
    return false;
}

std::string NewsService::getFeeds() const {
    std::lock_guard<std::mutex> lock(feeds_mutex_);
    
    nlohmann::json feeds_json = nlohmann::json::array();
    
    for (const auto& feed : feeds_) {
        nlohmann::json feed_json;
        feed_json["url"] = feed.url;
        feed_json["title"] = feed.title;
        feed_json["description"] = feed.description;
        feed_json["last_updated"] = feed.last_updated;
        feed_json["last_error"] = feed.last_error;
        feed_json["is_active"] = feed.is_active;
        feeds_json.push_back(feed_json);
    }
    
    return feeds_json.dump();
}

std::string NewsService::getLatestNews(bool force_refresh) {
    std::vector<NewsArticle> all_articles;
    
    {
        std::lock_guard<std::mutex> lock(feeds_mutex_);
        
        for (auto& feed : feeds_) {
            if (!feed.is_active) {
                continue;
            }
            
            std::string cache_key = generateCacheKey(feed.url);
            std::vector<NewsArticle> cached_articles;
            
            if (!force_refresh) {
                cached_articles = getCachedNews(cache_key);
            }
            
            if (cached_articles.empty()) {
                // Fetch fresh data
                HttpResponse response = performHttpRequest(feed.url);
                feed.last_fetch_attempt = time(nullptr);
                
                if (response.success && response.status_code == 200) {
                    FeedType type = detectFeedType(response.data);
                    std::vector<NewsArticle> articles;
                    
                    if (type == FeedType::RSS_2_0 || type == FeedType::RSS_1_0) {
                        articles = parseRSSFeed(response.data, feed);
                    } else if (type == FeedType::ATOM_1_0) {
                        articles = parseAtomFeed(response.data, feed);
                    }
                    
                    if (!articles.empty()) {
                        feed.last_updated = time(nullptr);
                        feed.last_error.clear();
                        setCachedNews(cache_key, articles);
                        cached_articles = articles;
                    } else {
                        feed.last_error = "Failed to parse feed content";
                    }
                } else {
                    feed.last_error = "HTTP error: " + std::to_string(response.status_code);
                }
            }
            
            // Add articles from this feed to the collection
            all_articles.insert(all_articles.end(), cached_articles.begin(), cached_articles.end());
        }
    }
    
    // Deduplicate and sort articles
    all_articles = deduplicateArticles(all_articles);
    
    // Sort by publication date (newest first)
    std::sort(all_articles.begin(), all_articles.end(),
        [](const NewsArticle& a, const NewsArticle& b) {
            return a.published_date > b.published_date;
        });
    
    // Limit total articles
    if (all_articles.size() > 100) {
        all_articles.resize(100);
    }
    
    return articlesToJson(all_articles);
}

int NewsService::refreshAllFeeds() {
    return getLatestNews(true).empty() ? 0 : static_cast<int>(feeds_.size());
}

void NewsService::clearCache() {
    std::lock_guard<std::mutex> lock(cache_mutex_);
    news_cache_.clear();
}

void NewsService::setCacheTTL(int ttl_seconds) {
    cache_ttl_seconds_ = std::max(300, ttl_seconds); // Minimum 5 minutes
}

std::string NewsService::getStatus() const {
    nlohmann::json status;
    status["service"] = "NewsService";
    status["initialized"] = (curl_handle_ != nullptr);
    status["cache_ttl_seconds"] = cache_ttl_seconds_;
    status["max_articles_per_feed"] = max_articles_per_feed_;
    
    {
        std::lock_guard<std::mutex> lock(feeds_mutex_);
        status["total_feeds"] = feeds_.size();
        
        int active_feeds = 0;
        for (const auto& feed : feeds_) {
            if (feed.is_active) active_feeds++;
        }
        status["active_feeds"] = active_feeds;
    }
    
    {
        std::lock_guard<std::mutex> lock(cache_mutex_);
        status["cache_entries"] = news_cache_.size();
    }
    
    return status.dump();
}

// Private methods implementation

NewsService::HttpResponse NewsService::performHttpRequest(const std::string& url) const {
    HttpResponse response;

    if (!curl_handle_) {
        response.status_code = 0;
        response.success = false;
        return response;
    }

    // Reset cURL handle
    curl_easy_reset(curl_handle_);
    
    // Set cURL options
    curl_easy_setopt(curl_handle_, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl_handle_, CURLOPT_WRITEFUNCTION, writeCallback);
    curl_easy_setopt(curl_handle_, CURLOPT_WRITEDATA, &response.data);
    curl_easy_setopt(curl_handle_, CURLOPT_TIMEOUT, 30L); // 30 second timeout
    curl_easy_setopt(curl_handle_, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl_handle_, CURLOPT_SSL_VERIFYPEER, 1L);
    curl_easy_setopt(curl_handle_, CURLOPT_SSL_VERIFYHOST, 2L);
    curl_easy_setopt(curl_handle_, CURLOPT_USERAGENT, "ModernDashboard/1.0 RSS Reader");

    // Perform the request
    CURLcode curl_result = curl_easy_perform(curl_handle_);
    
    if (curl_result == CURLE_OK) {
        curl_easy_getinfo(curl_handle_, CURLINFO_RESPONSE_CODE, &response.status_code);
        response.success = true;
    } else {
        response.status_code = 0;
        response.success = false;
        response.data = curl_easy_strerror(curl_result);
    }

    return response;
}

NewsService::FeedType NewsService::detectFeedType(const std::string& xml_content) const {
    // Simple detection based on root element
    if (xml_content.find("<rss") != std::string::npos) {
        if (xml_content.find("version=\"2.0\"") != std::string::npos) {
            return FeedType::RSS_2_0;
        } else {
            return FeedType::RSS_1_0;
        }
    } else if (xml_content.find("<feed") != std::string::npos && 
               xml_content.find("xmlns=\"http://www.w3.org/2005/Atom\"") != std::string::npos) {
        return FeedType::ATOM_1_0;
    }
    
    return FeedType::UNKNOWN;
}

std::vector<NewsService::NewsArticle> NewsService::parseRSSFeed(const std::string& xml_content, const Feed& feed_info) const {
    std::vector<NewsArticle> articles;
    
    tinyxml2::XMLDocument doc;
    if (doc.Parse(xml_content.c_str()) != tinyxml2::XML_SUCCESS) {
        return articles;
    }
    
    tinyxml2::XMLElement* rss = doc.FirstChildElement("rss");
    if (!rss) return articles;
    
    tinyxml2::XMLElement* channel = rss->FirstChildElement("channel");
    if (!channel) return articles;
    
    // Parse channel info
    std::string feed_title = getElementText(channel->FirstChildElement("title"));
    std::string feed_description = getElementText(channel->FirstChildElement("description"));
    
    // Parse items
    for (tinyxml2::XMLElement* item = channel->FirstChildElement("item");
         item != nullptr && articles.size() < max_articles_per_feed_;
         item = item->NextSiblingElement("item")) {
        
        NewsArticle article;
        article.title = stripHtmlTags(getElementText(item->FirstChildElement("title")));
        article.description = stripHtmlTags(getElementText(item->FirstChildElement("description")));
        article.link = getElementText(item->FirstChildElement("link"));
        article.author = getElementText(item->FirstChildElement("author"));
        article.category = getElementText(item->FirstChildElement("category"));
        article.source = feed_title.empty() ? feed_info.url : feed_title;
        
        // Parse publication date
        std::string pub_date = getElementText(item->FirstChildElement("pubDate"));
        article.published_date = parseDate(pub_date);
        
        // Generate unique ID
        article.id = generateArticleId(article.title, article.link);
        article.cached_at = time(nullptr);
        
        if (!article.title.empty() && !article.link.empty()) {
            articles.push_back(article);
        }
    }
    
    return articles;
}

std::vector<NewsService::NewsArticle> NewsService::parseAtomFeed(const std::string& xml_content, const Feed& feed_info) const {
    std::vector<NewsArticle> articles;
    
    tinyxml2::XMLDocument doc;
    if (doc.Parse(xml_content.c_str()) != tinyxml2::XML_SUCCESS) {
        return articles;
    }
    
    tinyxml2::XMLElement* feed = doc.FirstChildElement("feed");
    if (!feed) return articles;
    
    // Parse feed info
    std::string feed_title = getElementText(feed->FirstChildElement("title"));
    
    // Parse entries
    for (tinyxml2::XMLElement* entry = feed->FirstChildElement("entry");
         entry != nullptr && articles.size() < max_articles_per_feed_;
         entry = entry->NextSiblingElement("entry")) {
        
        NewsArticle article;
        article.title = stripHtmlTags(getElementText(entry->FirstChildElement("title")));
        article.source = feed_title.empty() ? feed_info.url : feed_title;
        
        // Get summary or content
        tinyxml2::XMLElement* summary = entry->FirstChildElement("summary");
        tinyxml2::XMLElement* content = entry->FirstChildElement("content");
        if (summary) {
            article.description = stripHtmlTags(getElementText(summary));
        } else if (content) {
            article.description = stripHtmlTags(getElementText(content));
        }
        
        // Get link (Atom can have multiple links)
        tinyxml2::XMLElement* link = entry->FirstChildElement("link");
        if (link) {
            article.link = getElementAttribute(link, "href");
        }
        
        // Get author
        tinyxml2::XMLElement* author = entry->FirstChildElement("author");
        if (author) {
            article.author = getElementText(author->FirstChildElement("name"));
        }
        
        // Get category
        tinyxml2::XMLElement* category = entry->FirstChildElement("category");
        if (category) {
            article.category = getElementAttribute(category, "term");
        }
        
        // Parse publication date (updated or published)
        std::string pub_date = getElementText(entry->FirstChildElement("updated"));
        if (pub_date.empty()) {
            pub_date = getElementText(entry->FirstChildElement("published"));
        }
        article.published_date = parseDate(pub_date);
        
        // Generate unique ID
        article.id = generateArticleId(article.title, article.link);
        article.cached_at = time(nullptr);
        
        if (!article.title.empty() && !article.link.empty()) {
            articles.push_back(article);
        }
    }
    
    return articles;
}

std::string NewsService::generateArticleId(const std::string& title, const std::string& link) const {
    std::hash<std::string> hasher;
    return std::to_string(hasher(title + link));
}

std::time_t NewsService::parseDate(const std::string& date_str) const {
    if (date_str.empty()) {
        return time(nullptr); // Return current time if no date
    }
    
    // Try parsing RFC822 format (RSS): "Wed, 18 Oct 2023 14:30:00 +0000"
    std::tm tm = {};
    char* result = strptime(date_str.c_str(), "%a, %d %b %Y %H:%M:%S", &tm);
    if (result) {
        return mktime(&tm);
    }
    
    // Try parsing ISO8601 format (Atom): "2023-10-18T14:30:00Z"
    result = strptime(date_str.c_str(), "%Y-%m-%dT%H:%M:%S", &tm);
    if (result) {
        return mktime(&tm);
    }
    
    // Try parsing simple date format: "2023-10-18"
    result = strptime(date_str.c_str(), "%Y-%m-%d", &tm);
    if (result) {
        return mktime(&tm);
    }
    
    // If all parsing fails, return current time
    return time(nullptr);
}

std::string NewsService::stripHtmlTags(const std::string& text) const {
    if (text.empty()) return text;
    
    std::regex html_tag("<[^>]*>");
    std::string clean_text = std::regex_replace(text, html_tag, "");
    
    // Replace common HTML entities
    std::regex amp("&amp;");
    clean_text = std::regex_replace(clean_text, amp, "&");
    
    std::regex lt("&lt;");
    clean_text = std::regex_replace(clean_text, lt, "<");
    
    std::regex gt("&gt;");
    clean_text = std::regex_replace(clean_text, gt, ">");
    
    std::regex quot("&quot;");
    clean_text = std::regex_replace(clean_text, quot, "\"");
    
    std::regex apos("&apos;");
    clean_text = std::regex_replace(clean_text, apos, "'");
    
    // Remove excessive whitespace
    std::regex whitespace("\\s+");
    clean_text = std::regex_replace(clean_text, whitespace, " ");
    
    // Trim leading and trailing whitespace
    clean_text.erase(clean_text.begin(), std::find_if(clean_text.begin(), clean_text.end(), [](unsigned char ch) {
        return !std::isspace(ch);
    }));
    clean_text.erase(std::find_if(clean_text.rbegin(), clean_text.rend(), [](unsigned char ch) {
        return !std::isspace(ch);
    }).base(), clean_text.end());
    
    return clean_text;
}

std::string NewsService::urlEncode(const std::string& value) const {
    std::ostringstream encoded;
    encoded.fill('0');
    encoded << std::hex;

    for (char c : value) {
        // Keep alphanumeric and special characters
        if (std::isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~') {
            encoded << c;
        } else {
            encoded << '%' << std::setw(2) << int(static_cast<unsigned char>(c));
        }
    }

    return encoded.str();
}

std::string NewsService::generateCacheKey(const std::string& feed_url) const {
    std::hash<std::string> hasher;
    return "feed:" + std::to_string(hasher(feed_url));
}

std::vector<NewsService::NewsArticle> NewsService::getCachedNews(const std::string& cache_key) const {
    std::lock_guard<std::mutex> lock(cache_mutex_);
    
    auto it = news_cache_.find(cache_key);
    if (it != news_cache_.end()) {
        if (!it->second.is_expired()) {
            return it->second.articles;
        } else {
            // Remove expired entry (const_cast needed for cleanup in const method)
            const_cast<std::map<std::string, CacheEntry>&>(news_cache_).erase(it);
        }
    }
    
    return std::vector<NewsArticle>();
}

void NewsService::setCachedNews(const std::string& cache_key, const std::vector<NewsArticle>& articles) const {
    std::lock_guard<std::mutex> lock(cache_mutex_);
    
    CacheEntry entry;
    entry.articles = articles;
    entry.cached_at = time(nullptr);
    entry.expires_at = entry.cached_at + cache_ttl_seconds_;
    
    const_cast<std::map<std::string, CacheEntry>&>(news_cache_)[cache_key] = entry;
}

std::string NewsService::articlesToJson(const std::vector<NewsArticle>& articles) const {
    nlohmann::json json_array = nlohmann::json::array();
    
    for (const auto& article : articles) {
        nlohmann::json article_json;
        article_json["id"] = article.id;
        article_json["title"] = article.title;
        article_json["description"] = article.description;
        article_json["link"] = article.link;
        article_json["source"] = article.source;
        article_json["author"] = article.author;
        article_json["category"] = article.category;
        article_json["published_date"] = article.published_date;
        article_json["cached_at"] = article.cached_at;
        
        json_array.push_back(article_json);
    }
    
    return json_array.dump();
}

std::vector<NewsService::NewsArticle> NewsService::deduplicateArticles(const std::vector<NewsArticle>& articles) const {
    std::vector<NewsArticle> unique_articles;
    std::set<std::string> seen_ids;
    
    for (const auto& article : articles) {
        if (seen_ids.find(article.id) == seen_ids.end()) {
            seen_ids.insert(article.id);
            unique_articles.push_back(article);
        }
    }
    
    return unique_articles;
}

std::string NewsService::getElementText(const tinyxml2::XMLElement* element) {
    if (!element) return "";
    
    const char* text = element->GetText();
    return text ? std::string(text) : "";
}

std::string NewsService::getElementAttribute(const tinyxml2::XMLElement* element, const char* attr_name) {
    if (!element || !attr_name) return "";
    
    const char* attr_value = element->Attribute(attr_name);
    return attr_value ? std::string(attr_value) : "";
}

// NewsWidget implementation

NewsWidget::NewsWidget() {
    news_service_ = std::make_unique<NewsService>();
}

bool NewsWidget::Initialize() {
    return news_service_->initialize();
}

void NewsWidget::Update() {
    // NewsService handles its own updates internally via cache management
    // This could trigger a refresh if needed
    news_service_->getLatestNews(false); // Don't force refresh on every update
}

std::string NewsWidget::GetData() const {
    return news_service_->getLatestNews(false);
}

void NewsWidget::SetConfig(const std::string& config) {
    // Parse config and apply to NewsService
    // Expected format: {"feeds": ["url1", "url2"], "cache_ttl": 1800}
    try {
        nlohmann::json config_json = nlohmann::json::parse(config);
        
        if (config_json.contains("feeds") && config_json["feeds"].is_array()) {
            // Clear existing feeds and add new ones
            // Note: This is a simplified approach - in production you'd want to 
            // diff the feeds to avoid unnecessary removals/additions
            for (const auto& feed_url : config_json["feeds"]) {
                if (feed_url.is_string()) {
                    news_service_->addFeed(feed_url.get<std::string>());
                }
            }
        }
        
        if (config_json.contains("cache_ttl") && config_json["cache_ttl"].is_number()) {
            news_service_->setCacheTTL(config_json["cache_ttl"].get<int>());
        }
    } catch (const std::exception& e) {
        std::cerr << "NewsWidget: Failed to parse config: " << e.what() << std::endl;
    }
}

void NewsWidget::Cleanup() {
    news_service_->clearCache();
}

bool NewsWidget::IsActive() const {
    return news_service_ != nullptr;
}

} // namespace services
} // namespace dashboard