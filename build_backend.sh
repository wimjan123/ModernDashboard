#!/bin/bash

set -e  # Exit on any error

echo "🔨 Building ModernDashboard C++ Backend"
echo "======================================="

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v cmake &> /dev/null; then
    echo "❌ CMake not found. Please install cmake first."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "   On macOS: brew install cmake"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "   On Linux: sudo apt-get install cmake"
    fi
    exit 1
fi

if ! command -v make &> /dev/null; then
    echo "❌ Make not found. Please install build tools."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "   On macOS: xcode-select --install"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "   On Linux: sudo apt-get install build-essential"
    fi
    exit 1
fi

echo "✅ Build tools available"

# Check for required dependencies
echo "🔍 Checking system dependencies..."

# Check pkg-config
if ! command -v pkg-config &> /dev/null; then
    echo "❌ pkg-config not found"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "   On macOS: brew install pkg-config"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "   On Linux: sudo apt-get install pkg-config"
    fi
    exit 1
fi

# Check libraries via pkg-config
MISSING_DEPS=()

if ! pkg-config --exists libcurl; then
    MISSING_DEPS+=("libcurl4-openssl-dev")
fi

if ! pkg-config --exists tinyxml2; then
    MISSING_DEPS+=("libtinyxml2-dev")
fi

if ! pkg-config --exists sqlite3; then
    MISSING_DEPS+=("libsqlite3-dev")
fi

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo "❌ Missing dependencies: ${MISSING_DEPS[*]}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "   On macOS: brew install curl tinyxml2 sqlite3"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "   On Linux: sudo apt-get install ${MISSING_DEPS[*]}"
    fi
    exit 1
fi

echo "✅ Required dependencies found"

# Clean build directory
echo "🧹 Cleaning build directory..."
if [ -d "build" ]; then
    rm -rf build
    echo "✅ Removed existing build directory"
fi

# Configure with CMake
echo "⚙️  Configuring with CMake..."
if ! cmake -B build -DCMAKE_BUILD_TYPE=Release; then
    echo "❌ CMake configuration failed"
    echo "   Check that all dependencies are properly installed"
    exit 1
fi
echo "✅ CMake configuration successful"

# Build the project
echo "🏗️  Building project..."
if ! cmake --build build --config Release; then
    echo "❌ Build failed"
    echo "   Check build output above for specific errors"
    exit 1
fi
echo "✅ Build successful"

# Verify library creation
echo "🔍 Verifying library creation..."
LIBRARY_NAME=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    LIBRARY_NAME="moderndash.dylib"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    LIBRARY_NAME="libmoderndash.so"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    LIBRARY_NAME="moderndash.dll"
fi

LIBRARY_PATH="build/${LIBRARY_NAME}"
if [ ! -f "$LIBRARY_PATH" ]; then
    echo "❌ Expected library not found: $LIBRARY_PATH"
    echo "   Available files in build/:"
    ls -la build/
    exit 1
fi

echo "✅ Library created: $LIBRARY_PATH"

# Check library properties (on macOS and Linux)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🔍 Library information (macOS):"
    file "$LIBRARY_PATH"
    echo "   Dependencies:"
    otool -L "$LIBRARY_PATH" | grep -v "$LIBRARY_PATH" | sed 's/^/   /'
    
    # Check if library exports expected symbols
    if nm -D "$LIBRARY_PATH" 2>/dev/null | grep -q "initialize_dashboard_engine"; then
        echo "✅ Expected FFI symbols found"
    else
        echo "⚠️  Warning: Expected FFI symbols not found with nm -D, checking with nm..."
        if nm "$LIBRARY_PATH" 2>/dev/null | grep -q "initialize_dashboard_engine"; then
            echo "✅ Expected FFI symbols found"
        else
            echo "❌ Expected FFI symbols not found"
            echo "   Available symbols containing 'init':"
            nm "$LIBRARY_PATH" 2>/dev/null | grep -i init || echo "   None found"
        fi
    fi
    
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "🔍 Library information (Linux):"
    file "$LIBRARY_PATH"
    echo "   Dependencies:"
    ldd "$LIBRARY_PATH" | sed 's/^/   /'
    
    # Check if library exports expected symbols
    if nm -D "$LIBRARY_PATH" 2>/dev/null | grep -q "initialize_dashboard_engine"; then
        echo "✅ Expected FFI symbols found"
    else
        echo "⚠️  Warning: Expected FFI symbols not found"
        echo "   Available exported symbols containing 'init':"
        nm -D "$LIBRARY_PATH" 2>/dev/null | grep -i init || echo "   None found"
    fi
fi

# Copy library to Flutter-expected locations (if needed)
echo "📂 Preparing library for Flutter FFI..."

# Create a directory structure that matches Flutter's expectations
if [ ! -d "flutter_frontend/lib/native" ]; then
    mkdir -p "flutter_frontend/lib/native"
fi

# Copy library to various locations the FFI bridge might look
cp "$LIBRARY_PATH" "flutter_frontend/lib/native/" || true
cp "$LIBRARY_PATH" "./" || true

echo "✅ Library copied to Flutter-expected locations"

# Verify executable creation
EXECUTABLE_PATH="build/ModernDashboard"
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    EXECUTABLE_PATH="build/ModernDashboard.exe"
fi

if [ -f "$EXECUTABLE_PATH" ]; then
    echo "✅ Test executable created: $EXECUTABLE_PATH"
    
    # Test that the executable can run (basic smoke test)
    if timeout 5 "$EXECUTABLE_PATH" --help 2>/dev/null; then
        echo "✅ Executable runs successfully"
    else
        echo "⚠️  Executable created but may have runtime issues"
    fi
else
    echo "❌ Expected executable not found: $EXECUTABLE_PATH"
fi

echo ""
echo "🎉 Backend build completed successfully!"
echo "   Library: $LIBRARY_PATH"
echo "   Executable: $EXECUTABLE_PATH"
echo ""
echo "Next steps:"
echo "   1. Run ./test_ffi_connection.sh to test FFI integration"
echo "   2. Use ./run_with_native_backend.sh to run Flutter with native backend"