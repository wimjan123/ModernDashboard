#ifndef WEATHER_SERVICE_H
#define WEATHER_SERVICE_H

#include <string>
#include <memory>
#include <map>
#include <mutex>
#include <curl/curl.h>
#include <nlohmann/json.hpp>

namespace dashboard {
namespace services {

/**
 * @brief WeatherService provides weather data integration using OpenWeatherMap API
 * 
 * Features:
 * - Current weather data by coordinates or city name
 * - 5-day weather forecast with 3-hour intervals
 * - Location geocoding (city name to coordinates)
 * - Multiple unit systems (standard/metric/imperial)
 * - Multilingual support
 * - Error handling with fallback mechanisms
 * - Response caching with configurable TTL
 */
class WeatherService {
public:
    /**
     * @brief HTTP response structure for API calls
     */
    struct HttpResponse {
        std::string data;
        long status_code;
        bool success;
        
        HttpResponse() : status_code(0), success(false) {}
    };

    /**
     * @brief Weather units enumeration
     */
    enum class Units {
        STANDARD,   // Kelvin, meter/sec, hPa
        METRIC,     // Celsius, meter/sec, hPa  
        IMPERIAL    // Fahrenheit, miles/hour, hPa
    };

    /**
     * @brief Weather data cache entry
     */
    struct CacheEntry {
        std::string data;
        time_t cached_at;
        time_t expires_at;
        
        bool is_expired() const {
            return time(nullptr) > expires_at;
        }
    };

private:
    std::string api_key_;
    std::string base_url_;
    CURL* curl_handle_;
    Units default_units_;
    std::string default_language_;
    int cache_ttl_seconds_;
    
    // Cache for weather data (location_key -> CacheEntry)
    mutable std::map<std::string, CacheEntry> weather_cache_;
    mutable std::mutex cache_mutex_;

public:
    /**
     * @brief Constructor
     */
    WeatherService();
    
    /**
     * @brief Destructor - cleanup cURL resources
     */
    ~WeatherService();

    /**
     * @brief Initialize the weather service with API key
     * @param api_key OpenWeatherMap API key
     * @param units Default units for temperature/wind/pressure
     * @param language Default language for weather descriptions
     * @return true if initialization successful
     */
    bool initialize(const std::string& api_key, 
                   Units units = Units::METRIC, 
                   const std::string& language = "en");

    /**
     * @brief Get current weather by coordinates
     * @param latitude Latitude (-90 to 90)
     * @param longitude Longitude (-180 to 180) 
     * @param units Override default units (optional)
     * @param language Override default language (optional)
     * @return JSON string with current weather data
     */
    std::string getCurrentWeather(double latitude, double longitude, 
                                 Units units = Units::METRIC,
                                 const std::string& language = "");

    /**
     * @brief Get current weather by city name
     * @param city_name City name (e.g., "London", "New York", "Tokyo")
     * @param state_code State code (optional, for US cities)
     * @param country_code ISO 3166 country code (optional)
     * @param units Override default units (optional)
     * @param language Override default language (optional)
     * @return JSON string with current weather data
     */
    std::string getCurrentWeather(const std::string& city_name,
                                 const std::string& state_code = "",
                                 const std::string& country_code = "",
                                 Units units = Units::METRIC,
                                 const std::string& language = "");

    /**
     * @brief Get 5-day weather forecast by coordinates
     * @param latitude Latitude (-90 to 90)
     * @param longitude Longitude (-180 to 180)
     * @param count Number of timestamps to return (optional, max 40)
     * @param units Override default units (optional)
     * @param language Override default language (optional)
     * @return JSON string with 5-day forecast data
     */
    std::string getForecast(double latitude, double longitude,
                           int count = 0,
                           Units units = Units::METRIC,
                           const std::string& language = "");

    /**
     * @brief Geocode location name to coordinates
     * @param location Location query (city, state, country)
     * @param limit Maximum number of results (1-5)
     * @return JSON string with geocoding results
     */
    std::string geocodeLocation(const std::string& location, int limit = 1);

    /**
     * @brief Reverse geocode coordinates to location name
     * @param latitude Latitude (-90 to 90)
     * @param longitude Longitude (-180 to 180)
     * @param limit Maximum number of results (1-5)
     * @return JSON string with reverse geocoding results
     */
    std::string reverseGeocode(double latitude, double longitude, int limit = 1);

    /**
     * @brief Set cache TTL for weather data
     * @param ttl_seconds Time to live in seconds (default: 600 = 10 minutes)
     */
    void setCacheTTL(int ttl_seconds);

    /**
     * @brief Clear all cached weather data
     */
    void clearCache();

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
     * @brief Build API URL with parameters
     * @param endpoint API endpoint (e.g., "weather", "forecast") 
     * @param params Map of query parameters
     * @return Complete URL string
     */
    std::string buildApiUrl(const std::string& endpoint, 
                           const std::map<std::string, std::string>& params) const;

    /**
     * @brief Convert Units enum to API parameter string
     * @param units Units enumeration value
     * @return API units parameter ("standard", "metric", "imperial")
     */
    std::string unitsToString(Units units) const;

    /**
     * @brief URL encode a string for use in query parameters
     * @param value String to encode
     * @return URL-encoded string
     */
    std::string urlEncode(const std::string& value) const;

    /**
     * @brief Generate cache key for weather data
     * @param type Request type ("current", "forecast", "geocode")
     * @param params Request parameters
     * @return Unique cache key string
     */
    std::string generateCacheKey(const std::string& type, 
                                const std::map<std::string, std::string>& params) const;

    /**
     * @brief Get cached data if available and not expired
     * @param cache_key Cache key to lookup
     * @return Cached data string, empty if not found/expired
     */
    std::string getCachedData(const std::string& cache_key) const;

    /**
     * @brief Store data in cache with TTL
     * @param cache_key Cache key to store under
     * @param data Data to cache
     */
    void setCachedData(const std::string& cache_key, const std::string& data) const;

    /**
     * @brief Handle API errors and create error response
     * @param status_code HTTP status code
     * @param response_data Response data (may contain error details)
     * @return JSON error response
     */
    std::string handleApiError(long status_code, const std::string& response_data) const;

    /**
     * @brief Validate coordinates are within valid ranges
     * @param latitude Latitude to validate
     * @param longitude Longitude to validate
     * @return true if coordinates are valid
     */
    static bool validateCoordinates(double latitude, double longitude);

    /**
     * @brief cURL write callback function
     * @param contents Response data
     * @param size Size of each data element
     * @param nmemb Number of data elements
     * @param user_data Pointer to std::string for storage
     * @return Number of bytes processed
     */
    static size_t writeCallback(void* contents, size_t size, size_t nmemb, std::string* user_data);
};

} // namespace services
} // namespace dashboard

#endif // WEATHER_SERVICE_H