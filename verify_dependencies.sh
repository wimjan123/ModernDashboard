#!/bin/bash

echo "🔍 ModernDashboard Dependency Verification"
echo "=========================================="

MISSING_DEPS=()
WARNINGS=()
OS_TYPE=""

# Detect operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macOS"
    PACKAGE_MANAGER="Homebrew"
    INSTALL_CMD="brew install"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="Linux"
    if command -v apt-get &> /dev/null; then
        PACKAGE_MANAGER="apt-get"
        INSTALL_CMD="sudo apt-get install"
    elif command -v yum &> /dev/null; then
        PACKAGE_MANAGER="yum"
        INSTALL_CMD="sudo yum install"
    elif command -v pacman &> /dev/null; then
        PACKAGE_MANAGER="pacman"
        INSTALL_CMD="sudo pacman -S"
    else
        PACKAGE_MANAGER="unknown"
        INSTALL_CMD="<package manager>"
    fi
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    OS_TYPE="Windows"
    PACKAGE_MANAGER="manual"
    INSTALL_CMD="manual installation"
else
    OS_TYPE="Unknown"
    PACKAGE_MANAGER="unknown"
    INSTALL_CMD="<unknown>"
fi

echo "Operating System: $OS_TYPE"
echo "Package Manager: $PACKAGE_MANAGER"
echo ""

# Check build tools
echo "🔨 Checking Build Tools"
echo "----------------------"

if command -v cmake &> /dev/null; then
    CMAKE_VERSION=$(cmake --version | head -n1)
    echo "✅ $CMAKE_VERSION"
    # Check minimum version (3.15)
    CMAKE_VER=$(cmake --version | grep -o '[0-9]\+\.[0-9]\+' | head -n1)
    if [ "$(printf '%s\n' "3.15" "$CMAKE_VER" | sort -V | head -n1)" != "3.15" ]; then
        WARNINGS+=("CMake version $CMAKE_VER is below recommended 3.15+")
    fi
else
    echo "❌ CMake not found"
    MISSING_DEPS+=("cmake")
fi

if command -v make &> /dev/null; then
    MAKE_VERSION=$(make --version | head -n1)
    echo "✅ $MAKE_VERSION"
else
    echo "❌ Make not found"
    if [[ "$OS_TYPE" == "macOS" ]]; then
        MISSING_DEPS+=("Command Line Tools (xcode-select --install)")
    else
        MISSING_DEPS+=("build-essential" "make")
    fi
fi

# Check for C++ compiler
if command -v g++ &> /dev/null; then
    GXX_VERSION=$(g++ --version | head -n1)
    echo "✅ $GXX_VERSION"
elif command -v clang++ &> /dev/null; then
    CLANG_VERSION=$(clang++ --version | head -n1)
    echo "✅ $CLANG_VERSION"
else
    echo "❌ C++ compiler (g++ or clang++) not found"
    if [[ "$OS_TYPE" == "macOS" ]]; then
        MISSING_DEPS+=("Command Line Tools (xcode-select --install)")
    else
        MISSING_DEPS+=("build-essential" "gcc" "g++")
    fi
fi

# Check pkg-config
if command -v pkg-config &> /dev/null; then
    PKG_CONFIG_VERSION=$(pkg-config --version)
    echo "✅ pkg-config $PKG_CONFIG_VERSION"
else
    echo "❌ pkg-config not found"
    MISSING_DEPS+=("pkg-config")
fi

echo ""

# Check system libraries
echo "📚 Checking System Libraries"
echo "----------------------------"

# Function to check library via pkg-config
check_pkg_lib() {
    local lib_name="$1"
    local pkg_name="$2"
    local apt_package="$3"
    local brew_package="$4"
    
    if command -v pkg-config &> /dev/null && pkg-config --exists "$pkg_name"; then
        local version=$(pkg-config --modversion "$pkg_name" 2>/dev/null || echo "unknown")
        echo "✅ $lib_name ($version)"
        return 0
    else
        echo "❌ $lib_name not found via pkg-config"
        if [[ "$OS_TYPE" == "macOS" ]]; then
            MISSING_DEPS+=("$brew_package")
        elif [[ "$PACKAGE_MANAGER" == "apt-get" ]]; then
            MISSING_DEPS+=("$apt_package")
        else
            MISSING_DEPS+=("$lib_name")
        fi
        return 1
    fi
}

# Check required libraries
check_pkg_lib "libcurl" "libcurl" "libcurl4-openssl-dev" "curl"
check_pkg_lib "TinyXML2" "tinyxml2" "libtinyxml2-dev" "tinyxml2"
check_pkg_lib "SQLite3" "sqlite3" "libsqlite3-dev" "sqlite3"

