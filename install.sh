#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Repository information
REPO="snyk-labs/snyk-cli-greybeard"
BINARY_NAME="greybeard"

# Output formatters
ohai() {
    printf "${BLUE}==>${BOLD} %s${NC}\n" "$1"
}

warn() {
    printf "${YELLOW}Warning${NC}: %s\n" "$1" >&2
}

error() {
    printf "${RED}Error${NC}: %s\n" "$1" >&2
    exit 1
}

ohai "Snyk CLI Greybeard Installer"
echo "This script will install the latest version of ${BINARY_NAME}"
echo ""

# Check for required commands
check_command() {
    if ! command -v "$1" &> /dev/null; then
        if [ -n "$2" ]; then
            warn "$2"
        else
            warn "$1 is required but not found"
        fi
        return 1
    fi
    return 0
}

# Detect OS and architecture
detect_platform() {
    ohai "Detecting platform"
    
    # Detect OS
    OS="unknown"
    ARCH="unknown"
    
    case "$(uname -s)" in
        Linux*)     OS="linux";;
        Darwin*)    OS="darwin";;
        MINGW*|MSYS*|CYGWIN*) 
            OS="windows"
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
        error "Unsupported operating system or architecture: $(uname -s), $(uname -m)"
    fi
    
    echo -e "Detected ${GREEN}$OS${NC} on ${GREEN}$ARCH${NC}"
}

# Get the latest release version
get_latest_version() {
    ohai "Fetching latest release information"
    
    # Choose download command (curl or wget)
    if command -v curl &> /dev/null; then
        echo "Using curl to fetch release information"
        
        # Create temp file for release info
        local temp_file=$(mktemp)
        
        # Fetch the release information with curl
        if curl -s -L "https://api.github.com/repos/${REPO}/releases/latest" -o "$temp_file"; then
            # Successfully fetched release info
            if command -v jq &> /dev/null; then
                VERSION=$(jq -r .tag_name "$temp_file")
            else
                VERSION=$(grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$temp_file" | sed -E 's/"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)"/\1/')
            fi
            rm -f "$temp_file"
        else
            rm -f "$temp_file"
            warn "Failed to fetch release information. Using v1.0.0 as fallback."
            VERSION="v1.0.0"
        fi
    elif command -v wget &> /dev/null; then
        echo "Using wget to fetch release information"
        
        # Create temp file for release info
        local temp_file=$(mktemp)
        
        # Fetch the release information with wget
        if wget -q -O "$temp_file" "https://api.github.com/repos/${REPO}/releases/latest"; then
            # Successfully fetched release info
            if command -v jq &> /dev/null; then
                VERSION=$(jq -r .tag_name "$temp_file")
            else
                VERSION=$(grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$temp_file" | sed -E 's/"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)"/\1/')
            fi
            rm -f "$temp_file"
        else
            rm -f "$temp_file"
            warn "Failed to fetch release information. Using v1.0.0 as fallback."
            VERSION="v1.0.0"
        fi
    else
        error "Neither curl nor wget found. Please install one of them and try again."
    fi
    
    if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
        warn "Could not determine latest version. Using v1.0.0 as fallback."
        VERSION="v1.0.0"
    else
        echo -e "Latest version: ${GREEN}$VERSION${NC}"
    fi
}

