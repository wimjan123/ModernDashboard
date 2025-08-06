# CRUSH.md

Project: ModernDashboard (C++ backend via CMake + Flutter desktop frontend via Flutter)

Build
- C++: mkdir -p build && cmake -S . -B build && cmake --build build -j$(nproc)
- Flutter (desktop): cd flutter_frontend && flutter pub get && flutter build <windows|macos|linux>
- Dev run (Flutter): cd flutter_frontend && flutter run -d <windows|macos|linux>

Test
- C++ (gtest expected under cpp_backend/tests): ctest --test-dir build --output-on-failure
- Build + run single C++ test: cd build && ctest -R <TestNameRegex> --output-on-failure
- Flutter all tests: cd flutter_frontend && flutter test
- Flutter single test file: cd flutter_frontend && flutter test test/<path_to_test>.dart
- Flutter single test name: cd flutter_frontend && flutter test --name "<test name>"

Lint/Format
- C++: clang-tidy (if config present) via: clang-tidy -p build $(git ls-files 'cpp_backend/**/*.cpp')
- C++ format: clang-format -i $(git ls-files 'cpp_backend/**/*.[ch]pp' 'cpp_backend/**/*.[ch]')
- Dart/Flutter: cd flutter_frontend && dart format . && dart analyze

Code Style
- Imports: C++ use angle brackets for system/3p, quotes for local; Dart use package: imports before relative.
- Formatting: clang-format for C++; dart format for Dart. 100 col soft limit.
- Types: Prefer explicit types (auto only when obvious); Dart prefer explicit over var in public APIs.
- Naming: C++ PascalCase types, camelCase methods/vars, SCREAMING_SNAKE_CASE consts; Dart follow Effective Dart.
- Errors: C++ return expected<bool/T> or bool + out param where practical; never throw across FFI. Log via utils/logger. Dart use Result-like patterns or exceptions caught at boundaries; no blocking UI.
- FFI: Only POD/UTF-8 across boundary; manage ownership (malloc/free) symmetrically; no global mutable state exposed.
- Concurrency: C++ guard with mutex/RAII; thread pools for services; Dart avoid compute-heavy work on UI isolate.
- Null/optional: Use std::optional in C++; Dart prefer nullable types with safe access; validate external data.
- Tests: Deterministic, no network by default; mock HTTP/WS and time; keep under 200ms per test.

Repo Conventions
- Build artifacts under build/; shared lib name: dashboard_backend(.dll|.so|.dylib) for FFI loading.
- Keep secrets out of repo; configure via env or platform keychain.
- If Cursor/Copilot rules are added later, mirror them here.
