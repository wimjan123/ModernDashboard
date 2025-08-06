#!/bin/bash

echo "🔍 FFI Debug Script - Modern Dashboard"
echo "======================================"

# Check if we're in the right directory
echo "📁 Current directory: $(pwd)"

# Check for built shared library
echo -e "\n🔨 Checking for built shared library..."
if [ -f "build/moderndash.dylib" ]; then
    echo "✅ Found: build/moderndash.dylib"
    ls -la build/moderndash.dylib
else
    echo "❌ Missing: build/moderndash.dylib"
fi

# Check if library is in Flutter app location
echo -e "\n📱 Checking Flutter app bundle location..."
APP_DIR="flutter_frontend/build/macos/Build/Products/Release/modern_dashboard.app"
if [ -d "$APP_DIR" ]; then
    echo "✅ Found app bundle: $APP_DIR"
    
    # Check if library is bundled with app
    if [ -f "$APP_DIR/Contents/Frameworks/moderndash.dylib" ]; then
        echo "✅ Library bundled in app: $APP_DIR/Contents/Frameworks/moderndash.dylib"
    else
        echo "❌ Library not bundled in app"
        echo "📋 App bundle contents:"
        ls -la "$APP_DIR/Contents/" 2>/dev/null || echo "   Cannot list contents"
    fi
else
    echo "❌ App bundle not found: $APP_DIR"
fi

# Check what Flutter tries to load
echo -e "\n🔍 FFI is looking for library at these locations:"
echo "   1. ./moderndash.dylib (relative to app's working directory)"
echo "   2. moderndash.dylib (in system library path)"

# Test if we can copy library to expected location
if [ -f "build/moderndash.dylib" ]; then
    echo -e "\n🔧 Suggested fixes:"
    echo "   Option 1: Copy library to Flutter working directory"
    echo "   cp build/moderndash.dylib flutter_frontend/"
    echo ""
    echo "   Option 2: Bundle library with app (more complex)"
    echo "   Option 3: Update FFI bridge to look in build/ directory"
fi

echo -e "\n📊 Quick test - try building and copying:"
echo "cmake -B build -DCMAKE_BUILD_TYPE=Release"
echo "cmake --build build --config Release"
echo "cp build/moderndash.dylib flutter_frontend/"
echo "cd flutter_frontend && flutter build macos"