#!/usr/bin/env bash
# ROCm-specific build flags for llama.cpp

export ROCM_PATH=/opt/rocm
cmake -B build \
    -DGGML_HIPBLAS=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DAMDGPU_TARGETS=all # Build for all supported AMD GPUs

cmake --build build --config Release -j$(nproc)
