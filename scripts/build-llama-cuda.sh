#!/usr/bin/env bash
# CUDA-specific build flags for llama.cpp

# Use BUILD_DIR from environment or fallback to 'build'
BUILD_DIR="${BUILD_DIR:-build}"

# Aggressively sanitize environment to prevent leakage from Distrobox host
echo "Sanitizing environment..."
unset CUDA_PATH
unset CUDA_ROOT
unset CUDA_HOME
unset CUDACXX
unset CUDAToolkit_ROOT
unset CUDAHOSTCXX

# Find CUDA toolkit inside the container
if [ -d "/usr/local/cuda" ]; then
    export CUDA_PATH=/usr/local/cuda
elif ls -d /usr/local/cuda-1* 1> /dev/null 2>&1; then
    export CUDA_PATH=$(ls -d /usr/local/cuda-1* | head -n 1)
fi

if [ -z "$CUDA_PATH" ]; then
    echo "Error: CUDA Toolkit not found in /usr/local/cuda or /usr/local/cuda-*"
    echo "Current PATH: $PATH"
    echo "Contents of /usr/local:"
    ls -l /usr/local
    exit 1
fi

# Set correct paths for the container environment
export PATH="$CUDA_PATH/bin:$PATH"
export CUDACXX="$CUDA_PATH/bin/nvcc"
export CUDA_HOME="$CUDA_PATH"
export CUDA_ROOT="$CUDA_PATH"
export CUDAToolkit_ROOT="$CUDA_PATH"

echo "--- CUDA Environment Debug ---"
echo "CUDA_PATH: $CUDA_PATH"
echo "CUDACXX: $CUDACXX"
echo "PATH: $PATH"
echo "nvcc location: $(which nvcc 2>/dev/null || echo 'NOT FOUND')"
if command -v nvcc > /dev/null; then
    nvcc --version | head -n 3
fi
echo "------------------------------"

# Force wipe if stale cache from host or previous failed attempts exist
if [ -d "$BUILD_DIR" ]; then
    if [ -f "$BUILD_DIR/CMakeCache.txt" ]; then
        if grep -iqE "/opt/cuda|/usr/local/cuda" "$BUILD_DIR/CMakeCache.txt"; then
            # Even if it points to /usr/local/cuda, we wipe to be safe with new env
            echo "Stale or host-polluted CMakeCache.txt detected. Wiping $BUILD_DIR..."
            rm -rf "$BUILD_DIR"
        fi
    fi
fi

mkdir -p "$BUILD_DIR"

cmake -B "$BUILD_DIR" \
    -DGGML_CUDA=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCUDAToolkit_ROOT="$CUDA_PATH" \
    -DCMAKE_CUDA_COMPILER="$CUDACXX" \
    -DCMAKE_CUDA_FLAGS="-allow-unsupported-compiler -D__NV_NO_HOST_COMPILER_CHECK=1" \
    -Wno-dev

cmake --build "$BUILD_DIR" --config Release -j$(nproc)
