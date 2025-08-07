#ifndef MAIL_SERVICE_H
#define MAIL_SERVICE_H

#include "core/widget_interface.h"
#include <string>
#include <vector>
#include <memory>
#include <mutex>
#include <nlohmann/json.hpp>

namespace dashboard {
namespace services {

class MailService {
public:
    struct MailAccount {
        std::string email_address;
        std::string password;
        std::string imap_server;
        int imap_port;
        bool use_ssl;
    };

    struct MailMessage {
        std::string id;
        std::string from;
        std::string to;
        std::string subject;
        std::string body;
        std::time_t timestamp;
        bool read;
    };

    MailService();
    ~MailService();

    bool initialize(const MailAccount& account);
    std::string getMailData();

private:
    MailAccount account_;
    bool initialized_;
    mutable std::mutex mutex_;
};

class MailWidget : public core::IWidget {
private:
    std::unique_ptr<MailService> mail_service_;

public:
    MailWidget();
    virtual ~MailWidget() = default;

    bool Initialize() override;
    void Update() override;
    std::string GetData() const override;
    void SetConfig(const std::string& config) override;
    void Cleanup() override;
    std::string GetId() const override { return "mail"; }
    bool IsActive() const override;

    MailService* getService() { return mail_service_.get(); }
};

} // namespace services
} // namespace dashboard

#endif // MAIL_SERVICE_H
