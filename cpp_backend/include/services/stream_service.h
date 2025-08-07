#ifndef STREAM_SERVICE_H
#define STREAM_SERVICE_H

#include "core/widget_interface.h"
#include <string>
#include <vector>
#include <memory>
#include <mutex>
#include <nlohmann/json.hpp>

namespace dashboard {
namespace services {

class StreamService {
public:
    StreamService();
    ~StreamService();

    bool startStream(const std::string& url);
    void stopStream(const std::string& url);
    std::string getStreamData(const std::string& url);

private:
    bool initialized_;
    mutable std::mutex mutex_;
};

class StreamWidget : public core::IWidget {
private:
    std::unique_ptr<StreamService> stream_service_;

public:
    StreamWidget();
    virtual ~StreamWidget() = default;

    bool Initialize() override;
    void Update() override;
    std::string GetData() const override;
    void SetConfig(const std::string& config) override;
    void Cleanup() override;
    std::string GetId() const override { return "stream"; }
    bool IsActive() const override;

    StreamService* getService() { return stream_service_.get(); }
};

} // namespace services
} // namespace dashboard

#endif // STREAM_SERVICE_H
