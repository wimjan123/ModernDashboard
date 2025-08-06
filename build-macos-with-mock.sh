#!/bin/bash

# Build macOS app with mock data enabled for full functionality
echo "🚀 Building Modern Dashboard for macOS with mock data enabled..."

cd flutter_frontend

# Ensure macOS platform is enabled
flutter config --enable-macos-desktop

# Get dependencies
flutter pub get

# Create macOS platform if it doesn't exist
if [ ! -d "macos" ]; then
    echo "📱 Creating macOS platform..."
    flutter create --platforms=macos .
fi

# Build macOS app with mock data flag
echo "🔨 Building macOS app with USE_MOCK_DATA=true..."
flutter build macos --dart-define=USE_MOCK_DATA=true

echo "✅ macOS build complete!"
echo "📍 App location: flutter_frontend/build/macos/Build/Products/Release/modern_dashboard.app"
echo "🎯 Mock data is enabled - all dashboard features will work!"

# Optionally open the app
read -p "Open the app now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "build/macos/Build/Products/Release/modern_dashboard.app"
fi