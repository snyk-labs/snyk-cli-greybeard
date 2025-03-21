#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Repository information
REPO="snyk-labs/snyk-cli-greybeard"
BINARY_NAME="greybeard"

echo -e "${BLUE}Snyk CLI Greybeard Installer${NC}"
echo "This script will install the latest version of ${BINARY_NAME}"
echo ""

# Detect OS and architecture
detect_os_arch() {
    # Detect OS
    OS="unknown"
    ARCH="unknown"
    
    case "$(uname -s)" in
        Linux*)     OS="linux";;
        Darwin*)    OS="darwin";;
        MINGW*|MSYS*|CYGWIN*) 
            OS="windows"
            BINARY_NAME="${BINARY_NAME}.exe"
            ;;
        *)          OS="unknown";;
    esac
    
    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64)  ARCH="amd64";;
        arm64|aarch64) ARCH="arm64";;
        *)             ARCH="unknown";;
    esac
    
    if [ "$OS" = "unknown" ] || [ "$ARCH" = "unknown" ]; then
        echo -e "${RED}Error: Unsupported operating system or architecture.${NC}"
        echo "OS: $(uname -s), Arch: $(uname -m)"
        exit 1
    fi
    
    echo -e "Detected ${GREEN}$OS${NC} on ${GREEN}$ARCH${NC}"
}

# Get the latest release info from GitHub
get_latest_release() {
    if command -v curl &> /dev/null; then
        LATEST_RELEASE=$(curl -s "https://api.github.com/repos/$REPO/releases/latest")
    elif command -v wget &> /dev/null; then
        LATEST_RELEASE=$(wget -qO- "https://api.github.com/repos/$REPO/releases/latest")
    else
        echo -e "${RED}Error: Neither curl nor wget found. Please install one of them and try again.${NC}"
        exit 1
    fi
    
    # Check if the release exists (non-empty response and no error message)
    if [ -z "$LATEST_RELEASE" ] || echo "$LATEST_RELEASE" | grep -q "API rate limit exceeded" || echo "$LATEST_RELEASE" | grep -q "\"message\":"; then
        echo -e "${YELLOW}Warning: No releases found or API error. Falling back to latest code from main branch.${NC}"
        USE_MAIN_BRANCH=true
        VERSION="main"
    else
        # Extract version number
        VERSION=$(echo "$LATEST_RELEASE" | grep -o '"tag_name": *"[^"]*"' | grep -o '[^"]*$')
        
        if [ -z "$VERSION" ]; then
            echo -e "${YELLOW}Warning: Could not determine the latest version. Falling back to main branch.${NC}"
            USE_MAIN_BRANCH=true
            VERSION="main"
        else
            USE_MAIN_BRANCH=false
            echo -e "Latest version: ${GREEN}$VERSION${NC}"
        fi
    fi
}

# Build from source if no releases are available
build_from_source() {
    echo -e "${YELLOW}No pre-built binaries available. Building from source...${NC}"
    
    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        echo -e "${RED}Error: Go is not installed, which is required to build from source.${NC}"
        echo "Please install Go (https://golang.org/doc/install) or wait for official releases."
        exit 1
    fi
    
    # Create a temporary directory
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    echo "Cloning repository..."
    if command -v git &> /dev/null; then
        git clone --depth 1 "https://github.com/$REPO.git" .
    else
        echo -e "${RED}Error: git is not installed, which is required to clone the repository.${NC}"
        exit 1
    fi
    
    echo "Building binary..."
    GOOS=$OS GOARCH=$ARCH go build -o "$BINARY_NAME"
    
    if [ ! -f "$BINARY_NAME" ]; then
        echo -e "${RED}Error: Failed to build binary.${NC}"
        exit 1
    fi
    
    TMP_FILE="$TMP_DIR/$BINARY_NAME"
    chmod +x "$TMP_FILE"
    echo -e "${GREEN}Build successful!${NC}"
}

