# Building Modern Dashboard on macOS

This guide explains how to build the Modern Dashboard application natively on macOS.

## Prerequisites

1. **macOS**: macOS 10.15 (Catalina) or later
2. **Homebrew**: Install from [https://brew.sh/](https://brew.sh/)
3. **Flutter**: Install from [https://flutter.dev/docs/get-started/install/macos](https://flutter.dev/docs/get-started/install/macos)
4. **Xcode**: Install from the Mac App Store (required for macOS app builds)

## Automated Build

The easiest way to build the project is using the provided build script:

```bash
./build-macos.sh
```

This script will:
- Install required dependencies via Homebrew
- Build the C++ backend
- Enable Flutter macOS desktop support
- Build the Flutter macOS app (.app bundle)
- Build the Flutter web app
- Verify all builds completed successfully

## Mock Data Mode (Recommended for Development/Demos)

The macOS app can now run with rich, interactive mock data equivalent to the web stub. Use the `--mock` flag:

```bash
./build-macos.sh --mock
```

What this does:
- Passes a Dart define `USE_MOCK_DATA=true` to the Flutter macOS build
- The Dart FFI bridge detects the flag and routes all data calls to the shared MockDataService
- No native library is loaded in mock mode, avoiding FFI issues during UI development

Implementation details:
- Switch controlled in [`dart.get _useMock()`](flutter_frontend/lib/services/ffi_bridge.dart:58)
- Shared mock implementation lives in [`dart.class MockDataService()`](flutter_frontend/lib/services/mock_data_service.dart:1)
- Web stub delegates to the same service in [`dart.class FfiBridge()`](flutter_frontend/lib/services/ffi_bridge_web.dart:1)

## Manual Build Steps

If you prefer to build manually:

### 1. Install Dependencies

```bash
brew install cmake curl nlohmann-json jq
```

### 2. Build C++ Backend

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

### 3. Build Flutter Frontend

```bash
cd flutter_frontend

# Enable macOS desktop support
flutter config --enable-macos-desktop

# Get dependencies
flutter pub get

# Create macOS project structure (if not already present)
flutter create --platforms=macos .

# Build for macOS (native mode)
flutter build macos

# Build for macOS (mock mode)
flutter build macos --dart-define=USE_MOCK_DATA=true

# Build for web
flutter build web --no-tree-shake-icons
```

## Built Artifacts

After a successful build, you'll find:

- **C++ Backend**: `build/ModernDashboard`
- **macOS App**: `flutter_frontend/build/macos/Build/Products/Release/modern_dashboard.app`
- **Web App**: `flutter_frontend/build/web/`

## Running the Applications

### Run the macOS App
```bash
open flutter_frontend/build/macos/Build/Products/Release/modern_dashboard.app
```

### Run the C++ Backend
```bash
./build/ModernDashboard
```

### Serve the Web App
```bash
cd flutter_frontend/build/web
python3 -m http.server 8000
# Then open http://localhost:8000 in your browser
```

## Troubleshooting

### Flutter macOS Support Issues
If you encounter issues with Flutter macOS support:
```bash
flutter doctor
flutter config --enable-macos-desktop
flutter clean
flutter pub get
```

### CMake Build Issues
If the C++ build fails:
```bash
# Clean build directory
rm -rf build
# Reinstall dependencies
brew reinstall cmake curl nlohmann-json
# Try building again
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

### Missing Xcode Command Line Tools
```bash
xcode-select --install
```

## GitHub Actions

The project includes GitHub Actions workflows that build on both Linux (self-hosted) and macOS (GitHub-hosted). The macOS builds require GitHub Actions billing to be enabled for private repositories.

If you encounter billing issues with GitHub Actions, you can always build locally using this guide.