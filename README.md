# ModernDashboard

A modern Flutter desktop application with Firebase backend, delivering beautiful cross-platform design with cloud-powered data synchronization and real-time updates.

![Dashboard Preview](https://img.shields.io/badge/Platform-macOS%20%7C%20iOS%20%7C%20Web-blue)
![Language](https://img.shields.io/badge/Language-Dart%20%7C%20Flutter-green)
![Backend](https://img.shields.io/badge/Backend-Firebase-orange)
![License](https://img.shields.io/badge/License-MIT-yellow)

## 🚀 Features

- **Cloud-Powered**: Firebase backend with real-time synchronization
- **Modern UI**: Flutter desktop with beautiful Material Design 3 dark theme
- **Cross-Platform**: Single codebase supporting macOS, iOS, and Web
- **Real-time Updates**: Live data feeds with Firestore real-time listeners
- **Offline Support**: Firestore persistence for offline functionality
- **Repository Pattern**: Clean architecture with dependency injection

### Dashboard Widgets

- 📰 **News Widget**: RSS feed aggregation with cloud storage
- 🌤️ **Weather Widget**: Real-time weather information with location-based updates
- ✅ **Todo Widget**: Task management with Firestore synchronization
- 📧 **Mail Widget**: Email notifications with cloud persistence

## 🏗️ Architecture

### Technology Stack

- **Frontend**: Flutter 3.10+ with Material Design 3
- **Backend**: Firebase (Firestore, Auth, Functions)
- **Database**: Cloud Firestore with offline persistence
- **Authentication**: Firebase Auth (anonymous authentication)
- **State Management**: Repository pattern with dependency injection

### Project Structure

```
ModernDashboard/
├── flutter_frontend/          # Flutter Desktop App
│   ├── lib/
│   │   ├── core/              # App core, theme, and DI
│   │   ├── firebase/          # Firebase services and configuration
│   │   ├── repositories/      # Data layer with repository pattern
│   │   ├── widgets/           # Dashboard widgets
│   │   ├── screens/           # Application screens
│   │   └── main.dart          # App entry point
│   ├── macos/                 # macOS platform files
│   ├── ios/                   # iOS platform files
│   ├── web/                   # Web platform files
│   └── pubspec.yaml           # Flutter dependencies
├── setup_macos.sh             # Automated macOS setup script
├── Makefile                   # Development commands
└── README.md                  # This file
```

## 🛠️ Installation

### Prerequisites

- **Flutter**: Version 3.10 or higher
- **Xcode**: Version 14 or higher (for macOS/iOS development)
- **CocoaPods**: For iOS/macOS dependency management
- **Firebase CLI**: For Firebase project configuration
- **Node.js**: Version 16+ (for Firebase CLI)

### Quick Setup (Recommended)

For automated macOS development setup:

```bash
git clone https://github.com/yourusername/ModernDashboard.git
cd ModernDashboard
./setup_macos.sh
```

This script will:
- Verify all prerequisites
- Enable macOS desktop support
- Configure Firebase for all platforms
- Install dependencies and CocoaPods
- Set up the development environment

### Manual Setup

#### 1. Install Prerequisites

**macOS Development Tools:**
```bash
# Install Xcode command line tools
xcode-select --install

# Install CocoaPods
sudo gem install cocoapods

# Install Firebase CLI
npm install -g firebase-tools
```

**Flutter Setup:**
```bash
# Verify Flutter installation
flutter doctor

# Enable macOS desktop support
flutter config --enable-macos-desktop
```

#### 2. Clone and Configure

```bash
git clone https://github.com/yourusername/ModernDashboard.git
cd ModernDashboard
```

#### 3. Firebase Configuration

```bash
# Login to Firebase
firebase login

# Configure Firebase project
cd flutter_frontend
flutterfire configure
```

This will:
- Create or select a Firebase project
- Generate `firebase_options.dart`
- Create platform-specific config files
- Set up Firebase services

#### 4. Platform Setup

```bash
# Generate macOS platform files
flutter create . --platforms=macos

# Install Flutter dependencies
flutter pub get

# Install macOS CocoaPods
cd macos && pod install && cd ..
```

## 🎯 Usage

### Development Commands

Using the Makefile for common tasks:

```bash
# Run on macOS
make run

# Run on iOS simulator
make run-ios

# Run on web
make run-web

# Run tests
make test

# Build for macOS
make build-macos
```

### Manual Commands

```bash
cd flutter_frontend

# Run on macOS
flutter run -d macos

# Run on iOS simulator
flutter run -d ios

# Run on web
flutter run -d web-server --web-port 8080

# Build for production
flutter build macos
```

### Firebase Emulators (Development)

For local development with Firebase emulators:

```bash
# Start Firebase emulators
make firebase-emulators

# Or manually
firebase emulators:start --only firestore,auth
```

## 🔧 Configuration

### Firebase Project Setup

1. **Create Firebase Project**: Visit [Firebase Console](https://console.firebase.google.com)
2. **Enable Services**:
   - Firestore Database
   - Authentication (Anonymous)
   - Functions (optional)
3. **Configure Security Rules**:
   ```javascript
   // Firestore rules for anonymous auth
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```

### Environment Configuration

Create `.env` file in `flutter_frontend/` for environment-specific settings:

```env
# Development settings
FLUTTER_ENV=development
FIREBASE_EMULATOR_HOST=localhost
FIRESTORE_EMULATOR_PORT=8080
```

## 🧪 Testing

### Unit and Widget Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

### Firebase Emulator Testing

```bash
# Start emulators
firebase emulators:start

# Run tests against emulators
flutter test --dart-define=USE_FIREBASE_EMULATOR=true
```

### Code Quality

```bash
# Format code
dart format .

# Analyze code
dart analyze

# Run linting
dart run dart_code_metrics:metrics analyze lib
```

## 🚀 Deployment

### macOS App Distribution

```bash
# Build for release
flutter build macos --release

# Create app bundle
cd build/macos/Build/Products/Release/
# App bundle is ready for distribution
```

### Web Deployment

```bash
# Build for web
flutter build web --release

# Deploy to Firebase Hosting (optional)
firebase deploy --only hosting
```

### Firebase Deployment

```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Functions (if using)
firebase deploy --only functions
```

## 🔍 Troubleshooting

### Common macOS Issues

**CocoaPods Issues:**
```bash
# Clean and reinstall pods
cd macos
rm -rf Pods Podfile.lock
pod install
```

**Firebase Configuration:**
```bash
# Regenerate Firebase config
flutterfire configure --force
```

**Build Issues:**
```bash
# Clean Flutter build
flutter clean
flutter pub get
cd macos && pod install
```

### Firebase Connectivity

**Check Firebase Connection:**
```bash
# Test Firebase project access
firebase projects:list

# Verify Firestore rules
firebase firestore:rules:get
```

**Emulator Issues:**
```bash
# Reset emulator data
firebase emulators:start --import=./emulator-data --export-on-exit
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow the existing code style and conventions
- Add tests for new features
- Update documentation for API changes
- Ensure Firebase security rules are properly configured
- Use meaningful commit messages
- Test on multiple platforms (macOS, iOS, Web)

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔮 Roadmap

- [ ] **Enhanced Widgets**: More dashboard widget types
- [ ] **Real-time Collaboration**: Multi-user support with Firestore
- [ ] **Push Notifications**: Firebase Cloud Messaging integration
- [ ] **Advanced Analytics**: Firebase Analytics integration
- [ ] **Plugin System**: Dynamic widget loading from Firestore
- [ ] **Configuration UI**: In-app settings management
- [ ] **Theming**: Multiple theme support with cloud sync
- [ ] **Localization**: Multi-language support
- [ ] **Android Support**: Android platform support

## 🙏 Acknowledgments

- **Flutter Team** for the excellent cross-platform framework
- **Firebase Team** for the comprehensive backend platform
- **Open Source Contributors** for the foundational libraries

## 📞 Support

For questions, bug reports, or feature requests:
- Open an [issue](https://github.com/yourusername/ModernDashboard/issues)
- Join our [discussions](https://github.com/yourusername/ModernDashboard/discussions)
- Email: support@moderndashboard.dev

---

**Built with ❤️ using Flutter and Firebase**
