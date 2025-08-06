#include "services/weather_service.h"
#include <iostream>
#include <sstream>
#include <iomanip>
#include <algorithm>
#include <mutex>

namespace dashboard {
namespace services {

// cURL write callback implementation
size_t WeatherService::writeCallback(void* contents, size_t size, size_t nmemb, std::string* user_data) {
    size_t real_size = size * nmemb;
    user_data->append(static_cast<char*>(contents), real_size);
    return real_size;
}

WeatherService::WeatherService() 
    : base_url_("https://api.openweathermap.org/data/2.5/")
    , curl_handle_(nullptr)
    , default_units_(Units::METRIC)
    , default_language_("en")
    , cache_ttl_seconds_(600) // 10 minutes default cache
{
    // Initialize cURL
    curl_handle_ = curl_easy_init();
    if (!curl_handle_) {
        std::cerr << "WeatherService: Failed to initialize cURL" << std::endl;
    }
}

WeatherService::~WeatherService() {
    if (curl_handle_) {
        curl_easy_cleanup(curl_handle_);
    }
}

bool WeatherService::initialize(const std::string& api_key, Units units, const std::string& language) {
    if (api_key.empty()) {
        std::cerr << "WeatherService: API key cannot be empty" << std::endl;
        return false;
    }

    if (!curl_handle_) {
        std::cerr << "WeatherService: cURL not initialized" << std::endl;
        return false;
    }

    api_key_ = api_key;
    default_units_ = units;
    default_language_ = language.empty() ? "en" : language;

    // Test API key with a simple request
    try {
        std::string test_response = getCurrentWeather(51.5074, -0.1278); // London coordinates
        nlohmann::json json_response = nlohmann::json::parse(test_response);
        
        // Check if response contains error
        if (json_response.contains("cod")) {
            int code = json_response["cod"];
            if (code == 401) {
                std::cerr << "WeatherService: Invalid API key" << std::endl;
                return false;
            } else if (code != 200) {
                std::cerr << "WeatherService: API test failed with code " << code << std::endl;
                return false;
            }
        }

        std::cout << "WeatherService: Successfully initialized with API key" << std::endl;
        return true;
        
    } catch (const std::exception& e) {
        std::cerr << "WeatherService: Initialization test failed: " << e.what() << std::endl;
        return false;
    }
}

std::string WeatherService::getCurrentWeather(double latitude, double longitude, 
                                            Units units, const std::string& language) {
    if (!validateCoordinates(latitude, longitude)) {
        return handleApiError(400, "Invalid coordinates");
    }

    // Build parameters
    std::map<std::string, std::string> params;
    params["lat"] = std::to_string(latitude);
    params["lon"] = std::to_string(longitude);
    params["appid"] = api_key_;
    params["units"] = unitsToString(units);
    params["lang"] = language.empty() ? default_language_ : language;

    // Check cache first
    std::string cache_key = generateCacheKey("current", params);
    std::string cached_data = getCachedData(cache_key);
    if (!cached_data.empty()) {
        return cached_data;
    }

    // Make API request
    std::string url = buildApiUrl("weather", params);
    HttpResponse response = performHttpRequest(url);

    if (response.success && response.status_code == 200) {
        // Cache successful response
        setCachedData(cache_key, response.data);
        return response.data;
    } else {
        return handleApiError(response.status_code, response.data);
    }
}

std::string WeatherService::getCurrentWeather(const std::string& city_name,
                                            const std::string& state_code,
                                            const std::string& country_code,
                                            Units units, const std::string& language) {
    if (city_name.empty()) {
        return handleApiError(400, "City name cannot be empty");
    }

    // Build query string for city
    std::string query = city_name;
    if (!state_code.empty()) {
        query += "," + state_code;
    }
    if (!country_code.empty()) {
        query += "," + country_code;
    }

    // Build parameters
    std::map<std::string, std::string> params;
    params["q"] = query;
    params["appid"] = api_key_;
    params["units"] = unitsToString(units);
    params["lang"] = language.empty() ? default_language_ : language;

    // Check cache first
    std::string cache_key = generateCacheKey("current", params);
    std::string cached_data = getCachedData(cache_key);
    if (!cached_data.empty()) {
        return cached_data;
    }

    // Make API request
    std::string url = buildApiUrl("weather", params);
    HttpResponse response = performHttpRequest(url);

    if (response.success && response.status_code == 200) {
        // Cache successful response
        setCachedData(cache_key, response.data);
        return response.data;
    } else {
        return handleApiError(response.status_code, response.data);
    }
}

std::string WeatherService::getForecast(double latitude, double longitude,
                                       int count, Units units, const std::string& language) {
    if (!validateCoordinates(latitude, longitude)) {
        return handleApiError(400, "Invalid coordinates");
    }

    // Build parameters
    std::map<std::string, std::string> params;
    params["lat"] = std::to_string(latitude);
    params["lon"] = std::to_string(longitude);
    params["appid"] = api_key_;
    params["units"] = unitsToString(units);
    params["lang"] = language.empty() ? default_language_ : language;
    
    if (count > 0 && count <= 40) {
        params["cnt"] = std::to_string(count);
    }

    // Check cache first
    std::string cache_key = generateCacheKey("forecast", params);
    std::string cached_data = getCachedData(cache_key);
    if (!cached_data.empty()) {
        return cached_data;
    }

    // Make API request
    std::string url = buildApiUrl("forecast", params);
    HttpResponse response = performHttpRequest(url);

    if (response.success && response.status_code == 200) {
        // Cache successful response
        setCachedData(cache_key, response.data);
        return response.data;
    } else {
        return handleApiError(response.status_code, response.data);
    }
}

std::string WeatherService::geocodeLocation(const std::string& location, int limit) {
    if (location.empty()) {
        return handleApiError(400, "Location cannot be empty");
    }

    // Build parameters for geocoding API
    std::map<std::string, std::string> params;
    params["q"] = location;
    params["limit"] = std::to_string(std::max(1, std::min(limit, 5))); // Clamp to 1-5
    params["appid"] = api_key_;

    // Check cache first
    std::string cache_key = generateCacheKey("geocode", params);
    std::string cached_data = getCachedData(cache_key);
    if (!cached_data.empty()) {
        return cached_data;
    }

    // Use different base URL for geocoding
    std::string url = "https://api.openweathermap.org/geo/1.0/direct?";
    bool first_param = true;
    for (const auto& param : params) {
        if (!first_param) url += "&";
        url += urlEncode(param.first) + "=" + urlEncode(param.second);
        first_param = false;
    }

    HttpResponse response = performHttpRequest(url);

    if (response.success && response.status_code == 200) {
        // Cache successful response
        setCachedData(cache_key, response.data);
        return response.data;
    } else {
        return handleApiError(response.status_code, response.data);
    }
}

std::string WeatherService::reverseGeocode(double latitude, double longitude, int limit) {
    if (!validateCoordinates(latitude, longitude)) {
        return handleApiError(400, "Invalid coordinates");
    }

    // Build parameters for reverse geocoding
    std::map<std::string, std::string> params;
    params["lat"] = std::to_string(latitude);
    params["lon"] = std::to_string(longitude);
    params["limit"] = std::to_string(std::max(1, std::min(limit, 5))); // Clamp to 1-5
    params["appid"] = api_key_;

    // Check cache first
    std::string cache_key = generateCacheKey("reverse_geocode", params);
    std::string cached_data = getCachedData(cache_key);
    if (!cached_data.empty()) {
        return cached_data;
    }

    // Use different base URL for reverse geocoding
    std::string url = "https://api.openweathermap.org/geo/1.0/reverse?";
    bool first_param = true;
    for (const auto& param : params) {
        if (!first_param) url += "&";
        url += urlEncode(param.first) + "=" + urlEncode(param.second);
        first_param = false;
    }

    HttpResponse response = performHttpRequest(url);

    if (response.success && response.status_code == 200) {
        // Cache successful response
        setCachedData(cache_key, response.data);
        return response.data;
    } else {
        return handleApiError(response.status_code, response.data);
    }
}

void WeatherService::setCacheTTL(int ttl_seconds) {
    cache_ttl_seconds_ = std::max(60, ttl_seconds); // Minimum 1 minute
}

void WeatherService::clearCache() {
    std::lock_guard<std::mutex> lock(cache_mutex_);
    weather_cache_.clear();
}

std::string WeatherService::getStatus() const {
    nlohmann::json status;
    status["service"] = "WeatherService";
    status["initialized"] = !api_key_.empty();
    status["api_key_set"] = !api_key_.empty();
    status["base_url"] = base_url_;
    status["default_units"] = unitsToString(default_units_);
    status["default_language"] = default_language_;
    status["cache_ttl_seconds"] = cache_ttl_seconds_;
    
    {
        std::lock_guard<std::mutex> lock(cache_mutex_);
        status["cache_entries"] = weather_cache_.size();
    }
    
    return status.dump();
}

// Private methods implementation

WeatherService::HttpResponse WeatherService::performHttpRequest(const std::string& url) const {
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
    curl_easy_setopt(curl_handle_, CURLOPT_USERAGENT, "ModernDashboard/1.0");

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

std::string WeatherService::buildApiUrl(const std::string& endpoint, 
                                       const std::map<std::string, std::string>& params) const {
    std::string url = base_url_ + endpoint + "?";
    
    bool first_param = true;
    for (const auto& param : params) {
        if (!first_param) {
            url += "&";
        }
        url += urlEncode(param.first) + "=" + urlEncode(param.second);
        first_param = false;
    }
    
    return url;
}

std::string WeatherService::unitsToString(Units units) const {
    switch (units) {
        case Units::STANDARD: return "standard";
        case Units::METRIC: return "metric";
        case Units::IMPERIAL: return "imperial";
        default: return "metric";
    }
}

std::string WeatherService::urlEncode(const std::string& value) const {
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

std::string WeatherService::generateCacheKey(const std::string& type, 
                                           const std::map<std::string, std::string>& params) const {
    std::string key = type + ":";
    
    // Sort parameters for consistent key generation
    std::map<std::string, std::string> sorted_params(params);
    for (const auto& param : sorted_params) {
        if (param.first != "appid") { // Don't include API key in cache key
            key += param.first + "=" + param.second + ";";
        }
    }
    
    return key;
}

std::string WeatherService::getCachedData(const std::string& cache_key) const {
    std::lock_guard<std::mutex> lock(cache_mutex_);
    
    auto it = weather_cache_.find(cache_key);
    if (it != weather_cache_.end()) {
        if (!it->second.is_expired()) {
            return it->second.data;
        } else {
            // Remove expired entry
            weather_cache_.erase(it);
        }
    }
    
    return "";
}

void WeatherService::setCachedData(const std::string& cache_key, const std::string& data) const {
    std::lock_guard<std::mutex> lock(cache_mutex_);
    
    CacheEntry entry;
    entry.data = data;
    entry.cached_at = time(nullptr);
    entry.expires_at = entry.cached_at + cache_ttl_seconds_;
    
    weather_cache_[cache_key] = entry;
}

std::string WeatherService::handleApiError(long status_code, const std::string& response_data) const {
    nlohmann::json error_response;
    error_response["error"] = true;
    error_response["status_code"] = status_code;
    error_response["service"] = "WeatherService";
    
    // Try to parse API error response
    try {
        nlohmann::json api_error = nlohmann::json::parse(response_data);
        if (api_error.contains("message")) {
            error_response["message"] = api_error["message"];
        }
        if (api_error.contains("cod")) {
            error_response["api_code"] = api_error["cod"];
        }
    } catch (const std::exception&) {
        // If parsing fails, use HTTP status-based messages
        switch (status_code) {
            case 400:
                error_response["message"] = "Bad request - check parameters";
                break;
            case 401:
                error_response["message"] = "Unauthorized - check API key";
                break;
            case 404:
                error_response["message"] = "Location not found";
                break;
            case 429:
                error_response["message"] = "Too many requests - rate limit exceeded";
                break;
            case 500:
            case 502:
            case 503:
                error_response["message"] = "Server error - try again later";
                break;
            default:
                error_response["message"] = response_data.empty() ? "Unknown error" : response_data;
                break;
        }
    }
    
    return error_response.dump();
}

bool WeatherService::validateCoordinates(double latitude, double longitude) {
    return (latitude >= -90.0 && latitude <= 90.0 && 
            longitude >= -180.0 && longitude <= 180.0);
}

} // namespace services
} // namespace dashboard