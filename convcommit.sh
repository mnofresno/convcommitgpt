#!/bin/bash

# Function to print verbose messages
verbose_echo() {
    if [ "$VERBOSE" = true ]; then
        echo "$1"
    fi
}

# Parse command line arguments
VERBOSE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
verbose_echo "Script directory: $SCRIPT_DIR"

# Detect container runtime
if command -v docker >/dev/null 2>&1; then
    CONTAINER_CMD="docker"
    verbose_echo "Container runtime detected: Docker"
elif command -v podman >/dev/null 2>&1; then
    CONTAINER_CMD="podman"
    verbose_echo "Container runtime detected: Podman"
else
    echo "Error: Neither Docker nor Podman is installed"
    exit 1
fi

# Detect architecture
case "$(uname -m)" in
    "x86_64")
        PLATFORM="linux/amd64"
        ;;
    "arm64"|"aarch64")
        PLATFORM="linux/arm64"
        ;;
    *)
        echo "Error: Unsupported architecture $(uname -m)"
        exit 1
        ;;
esac
verbose_echo "Platform detected: $PLATFORM"

# Read configuration from .env
if [ -f ~/.local/lib/convcommitgpt/.env ]; then
    verbose_echo "Reading configuration from ~/.local/lib/convcommitgpt/.env"
    source ~/.local/lib/convcommitgpt/.env
else
    echo "Error: Configuration file ~/.local/lib/convcommitgpt/.env not found"
    exit 1
fi

# Image name
IMAGE_NAME="ghcr.io/mnofresno/convcommitgpt:latest"
verbose_echo "Using image: $IMAGE_NAME"

# Function to check if directory is a git repository
is_git_repo() {
    local dir="$1"
    if [ -d "$dir/.git" ] || git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

if [[ "$1" == "-d" && "$2" == "-" ]]; then
    verbose_echo "Processing direct diff from stdin"
    DIRECT_DIFF=$(cat -)
    verbose_echo "Running container with direct diff..."
    echo "$DIRECT_DIFF"| $CONTAINER_CMD run --rm -i \
        --platform "$PLATFORM" \
        --network host \
        -e BASE_URL="$BASE_URL" \
        -e MODEL="$MODEL" \
        -e OPENAI_TIMEOUT=300 \
        -e HTTPX_TIMEOUT=300 \
        -e VERBOSE="$VERBOSE" \
        --security-opt=label=disable \
        --user "$(id -u):$(id -g)" \
        $IMAGE_NAME "${@:2}"
else
    if [ -z "$1" ]; then
        echo "Error: A directory path is required when no diff is passed through stdin."
        exit 1
    fi
    GIT_DIR="$(realpath "${1:-'.'}")"
    verbose_echo "Git directory: $GIT_DIR"
    
    # Verify it's a Git repository
    if ! is_git_repo "$GIT_DIR"; then
        echo "Error: $GIT_DIR is not a Git repository"
        exit 1
    fi
    verbose_echo "Git repository verified"
    
    # Generate diff locally
    verbose_echo "Generating git diff..."
    DIFF=$(cd "$GIT_DIR" && git diff --cached)
    
    if [ -z "$DIFF" ]; then
        echo "No staged changes found in $GIT_DIR"
        exit 1
    fi
    verbose_echo "Diff generated successfully"
    
    # Pass diff to container
    verbose_echo "Running container with git diff..."
    echo "$DIFF" | $CONTAINER_CMD run --rm -i \
        --platform "$PLATFORM" \
        --network host \
        -e BASE_URL="$BASE_URL" \
        -e MODEL="$MODEL" \
        -e OPENAI_TIMEOUT=300 \
        -e HTTPX_TIMEOUT=300 \
        -e VERBOSE="$VERBOSE" \
        --security-opt=label=disable \
        --user "$(id -u):$(id -g)" \
        $IMAGE_NAME -d - "${@:2}"
fi
