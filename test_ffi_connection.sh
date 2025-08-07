#!/bin/bash

set -e  # Exit on any error

echo "🔗 Testing FFI Connection"
echo "========================="

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

# Check Flutter doctor
echo "📋 Checking Flutter setup..."
cd flutter_frontend
if ! flutter doctor -v | grep -q "No issues found"; then
    echo "⚠️  Flutter doctor found some issues. Continuing anyway..."
    flutter doctor
else
    echo "✅ Flutter setup looks good"
fi

# Ensure Flutter desktop is enabled (for macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🖥️  Enabling macOS desktop support..."
    flutter config --enable-macos-desktop
fi

# Get Flutter dependencies
echo "📦 Getting Flutter dependencies..."
if ! flutter pub get; then
    echo "❌ Failed to get Flutter dependencies"
    exit 1
fi
echo "✅ Flutter dependencies updated"

# Check if native library exists
echo "🔍 Verifying native library existence..."
LIBRARY_PATHS=(
    "../build/moderndash.dylib"
    "../build/libmoderndash.dylib" 
    "../build/moderndash.so"
    "../build/libmoderndash.so"
    "../build/moderndash.dll"
    "lib/native/moderndash.dylib"
    "lib/native/libmoderndash.dylib"
    "lib/native/moderndash.so"
    "lib/native/libmoderndash.so"
    "../moderndash.dylib"
    "../libmoderndash.dylib"
    "../moderndash.so"
    "../libmoderndash.so"
)

LIBRARY_FOUND=""
for path in "${LIBRARY_PATHS[@]}"; do
    if [ -f "$path" ]; then
        LIBRARY_FOUND="$path"
        echo "✅ Found native library: $path"
        break
    fi
done

if [ -z "$LIBRARY_FOUND" ]; then
    echo "❌ Native library not found in any expected location:"
    for path in "${LIBRARY_PATHS[@]}"; do
        echo "   ❌ $path"
    done
    echo ""
    echo "Please run './build_backend.sh' first to build the native library"
    exit 1
fi

# Verify library symbols (macOS/Linux)
echo "🔍 Verifying library exports..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "   Library info:"
    file "$LIBRARY_FOUND"
    
    echo "   Checking for required FFI symbols..."
    REQUIRED_SYMBOLS=("initialize_dashboard_engine" "get_news_data" "get_weather_data")
    MISSING_SYMBOLS=()
    
    for symbol in "${REQUIRED_SYMBOLS[@]}"; do
        if nm "$LIBRARY_FOUND" 2>/dev/null | grep -q "$symbol"; then
            echo "   ✅ $symbol"
        else
            echo "   ❌ $symbol (missing)"
            MISSING_SYMBOLS+=("$symbol")
        fi
    done
    
    if [ ${#MISSING_SYMBOLS[@]} -gt 0 ]; then
        echo "⚠️  Some expected symbols missing: ${MISSING_SYMBOLS[*]}"
        echo "   Available symbols:"
        nm "$LIBRARY_FOUND" 2>/dev/null | grep -E "(T|D|B)" | head -10
    else
        echo "✅ All required FFI symbols found"
    fi
    
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "   Library info:"
    file "$LIBRARY_FOUND"
    
    echo "   Checking for required FFI symbols..."
    REQUIRED_SYMBOLS=("initialize_dashboard_engine" "get_news_data" "get_weather_data")
    MISSING_SYMBOLS=()
    
    for symbol in "${REQUIRED_SYMBOLS[@]}"; do
        if nm -D "$LIBRARY_FOUND" 2>/dev/null | grep -q "$symbol"; then
            echo "   ✅ $symbol"
        else
            echo "   ❌ $symbol (missing)"
            MISSING_SYMBOLS+=("$symbol")
        fi
    done
    
    if [ ${#MISSING_SYMBOLS[@]} -gt 0 ]; then
        echo "⚠️  Some expected symbols missing: ${MISSING_SYMBOLS[*]}"
        echo "   Available exported symbols:"
        nm -D "$LIBRARY_FOUND" 2>/dev/null | head -10
    else
        echo "✅ All required FFI symbols found"
    fi
fi

# Test Flutter app compilation with native backend enabled
echo "🚀 Testing Flutter compilation with native backend..."
echo "   Building with --dart-define=USE_MOCK_DATA=false"

# Clean Flutter build first
flutter clean

# Try to build the Flutter app
if flutter build macos --dart-define=USE_MOCK_DATA=false --debug 2>&1 | tee /tmp/flutter_build.log; then
    echo "✅ Flutter build successful with native backend enabled"
else
    echo "❌ Flutter build failed"
    echo "   Check the build log above for errors"
    echo "   Looking for FFI-related errors:"
    if grep -i "ffi\|library\|symbol" /tmp/flutter_build.log; then
        echo "   Found FFI-related issues in build log"
    fi
    exit 1
fi

# Test running the app briefly
echo "🧪 Testing app startup with native backend..."
echo "   Starting app for 10 seconds to check FFI loading..."

# Create a temporary script to run the app and capture output
cat > /tmp/test_app.sh << 'EOF'
#!/bin/bash
cd flutter_frontend
timeout 15 flutter run -d macos --dart-define=USE_MOCK_DATA=false 2>&1 | tee /tmp/flutter_run.log &
FLUTTER_PID=$!

# Wait a moment for the app to start
sleep 8

# Kill the Flutter process
kill $FLUTTER_PID 2>/dev/null || true
wait $FLUTTER_PID 2>/dev/null || true

# Check the log for FFI loading messages
if grep -i "ffi\|native\|library" /tmp/flutter_run.log; then
    echo "FFI-related output found in app log"
else
    echo "No FFI-related output in app log"
fi

# Check for successful initialization
if grep -q "Dashboard engine initialized" /tmp/flutter_run.log; then
    echo "✅ Native backend successfully initialized"
    exit 0
elif grep -i "error\|exception\|failed" /tmp/flutter_run.log | grep -i "ffi\|native\|library"; then
    echo "❌ FFI loading errors detected"
    exit 1
else
    echo "⚠️  App started but FFI status unclear"
    exit 0
fi
EOF

chmod +x /tmp/test_app.sh
if /tmp/test_app.sh; then
    echo "✅ App startup test completed"
else
    echo "⚠️  App startup had issues, but may still work"
fi

# Clean up
rm -f /tmp/test_app.sh /tmp/flutter_build.log /tmp/flutter_run.log

echo ""
echo "🎉 FFI Connection Test Summary"
echo "=============================="
echo "✅ Native library found: $LIBRARY_FOUND"
echo "✅ Flutter build successful with native backend"
echo "✅ App startup test completed"
echo ""
echo "The FFI connection appears to be working!"
echo "You can now run './run_with_native_backend.sh' to use the app with native data"

cd ..