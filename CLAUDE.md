# Claude Code Project Information

This file contains important information for Claude Code about the Modern Dashboard project, including build instructions, common issues, and project structure.
During coding, don't forget to git push in between steps
## Project Overview

Modern Dashboard is a cross-platform application with:
- **C++ Backend**: Native backend built with CMake
- **Flutter Frontend**: Cross-platform UI supporting web, macOS, and Linux
- **Multi-platform Architecture**: Designed for desktop and web deployment

## Build Commands

### Testing and Linting
- **Flutter Analysis**: `cd flutter_frontend && flutter analyze`
- **Flutter Tests**: `cd flutter_frontend && flutter test`
- **C++ Build Test**: `cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release`

### Platform-Specific Builds

#### Linux (Self-hosted Runners)
```bash
# C++ Backend
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release

# Flutter Web
cd flutter_frontend
flutter pub get
flutter build web --no-tree-shake-icons
```

#### macOS (Local Development)

**🎯 NEW: For Full Dashboard Functionality:**
```bash
# Use the new script with mock data enabled (RECOMMENDED)
./build-macos-with-mock.sh

# Or manual build with mock data
cd flutter_frontend
flutter config --enable-macos-desktop
flutter pub get
flutter create --platforms=macos .
flutter build macos --dart-define USE_MOCK_DATA=true
```

**Legacy build (limited functionality):**
```bash
# Use automated script
./build-macos.sh

# Or manual build
brew install cmake curl nlohmann-json jq
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release

cd flutter_frontend
flutter config --enable-macos-desktop
flutter pub get
flutter create --platforms=macos .
flutter build macos
flutter build web --no-tree-shake-icons
```

## Recent Fixes Applied

### GitHub Actions Build Errors (Fixed)
- **Issue**: FFI compilation errors on web platform
- **Solution**: Implemented platform-specific code using `kIsWeb` runtime checks
- **Files Modified**: `flutter_frontend/lib/services/cpp_bridge.dart`

- **Issue**: Missing `main()` function in C++ backend
- **Solution**: Added proper main function to `cpp_backend/src/main.cpp`
- **Result**: C++ executable now builds successfully

### Platform Support Added
- **macOS Desktop**: Full native macOS app builds (.app bundle)
- **Web Platform**: Cross-platform web builds with mock data
- **CI/CD**: Multi-platform GitHub Actions workflow

## Project Structure

```
ModernDashboard/
├── cpp_backend/           # C++ backend source
│   ├── src/main.cpp      # Main entry point (fixed)
│   ├── include/          # Header files
│   └── src/              # Implementation
├── flutter_frontend/     # Flutter UI application
│   ├── lib/services/cpp_bridge.dart  # Platform bridge (fixed)
│   ├── lib/              # Dart source code
│   └── pubspec.yaml      # Dependencies
├── shared/               # Shared headers between C++ and Flutter
├── .github/workflows/    # CI/CD configuration (enhanced)
├── build-macos.sh       # Local macOS build script
├── BUILD-MACOS.md       # macOS build documentation
└── CMakeLists.txt       # C++ build configuration
```

## Common Issues and Solutions

### FFI Web Compilation
- **Problem**: `dart:ffi` not available on web platform
- **Solution**: Uses `kIsWeb` check to provide platform-specific implementations
- **Code**: See `flutter_frontend/lib/services/cpp_bridge.dart`

### GitHub Actions macOS Builds
- **Problem**: Billing limits on GitHub-hosted macOS runners
- **Solution**: Made macOS jobs optional (`continue-on-error: true`)
- **Alternative**: Use local build script `./build-macos.sh`

### C++ Linker Errors
- **Problem**: Missing main function
- **Solution**: Added proper main() function in `cpp_backend/src/main.cpp`
- **Verification**: Check for `build/ModernDashboard` executable after build

## Dependencies

### System Dependencies (Linux)
```bash
sudo apt-get update
sudo apt-get install -y cmake build-essential libcurl4-openssl-dev nlohmann-json3-dev jq \
  libsqlite3-dev libxml2-dev pkg-config
```

### System Dependencies (macOS)
```bash
brew install cmake curl nlohmann-json jq sqlite libxml2 pkg-config
```

### Flutter Dependencies
- Flutter SDK 3.24.0 or later
- Dart SDK (included with Flutter)
- Platform-specific: Xcode (macOS), Visual Studio (Windows)

