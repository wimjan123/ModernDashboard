# Claude Code Project Information

This file contains important information for Claude Code about the Modern Dashboard project, including build instructions, common issues, and project structure.

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
sudo apt-get install -y cmake build-essential libcurl4-openssl-dev nlohmann-json3-dev jq
```

### System Dependencies (macOS)
```bash
brew install cmake curl nlohmann-json jq
```

### Flutter Dependencies
- Flutter SDK 3.24.0 or later
- Dart SDK (included with Flutter)
- Platform-specific: Xcode (macOS), Visual Studio (Windows)

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

### Future Improvements
- Add Linux desktop builds (requires Flutter desktop setup)
- Implement actual FFI integration for native platforms
- Add automated testing for platform bridges
- Enhance error handling in build scripts

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