#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
echo "Script directory: $SCRIPT_DIR"

# Detect container runtime
if command -v docker >/dev/null 2>&1; then
    CONTAINER_CMD="docker"
    echo "Container runtime detected: Docker"
elif command -v podman >/dev/null 2>&1; then
    CONTAINER_CMD="podman"
    echo "Container runtime detected: Podman"
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
echo "Platform detected: $PLATFORM"

# Detect OS and set Ollama URL and network configuration
echo "Detecting OS type: $OSTYPE"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS detected"
    if [[ "$CONTAINER_CMD" == "docker" ]]; then
        echo "Using Docker on macOS"
        OLLAMA_BASE_URL="http://host.docker.internal:11434/v1"
        HOST_IP=$(ipconfig getifaddr en0)
        echo "Host IP detected: $HOST_IP"
        NETWORK_OPTS="--add-host=host.docker.internal:$HOST_IP"
        echo "Network options: $NETWORK_OPTS"
    else
        echo "Using Podman on macOS"
        HOST_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
        if [ -z "$HOST_IP" ]; then
            echo "Error: Could not determine host IP address"
            exit 1
        fi
        echo "Host IP detected: $HOST_IP"
        OLLAMA_BASE_URL="http://${HOST_IP}:11434/v1"
        NETWORK_OPTS="--add-host=host.docker.internal:${HOST_IP}"
        echo "Network options: $NETWORK_OPTS"
    fi
else
    echo "Linux detected"
    OLLAMA_BASE_URL="http://localhost:11434/v1"
    NETWORK_OPTS=""
    echo "Network options: $NETWORK_OPTS"
fi

echo "Ollama base URL: $OLLAMA_BASE_URL"
OLLAMA_MODEL="qwen3:8b"
echo "Ollama model: $OLLAMA_MODEL"

# Image name
IMAGE_NAME="ghcr.io/mnofresno/convcommitgpt:latest"
echo "Using image: $IMAGE_NAME"

# Function to check if directory is a git repository
is_git_repo() {
    local dir="$1"
    if [ -d "$dir/.git" ] || git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

if [[ "$1" == "-d" && "$2" == "-" ]]; then
    echo "Processing direct diff from stdin"
    DIRECT_DIFF=$(cat -)
    echo "Running container with direct diff..."
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
    echo "Git directory: $GIT_DIR"
    
    # Verify it's a Git repository
    if ! is_git_repo "$GIT_DIR"; then
        echo "Error: $GIT_DIR is not a Git repository"
        exit 1
    fi
    echo "Git repository verified"
    
    # Generate diff locally
    echo "Generating git diff..."
    DIFF=$(cd "$GIT_DIR" && git diff --cached)
    
    if [ -z "$DIFF" ]; then
        echo "No staged changes found in $GIT_DIR"
        exit 1
    fi
    echo "Diff generated successfully"
    
    # Pass diff to container
    echo "Running container with git diff..."
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
