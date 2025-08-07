# ModernDashboard Makefile
# Simplified development commands and build automation

.PHONY: help setup deps clean run run-ios run-web debug build-macos build-ios build-web build-all test analyze format lint firebase-setup firebase-emulators firebase-deploy doctor upgrade

# Default target
.DEFAULT_GOAL := help

# Variables
FLUTTER_DIR = flutter_frontend
SETUP_SCRIPT = setup_macos.sh

# Help target - Display available commands
help:
	@echo "ModernDashboard Development Commands"
	@echo "===================================="
	@echo ""
	@echo "Setup targets:"
	@echo "  make setup              Run the macOS setup script"
	@echo "  make deps               Install Flutter dependencies and pods"
	@echo "  make clean              Clean build artifacts and caches"
	@echo ""
	@echo "Development targets:"
	@echo "  make run                Run the app on macOS"
	@echo "  make run-ios            Run on iOS simulator"
	@echo "  make run-web            Run on web browser"
	@echo "  make debug              Run in debug mode with verbose logging"
	@echo ""
	@echo "Build targets:"
	@echo "  make build-macos        Build macOS app bundle"
	@echo "  make build-ios          Build iOS app"
	@echo "  make build-web          Build web app"
	@echo "  make build-all          Build for all platforms"
	@echo ""
	@echo "Testing and quality targets:"
	@echo "  make test               Run unit and widget tests"
	@echo "  make analyze            Run Flutter analyzer"
	@echo "  make format             Format Dart code"
	@echo "  make lint               Run linting checks"
	@echo ""
	@echo "Firebase targets:"
	@echo "  make firebase-setup     Configure Firebase project"
	@echo "  make firebase-emulators Start Firebase emulators for local development"
	@echo "  make firebase-deploy    Deploy to Firebase (if using Hosting)"
	@echo ""
	@echo "Utility targets:"
	@echo "  make doctor             Run Flutter doctor to check setup"
	@echo "  make upgrade            Upgrade Flutter and dependencies"
	@echo "  make help               Display this help message"

# Setup targets
setup:
	@echo "Running macOS setup script..."
	@if [ -f "$(SETUP_SCRIPT)" ]; then \
		chmod +x $(SETUP_SCRIPT) && ./$(SETUP_SCRIPT); \
	else \
		echo "Error: $(SETUP_SCRIPT) not found. Please ensure the setup script exists."; \
		exit 1; \
	fi

deps:
	@echo "Installing Flutter dependencies..."
	@cd $(FLUTTER_DIR) && flutter pub get
	@echo "Installing iOS pods..."
	@if [ -d "$(FLUTTER_DIR)/ios" ]; then \
		cd $(FLUTTER_DIR)/ios && pod install; \
	else \
		echo "iOS directory not found, skipping pod install"; \
	fi
	@echo "Installing macOS pods..."
	@if [ -d "$(FLUTTER_DIR)/macos" ]; then \
		cd $(FLUTTER_DIR)/macos && pod install; \
	else \
		echo "macOS directory not found, skipping pod install"; \
	fi

clean:
	@echo "Cleaning build artifacts and caches..."
	@cd $(FLUTTER_DIR) && flutter clean
	@cd $(FLUTTER_DIR) && flutter pub get
	@echo "Cleaning iOS pods..."
	@if [ -d "$(FLUTTER_DIR)/ios" ]; then \
		cd $(FLUTTER_DIR)/ios && rm -rf Pods Podfile.lock; \
	fi
	@echo "Cleaning macOS pods..."
	@if [ -d "$(FLUTTER_DIR)/macos" ]; then \
		cd $(FLUTTER_DIR)/macos && rm -rf Pods Podfile.lock; \
	fi
	@echo "Clean complete. Run 'make deps' to reinstall dependencies."

# Development targets
run:
	@echo "Running app on macOS..."
	@cd $(FLUTTER_DIR) && flutter run -d macos

run-ios:
	@echo "Running app on iOS simulator..."
	@cd $(FLUTTER_DIR) && flutter run -d ios

run-web:
	@echo "Running app on web browser..."
	@cd $(FLUTTER_DIR) && flutter run -d web-server --web-port 8080

debug:
	@echo "Running app in debug mode with verbose logging..."
	@cd $(FLUTTER_DIR) && flutter run -d macos --verbose --debug

# Build targets
build-macos:
	@echo "Building macOS app bundle..."
	@cd $(FLUTTER_DIR) && flutter build macos --release

build-ios:
	@echo "Building iOS app..."
	@cd $(FLUTTER_DIR) && flutter build ios --release --no-codesign

build-web:
	@echo "Building web app..."
	@cd $(FLUTTER_DIR) && flutter build web --release

build-all: build-macos build-ios build-web
	@echo "All platform builds completed successfully!"

# Testing and quality targets
test:
	@echo "Running unit and widget tests..."
	@cd $(FLUTTER_DIR) && flutter test --coverage
	@echo "Test coverage report generated in coverage/lcov.info"

analyze:
	@echo "Running Flutter analyzer..."
	@cd $(FLUTTER_DIR) && flutter analyze

format:
	@echo "Formatting Dart code..."
	@cd $(FLUTTER_DIR) && dart format . --set-exit-if-changed

lint: analyze
	@echo "Running linting checks..."
	@cd $(FLUTTER_DIR) && dart analyze --fatal-infos --fatal-warnings

# Firebase targets
firebase-setup:
	@echo "Configuring Firebase project..."
	@if command -v flutterfire >/dev/null 2>&1; then \
		cd $(FLUTTER_DIR) && flutterfire configure; \
	else \
		echo "FlutterFire CLI not found. Installing..."; \
		dart pub global activate flutterfire_cli; \
		cd $(FLUTTER_DIR) && flutterfire configure; \
	fi

firebase-emulators:
	@echo "Starting Firebase emulators for local development..."
	@if command -v firebase >/dev/null 2>&1; then \
		cd $(FLUTTER_DIR) && firebase emulators:start; \
	else \
		echo "Firebase CLI not found. Please install it first:"; \
		echo "npm install -g firebase-tools"; \
		exit 1; \
	fi

firebase-deploy:
	@echo "Deploying to Firebase..."
	@if command -v firebase >/dev/null 2>&1; then \
		cd $(FLUTTER_DIR) && flutter build web --release && firebase deploy; \
	else \
		echo "Firebase CLI not found. Please install it first:"; \
		echo "npm install -g firebase-tools"; \
		exit 1; \
	fi

# Utility targets
doctor:
	@echo "Running Flutter doctor to check setup..."
	@flutter doctor -v

upgrade:
	@echo "Upgrading Flutter and dependencies..."
	@flutter upgrade
	@cd $(FLUTTER_DIR) && flutter pub upgrade
	@echo "Upgrade complete. Consider running 'make clean && make deps' to refresh dependencies."

# Development workflow shortcuts
dev-setup: setup deps
	@echo "Development environment setup complete!"

quick-test: format analyze test
	@echo "Quick quality checks completed!"

pre-commit: format analyze test
	@echo "Pre-commit checks completed successfully!"

# Platform-specific shortcuts
macos: clean deps run
	@echo "macOS development workflow completed!"

ios: clean deps run-ios
	@echo "iOS development workflow completed!"

web: clean deps run-web
	@echo "Web development workflow completed!"