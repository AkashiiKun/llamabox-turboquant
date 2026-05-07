#!/usr/bin/env bash
# Vulkan-specific build flags for llama.cpp

cmake -B build \
    -DGGML_VULKAN=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_NATIVE=OFF # Better compatibility across different Vulkan devices

cmake --build build --config Release -j$(nproc)
