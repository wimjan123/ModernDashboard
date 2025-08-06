#pragma once

#include <string>
#include <memory>

namespace dashboard {
namespace core {

class IWidget {
public:
    virtual ~IWidget() = default;
    
    virtual bool Initialize() = 0;
    virtual void Update() = 0;
    virtual std::string GetData() const = 0;
    virtual void SetConfig(const std::string& config) = 0;
    virtual void Cleanup() = 0;
    virtual std::string GetId() const = 0;
    virtual bool IsActive() const = 0;
};

}  // namespace core
}  // namespace dashboard