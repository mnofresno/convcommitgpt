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
    mkdir -p ~/.local/bin
    mkdir -p ~/.local/lib/convcommitgpt
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

    cp -r /tmp/*.py /tmp/*.txt /tmp/*.md /tmp/convcommit.sh ~/.local/lib/convcommitgpt/
    cd -
}

# Function to setup container runtime
setup_container_runtime() {
    print_message "Setting up container runtime..." "$YELLOW"
    
    # Pull Docker image
    print_message "Pulling container image..." "$YELLOW"
    if ! $CONTAINER_CMD pull ghcr.io/mnofresno/convcommitgpt:latest; then
        print_message "Error: Failed to pull container image" "$RED"
        exit 1
    fi

    # Tag image for local use
    if [[ "$CONTAINER_CMD" == "podman" ]]; then
        print_message "Tagging image for Podman..." "$YELLOW"
        $CONTAINER_CMD tag ghcr.io/mnofresno/convcommitgpt:latest localhost/convcommitgpt:latest
    fi
}

# Function to setup symlinks
setup_symlinks() {
    print_message "Setting up symlinks..." "$YELLOW"
    # Create symlink to convcommit.sh
    ln -sf ~/.local/lib/convcommitgpt/convcommit.sh ~/.local/bin/convcommit
    # Set permissions
    chmod +x ~/.local/lib/convcommitgpt/convcommit.sh
    chmod +x ~/.local/bin/convcommit
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
}

# Run main function
main 