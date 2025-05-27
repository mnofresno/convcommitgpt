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
    
    # Create a new builder instance
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
    
    # Copy all Python files, requirements.txt, and markdown files
    cp *.py "$BUILD_DIR/" 2>/dev/null || true
    cp requirements.txt "$BUILD_DIR/" 2>/dev/null || true
    cp *.md "$BUILD_DIR/" 2>/dev/null || true
    cp Dockerfile "$BUILD_DIR/"
    
    # Change to build directory
    cd "$BUILD_DIR"
    
    # Verify essential files exist
    if [ ! -f "requirements.txt" ] || [ ! -f "convcommit.py" ] || [ ! -f "Dockerfile" ]; then
        print_message "Error: Essential files are missing" "$RED"
        return 1
    fi
}

# Build and push for a specific architecture
build_and_push_arch() {
    local arch=$1
    local version=$2
    
    print_message "Building and pushing for architecture: $arch" "$YELLOW"
    
    if ! docker buildx build \
        --platform "linux/$arch" \
        --tag "ghcr.io/mnofresno/convcommitgpt:latest-$arch" \
        --tag "ghcr.io/mnofresno/convcommitgpt:$version-$arch" \
        --push \
        --no-cache \
        --progress=plain \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        --build-arg DOCKER_BUILDKIT=1 \
        .; then
        print_message "Error: Failed to build and push image for $arch" "$RED"
        return 1
    fi
    
    return 0
}

# Create and push manifest
create_manifest() {
    local version=$1
    
    print_message "Creating multi-arch manifest for version $version..." "$YELLOW"
    
    # Remove existing manifest if it exists
    docker manifest rm "ghcr.io/mnofresno/convcommitgpt:$version" 2>/dev/null || true
    
    # Create new manifest
    docker manifest create "ghcr.io/mnofresno/convcommitgpt:$version" \
        "ghcr.io/mnofresno/convcommitgpt:$version-amd64" \
        "ghcr.io/mnofresno/convcommitgpt:$version-arm64"
    
    # Push manifest
    docker manifest push "ghcr.io/mnofresno/convcommitgpt:$version"
}

# Build and push multi-architecture images
build_and_push() {
    print_message "Building and pushing multi-architecture images..." "$YELLOW"
    
    local version="1.0.0"
    
    # Build and push for amd64
    if ! build_and_push_arch "amd64" "$version"; then
        return 1
    fi
    
    # Build and push for arm64
    if ! build_and_push_arch "arm64" "$version"; then
        return 1
    fi
    
    # Create and push manifests
    create_manifest "latest"
    create_manifest "$version"
    
    # Verify manifests
    print_message "Verifying manifests..." "$YELLOW"
    docker manifest inspect "ghcr.io/mnofresno/convcommitgpt:latest"
    docker manifest inspect "ghcr.io/mnofresno/convcommitgpt:$version"
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
    if ! build_and_push; then
        print_message "Error: Build and push failed" "$RED"
        cleanup
        exit 1
    fi
    
    # Cleanup
    cleanup
    
    print_message "Build and push completed successfully!" "$GREEN"
}

# Run main function
main 