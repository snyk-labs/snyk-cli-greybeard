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
    
    if [ -z "$LATEST_RELEASE" ]; then
        echo -e "${RED}Error: Failed to fetch latest release information.${NC}"
        exit 1
    fi
    
    # Extract version number
    VERSION=$(echo "$LATEST_RELEASE" | grep -o '"tag_name": *"[^"]*"' | grep -o '[^"]*$')
    
    if [ -z "$VERSION" ]; then
        echo -e "${RED}Error: Could not determine the latest version.${NC}"
        exit 1
    fi
    
    echo -e "Latest version: ${GREEN}$VERSION${NC}"
}

# Download the binary
download_binary() {
    BINARY_URL=""
    ASSET_NAME="${BINARY_NAME}-$OS-$ARCH"
    
    if [ "$OS" = "windows" ]; then
        ASSET_NAME="${BINARY_NAME}-$OS-$ARCH.exe"
    fi
    
    if command -v jq &> /dev/null; then
        # Get download URL using jq (more reliable)
        BINARY_URL=$(echo "$LATEST_RELEASE" | jq -r ".assets[] | select(.name == \"$ASSET_NAME\") | .browser_download_url")
    else
        # Fallback to grep/sed if jq is not available
        BINARY_URL=$(echo "$LATEST_RELEASE" | grep -o "\"browser_download_url\":\"[^\"]*$ASSET_NAME\"" | grep -o "https://[^\"]*")
    fi
    
    if [ -z "$BINARY_URL" ]; then
        echo -e "${RED}Error: Could not find download URL for $ASSET_NAME${NC}"
        exit 1
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