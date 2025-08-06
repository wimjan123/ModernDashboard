# ModernDashboard

A high-performance native desktop application combining C++ backend services with Flutter's modern UI framework, delivering native performance with beautiful cross-platform design.

![Dashboard Preview](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-blue)
![Language](https://img.shields.io/badge/Language-C%2B%2B20%20%7C%20Dart-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## 🚀 Features

- **Native Performance**: C++ backend with direct system integration
- **Modern UI**: Flutter desktop with beautiful Material Design 3 dark theme
- **Cross-Platform**: Single codebase supporting Windows, macOS, and Linux
- **Real-time Updates**: Live data feeds with configurable refresh intervals
- **Modular Architecture**: Plugin-based widget system for easy extensibility

### Dashboard Widgets

- 📰 **News Widget**: RSS feed aggregation from multiple sources
- 🌤️ **Weather Widget**: Real-time weather information with location-based updates
- ✅ **Todo Widget**: Task management with completion tracking
- 📧 **Mail Widget**: Email notifications with unread count indicators

## 🏗️ Architecture

### Technology Stack

- **Backend**: C++20 with CMake, SQLite, OpenSSL, libcurl
- **Frontend**: Flutter 3.10+ with FFI bridge
- **Communication**: Foreign Function Interface (FFI) for high-performance data exchange
- **Database**: SQLite3 for local data persistence
- **Network**: HTTP/HTTPS clients with SSL/TLS support

### Project Structure

```
ModernDashboard/
├── cpp_backend/                # C++ Backend Engine
│   ├── src/
│   │   ├── core/              # Core systems (Engine, WidgetManager)
│   │   ├── services/          # Business logic services
│   │   ├── network/           # HTTP/WebSocket clients
│   │   ├── database/          # Data persistence layer
│   │   └── main.cpp           # FFI interface implementation
│   └── include/               # Public headers
├── flutter_frontend/          # Flutter Desktop App
│   ├── lib/
│   │   ├── core/              # App core and theme
│   │   ├── services/          # FFI bridge services
│   │   ├── widgets/           # Dashboard widgets
│   │   └── screens/           # Application screens
│   └── pubspec.yaml           # Flutter dependencies
├── shared/                    # Shared interface definitions
│   ├── ffi_interface.h        # C++ ↔ Dart interface
│   ├── data_models.h          # Shared data structures
│   └── constants.h            # Configuration constants
└── CMakeLists.txt             # Build configuration
```

## 🛠️ Installation

### Prerequisites

- **C++ Compiler**: GCC 9+ or Clang 10+ with C++20 support
- **CMake**: Version 3.15 or higher
- **Flutter**: Version 3.10 or higher
- **System Libraries**: SQLite3, OpenSSL, libcurl

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install build-essential cmake libsqlite3-dev libssl-dev libcurl4-openssl-dev
```

#### macOS
```bash
brew install cmake openssl sqlite3 curl
```

#### Windows
- Install Visual Studio 2019+ with C++ tools
- Install CMake from https://cmake.org/download/
- Install vcpkg for dependency management

### Build Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/ModernDashboard.git
   cd ModernDashboard
   ```

2. **Build C++ Backend**
   ```bash
   mkdir -p build
   cmake -S . -B build
   cmake --build build -j$(nproc)
   ```

3. **Build Flutter Frontend**
   ```bash
   cd flutter_frontend
   flutter pub get
   flutter build windows  # or macos/linux
   ```

4. **Development Run**
   ```bash
   cd flutter_frontend
   flutter run -d windows  # or macos/linux
   ```

## 🎯 Usage

### Running the Application

After building, run the Flutter application:

```bash
cd flutter_frontend
flutter run -d <platform>
```

The dashboard will automatically:
- Initialize the C++ backend engine
- Load default RSS feeds and configurations
- Start periodic updates for all widgets
- Display real-time information in a responsive grid layout

### Configuration

Widget configurations can be modified through:
- **News Feeds**: Add/remove RSS sources via FFI interface
- **Weather Location**: Update location for weather data
- **Update Intervals**: Modify refresh rates in `shared/constants.h`

## 🧪 Testing

### C++ Tests
```bash
# Build and run C++ tests (requires Google Test)
ctest --test-dir build --output-on-failure
```

### Flutter Tests
```bash
cd flutter_frontend
flutter test
```

### Code Quality
```bash
# C++ formatting and analysis
clang-format -i $(git ls-files 'cpp_backend/**/*.[ch]pp')
clang-tidy -p build $(git ls-files 'cpp_backend/**/*.cpp')

# Dart formatting and analysis
cd flutter_frontend
dart format .
dart analyze
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
- Ensure cross-platform compatibility
- Use meaningful commit messages

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔮 Roadmap

- [ ] **Network Layer**: Complete HTTP client and RSS parser implementation
- [ ] **Stream Integration**: Video streaming support with FFmpeg
- [ ] **Database Layer**: Full SQLite integration with migrations
- [ ] **Plugin System**: Dynamic widget loading
- [ ] **Configuration UI**: In-app settings management
- [ ] **Theming**: Multiple theme support
- [ ] **Localization**: Multi-language support
- [ ] **Mobile Support**: iOS and Android versions

## 🙏 Acknowledgments

- **Flutter Team** for the excellent cross-platform framework
- **CMake Community** for the robust build system
- **Open Source Contributors** for the foundational libraries

## 📞 Support

For questions, bug reports, or feature requests:
- Open an [issue](https://github.com/yourusername/ModernDashboard/issues)
- Join our [discussions](https://github.com/yourusername/ModernDashboard/discussions)
- Email: support@moderndashboard.dev

---

**Built with ❤️ using C++ and Flutter**# Self-hosted runner is now configured and running on VPS
