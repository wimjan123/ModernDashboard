#pragma once

#include "widget_interface.h"
#include <unordered_map>
#include <memory>
#include <mutex>
#include <functional>

namespace dashboard {
namespace core {

class WidgetManager {
private:
    std::unordered_map<std::string, std::unique_ptr<IWidget>> widgets_;
    mutable std::mutex widgets_mutex_;
    
public:
    WidgetManager() = default;
    ~WidgetManager() = default;
    
    // Non-copyable
    WidgetManager(const WidgetManager&) = delete;
    WidgetManager& operator=(const WidgetManager&) = delete;
    
    template<typename T>
    bool RegisterWidget(const std::string& id) {
        std::lock_guard<std::mutex> lock(widgets_mutex_);
        if (widgets_.find(id) != widgets_.end()) {
            return false;  // Widget already exists
        }
        
        auto widget = std::make_unique<T>();
        if (!widget) {
            return false;
        }
        
        widgets_[id] = std::move(widget);
        return true;
    }
    
    bool StartWidget(const std::string& id);
    void StopWidget(const std::string& id);
    std::string GetWidgetData(const std::string& id) const;
    bool SetWidgetConfig(const std::string& id, const std::string& config);
    void UpdateAllWidgets();
    bool IsWidgetActive(const std::string& id) const;
    void ShutdownAllWidgets();
    
    std::vector<std::string> GetActiveWidgetIds() const;
};

}  // namespace core
}  // namespace dashboard