# Download the binary
download_binary() {
    if [ "$USE_MAIN_BRANCH" = true ]; then
        build_from_source
        return
    fi
    
    BINARY_URL=""
    ASSET_NAME="${BINARY_NAME}-$OS-$ARCH"
    
    if [ "$OS" = "windows" ]; then
        ASSET_NAME="${BINARY_NAME}-$OS-$ARCH.exe"
    fi
    
    if command -v jq &> /dev/null; then
        # Get download URL using jq (more reliable)
        BINARY_URL=$(echo "$LATEST_RELEASE" | jq -r ".assets[] | select(.name == \"$ASSET_NAME\") | .browser_download_url")
    else
        # Extract the section containing our asset and look for browser_download_url
        # This handles the case where URLs contain newlines
        ASSET_SECTION=$(echo "$LATEST_RELEASE" | grep -A 30 "\"name\": \"$ASSET_NAME\"")
        URL_LINE=$(echo "$ASSET_SECTION" | grep "browser_download_url")
        if [ -n "$URL_LINE" ]; then
            # Extract the URL part and fix potential newlines
            BINARY_URL=$(echo "$URL_LINE" | grep -o "https://[^\"]*" | tr -d '\n\r')
        fi
    fi
    
    if [ -z "$BINARY_URL" ]; then
        # Direct construction of the URL as a fallback
        if [ -n "$VERSION" ] && [ "$VERSION" != "main" ]; then
            # Try to construct the URL directly
            BINARY_URL="https://github.com/$REPO/releases/download/$VERSION/$ASSET_NAME"
            echo -e "${YELLOW}Directly constructed URL: $BINARY_URL${NC}"
            
            # Verify this URL exists
            if command -v curl &> /dev/null; then
                HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L -I "$BINARY_URL")
            elif command -v wget &> /dev/null; then
                HTTP_CODE=$(wget --spider -S "$BINARY_URL" 2>&1 | grep "HTTP/" | awk '{print $2}' | tail -1)
            else
                HTTP_CODE="404" # Just assume failure if we can't check
            fi
            
            if [[ "$HTTP_CODE" == "404" ]]; then
                BINARY_URL=""
            fi
        fi
    fi
    
    if [ -z "$BINARY_URL" ]; then
        echo -e "${YELLOW}Warning: Could not find download URL for $ASSET_NAME. Falling back to building from source.${NC}"
        # For debugging
        echo "Debug info:"
        echo "OS: $OS, ARCH: $ARCH, ASSET_NAME: $ASSET_NAME"
        echo "Available assets:"
        echo "$LATEST_RELEASE" | grep -o "\"name\":\"[^\"]*\"" | grep -o "[^\"]*$" | grep -v "tag_name\|name\|target_commitish"
        build_from_source
        return
    fi
    
    echo "Downloading ${BLUE}$ASSET_NAME${NC} from ${BLUE}$BINARY_URL${NC}"
    
    # Create temporary directory
    TMP_DIR=$(mktemp -d)
    TMP_FILE="$TMP_DIR/$ASSET_NAME"
    
    # Download the binary
    if command -v curl &> /dev/null; then
        curl -L -s "$BINARY_URL" -o "$TMP_FILE"
    elif command -v wget &> /dev/null; then
        wget -q "$BINARY_URL" -O "$TMP_FILE"
    fi
    
    if [ ! -f "$TMP_FILE" ]; then
        echo -e "${RED}Error: Failed to download binary.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Download successful!${NC}"
    
    # Make binary executable
    chmod +x "$TMP_FILE"
}

# Install the binary
install_binary() {
    INSTALL_DIR=""
    
    # Determine install location based on OS
    if [ "$OS" = "windows" ]; then
        # Windows: Create directory in AppData if it doesn't exist
        INSTALL_DIR="$APPDATA/snyk-cli-greybeard"
        mkdir -p "$INSTALL_DIR"
    else
        # Linux/macOS: Check for standard directories
        for dir in "/usr/local/bin" "$HOME/.local/bin" "$HOME/bin"; do
            if [ -d "$dir" ] && [ -w "$dir" ]; then
                INSTALL_DIR="$dir"
                break
            fi
        done
        
        # If no writable directory found, use ~/.local/bin and create it if needed
        if [ -z "$INSTALL_DIR" ]; then
            INSTALL_DIR="$HOME/.local/bin"
            mkdir -p "$INSTALL_DIR"
            echo -e "${YELLOW}No writable standard binary directories found. Creating $INSTALL_DIR${NC}"
        fi
    fi
    
    DEST_PATH="$INSTALL_DIR/$BINARY_NAME"
    if [ "$OS" = "windows" ]; then
        DEST_PATH="$INSTALL_DIR/$BINARY_NAME.exe"
    fi
    
    # Copy binary to installation directory
    cp "$TMP_FILE" "$DEST_PATH"
    
    echo -e "${GREEN}Successfully installed $BINARY_NAME to $DEST_PATH${NC}"
    
    # Clean up temporary directory
    rm -rf "$TMP_DIR"
    
    # Add installation directory to PATH if needed
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        if [ "$OS" = "windows" ]; then
            echo -e "${YELLOW}Please add $INSTALL_DIR to your PATH:${NC}"
            echo "setx PATH \"%PATH%;$INSTALL_DIR\""
        else
            echo -e "${YELLOW}Please add $INSTALL_DIR to your PATH if it's not already there:${NC}"
            echo "export PATH=\"\$PATH:$INSTALL_DIR\""
            echo "You may want to add this line to your .bashrc, .zshrc, or equivalent file."
        fi
    fi
}

# Check for dependencies
check_dependencies() {
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        echo -e "${RED}Error: Neither curl nor wget is installed. Please install one of them and try again.${NC}"
        exit 1
    fi
}

remind_openai_key() {
    echo -e "\n${YELLOW}IMPORTANT: Don't forget to set your OpenAI API key:${NC}"
    if [ "$OS" = "windows" ]; then
        echo "setx OPENAI_API_KEY \"your-api-key\""
    else
        echo "export OPENAI_API_KEY='your-api-key'"
        echo "You may want to add this to your .bashrc, .zshrc, or equivalent file."
    fi
}

# Main installation process
main() {
    check_dependencies
    detect_os_arch
    get_latest_release
    download_binary
    install_binary
    remind_openai_key
    
    echo -e "\n${GREEN}Installation complete!${NC}"
    echo -e "You can now run '${BLUE}$BINARY_NAME${NC}' from the command line."
}

main 