#!/usr/bin/env bash

# llamabox setup script
# Streamlines building llama.cpp using Distrobox

set -e

CONTAINER_NAME="llamabox"
IMAGE_BASE="ghcr.io/mienaiKnife/llamabox"
BACKEND=""

# --- Utility Functions ---

info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

warn() {
    echo -e "\e[33m[WARN]\e[0m $1"
}

error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
    exit "${2:-1}"
}

check_dependencies() {
    local deps=("distrobox" "lshw")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "Missing dependency: $dep. Please install it and try again."
        fi
    done

    if ! command -v podman &> /dev/null && ! command -v docker &> /dev/null; then
        error "Missing dependency: podman or docker. Please install one of them and try again."
    fi
}

detect_gpu() {
    if [ -n "$BACKEND" ]; then
        info "Using user-specified backend: $BACKEND"
        return
    fi

    local lshw_output
    lshw_output=$(lshw -C display 2>/dev/null) || error "Failed to run lshw. Please ensure it is installed and you have correct permissions."

    if echo "$lshw_output" | grep -iq "nvidia"; then
        BACKEND="cuda"
    elif echo "$lshw_output" | grep -iqE "advanced micro devices|amdgpu"; then
        BACKEND="rocm"
    elif echo "$lshw_output" | grep -iq "intel corporation"; then
        # Check if there's also a discrete GPU
        if echo "$lshw_output" | grep -iqE "nvidia|advanced micro devices|amdgpu"; then
            warn "Both Intel and discrete GPU detected. Defaulting to discrete GPU."
            # Re-run detection to pick the discrete one properly
            if echo "$lshw_output" | grep -iq "nvidia"; then
                BACKEND="cuda"
            else
                BACKEND="rocm"
            fi
        else
            BACKEND="sycl"
        fi
    else
        warn "No supported GPU detected. Falling back to Vulkan."
        BACKEND="vulkan"
    fi

    info "Detected GPU backend: $BACKEND"
}

# --- Commands ---

create() {
    check_dependencies
    detect_gpu

    local image="$IMAGE_BASE:$BACKEND"

    info "Creating Distrobox container: $CONTAINER_NAME using image $image"
    distrobox create --name "$CONTAINER_NAME" --image "$image" --yes

    info "Building llama.cpp inside the container..."
    distrobox enter "$CONTAINER_NAME" -- /usr/bin/build-llama

    info "Ensuring host export directory exists: $HOME/.local/bin"
    mkdir -p "$HOME/.local/bin"

    info "Exporting binaries to the host..."
    distrobox enter "$CONTAINER_NAME" -- distrobox-export --bin /usr/local/bin/llama-cli --export-path "$HOME/.local/bin"
    distrobox enter "$CONTAINER_NAME" -- distrobox-export --bin /usr/local/bin/llama-server --export-path "$HOME/.local/bin"

    info "Setup complete! You can now run 'llama-cli' from your terminal."
    info "Note: Ensure '$HOME/.local/bin' is in your PATH."
}

remove() {
    info "Removing Distrobox container: $CONTAINER_NAME"
    distrobox rm "$CONTAINER_NAME" --force
    
    info "Removing exported binaries..."
    rm -f "$HOME/.local/bin/llama-cli"
    rm -f "$HOME/.local/bin/llama-server"
    
    info "Removal complete."
}

upgrade() {
    info "Upgrading llamabox..."
    remove
    create
}

# --- Main ---

case "$1" in
    remove)
        remove
        ;;
    upgrade)
        upgrade
        ;;
    create|"")
        # Handle optional --backend flag for create
        shift $(( $# > 0 ? 1 : 0 ))
        while [[ $# -gt 0 ]]; do
            case $1 in
                --backend)
                    BACKEND="$2"
                    shift 2
                    ;;
                *)
                    error "Unknown option: $1"
                    ;;
            esac
        done
        create
        ;;
    *)
        echo "Usage: $0 [create|remove|upgrade] [--backend cuda|rocm|sycl|vulkan]"
        exit 1
        ;;
esac
