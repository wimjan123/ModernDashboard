#include "core/dashboard_engine.h"
#include "services/news_service.h"
#include <thread>

namespace dashboard {
namespace core {

DashboardEngine::DashboardEngine() 
    : widget_manager_(std::make_unique<WidgetManager>())
    , running_(false) {
}

DashboardEngine::~DashboardEngine() {
    Shutdown();
}

bool DashboardEngine::Initialize() {
    if (running_.load()) {
        return false;  // Already running
    }
    
    if (!widget_manager_) {
        return false;
    }
    
    // Register default widgets
    RegisterWidget<services::NewsWidget>("news");
    
    running_ = true;
    
    // Start update thread
    update_thread_ = std::thread(&DashboardEngine::UpdateLoop, this);
    
    return true;
}

void DashboardEngine::Shutdown() {
    if (!running_.load()) {
        return;  // Already stopped
    }
    
    running_ = false;
    
    // Wait for update thread to finish
    if (update_thread_.joinable()) {
        update_thread_.join();
    }
    
    // Shutdown all widgets
    if (widget_manager_) {
        widget_manager_->ShutdownAllWidgets();
    }
}

void DashboardEngine::UpdateLoop() {
    while (running_.load()) {
        if (widget_manager_) {
            widget_manager_->UpdateAllWidgets();
        }
        
        std::this_thread::sleep_for(update_interval_);
    }
}

bool DashboardEngine::StartWidget(const std::string& id) {
    if (!widget_manager_) {
        return false;
    }
    return widget_manager_->StartWidget(id);
}

void DashboardEngine::StopWidget(const std::string& id) {
    if (widget_manager_) {
        widget_manager_->StopWidget(id);
    }
}

std::string DashboardEngine::GetWidgetData(const std::string& id) const {
    if (!widget_manager_) {
        return "{}";
    }
    return widget_manager_->GetWidgetData(id);
}

bool DashboardEngine::SetWidgetConfig(const std::string& id, const std::string& config) {
    if (!widget_manager_) {
        return false;
    }
    return widget_manager_->SetWidgetConfig(id, config);
}

std::vector<std::string> DashboardEngine::GetActiveWidgets() const {
    if (!widget_manager_) {
        return {};
    }
    return widget_manager_->GetActiveWidgetIds();
}

}  // namespace core
}  // namespace dashboard