#include "services/mail_service.h"
#include <iostream>

namespace dashboard {
namespace services {

MailService::MailService() : initialized_(false) {}

MailService::~MailService() {}

bool MailService::initialize(const MailAccount& account) {
    std::lock_guard<std::mutex> lock(mutex_);
    account_ = account;
    initialized_ = true;
    return true;
}

std::string MailService::getMailData() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!initialized_) {
        return "[]";
    }

    nlohmann::json mail_data = nlohmann::json::array();
    // In a real implementation, this would fetch emails from the IMAP server.
    // For now, we'll return some mock data.
    mail_data.push_back({
        {"id", "1"},
        {"from", "test@example.com"},
        {"to", account_.email_address},
        {"subject", "Test Email"},
        {"body", "This is a test email."},
        {"timestamp", std::time(nullptr)},
        {"read", false}
    });

    return mail_data.dump();
}

MailWidget::MailWidget() {
    mail_service_ = std::make_unique<MailService>();
}

bool MailWidget::Initialize() {
    // For now, we'll use a default account.
    // In a real implementation, this would be loaded from config.
    MailService::MailAccount account;
    account.email_address = "user@example.com";
    account.password = "password";
    account.imap_server = "imap.example.com";
    account.imap_port = 993;
    account.use_ssl = true;
    return mail_service_->initialize(account);
}

void MailWidget::Update() {}

std::string MailWidget::GetData() const {
    return mail_service_->getMailData();
}

void MailWidget::SetConfig(const std::string& config) {
    try {
        nlohmann::json config_json = nlohmann::json::parse(config);
        MailService::MailAccount account;
        account.email_address = config_json.value("email_address", "");
        account.password = config_json.value("password", "");
        account.imap_server = config_json.value("imap_server", "");
        account.imap_port = config_json.value("imap_port", 993);
        account.use_ssl = config_json.value("use_ssl", true);
        mail_service_->initialize(account);
    } catch (const std::exception& e) {
        std::cerr << "MailWidget: Failed to parse config: " << e.what() << std::endl;
    }
}

void MailWidget::Cleanup() {}

bool MailWidget::IsActive() const {
    return mail_service_ != nullptr;
}

} // namespace services
} // namespace dashboard
