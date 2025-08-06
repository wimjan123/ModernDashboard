#!/bin/bash

# macOS Build Script for Modern Dashboard
# Run this script on a macOS machine to build both C++ backend and Flutter frontend

set -e

echo "🍎 Building Modern Dashboard for macOS..."

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ This script must be run on macOS"
    exit 1
fi

# Install dependencies
echo "📦 Installing dependencies..."
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew is required. Please install it from https://brew.sh/"
    exit 1
fi

brew install cmake curl nlohmann-json jq

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is required. Please install it from https://flutter.dev/docs/get-started/install/macos"
    exit 1
fi

# Build C++ Backend
echo "🔨 Building C++ Backend..."
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release

if [ -f "build/ModernDashboard" ]; then
    echo "✅ C++ backend built successfully"
else
    echo "❌ C++ backend build failed"
    exit 1
fi

# Setup Flutter for macOS
echo "📱 Setting up Flutter for macOS..."
cd flutter_frontend

flutter config --enable-macos-desktop
flutter pub get

# Create macOS project structure if needed
flutter create --platforms=macos .

# Build Flutter for macOS
echo "🔨 Building Flutter for macOS..."
flutter build macos

# Build Flutter for web as well
echo "🌐 Building Flutter for web..."
flutter build web --no-tree-shake-icons

# Verify builds
echo "✅ Verifying builds..."
if [ -d "build/macos/Build/Products/Release/modern_dashboard.app" ]; then
    echo "✅ Flutter macOS app built successfully at: build/macos/Build/Products/Release/modern_dashboard.app"
else
    echo "❌ Flutter macOS app build failed"
    exit 1
fi

if [ -f "build/web/index.html" ]; then
    echo "✅ Flutter web app built successfully"
else
    echo "❌ Flutter web app build failed"
    exit 1
fi

cd ..

echo ""
echo "🎉 macOS build completed successfully!"
echo ""
echo "Built artifacts:"
echo "  C++ Backend: build/ModernDashboard"
echo "  macOS App:   flutter_frontend/build/macos/Build/Products/Release/modern_dashboard.app"
echo "  Web App:     flutter_frontend/build/web/"
echo ""
echo "To run the macOS app:"
echo "  open flutter_frontend/build/macos/Build/Products/Release/modern_dashboard.app"
echo ""
echo "To run the C++ backend:"
echo "  ./build/ModernDashboard"