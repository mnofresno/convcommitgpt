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

# Function to get host IP
get_host_ip() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Try different network interfaces on macOS
        for interface in en0 en1; do
            ip=$(ipconfig getifaddr $interface 2>/dev/null)
            if [ ! -z "$ip" ]; then
                echo "$ip"
                return 0
            fi
        done
        echo "Error: Could not determine host IP address"
        return 1
    else
        # Linux - try different methods
        # First try hostname -I
        ip=$(hostname -I | awk '{print $1}' 2>/dev/null)
        if [ ! -z "$ip" ]; then
            echo "$ip"
            return 0
        fi
        # Then try ip command
        ip=$(ip route get 1 | awk '{print $7;exit}' 2>/dev/null)
        if [ ! -z "$ip" ]; then
            echo "$ip"
            return 0
        fi
        echo "Error: Could not determine host IP address"
        return 1
    fi
}

# Detect OS and set Ollama URL and network configuration
echo "Detecting OS type: $OSTYPE"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS detected"
    if [[ "$CONTAINER_CMD" == "docker" ]]; then
        echo "Using Docker on macOS"
        OLLAMA_BASE_URL="http://host.docker.internal:11434/v1"
        HOST_IP=$(get_host_ip)
        if [ $? -ne 0 ]; then
            exit 1
        fi
        echo "Host IP detected: $HOST_IP"
        NETWORK_OPTS="--add-host=host.docker.internal:$HOST_IP"
    else
        echo "Using Podman on macOS"
        HOST_IP=$(get_host_ip)
        if [ $? -ne 0 ]; then
            exit 1
        fi
        echo "Host IP detected: $HOST_IP"
        OLLAMA_BASE_URL="http://${HOST_IP}:11434/v1"
        NETWORK_OPTS="--add-host=host.docker.internal:${HOST_IP}"
    fi
else
    echo "Linux detected"
    if [[ "$CONTAINER_CMD" == "docker" ]]; then
        echo "Using Docker on Linux"
        OLLAMA_BASE_URL="http://host.docker.internal:11434/v1"
        HOST_IP=$(get_host_ip)
        if [ $? -ne 0 ]; then
            exit 1
        fi
        echo "Host IP detected: $HOST_IP"
        NETWORK_OPTS="--add-host=host.docker.internal:$HOST_IP"
    else
        echo "Using Podman on Linux"
        OLLAMA_BASE_URL="http://localhost:11434/v1"
        NETWORK_OPTS=""
    fi
fi

echo "Network options: $NETWORK_OPTS"
echo "Ollama base URL: $OLLAMA_BASE_URL"

# Check if Ollama is running
echo "Checking if Ollama is running..."
if ! curl -s "$OLLAMA_BASE_URL" > /dev/null; then
    echo "Error: Ollama is not running or not accessible at $OLLAMA_BASE_URL"
    echo "Please start Ollama with: ollama serve"
    exit 1
fi

# Get model from .env file or use default
if [ -f ~/.local/lib/convcommitgpt/.env ]; then
    OLLAMA_MODEL=$(grep MODEL ~/.local/lib/convcommitgpt/.env | cut -d'=' -f2)
else
    OLLAMA_MODEL="qwen3:8b"
fi
echo "Ollama model: $OLLAMA_MODEL"

# Check if model is available
echo "Checking if model $OLLAMA_MODEL is available..."
if ! curl -s "$OLLAMA_BASE_URL/tags" | grep -q "$OLLAMA_MODEL"; then
    echo "Error: Model $OLLAMA_MODEL is not available in Ollama"
    echo "Please pull the model using: ollama pull $OLLAMA_MODEL"
    exit 1
fi

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
        --security-opt=label=disable \
        --user "$(id -u):$(id -g)" \
        $IMAGE_NAME -d - "${@:2}"
fi
