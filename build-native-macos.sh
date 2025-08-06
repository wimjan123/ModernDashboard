#!/bin/bash

echo "🚀 Building Modern Dashboard with Native C++ FFI for macOS..."

# Step 1: Build the C++ shared library
echo "🔨 Building C++ shared library..."
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release

# Check if library was built
if [ ! -f "build/moderndash.dylib" ]; then
    echo "❌ Failed to build moderndash.dylib"
    echo "Check CMake output for errors"
    exit 1
fi

echo "✅ Built moderndash.dylib"
ls -la build/moderndash.dylib

# Step 2: Copy library to Flutter directory (where FFI will look for it)
echo "📂 Copying library to Flutter directory..."
cp build/moderndash.dylib flutter_frontend/
echo "✅ Copied to flutter_frontend/moderndash.dylib"

# Step 3: Enable macOS desktop and get dependencies
echo "📱 Setting up Flutter for macOS..."
cd flutter_frontend
flutter config --enable-macos-desktop
flutter pub get

# Create macOS platform if needed
if [ ! -d "macos" ]; then
    echo "📱 Creating macOS platform..."
    flutter create --platforms=macos .
fi

# Step 4: Build Flutter app (WITHOUT mock data flag)
echo "🔨 Building Flutter app with native C++ FFI..."
flutter build macos

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo "✅ Native macOS build complete!"
    echo "📍 App location: build/macos/Build/Products/Release/modern_dashboard.app"
    echo "🎯 Native C++ FFI is enabled - no mock data needed!"
    
    # Optionally open the app
    read -p "Open the app now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "build/macos/Build/Products/Release/modern_dashboard.app"
    fi
else
    echo "❌ Flutter build failed"
    echo "Check the output above for errors"
    echo "You can also check console output in the app for FFI loading messages"
fi