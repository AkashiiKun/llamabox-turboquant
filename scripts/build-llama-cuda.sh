#!/usr/bin/env bash
# CUDA-specific build flags for llama.cpp

# Use BUILD_DIR from environment or fallback to 'build'
BUILD_DIR="${BUILD_DIR:-build}"

# Unset host-polluted variables to ensure container toolkit is used
unset CUDACXX
unset CUDA_PATH

# Find CUDA toolkit
if [ -d "/usr/local/cuda" ]; then
    export CUDA_PATH=/usr/local/cuda
elif ls -d /usr/local/cuda-* 1> /dev/null 2>&1; then
    export CUDA_PATH=$(ls -d /usr/local/cuda-* | head -n 1)
fi

if [ -z "$CUDA_PATH" ]; then
    echo "Error: CUDA Toolkit not found in /usr/local/cuda or /usr/local/cuda-*"
    exit 1
fi

export PATH="$CUDA_PATH/bin:$PATH"
export CUDACXX="$CUDA_PATH/bin/nvcc"

echo "Using CUDA Toolkit at: $CUDA_PATH"
echo "Using CUDA Compiler: $CUDACXX"

cmake -B "$BUILD_DIR" \
    -DGGML_CUDA=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="$CUDACXX" \
    -DCMAKE_CUDA_FLAGS="-allow-unsupported-compiler -D__NV_NO_HOST_COMPILER_CHECK=1"

cmake --build "$BUILD_DIR" --config Release -j$(nproc)
