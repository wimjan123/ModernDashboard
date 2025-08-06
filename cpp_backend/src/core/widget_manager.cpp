#include "core/widget_manager.h"
#include <algorithm>

namespace dashboard {
namespace core {

bool WidgetManager::StartWidget(const std::string& id) {
    std::lock_guard<std::mutex> lock(widgets_mutex_);
    
    auto it = widgets_.find(id);
    if (it == widgets_.end()) {
        return false;
    }
    
    return it->second->Initialize();
}

void WidgetManager::StopWidget(const std::string& id) {
    std::lock_guard<std::mutex> lock(widgets_mutex_);
    
    auto it = widgets_.find(id);
    if (it != widgets_.end()) {
        it->second->Cleanup();
    }
}

std::string WidgetManager::GetWidgetData(const std::string& id) const {
    std::lock_guard<std::mutex> lock(widgets_mutex_);
    
    auto it = widgets_.find(id);
    if (it == widgets_.end() || !it->second->IsActive()) {
        return "{}";
    }
    
    return it->second->GetData();
}

bool WidgetManager::SetWidgetConfig(const std::string& id, const std::string& config) {
    std::lock_guard<std::mutex> lock(widgets_mutex_);
    
    auto it = widgets_.find(id);
    if (it == widgets_.end()) {
        return false;
    }
    
    try {
        it->second->SetConfig(config);
        return true;
    } catch (...) {
        return false;
    }
}

void WidgetManager::UpdateAllWidgets() {
    std::lock_guard<std::mutex> lock(widgets_mutex_);
    
    for (auto& [id, widget] : widgets_) {
        if (widget && widget->IsActive()) {
            try {
                widget->Update();
            } catch (...) {
                // Log error but continue with other widgets
            }
        }
    }
}

bool WidgetManager::IsWidgetActive(const std::string& id) const {
    std::lock_guard<std::mutex> lock(widgets_mutex_);
    
    auto it = widgets_.find(id);
    return it != widgets_.end() && it->second->IsActive();
}

void WidgetManager::ShutdownAllWidgets() {
    std::lock_guard<std::mutex> lock(widgets_mutex_);
    
    for (auto& [id, widget] : widgets_) {
        if (widget) {
            widget->Cleanup();
        }
    }
}

std::vector<std::string> WidgetManager::GetActiveWidgetIds() const {
    std::lock_guard<std::mutex> lock(widgets_mutex_);
    
    std::vector<std::string> active_ids;
    for (const auto& [id, widget] : widgets_) {
        if (widget && widget->IsActive()) {
            active_ids.push_back(id);
        }
    }
    
    return active_ids;
}

}  // namespace core
}  // namespace dashboard