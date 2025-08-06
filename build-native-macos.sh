#!/bin/bash

echo "🚀 Building Modern Dashboard with Native C++ FFI for macOS..."

# Step 1: Build the C++ shared library
echo "🔨 Building C++ shared library..."
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release

# Check what was actually built
echo "🔍 Checking build directory contents..."
ls -la build/

# Look for the library file (could be libmoderndash.dylib or moderndash.dylib)
DYLIB_PATH=""
if [ -f "build/libmoderndash.dylib" ]; then
    DYLIB_PATH="build/libmoderndash.dylib"
elif [ -f "build/moderndash.dylib" ]; then
    DYLIB_PATH="build/moderndash.dylib"
fi

if [ -z "$DYLIB_PATH" ]; then
    echo "❌ Failed to find .dylib file in build directory"
    echo "Expected: build/moderndash.dylib or build/libmoderndash.dylib"
    exit 1
fi

echo "✅ Found library: $DYLIB_PATH"
ls -la "$DYLIB_PATH"

# Step 2: Copy library to Flutter directory (where FFI will look for it)
echo "📂 Copying library to Flutter directory..."
cp "$DYLIB_PATH" flutter_frontend/moderndash.dylib

# Also copy with the lib prefix if the original has it
if [[ "$DYLIB_PATH" == *"libmoderndash"* ]]; then
    cp "$DYLIB_PATH" flutter_frontend/libmoderndash.dylib
    echo "✅ Copied to flutter_frontend/libmoderndash.dylib and flutter_frontend/moderndash.dylib"
else
    echo "✅ Copied to flutter_frontend/moderndash.dylib"
fi

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