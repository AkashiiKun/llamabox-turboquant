#!/usr/bin/env bash
# CUDA-specific build flags for llama.cpp

cmake -B build \
    -DGGML_CUDA=ON \
    -DCMAKE_BUILD_TYPE=Release

cmake --build build --config Release -j$(nproc)
