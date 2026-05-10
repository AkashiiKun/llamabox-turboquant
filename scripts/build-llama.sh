#!/usr/bin/env bash

# Shared build script for llama.cpp inside the container
# Located at /usr/bin/build-llama

set -e

LLAMA_DIR="$HOME/llama.cpp"
BUILD_DIR="$LLAMA_DIR/build"

# 1. Clone or update llama.cpp
if [ ! -d "$LLAMA_DIR" ]; then
    echo "Cloning llama.cpp..."
    git clone https://github.com/ggml-org/llama.cpp "$LLAMA_DIR"
fi

cd "$LLAMA_DIR"
echo "Updating llama.cpp..."
git pull

# 2. Determine backend and run variant-specific build
# The variant-specific script is expected to be at /usr/bin/build-llama-variant
VARIANT_SCRIPT=""
if [ -f "/usr/bin/build-llama-cuda" ]; then
    VARIANT_SCRIPT="/usr/bin/build-llama-cuda"
elif [ -f "/usr/bin/build-llama-rocm" ]; then
    VARIANT_SCRIPT="/usr/bin/build-llama-rocm"
elif [ -f "/usr/bin/build-llama-sycl" ]; then
    VARIANT_SCRIPT="/usr/bin/build-llama-sycl"
elif [ -f "/usr/bin/build-llama-vulkan" ]; then
    VARIANT_SCRIPT="/usr/bin/build-llama-vulkan"
else
    echo "Error: No variant-specific build script found in /usr/bin/"
    exit 1
fi

echo "Found variant script: $VARIANT_SCRIPT"
source "$VARIANT_SCRIPT"

# 3. Symlink built binaries to /usr/local/bin for easy export
# Assuming the variant script ran cmake and cmake --build
# Use sudo as /usr/local/bin is root-owned
sudo mkdir -p /usr/local/bin
sudo find "$BUILD_DIR/bin" -maxdepth 1 -executable -type f -exec ln -sf {} /usr/local/bin/ \;

echo "Build and symlinking complete."
