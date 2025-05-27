#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Repository URL
REPO_URL="https://raw.githubusercontent.com/mnofresno/convcommitgpt/main"
IMAGE_NAME="ghcr.io/mnofresno/convcommitgpt:latest"

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
    elif command_exists podman; then
        CONTAINER_CMD="podman"
    else
        print_message "Error: Neither Docker nor Podman is installed" "$RED"
        exit 1
    fi
}

# Function to create necessary directories
create_directories() {
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
        read -p "Enter the Ollama base URL (default: http://host.docker.internal:11434/v1): " base_url
        read -p "Enter the model name (default: qwen3:8b): " model

        base_url=${base_url:-"http://host.docker.internal:11434/v1"}
        model=${model:-"qwen3:8b"}

        cat > ~/.local/lib/convcommitgpt/.env << EOF
BASE_URL=${base_url}
MODEL=${model}
EOF
    fi
}

# Function to download files
download_files() {
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
        curl -sSL "${REPO_URL}/${file}" -o "${file}"
    done
}

# Main installation process
main() {
    print_message "Starting convcommitgpt installation..." "$GREEN"

    # Check container runtime
    check_container_runtime

    # Create directories
    create_directories

    # Backup existing installation
    backup_existing

    # Copy files to installation directory
    print_message "Copying files..." "$YELLOW"
    cd /tmp
    download_files
    cp -r /tmp/*.py /tmp/*.txt /tmp/*.md /tmp/convcommit.sh ~/.local/lib/convcommitgpt/
    cd -

    # Set permissions
    chmod +x ~/.local/lib/convcommitgpt/convcommit.sh
    chmod +x ~/.local/bin/convcommit

    # Pull Docker image
    print_message "Pulling Docker image..." "$YELLOW"
    $CONTAINER_CMD pull $IMAGE_NAME
    $CONTAINER_CMD tag $IMAGE_NAME convcommitgpt:local

    # Create symlink to convcommit.sh
    ln -sf ~/.local/lib/convcommitgpt/convcommit.sh ~/.local/bin/convcommit

    # Setup configuration
    setup_configuration

    print_message "Installation completed successfully!" "$GREEN"
    print_message "You can now use 'convcommit' command" "$GREEN"
}

# Run main function
main 