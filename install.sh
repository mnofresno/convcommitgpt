#!/bin/bash

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

# Function to check Docker/Podman
check_container_runtime() {
    if command_exists docker; then
        CONTAINER_CMD="docker"
        print_message "Docker detected" "$GREEN"
        # Check if Docker daemon is running
        if ! docker info >/dev/null 2>&1; then
            print_message "Error: Docker daemon is not running" "$RED"
            print_message "Please start Docker and try again" "$YELLOW"
            exit 1
        fi
    elif command_exists podman; then
        CONTAINER_CMD="podman"
        print_message "Podman detected" "$GREEN"
        # Check if Podman daemon is running
        if ! podman info >/dev/null 2>&1; then
            print_message "Error: Podman daemon is not running" "$RED"
            print_message "Please start Podman and try again" "$YELLOW"
            exit 1
        fi
    else
        print_message "Error: Neither Docker nor Podman is installed" "$RED"
        print_message "Please install Docker or Podman first" "$YELLOW"
        exit 1
    fi
}

# Function to check Git
check_git() {
    if ! command_exists git; then
        print_message "Error: Git is not installed" "$RED"
        print_message "Please install Git first" "$YELLOW"
        exit 1
    fi
}

# Function to check Ollama
check_ollama() {
    if ! command_exists ollama; then
        print_message "Warning: Ollama is not installed" "$YELLOW"
        print_message "Please install Ollama from https://ollama.ai" "$YELLOW"
        print_message "After installation, run: ollama pull qwen3:8b" "$YELLOW"
    fi
}

# Function to create necessary directories
create_directories() {
    print_message "Creating necessary directories..." "$YELLOW"
    
    # Create ~/.local/bin if it doesn't exist
    if [ ! -d ~/.local/bin ]; then
        print_message "Creating ~/.local/bin directory..." "$YELLOW"
        mkdir -p ~/.local/bin
        chmod 755 ~/.local/bin
    fi
    
    # Create ~/.local/lib/convcommitgpt if it doesn't exist
    if [ ! -d ~/.local/lib/convcommitgpt ]; then
        print_message "Creating ~/.local/lib/convcommitgpt directory..." "$YELLOW"
        mkdir -p ~/.local/lib/convcommitgpt
        chmod 755 ~/.local/lib/convcommitgpt
    fi
    
    # Add ~/.local/bin to PATH if it's not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        print_message "Adding ~/.local/bin to PATH..." "$YELLOW"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
        export PATH="$HOME/.local/bin:$PATH"
    fi
}

# Function to backup existing installation
backup_existing() {
    if [ -f ~/.local/bin/convcommit ]; then
        print_message "Backing up existing installation..." "$YELLOW"
        mv ~/.local/bin/convcommit ~/.local/bin/convcommit.bak
    fi
    if [ -f ~/.local/lib/convcommitgpt/.env ]; then
        cp ~/.local/lib/convcommitgpt/.env ~/.local/lib/convcommitgpt/.env.bak
    fi
}

# Function to setup configuration
setup_configuration() {
    if [ ! -f ~/.local/lib/convcommitgpt/.env ]; then
        print_message "Setting up configuration..." "$YELLOW"
        read -p "Enter the Ollama base URL (default: http://localhost:11434/v1): " base_url
        read -p "Enter the model name (default: qwen3:8b): " model

        base_url=${base_url:-"http://localhost:11434/v1"}
        model=${model:-"qwen3:8b"}

        cat > ~/.local/lib/convcommitgpt/.env << EOF
BASE_URL=${base_url}
MODEL=${model}
EOF
    fi
}

