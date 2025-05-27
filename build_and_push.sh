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

# Check for required tools
check_requirements() {
    print_message "Checking requirements..." "$YELLOW"
    
    if ! command_exists docker; then
        print_message "Error: Docker is not installed" "$RED"
        exit 1
    fi
    
    if ! command_exists docker buildx; then
        print_message "Error: Docker Buildx is not installed" "$RED"
        print_message "Please enable Buildx in Docker Desktop or install it manually" "$RED"
        exit 1
    fi
}

# Create and use a new builder instance
setup_builder() {
    print_message "Setting up Docker Buildx..." "$YELLOW"
    
    # Remove existing builder if it exists
    docker buildx rm multiarch-builder 2>/dev/null || true
    
    # Create a new builder instance with qemu support
    docker buildx create --name multiarch-builder --driver docker-container --use
    
    # Start the builder
    docker buildx inspect --bootstrap
}

# Prepare build directory
prepare_build_dir() {
    print_message "Preparing build directory..." "$YELLOW"
    
    # Create temporary build directory
    BUILD_DIR=$(mktemp -d)
    print_message "Created build directory: $BUILD_DIR" "$GREEN"
    
    # Copy necessary files
    cp Dockerfile "$BUILD_DIR/"
    cp requirements.txt "$BUILD_DIR/"
    cp convcommit.py "$BUILD_DIR/"
    cp assistant.py "$BUILD_DIR/"
    cp diff_generator.py "$BUILD_DIR/"
    cp runner.py "$BUILD_DIR/"
    cp spinner.py "$BUILD_DIR/"
    cp instructions_prompt.md "$BUILD_DIR/"
    
    # Change to build directory
    cd "$BUILD_DIR"
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
            print_message "Error: Unsupported architecture $(uname -m)" "$RED"
            exit 1
            ;;
    esac
}

# Build and push multi-architecture images
build_and_push() {
    print_message "Building and pushing multi-architecture images..." "$YELLOW"
    
    # Get host architecture
    ARCH=$(detect_architecture)
    print_message "Building for architecture: $ARCH" "$GREEN"
    
    # Build and push for host architecture only
    if ! docker buildx build \
        --platform "$ARCH" \
        --tag ghcr.io/mnofresno/convcommitgpt:1.0.0 \
        --tag ghcr.io/mnofresno/convcommitgpt:latest \
        --push \
        --no-cache \
        --progress=plain \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        --build-arg DOCKER_BUILDKIT=1 \
        .; then
        print_message "Error: Failed to build and push images" "$RED"
        exit 1
    fi
}

# Cleanup
cleanup() {
    print_message "Cleaning up..." "$YELLOW"
    rm -rf "$BUILD_DIR"
}

# Main process
main() {
    print_message "Starting multi-architecture build process..." "$GREEN"
    
    # Check requirements
    check_requirements
    
    # Setup builder
    setup_builder
    
    # Prepare build directory
    prepare_build_dir
    
    # Build and push
    build_and_push
    
    # Cleanup
    cleanup
    
    print_message "Build and push completed successfully!" "$GREEN"
}

# Run main function
main 