# Download and install binary
install_binary() {
    ohai "Preparing to install ${BINARY_NAME} ${VERSION}"
    
    # Determine binary name and URL
    if [ "$OS" = "windows" ]; then
        ASSET_NAME="${BINARY_NAME}-${OS}-${ARCH}.exe"
    else
        ASSET_NAME="${BINARY_NAME}-${OS}-${ARCH}"
    fi
    
    DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET_NAME}"
    
    printf "Downloading ${BLUE}%s${NC} from:\n" "${ASSET_NAME}"
    echo "${DOWNLOAD_URL}"
    
    # Create temporary directory
    TMP_DIR=$(mktemp -d)
    TMP_FILE="${TMP_DIR}/${ASSET_NAME}"
    
    # Download binary
    echo "Downloading binary to ${TMP_FILE}"
    
    if command -v curl &> /dev/null; then
        echo "Using curl to download binary"
        # Try up to 3 times with curl
        local attempts=0
        local max_attempts=3
        local success=false
        
        while [ $attempts -lt $max_attempts ] && [ "$success" = "false" ]; do
            if curl -s -L -o "${TMP_FILE}" "${DOWNLOAD_URL}"; then
                success=true
            else
                attempts=$((attempts + 1))
                if [ $attempts -lt $max_attempts ]; then
                    wait_time=$((2 ** (attempts - 1)))
                    warn "Download failed, retrying in ${wait_time} seconds... (Attempt ${attempts}/${max_attempts})"
                    sleep $wait_time
                fi
            fi
        done
        
        if [ "$success" = "false" ]; then
            rm -rf "${TMP_DIR}"
            error "Failed to download binary from ${DOWNLOAD_URL} after ${max_attempts} attempts"
        fi
    elif command -v wget &> /dev/null; then
        echo "Using wget to download binary"
        # Try up to 3 times with wget
        local attempts=0
        local max_attempts=3
        local success=false
        
        while [ $attempts -lt $max_attempts ] && [ "$success" = "false" ]; do
            if wget -q -O "${TMP_FILE}" "${DOWNLOAD_URL}"; then
                success=true
            else
                attempts=$((attempts + 1))
                if [ $attempts -lt $max_attempts ]; then
                    wait_time=$((2 ** (attempts - 1)))
                    warn "Download failed, retrying in ${wait_time} seconds... (Attempt ${attempts}/${max_attempts})"
                    sleep $wait_time
                fi
            fi
        done
        
        if [ "$success" = "false" ]; then
            rm -rf "${TMP_DIR}"
            error "Failed to download binary from ${DOWNLOAD_URL} after ${max_attempts} attempts"
        fi
    else
        rm -rf "${TMP_DIR}"
        error "Neither curl nor wget found. Please install one of them and try again."
    fi
    
    if [ ! -f "${TMP_FILE}" ]; then
        rm -rf "${TMP_DIR}"
        error "Downloaded file not found at ${TMP_FILE}"
    fi
    
    # Make binary executable
    chmod +x "${TMP_FILE}"
    
    ohai "Installing ${BINARY_NAME}"
    
    # Install binary
    INSTALL_DIR=""
    
    if [ "$OS" = "windows" ]; then
        INSTALL_DIR="$APPDATA/snyk-cli-greybeard"
        mkdir -p "$INSTALL_DIR"
    else
        for dir in "/usr/local/bin" "$HOME/.local/bin" "$HOME/bin"; do
            if [ -d "$dir" ] && [ -w "$dir" ]; then
                INSTALL_DIR="$dir"
                break
            fi
        done
        
        if [ -z "$INSTALL_DIR" ]; then
            INSTALL_DIR="$HOME/.local/bin"
            mkdir -p "$INSTALL_DIR"
        fi
    fi
    
    if [ "$OS" = "windows" ]; then
        DEST_PATH="$INSTALL_DIR/${BINARY_NAME}.exe"
    else
        DEST_PATH="$INSTALL_DIR/${BINARY_NAME}"
    fi
    
    cp "${TMP_FILE}" "${DEST_PATH}"
    echo -e "${GREEN}Successfully installed ${BINARY_NAME} to ${DEST_PATH}${NC}"
    
    # Clean up
    rm -rf "${TMP_DIR}"
    
    # Remind about PATH if needed
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        warn "Please add $INSTALL_DIR to your PATH if it's not already there:"
        if [ "$OS" = "windows" ]; then
            echo "setx PATH \"%PATH%;$INSTALL_DIR\""
        else
            echo "export PATH=\"\$PATH:$INSTALL_DIR\""
        fi
    fi
    
    # Remind about OpenAI API key
    echo -e "\n${YELLOW}IMPORTANT${NC}: Don't forget to set your OpenAI API key:"
    if [ "$OS" = "windows" ]; then
        echo "setx OPENAI_API_KEY \"your-api-key\""
    else
        echo "export OPENAI_API_KEY='your-api-key'"
    fi
}

# Main installation process
main() {
    detect_platform
    get_latest_version
    install_binary
    
    ohai "Installation complete!"
    echo -e "You can now run '${BLUE}${BINARY_NAME}${NC}' from the command line."
}

main

# Windows PowerShell/CMD detection (outside of MINGW/MSYS/Cygwin)
# This check must happen after OS is defined in detect_platform
if [[ -z "${BASH_VERSION}" ]] && [[ "$OS" = "windows" ]]; then
  warn "This script requires Bash. On Windows, please use Git Bash, WSL, or similar."
  exit 1
fi 