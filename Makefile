# Makefile for Snyk CLI Greybeard
# Cross-compiles to multiple platforms and architectures

BINARY_NAME=greybeard
VERSION=$(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME=$(shell date -u '+%Y-%m-%d_%H:%M:%S')
DIST_DIR=dist

# Detect OS and architecture
UNAME_S := $(shell uname -s 2>/dev/null || echo "unknown")
UNAME_M := $(shell uname -m 2>/dev/null || echo "unknown")

# Set default install directory based on OS
ifeq ($(UNAME_S),Darwin)
	INSTALL_DIR=/usr/local/bin
	PLATFORM=darwin
	ifeq ($(UNAME_M),arm64)
		ARCH=arm64
	else
		ARCH=amd64
	endif
else ifeq ($(UNAME_S),Linux)
	INSTALL_DIR=/usr/local/bin
	PLATFORM=linux
	ifeq ($(UNAME_M),aarch64)
		ARCH=arm64
	else
		ARCH=amd64
	endif
else ifneq (,$(findstring MINGW,$(UNAME_S)))
	# Windows detection
	PLATFORM=windows
	ARCH=amd64
	BINARY_EXT=.exe
	INSTALL_DIR=$(APPDATA)/snyk-cli-greybeard
endif

# Supported platforms
PLATFORMS=linux-amd64 linux-arm64 darwin-amd64 darwin-arm64 windows-amd64

.PHONY: all clean compile install $(PLATFORMS)

all: clean compile

# Creates the distribution directory
$(DIST_DIR):
	mkdir -p $(DIST_DIR)

# Main compile target - builds for all platforms
compile: $(DIST_DIR) $(PLATFORMS)
	@echo "Cross-compilation complete!"
	@ls -la $(DIST_DIR)

# Linux AMD64
linux-amd64: $(DIST_DIR)
	@echo "Building for Linux (amd64)..."
	GOOS=linux GOARCH=amd64 go build -o $(DIST_DIR)/$(BINARY_NAME)-linux-amd64 -ldflags "-X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME)"

# Linux ARM64
linux-arm64: $(DIST_DIR)
	@echo "Building for Linux (arm64)..."
	GOOS=linux GOARCH=arm64 go build -o $(DIST_DIR)/$(BINARY_NAME)-linux-arm64 -ldflags "-X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME)"

# macOS AMD64
darwin-amd64: $(DIST_DIR)
	@echo "Building for macOS (amd64)..."
	GOOS=darwin GOARCH=amd64 go build -o $(DIST_DIR)/$(BINARY_NAME)-darwin-amd64 -ldflags "-X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME)"

# macOS ARM64 (Apple Silicon)
darwin-arm64: $(DIST_DIR)
	@echo "Building for macOS (arm64)..."
	GOOS=darwin GOARCH=arm64 go build -o $(DIST_DIR)/$(BINARY_NAME)-darwin-arm64 -ldflags "-X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME)"

# Windows AMD64
windows-amd64: $(DIST_DIR)
	@echo "Building for Windows (amd64)..."
	GOOS=windows GOARCH=amd64 go build -o $(DIST_DIR)/$(BINARY_NAME)-windows-amd64.exe -ldflags "-X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME)"

# Install the binary to the system based on detected platform
install:
	@echo "Detected platform: $(PLATFORM)-$(ARCH)"
ifeq ($(PLATFORM),windows)
	@echo "Building for Windows..."
	@mkdir -p $(INSTALL_DIR)
	@go build -o $(BINARY_NAME)$(BINARY_EXT) -ldflags "-X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME)"
	@echo "Installing to $(INSTALL_DIR)\\$(BINARY_NAME)$(BINARY_EXT)..."
	@cp $(BINARY_NAME)$(BINARY_EXT) $(INSTALL_DIR)/
	@echo "Installation complete!"
	@echo "Please ensure $(INSTALL_DIR) is in your PATH."
	@echo ""
	@echo "You can add it to your PATH with:"
	@echo "setx PATH \"%PATH%;$(INSTALL_DIR)\""
else
	@echo "Building for $(PLATFORM)-$(ARCH)..."
	@GOOS=$(PLATFORM) GOARCH=$(ARCH) go build -o $(BINARY_NAME) -ldflags "-X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME)"
	@echo "Installing to $(INSTALL_DIR)/$(BINARY_NAME)..."
	@if [ -w "$(INSTALL_DIR)" ]; then \
		cp $(BINARY_NAME) $(INSTALL_DIR)/; \
		echo "Installation complete! You can now run '$(BINARY_NAME)' from anywhere."; \
	else \
		echo "Error: You don't have permission to write to $(INSTALL_DIR)."; \
		echo "You can use sudo to install: sudo make install"; \
		echo "Or you can use the local binary: ./$(BINARY_NAME)"; \
	fi
endif
	@if [ -z "$$OPENAI_API_KEY" ]; then \
		echo ""; \
		echo "IMPORTANT: Don't forget to set your OpenAI API key with:"; \
		echo "export OPENAI_API_KEY='your-api-key' (Linux/macOS)"; \
		echo "or"; \
		echo "setx OPENAI_API_KEY \"your-api-key\" (Windows)"; \
	fi

# Clean build artifacts
clean:
	@echo "Cleaning up..."
	rm -rf $(DIST_DIR)
	rm -f $(BINARY_NAME) $(BINARY_NAME).exe
	go clean

# Show help
help:
	@echo "Available targets:"
	@echo "  make compile    - Cross-compile for all supported platforms"
	@echo "  make install    - Build and install to the system (platform-specific)"
	@echo "  make clean      - Remove all build artifacts"
	@echo "  make help       - Show this help message"
	@echo ""
	@echo "Individual platform targets:"
	@echo "  make linux-amd64"
	@echo "  make linux-arm64"
	@echo "  make darwin-amd64"
	@echo "  make darwin-arm64"
	@echo "  make windows-amd64" 