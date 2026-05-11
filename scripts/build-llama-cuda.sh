#!/usr/bin/env bash
# CUDA-specific build flags for llama.cpp

export CUDA_PATH=/usr/local/cuda
export PATH="$CUDA_PATH/bin:$PATH"
export CUDACXX="$CUDA_PATH/bin/nvcc"

cmake -B build \
    -DGGML_CUDA=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="$CUDACXX" \
    -DCMAKE_CUDA_FLAGS="-allow-unsupported-compiler -D__NV_NO_HOST_COMPILER_CHECK=1"

cmake --build build --config Release -j$(nproc)
