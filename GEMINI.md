# GEMINI.md: ModernDashboard

## Project Overview

ModernDashboard is a high-performance, cross-platform desktop application with a C++ backend and a Flutter frontend. The backend provides native performance for data processing and system integration, while the Flutter frontend offers a modern, responsive user interface. The two parts of the application communicate using a Foreign Function Interface (FFI), with shared data models and constants defined in the `shared` directory.

The application features a modular widget-based architecture, allowing for easy extension with new functionalities. The current widgets include:

*   **News:** Aggregates RSS feeds.
*   **Weather:** Displays real-time weather information.
*   **Todo:** A simple task manager.
*   **Mail:** Notifies about new emails.

## Building and Running

### Prerequisites

*   **C++ Compiler:** C++20 support (GCC 9+, Clang 10+, or MSVC 2019+).
*   **CMake:** Version 3.15 or higher.
*   **Flutter SDK:** Version 3.10 or higher.
*   **System Libraries:**
    *   `libcurl`
    *   `openssl`
    *   `sqlite3`
    *   `tinyxml2`
    *   `nlohmann_json`

### Build Process

1.  **Build the C++ Backend:**
    ```bash
    mkdir -p build
    cmake -S . -B build
    cmake --build build
    ```

2.  **Build the Flutter Frontend:**
    ```bash
    cd flutter_frontend
    flutter pub get
    flutter build <windows|macos|linux>
    ```

### Running in Development

To run the application in development mode with hot reload:

```bash
cd flutter_frontend
flutter run -d <windows|macos|linux>
```

### Testing

*   **C++ Tests:**
    ```bash
    ctest --test-dir build --output-on-failure
    ```

*   **Flutter Tests:**
    ```bash
    cd flutter_frontend
    flutter test
    ```

## Development Conventions

### Code Style

*   **C++:** Follows the conventions in the existing codebase. `clang-format` and `clang-tidy` are used for formatting and static analysis.
*   **Dart/Flutter:** Follows the standard Dart and Flutter style guides. `dart format` and `dart analyze` are used for formatting and analysis.

### FFI Bridge

The C++ backend exposes a C-style API in `shared/ffi_interface.h` that is consumed by the Flutter frontend using the `dart:ffi` library. When adding new functionality, this interface must be updated.

### Contribution Guidelines

1.  Fork the repository.
2.  Create a feature branch.
3.  Add tests for new features.
4.  Update documentation for API changes.
5.  Ensure cross-platform compatibility.
6.  Use meaningful commit messages.
7.  Open a pull request.
