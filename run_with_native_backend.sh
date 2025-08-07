#!/bin/bash

set -e  # Exit on any error

echo "🚀 Running ModernDashboard with Native Backend"
echo "=============================================="

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

# Ensure we're in the project root
if [ ! -f "CMakeLists.txt" ] || [ ! -d "flutter_frontend" ]; then
    echo "❌ Please run this script from the ModernDashboard project root directory"
    exit 1
fi

# Check if native library exists
echo "🔍 Checking for native library..."
LIBRARY_FOUND=""
LIBRARY_PATHS=(
    "build/moderndash.dylib"
    "build/libmoderndash.dylib"
    "build/moderndash.so"
    "build/libmoderndash.so"
    "build/moderndash.dll"
)

for path in "${LIBRARY_PATHS[@]}"; do
    if [ -f "$path" ]; then
        LIBRARY_FOUND="$path"
        echo "✅ Found native library: $path"
        break
    fi
done

if [ -z "$LIBRARY_FOUND" ]; then
    echo "❌ Native library not found. Building it now..."
    if [ -f "./build_backend.sh" ]; then
        echo "   Running ./build_backend.sh..."
        if ! ./build_backend.sh; then
            echo "❌ Backend build failed. Cannot run with native backend."
            exit 1
        fi
        
        # Re-check for library after build
        for path in "${LIBRARY_PATHS[@]}"; do
            if [ -f "$path" ]; then
                LIBRARY_FOUND="$path"
                echo "✅ Native library created: $path"
                break
            fi
        done
        
        if [ -z "$LIBRARY_FOUND" ]; then
            echo "❌ Backend build completed but library still not found"
            exit 1
        fi
    else
        echo "❌ build_backend.sh not found. Please build the C++ backend first:"
        echo "   cmake -B build -DCMAKE_BUILD_TYPE=Release"
        echo "   cmake --build build --config Release"
        exit 1
    fi
fi

# Ensure library is copied to Flutter-expected locations
echo "📂 Preparing library for Flutter..."
cd flutter_frontend

# Create native library directory if it doesn't exist
if [ ! -d "lib/native" ]; then
    mkdir -p lib/native
fi

# Copy library to where Flutter FFI can find it
cp "../$LIBRARY_FOUND" "lib/native/" 2>/dev/null || true
cp "../$LIBRARY_FOUND" "./" 2>/dev/null || true

# Get Flutter dependencies
echo "📦 Updating Flutter dependencies..."
if ! flutter pub get; then
    echo "❌ Failed to get Flutter dependencies"
    exit 1
fi

# Enable desktop support based on platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🖥️  Ensuring macOS desktop support is enabled..."
    flutter config --enable-macos-desktop
    PLATFORM_ARG="-d macos"
    BUILD_PLATFORM="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "🖥️  Ensuring Linux desktop support is enabled..."
    flutter config --enable-linux-desktop
    PLATFORM_ARG="-d linux"
    BUILD_PLATFORM="linux"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    echo "🖥️  Ensuring Windows desktop support is enabled..."
    flutter config --enable-windows-desktop
    PLATFORM_ARG="-d windows"
    BUILD_PLATFORM="windows"
else
    echo "⚠️  Platform not detected for desktop support, continuing anyway..."
    PLATFORM_ARG=""
    BUILD_PLATFORM="unknown"
fi

# Check if we should build first or run directly
RUN_MODE="run"
BUILD_FIRST="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build-first)
            BUILD_FIRST="true"
            shift
            ;;
        --release)
            RUN_MODE="release"
            shift
            ;;
        --debug)
            RUN_MODE="debug"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --build-first    Build the Flutter app before running"
            echo "  --release        Run in release mode"
            echo "  --debug          Run in debug mode (default)"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "This script runs the ModernDashboard Flutter app with the native C++ backend enabled."
            echo "It automatically disables mock data and uses the real FFI bridge."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Build if requested
if [ "$BUILD_FIRST" = "true" ] && [ "$BUILD_PLATFORM" != "unknown" ]; then
    echo "🏗️  Building Flutter app for $BUILD_PLATFORM..."
    if [ "$RUN_MODE" = "release" ]; then
        if ! flutter build $BUILD_PLATFORM --dart-define=USE_MOCK_DATA=false --release; then
            echo "❌ Flutter build failed"
            exit 1
        fi
    else
        if ! flutter build $BUILD_PLATFORM --dart-define=USE_MOCK_DATA=false --debug; then
            echo "❌ Flutter build failed"
            exit 1
        fi
    fi
    echo "✅ Flutter build successful"
fi

# Set up environment
export USE_MOCK_DATA=false

echo ""
echo "🎯 Configuration Summary"
echo "========================"
echo "Native Library: $LIBRARY_FOUND"
echo "Platform: $BUILD_PLATFORM"
echo "Mock Data: DISABLED (USE_MOCK_DATA=false)"
echo "Run Mode: $RUN_MODE"
echo ""

echo "🚀 Starting Flutter app with native backend..."
echo "   Press Ctrl+C to stop the application"
echo "   Watch the console for FFI loading messages"
echo ""

# Run the Flutter app with native backend enabled
FLUTTER_CMD="flutter run --dart-define=USE_MOCK_DATA=false"

if [ "$RUN_MODE" = "release" ]; then
    FLUTTER_CMD="$FLUTTER_CMD --release"
fi

if [ -n "$PLATFORM_ARG" ]; then
    FLUTTER_CMD="$FLUTTER_CMD $PLATFORM_ARG"
fi

echo "Executing: $FLUTTER_CMD"
echo ""

# Execute the command
exec $FLUTTER_CMD