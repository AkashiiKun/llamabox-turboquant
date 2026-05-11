#!/usr/bin/env bash
# ROCm-specific build flags for llama.cpp

# Use BUILD_DIR from environment or fallback to 'build'
BUILD_DIR="${BUILD_DIR:-build}"

export ROCM_PATH=/usr
cmake -B "$BUILD_DIR" \
    -DGGML_HIPBLAS=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DAMDGPU_TARGETS=all # Build for all supported AMD GPUs

cmake --build "$BUILD_DIR" --config Release -j$(nproc)