# Function to download files
download_files() {
    print_message "Downloading files..." "$YELLOW"
    cd /tmp
    local files=(
        "convcommit.py"
        "assistant.py"
        "diff_generator.py"
        "runner.py"
        "spinner.py"
        "requirements.txt"
        "instructions_prompt.md"
        "convcommit.sh"
    )

    for file in "${files[@]}"; do
        if ! curl -sSL "https://raw.githubusercontent.com/mnofresno/convcommitgpt/main/${file}" -o "${file}"; then
            print_message "Error: Failed to download ${file}" "$RED"
            exit 1
        fi
    done

    print_message "Copying files to installation directory..." "$YELLOW"
    cp -r /tmp/*.py /tmp/*.txt /tmp/*.md /tmp/convcommit.sh ~/.local/lib/convcommitgpt/
    cd -
}

# Function to detect system architecture
detect_architecture() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            print_message "Error: Unsupported architecture: $arch" "$RED"
            exit 1
            ;;
    esac
}

# Function to setup container runtime
setup_container_runtime() {
    print_message "Setting up container runtime..." "$YELLOW"
    
    # Detect architecture
    local arch=$(detect_architecture)
    print_message "Detected architecture: $arch" "$GREEN"
    
    # Pull Docker image with architecture-specific tag
    print_message "Pulling container image for $arch..." "$YELLOW"
    if ! $CONTAINER_CMD pull "ghcr.io/mnofresno/convcommitgpt:latest-$arch"; then
        print_message "Error: Failed to pull container image for $arch" "$RED"
        exit 1
    fi

    # Tag image for local use
    if [[ "$CONTAINER_CMD" == "podman" ]]; then
        print_message "Tagging image for Podman..." "$YELLOW"
        $CONTAINER_CMD tag "ghcr.io/mnofresno/convcommitgpt:latest-$arch" localhost/convcommitgpt:latest
    fi
}

# Function to setup symlinks
setup_symlinks() {
    print_message "Setting up symlinks..." "$YELLOW"
    
    # Ensure directories exist
    create_directories
    
    # Verify source file exists
    if [ ! -f ~/.local/lib/convcommitgpt/convcommit.sh ]; then
        print_message "Error: Source file ~/.local/lib/convcommitgpt/convcommit.sh does not exist" "$RED"
        exit 1
    fi
    
    # Set permissions on source file
    print_message "Setting permissions on convcommit.sh..." "$YELLOW"
    chmod +x ~/.local/lib/convcommitgpt/convcommit.sh
    
    # Remove existing symlink if it exists
    if [ -L ~/.local/bin/convcommit ]; then
        print_message "Removing existing symlink..." "$YELLOW"
        rm ~/.local/bin/convcommit
    fi
    
    # Create new symlink
    print_message "Creating new symlink..." "$YELLOW"
    ln -sf ~/.local/lib/convcommitgpt/convcommit.sh ~/.local/bin/convcommit
    
    # Verify the symlink was created
    if [ ! -L ~/.local/bin/convcommit ]; then
        print_message "Error: Failed to create symlink" "$RED"
        exit 1
    fi
    
    # Verify the script is executable
    if [ ! -x ~/.local/lib/convcommitgpt/convcommit.sh ]; then
        print_message "Error: Failed to set executable permissions" "$RED"
        exit 1
    fi
    
    print_message "Symlink created successfully" "$GREEN"
}

# Main installation process
main() {
    print_message "Starting convcommitgpt installation..." "$GREEN"

    # Check dependencies
    check_container_runtime
    check_git
    check_ollama

    # Create directories
    create_directories

    # Backup existing installation
    backup_existing

    # Download and copy files
    download_files

    # Setup container runtime
    setup_container_runtime

    # Setup configuration
    setup_configuration

    # Setup symlinks and permissions
    setup_symlinks

    print_message "Installation completed successfully!" "$GREEN"
    print_message "You can now use 'convcommit' command" "$GREEN"
    print_message "Make sure Ollama is running with: ollama serve" "$YELLOW"
    print_message "And the model is pulled with: ollama pull qwen3:8b" "$YELLOW"
    
    # Print PATH information
    print_message "Note: You may need to restart your terminal or run 'source ~/.bashrc' (or 'source ~/.zshrc') to update your PATH" "$YELLOW"
    
    # Print verification information
    print_message "Verifying installation..." "$YELLOW"
    if [ -L ~/.local/bin/convcommit ]; then
        print_message "✓ Symlink exists" "$GREEN"
    else
        print_message "✗ Symlink does not exist" "$RED"
    fi
    
    if [ -x ~/.local/lib/convcommitgpt/convcommit.sh ]; then
        print_message "✓ Script is executable" "$GREEN"
    else
        print_message "✗ Script is not executable" "$RED"
    fi
    
    if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
        print_message "✓ ~/.local/bin is in PATH" "$GREEN"
    else
        print_message "✗ ~/.local/bin is not in PATH" "$RED"
    fi
}

# Run main function
main 