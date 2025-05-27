#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# Detect container runtime
if command -v docker >/dev/null 2>&1; then
    CONTAINER_CMD="docker"
    DOCKER_HOST_FLAG="--add-host=host.docker.internal:host-gateway"
elif command -v podman >/dev/null 2>&1; then
    CONTAINER_CMD="podman"
    DOCKER_HOST_FLAG=""
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

# Detect OS and set Ollama URL and network configuration
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ "$CONTAINER_CMD" == "docker" ]]; then
        # Docker on macOS
        OLLAMA_BASE_URL="http://host.docker.internal:11434/v1"
        NETWORK_OPTS="--add-host=host.docker.internal:$(ipconfig getifaddr en0)"
    else
        # Podman on macOS
        HOST_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
        if [ -z "$HOST_IP" ]; then
            echo "Error: Could not determine host IP address"
            exit 1
        fi
        OLLAMA_BASE_URL="http://${HOST_IP}:11434/v1"
        NETWORK_OPTS="--add-host=host.docker.internal:${HOST_IP}"
    fi
else
    # Linux
    OLLAMA_BASE_URL="http://localhost:11434/v1"
    NETWORK_OPTS=""
fi

OLLAMA_MODEL="qwen3:8b"

# Image name
IMAGE_NAME="ghcr.io/mnofresno/convcommitgpt:latest"

# Function to check if directory is a git repository
is_git_repo() {
    local dir="$1"
    if [ -d "$dir/.git" ] || git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

if [[ "$1" == "-d" && "$2" == "-" ]]; then
    DIRECT_DIFF=$(cat -)
    echo "$DIRECT_DIFF"| $CONTAINER_CMD run --rm -i \
        --platform "$PLATFORM" \
        $NETWORK_OPTS \
        -e BASE_URL="$OLLAMA_BASE_URL" \
        -e MODEL="$OLLAMA_MODEL" \
        -v "$SCRIPT_DIR:/app" \
        --security-opt=label=disable \
        --user "$(id -u):$(id -g)" \
        $IMAGE_NAME "${@:2}"
else
    if [ -z "$1" ]; then
        echo "Error: A directory path is required when no diff is passed through stdin."
        exit 1
    fi
    GIT_DIR="$(realpath "${1:-'.'}")"
    
    # Verify it's a Git repository
    if ! is_git_repo "$GIT_DIR"; then
        echo "Error: $GIT_DIR is not a Git repository"
        exit 1
    fi
    
    # Generate diff locally
    DIFF=$(cd "$GIT_DIR" && git diff --cached)
    
    if [ -z "$DIFF" ]; then
        echo "No staged changes found in $GIT_DIR"
        exit 1
    fi
    
    # Pass diff to container
    echo "$DIFF" | $CONTAINER_CMD run --rm -i \
        --platform "$PLATFORM" \
        $NETWORK_OPTS \
        -e BASE_URL="$OLLAMA_BASE_URL" \
        -e MODEL="$OLLAMA_MODEL" \
        -v "$SCRIPT_DIR:/app" \
        --security-opt=label=disable \
        --user "$(id -u):$(id -g)" \
        $IMAGE_NAME -d - "${@:2}"
fi