# Check OpenSSL (different approach since it's sometimes not in pkg-config)
if pkg-config --exists openssl; then
    OPENSSL_VERSION=$(pkg-config --modversion openssl)
    echo "✅ OpenSSL ($OPENSSL_VERSION)"
elif [[ "$OS_TYPE" == "macOS" ]] && [ -d "/usr/local/opt/openssl" ]; then
    echo "✅ OpenSSL (Homebrew installation detected)"
elif [ -f "/usr/include/openssl/opensslv.h" ]; then
    echo "✅ OpenSSL (system installation detected)"
else
    echo "❌ OpenSSL not found"
    if [[ "$OS_TYPE" == "macOS" ]]; then
        MISSING_DEPS+=("openssl")
    else
        MISSING_DEPS+=("libssl-dev")
    fi
fi

# Check nlohmann/json (header-only library)
if [ -f "/usr/local/include/nlohmann/json.hpp" ] || [ -f "/usr/include/nlohmann/json.hpp" ] || [ -f "/opt/homebrew/include/nlohmann/json.hpp" ]; then
    echo "✅ nlohmann/json (found in system)"
elif pkg-config --exists nlohmann_json; then
    NLOHMANN_VERSION=$(pkg-config --modversion nlohmann_json)
    echo "✅ nlohmann/json ($NLOHMANN_VERSION)"
else
    echo "❌ nlohmann/json not found"
    if [[ "$OS_TYPE" == "macOS" ]]; then
        MISSING_DEPS+=("nlohmann-json")
    else
        MISSING_DEPS+=("nlohmann-json3-dev")
    fi
fi

echo ""

# Check Flutter
echo "🐦 Checking Flutter"
echo "------------------"

if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -n1)
    echo "✅ $FLUTTER_VERSION"
    
    # Check Flutter doctor
    echo "   Running Flutter doctor..."
    if flutter doctor --android-licenses &>/dev/null || true; then
        # Suppress android license prompts
        true
    fi
    
    flutter doctor -v > /tmp/flutter_doctor.log 2>&1
    
    if grep -q "\[✓\].*Flutter" /tmp/flutter_doctor.log; then
        echo "   ✅ Flutter SDK OK"
    else
        echo "   ⚠️  Flutter SDK issues detected"
        WARNINGS+=("Flutter doctor found issues - run 'flutter doctor' for details")
    fi
    
    # Check if desktop is enabled (for macOS/Linux)
    if [[ "$OS_TYPE" == "macOS" ]]; then
        if flutter config | grep -q "enable-macos-desktop: true"; then
            echo "   ✅ macOS desktop support enabled"
        else
            echo "   ⚠️  macOS desktop support not enabled"
            WARNINGS+=("Enable macOS desktop: flutter config --enable-macos-desktop")
        fi
    elif [[ "$OS_TYPE" == "Linux" ]]; then
        if flutter config | grep -q "enable-linux-desktop: true"; then
            echo "   ✅ Linux desktop support enabled"
        else
            echo "   ⚠️  Linux desktop support not enabled"
            WARNINGS+=("Enable Linux desktop: flutter config --enable-linux-desktop")
        fi
    fi
    
    rm -f /tmp/flutter_doctor.log
else
    echo "❌ Flutter not found"
    MISSING_DEPS+=("Flutter SDK (https://flutter.dev/docs/get-started/install)")
fi

echo ""

# Summary
echo "📋 Summary"
echo "----------"

if [ ${#MISSING_DEPS[@]} -eq 0 ] && [ ${#WARNINGS[@]} -eq 0 ]; then
    echo "🎉 All dependencies are satisfied!"
    echo "   You can proceed with building the project."
    echo ""
    echo "Next steps:"
    echo "   1. Run './build_backend.sh' to build the C++ backend"
    echo "   2. Run './test_ffi_connection.sh' to verify FFI integration"
else
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        echo "❌ Missing dependencies (${#MISSING_DEPS[@]}):"
        for dep in "${MISSING_DEPS[@]}"; do
            echo "   • $dep"
        done
        echo ""
        echo "🔧 Installation commands for $OS_TYPE:"
        if [[ "$OS_TYPE" == "macOS" ]]; then
            echo "   $INSTALL_CMD $(echo "${MISSING_DEPS[@]}" | tr ' ' ' ')"
        elif [[ "$PACKAGE_MANAGER" == "apt-get" ]]; then
            echo "   sudo apt-get update"
            echo "   $INSTALL_CMD $(echo "${MISSING_DEPS[@]}" | tr ' ' ' ')"
        else
            echo "   $INSTALL_CMD $(echo "${MISSING_DEPS[@]}" | tr ' ' ' ')"
        fi
    fi
    
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  Warnings (${#WARNINGS[@]}):"
        for warning in "${WARNINGS[@]}"; do
            echo "   • $warning"
        done
    fi
fi

echo ""

# Exit with appropriate code
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    exit 1
else
    exit 0
fi