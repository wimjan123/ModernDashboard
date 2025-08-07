#!/bin/bash

# ModernDashboard macOS Setup Script
# This script sets up the development environment for macOS builds with Firebase support

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Script header
echo -e "${BLUE}"
echo "=================================================="
echo "  ModernDashboard macOS Setup Script"
echo "=================================================="
echo -e "${NC}"
echo "This script will set up your macOS development environment for the ModernDashboard Flutter app with Firebase support."
echo ""

# Check if we're in the right directory
if [ ! -f "flutter_frontend/pubspec.yaml" ]; then
    print_error "This script must be run from the ModernDashboard root directory."
    print_error "Please navigate to the project root and run: ./setup_macos.sh"
    exit 1
fi

# Step 1: Check Flutter installation
print_step "Checking Flutter installation..."
if ! check_command flutter; then
    print_error "Flutter is not installed or not in PATH."
    echo "Please install Flutter from: https://docs.flutter.dev/get-started/install/macos"
    exit 1
fi

# Check Flutter version
FLUTTER_VERSION=$(flutter --version | head -n 1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
print_success "Flutter $FLUTTER_VERSION found"

# Step 2: Check Xcode installation
print_step "Checking Xcode installation..."
if ! xcode-select -p &>/dev/null; then
    print_error "Xcode command line tools not found."
    echo "Please install Xcode from the App Store and run:"
    echo "  sudo xcode-select --install"
    exit 1
fi

print_success "Xcode command line tools found"

# Accept Xcode license if needed
print_step "Ensuring Xcode license is accepted..."
if ! sudo xcodebuild -license check &>/dev/null; then
    print_warning "Xcode license needs to be accepted."
    sudo xcodebuild -license accept
fi
print_success "Xcode license accepted"

# Step 3: Check CocoaPods installation
print_step "Checking CocoaPods installation..."
if ! check_command pod; then
    print_warning "CocoaPods not found. Installing..."
    if check_command brew; then
        brew install cocoapods
    else
        sudo gem install cocoapods
    fi
    print_success "CocoaPods installed"
else
    print_success "CocoaPods found"
fi

# Step 4: Check Node.js and npm (required for Firebase CLI)
print_step "Checking Node.js installation..."
if ! check_command node; then
    print_warning "Node.js not found. Installing via Homebrew..."
    if ! check_command brew; then
        print_error "Homebrew not found. Please install Homebrew first:"
        echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        exit 1
    fi
    brew install node
    print_success "Node.js installed"
else
    print_success "Node.js found"
fi

# Step 5: Check Firebase CLI
print_step "Checking Firebase CLI installation..."
if ! check_command firebase; then
    print_warning "Firebase CLI not found. Installing..."
    npm install -g firebase-tools
    print_success "Firebase CLI installed"
else
    print_success "Firebase CLI found"
fi

# Step 6: Check FlutterFire CLI
print_step "Checking FlutterFire CLI installation..."
if ! check_command flutterfire; then
    print_warning "FlutterFire CLI not found. Installing..."
    dart pub global activate flutterfire_cli
    
    # Add dart pub global bin to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.pub-cache/bin:"* ]]; then
        print_warning "Adding Dart pub global bin to PATH..."
        echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.zshrc
        echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.bash_profile
        export PATH="$PATH:$HOME/.pub-cache/bin"
    fi
    print_success "FlutterFire CLI installed"
else
    print_success "FlutterFire CLI found"
fi

# Step 7: Enable macOS desktop support
print_step "Enabling macOS desktop support in Flutter..."
flutter config --enable-macos-desktop
print_success "macOS desktop support enabled"

# Step 8: Navigate to Flutter frontend directory
cd flutter_frontend

# Step 9: Generate macOS platform files
print_step "Generating macOS platform files..."
if [ ! -d "macos" ]; then
    flutter create . --platforms=macos
    print_success "macOS platform files generated"
else
    print_success "macOS platform files already exist"
fi

# Step 10: Install Flutter dependencies
print_step "Installing Flutter dependencies..."
flutter pub get
print_success "Flutter dependencies installed"

# Step 11: Firebase authentication and configuration
print_step "Setting up Firebase configuration..."
echo ""
print_warning "You will now be prompted to configure Firebase."
print_warning "Please ensure you have a Firebase project ready or create one at: https://console.firebase.google.com"
echo ""

# Check if user is logged into Firebase
if ! firebase projects:list &>/dev/null; then
    print_warning "You need to log in to Firebase first."
    firebase login
fi

# Run FlutterFire configuration
print_step "Running FlutterFire configuration..."
echo "Please select your Firebase project and ensure you enable the following platforms:"
echo "  - iOS (required for macOS)"
echo "  - macOS"
echo "  - Android"
echo "  - Web (optional)"
echo ""

flutterfire configure

print_success "Firebase configuration completed"

# Step 12: Copy Firebase configuration for macOS
print_step "Setting up Firebase configuration for macOS..."
if [ -f "ios/Runner/GoogleService-Info.plist" ] && [ -d "macos/Runner" ]; then
    cp ios/Runner/GoogleService-Info.plist macos/Runner/
    print_success "Firebase configuration copied to macOS"
else
    print_warning "Firebase configuration files not found. You may need to run 'flutterfire configure' again."
fi

# Step 13: Install CocoaPods dependencies for macOS
print_step "Installing CocoaPods dependencies for macOS..."
cd macos
if [ -f "Podfile" ]; then
    pod install
    print_success "macOS CocoaPods dependencies installed"
else
    print_warning "Podfile not found in macOS directory"
fi
cd ..

# Step 14: Run Flutter doctor
print_step "Running Flutter doctor to verify setup..."
flutter doctor

# Step 15: Final verification
print_step "Performing final verification..."

# Check if firebase_options.dart was generated
if [ -f "lib/firebase_options.dart" ]; then
    print_success "Firebase options file generated"
else
    print_warning "Firebase options file not found. You may need to run 'flutterfire configure' again."
fi

# Check if macOS platform is properly set up
if [ -d "macos" ] && [ -f "macos/Runner.xcworkspace" ]; then
    print_success "macOS platform properly configured"
else
    print_warning "macOS platform may not be properly configured"
fi

# Success message
echo ""
echo -e "${GREEN}"
echo "=================================================="
echo "  Setup Complete! 🎉"
echo "=================================================="
echo -e "${NC}"
echo ""
echo "Your macOS development environment is now ready!"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Build and run the app on macOS:"
echo "   ${YELLOW}flutter run -d macos${NC}"
echo ""
echo "2. If you encounter any issues, try:"
echo "   ${YELLOW}flutter clean && flutter pub get${NC}"
echo "   ${YELLOW}cd macos && pod install && cd ..${NC}"
echo ""
echo "3. To build a release version:"
echo "   ${YELLOW}flutter build macos${NC}"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo "• Run on macOS: ${YELLOW}flutter run -d macos${NC}"
echo "• Run on iOS Simulator: ${YELLOW}flutter run -d ios${NC}"
echo "• Run on web: ${YELLOW}flutter run -d web${NC}"
echo "• Run tests: ${YELLOW}flutter test${NC}"
echo "• Check setup: ${YELLOW}flutter doctor${NC}"
echo ""
echo -e "${BLUE}Firebase:${NC}"
echo "• Your Firebase project is configured and ready to use"
echo "• Configuration files are located in lib/firebase_options.dart"
echo "• Platform-specific configs are in ios/Runner/ and macos/Runner/"
echo ""
echo "Happy coding! 🚀"