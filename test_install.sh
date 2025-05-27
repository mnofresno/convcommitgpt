#!/bin/bash

# Change to script directory
cd "$(dirname "$0")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to print colored messages
print_message() {
    echo -e "${2}${1}${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check sudo permissions
check_sudo() {
    print_message "Checking sudo permissions..." "$YELLOW"
    if ! sudo -v; then
        print_message "Error: This script requires sudo permissions to install convcommitgpt" "$RED"
        print_message "Please run the script with sudo or ensure you have the necessary permissions" "$RED"
        exit 1
    fi
    # Keep sudo session alive
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" 2>/dev/null || exit
    done &
}

# Function to check container runtime
check_container_runtime() {
    print_message "Checking container runtime..." "$YELLOW"
    
    # Check if docker exists and is authenticated
    if command_exists docker; then
        if docker login ghcr.io >/dev/null 2>&1; then
            CONTAINER_CMD="docker"
            print_message "Using Docker as container runtime" "$GREEN"
            return 0
        fi
    fi
    
    # If docker is not available or not authenticated, try podman
    if command_exists podman; then
        CONTAINER_CMD="podman"
        print_message "Using Podman as container runtime" "$GREEN"
        return 0
    fi
    
    print_message "Error: Neither Docker nor Podman is installed" "$RED"
    print_message "Please install either Docker (https://docs.docker.com/get-docker/) or Podman (https://podman.io/getting-started/installation)" "$RED"
    exit 1
}

# Function to create temporary directory
create_temp_dir() {
    TEMP_DIR=$(mktemp -d)
    print_message "Created temporary directory: $TEMP_DIR" "$GREEN"
}

# Function to update progress bar
update_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    printf "\r[%-${width}s] %d%%" "$(printf '#%.0s' $(seq 1 $completed))$(printf ' %.0s' $(seq 1 $remaining))" $percentage
}

# Function to copy files to temp directory with progress
copy_files() {
    print_message "Copying files to temporary directory..." "$YELLOW"
    
    # Essential files to copy
    essential_files=(
        "convcommit.py"
        "assistant.py"
        "diff_generator.py"
        "runner.py"
        "spinner.py"
        "instructions_prompt.md"
        "requirements.txt"
        "convcommit.sh"
    )
    
    # Create directories
    mkdir -p "$TEMP_DIR"
    
    # Copy essential files
    total=${#essential_files[@]}
    current=0
    for file in "${essential_files[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$TEMP_DIR/"
            current=$((current + 1))
            update_progress $current $total
        else
            print_message "Warning: $file was not found" "$YELLOW"
        fi
    done
    echo
    
    # Verify requirements.txt was copied and has content
    if [ ! -f "$TEMP_DIR/requirements.txt" ]; then
        print_message "Error: requirements.txt was not found" "$RED"
        exit 1
    fi
    
    if [ ! -s "$TEMP_DIR/requirements.txt" ]; then
        print_message "Error: requirements.txt is empty" "$RED"
        exit 1
    fi
    
    # Show requirements.txt contents for debugging
    print_message "Contents of requirements.txt:" "$YELLOW"
    cat "$TEMP_DIR/requirements.txt"
    
    print_message "Files copied successfully!" "$GREEN"
}

# Function to detect host architecture
detect_architecture() {
    case "$(uname -m)" in
        "x86_64")
            echo "linux/amd64"
            ;;
        "arm64"|"aarch64")
            echo "linux/arm64"
            ;;
        *)
            echo "Error: Unsupported architecture $(uname -m)"
            exit 1
            ;;
    esac
}

# Function to run installation
run_installation() {
    print_message "Running installation..." "$YELLOW"
    
    # Get host architecture
    ARCH=$(detect_architecture)
    
    # Pull the pre-built image
    print_message "Pulling Docker image..." "$YELLOW"
    if ! $CONTAINER_CMD pull ghcr.io/mnofresno/convcommitgpt:latest; then
        print_message "Error: Failed to pull Docker image" "$RED"
        exit 1
    fi
    
    # Create config directory if it doesn't exist
    mkdir -p "$HOME/.config/convcommitgpt"
    
    # Copy .env file if it exists
    if [ -f ".env" ]; then
        print_message "Copying .env file to config directory..." "$YELLOW"
        cp ".env" "$HOME/.config/convcommitgpt/"
    else
        print_message "Warning: .env file not found" "$YELLOW"
        print_message "You may need to create one at $HOME/.config/convcommitgpt/.env" "$YELLOW"
    fi
    
    # Create bin directory if it doesn't exist
    mkdir -p "$HOME/.local/bin"
    
    # Create lib directory for the application
    mkdir -p "$HOME/.local/lib/convcommitgpt"
    
    # Copy application files to lib directory
    print_message "Copying application files..." "$YELLOW"
    cp -r "$TEMP_DIR"/* "$HOME/.local/lib/convcommitgpt/"
    
    # Create symlink to convcommit.sh
    print_message "Creating symlink to convcommit.sh" "$YELLOW"
    ln -sf "$HOME/.local/lib/convcommitgpt/convcommit.sh" "$HOME/.local/bin/convcommit"
    
    # Add ~/.local/bin to PATH if not already present
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        print_message "Adding ~/.local/bin to PATH" "$YELLOW"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    fi
    
    print_message "Installation completed successfully!" "$GREEN"
    print_message "You can now use the 'convcommit' command" "$GREEN"
    print_message "Please restart your terminal or run 'source ~/.bashrc' (or 'source ~/.zshrc') to update your PATH" "$YELLOW"
}

# Function to clean up
cleanup() {
    print_message "Cleaning up temporary directory..." "$YELLOW"
    rm -rf "$TEMP_DIR"
}

# Main execution
print_message "Starting test installation..." "$GREEN"

# Check sudo permissions
check_sudo

# Check container runtime
check_container_runtime

# Create temporary directory
create_temp_dir

# Copy files
copy_files

# Run installation
run_installation

# Clean up
cleanup

print_message "Test installation completed!" "$GREEN"
print_message "You can now test the 'convcommit' command" "$GREEN"
print_message "To uninstall, run: sudo ./uninstall.sh" "$YELLOW" 