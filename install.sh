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
    echo "Fetching release info from GitHub API..."
    
    if command -v curl &> /dev/null; then
        echo "Using curl to fetch GitHub API data"
        LATEST_RELEASE=$(curl -s "https://api.github.com/repos/$REPO/releases/latest")
    elif command -v wget &> /dev/null; then
        echo "Using wget to fetch GitHub API data"
        LATEST_RELEASE=$(wget -qO- "https://api.github.com/repos/$REPO/releases/latest")
    else
        echo -e "${RED}Error: Neither curl nor wget found. Please install one of them and try again.${NC}"
        exit 1
    fi
    
    # Verify we got a valid response (not empty and no error message)
    if [ -z "$LATEST_RELEASE" ]; then
        echo -e "${YELLOW}Warning: Empty response when fetching latest release. Falling back to main branch.${NC}"
        USE_MAIN_BRANCH=true
        VERSION="main"
        return
    fi
    
    # Check for API errors
    if echo "$LATEST_RELEASE" | grep -q "API rate limit exceeded" || echo "$LATEST_RELEASE" | grep -q "\"message\":" || echo "$LATEST_RELEASE" | grep -q "Not Found"; then
        echo -e "${YELLOW}Warning: GitHub API error or no releases found. Falling back to main branch.${NC}"
        echo -e "API Response: $(echo "$LATEST_RELEASE" | grep -o "\"message\":\"[^\"]*\"" | head -1)"
        USE_MAIN_BRANCH=true
        VERSION="main"
        return
    fi
    
    # Most reliable approach: Use jq if available
    if command -v jq &> /dev/null; then
        echo "Using jq to extract version"
        VERSION=$(echo "$LATEST_RELEASE" | jq -r '.tag_name // ""')
        if [ -n "$VERSION" ]; then
            echo "Found version using jq: $VERSION"
        fi
    fi
    
    # Fallback: Use sed patterns if jq failed or isn't available
    if [ -z "$VERSION" ]; then
        echo "Using sed to extract version"
        # Convert all newlines to spaces to handle multi-line JSON
        LATEST_RELEASE_CLEAN=$(echo "$LATEST_RELEASE" | tr '\n' ' ')
        
        # Simple fix: Grep for exact tag_name pattern with spaces after colon
        VERSION=$(echo "$LATEST_RELEASE_CLEAN" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
        
        if [ -z "$VERSION" ]; then
            # Try alternative pattern without spaces
            VERSION=$(echo "$LATEST_RELEASE_CLEAN" | sed -n 's/.*"tag_name":"\([^"]*\)".*/\1/p' | head -1)
        fi
    fi
    
    if [ -z "$VERSION" ]; then
        echo -e "${YELLOW}Warning: Could not determine the latest version. Falling back to main branch.${NC}"
        USE_MAIN_BRANCH=true
        VERSION="main"
    else
        USE_MAIN_BRANCH=false
        echo -e "Latest version: ${GREEN}$VERSION${NC}"
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
    
    # Set platform-specific binary name
    BINARY_URL=""
    ASSET_NAME="${BINARY_NAME}-$OS-$ARCH"
    
    if [ "$OS" = "windows" ]; then
        ASSET_NAME="${BINARY_NAME}-$OS-$ARCH.exe"
    fi
    
    # Direct URL override for debugging
    if [ -n "$DEBUG_URL" ]; then
        echo "DEBUG: Using direct URL: $DEBUG_URL"
        BINARY_URL="$DEBUG_URL"
    else
        echo "Looking for asset: ${BLUE}$ASSET_NAME${NC}"
        
        # Directly construct the download URL using the version (tag_name)
        # This is the most reliable method
        if [ -n "$VERSION" ] && [ "$VERSION" != "main" ]; then
            DIRECT_URL="https://github.com/$REPO/releases/download/$VERSION/$ASSET_NAME"
            echo "Using version $VERSION to create URL: $DIRECT_URL"
            
            # Verify this URL exists
            if command -v curl &> /dev/null; then
                HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L -I "$DIRECT_URL")
            elif command -v wget &> /dev/null; then
                HTTP_CODE=$(wget --spider -S "$DIRECT_URL" 2>&1 | grep "HTTP/" | awk '{print $2}' | tail -1)
            else
                HTTP_CODE="404" # Just assume failure if we can't check
            fi
            
            echo "HTTP status for direct URL: $HTTP_CODE"
            if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "302" ]]; then
                BINARY_URL="$DIRECT_URL"
                echo "URL is valid: $BINARY_URL"
            else 
                echo "URL returned status $HTTP_CODE"
            fi
        fi
    fi
    
    if [ -z "$BINARY_URL" ]; then
        echo -e "${YELLOW}Warning: Could not find download URL for $ASSET_NAME. Falling back to building from source.${NC}"
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
    
    if [ ! -f "$TMP_FILE" ] || [ ! -s "$TMP_FILE" ]; then
        echo -e "${RED}Error: Failed to download binary or file is empty.${NC}"
        echo "Falling back to building from source..."
        build_from_source
        return
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
    echo -e "${BLUE}===== Installation Started =====${NC}"
    check_dependencies
    detect_os_arch
    
    # Direct version override for debugging
    if [ -n "$DEBUG_VERSION" ]; then
        echo "DEBUG: Using hard-coded version: $DEBUG_VERSION"
        VERSION="$DEBUG_VERSION"
        USE_MAIN_BRANCH=false
    else
        echo -e "${BLUE}===== Fetching Latest Release =====${NC}"
        get_latest_release
    fi
    
    echo -e "${BLUE}===== Preparing Binary =====${NC}"
    download_binary
    
    echo -e "${BLUE}===== Installing Binary =====${NC}"
    install_binary
    
    echo -e "${BLUE}===== Finalizing Installation =====${NC}"
    remind_openai_key
    
    echo -e "\n${GREEN}Installation complete!${NC}"
    echo -e "You can now run '${BLUE}$BINARY_NAME${NC}' from the command line."
}

# If being sourced, don't run main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Allow overriding the version for testing
    if [ "$1" = "--version" ] && [ -n "$2" ]; then
        DEBUG_VERSION="$2"
        echo "DEBUG: Will use version $DEBUG_VERSION"
    fi
    
    # Allow overriding the download URL for testing
    if [ "$1" = "--url" ] && [ -n "$2" ]; then
        DEBUG_URL="$2"
        echo "DEBUG: Will download directly from $DEBUG_URL"
    fi
    
    # Allow directly specifying a version for an already released version
    if [ "$1" = "--use-release" ] && [ -n "$2" ]; then
        VERSION="$2"
        USE_MAIN_BRANCH=false
        DEBUG_URL="https://github.com/$REPO/releases/download/$VERSION/${BINARY_NAME}-$OS-$ARCH"
        if [ "$OS" = "windows" ]; then
            DEBUG_URL="${DEBUG_URL}.exe"
        fi
        echo "DEBUG: Will use version $VERSION with URL $DEBUG_URL"
    fi
    
    main
fi 