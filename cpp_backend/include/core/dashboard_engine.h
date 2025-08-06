#pragma once

#include "widget_manager.h"
#include <memory>
#include <thread>
#include <atomic>
#include <chrono>

namespace dashboard {
namespace core {

class DashboardEngine {
private:
    std::unique_ptr<WidgetManager> widget_manager_;
    std::thread update_thread_;
    std::atomic<bool> running_;
    std::chrono::seconds update_interval_{5};
    
    void UpdateLoop();
    
public:
    DashboardEngine();
    ~DashboardEngine();
    
    // Non-copyable
    DashboardEngine(const DashboardEngine&) = delete;
    DashboardEngine& operator=(const DashboardEngine&) = delete;
    
    bool Initialize();
    void Shutdown();
    
    // Widget management
    template<typename T>
    bool RegisterWidget(const std::string& id) {
        if (!widget_manager_) {
            return false;
        }
        return widget_manager_->RegisterWidget<T>(id);
    }
    
    bool StartWidget(const std::string& id);
    void StopWidget(const std::string& id);
    std::string GetWidgetData(const std::string& id) const;
    bool SetWidgetConfig(const std::string& id, const std::string& config);
    
    // System status
    bool IsRunning() const { return running_.load(); }
    std::vector<std::string> GetActiveWidgets() const;
};

}  // namespace core
}  // namespace dashboard