### New Production Dependencies
**C++ Libraries:**
- **libcurl**: HTTP client for API requests
- **SQLite3**: Local database for data persistence
- **nlohmann/json**: JSON parsing and serialization
- **libxml2**: RSS/Atom feed parsing
- **OpenSSL**: Secure communications (typically bundled with system)

**Flutter Packages:**
```yaml
dependencies:
  http: ^1.1.0          # HTTP client for API calls
  sqflite: ^2.3.0       # SQLite database integration
  path_provider: ^2.1.0 # File system path handling
  shared_preferences: ^2.2.0 # Settings persistence
  url_launcher: ^6.2.0  # External URL handling
  flutter_local_notifications: ^17.0.0 # Desktop notifications
```

## Architecture Notes

### Platform Bridge
- **Native Platforms**: Uses FFI to call C++ backend functions
- **Web Platform**: Uses mock data providers (no FFI support)
- **Detection**: Runtime platform detection with `kIsWeb`

### Build Artifacts
- **C++ Backend**: `build/ModernDashboard` (executable)
- **Flutter Web**: `flutter_frontend/build/web/index.html`
- **macOS App**: `flutter_frontend/build/macos/Build/Products/Release/modern_dashboard.app`

## CI/CD Status

### Working Builds
- ✅ Linux C++ Backend (self-hosted)
- ✅ Flutter Web Build (self-hosted)
- ✅ Integration Tests (self-hosted)

### Optional Builds
- 🟡 macOS C++ Backend (GitHub-hosted, billing dependent)
- 🟡 macOS Flutter App (GitHub-hosted, billing dependent)
- 🟡 macOS Integration Tests (GitHub-hosted, billing dependent)

### Workflow Files
- `.github/workflows/build.yml`: Main CI/CD pipeline
- Runs on both self-hosted (Linux) and GitHub-hosted (macOS) runners
- Includes comprehensive artifact verification

## Development Notes

### Context7 Integration
This project was enhanced using the Context7 MCP server, which provided:
- Current GitHub Actions best practices (2024)
- Modern Flutter web build optimizations
- Platform-specific FFI handling patterns
- CMake configuration improvements

### Current Implementation Status (January 2025)
- ✅ **FFI Bridge**: Mock data fallback system implemented
- ✅ **Cross-platform Builds**: macOS, Linux, Web support  
- ✅ **UI Framework**: Modern glassmorphism design system
- 🚧 **External APIs**: In progress - Weather, News, Email, Streaming
- 🚧 **Database Integration**: SQLite implementation in progress
- 📋 **Testing Suite**: Planned comprehensive test coverage

### Active Development Phases
**Phase 1**: C++ Backend Services (Weeks 2-4)
- WeatherService with OpenWeatherMap API
- NewsService with RSS feed parsing  
- TodoService with SQLite persistence
- MailService with IMAP/POP3 support
- StreamService for real-time data

**Phase 2**: External API Integration (Weeks 5-7)
- Live weather data with forecasting
- Multi-source news aggregation
- Email account integration
- WebSocket/SSE streaming support

**Phase 3**: Enhanced Flutter UI (Weeks 8-10)
- Interactive todo management
- Advanced weather widgets
- News reader functionality
- Email client features
- Theme and configuration system

### Implementation Tracking
📋 **Full Implementation Plan**: See `IMPLEMENTATION_PLAN.md`
🎯 **Context7 Integration**: Using latest best practices throughout development
⏱️ **Estimated Timeline**: 16 weeks total development cycle

## Troubleshooting

### Build Failures
1. Check dependencies are installed
2. Verify Flutter version (3.24.0+)
3. For macOS: ensure Xcode command line tools installed
4. Clean build: `rm -rf build flutter_frontend/build`

### GitHub Actions Issues
1. Check billing limits for macOS runners
2. Self-hosted runners should handle Linux builds
3. macOS builds can be done locally with `./build-macos.sh`

### Flutter Platform Issues
```bash
flutter doctor
flutter clean
flutter pub get
flutter config --enable-macos-desktop  # for macOS
```

- **Development Note**: Always remember to `git push` in between tasks/steps
- always check if there is a mcp that you can use. The following mcp are installed: Dart, dart, Firebase and Context7