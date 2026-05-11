#!/usr/bin/env bash
# Vulkan-specific build flags for llama.cpp

# Use BUILD_DIR from environment or fallback to 'build'
BUILD_DIR="${BUILD_DIR:-build}"

cmake -B "$BUILD_DIR" \
    -DGGML_VULKAN=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_NATIVE=OFF # Better compatibility across different Vulkan devices

cmake --build "$BUILD_DIR" --config Release -j$(nproc)
