#!/usr/bin/env bash
# SYCL-specific build flags for llama.cpp

# Use BUILD_DIR from environment or fallback to 'build'
BUILD_DIR="${BUILD_DIR:-build}"

# Source oneAPI environment
if [ -f "/opt/intel/oneapi/setvars.sh" ]; then
    source /opt/intel/oneapi/setvars.sh
fi

cmake -B "$BUILD_DIR" \
    -DGGML_SYCL=ON \
    -DCMAKE_C_COMPILER=icx \
    -DCMAKE_CXX_COMPILER=icpx \
    -DCMAKE_BUILD_TYPE=Release

cmake --build "$BUILD_DIR" --config Release -j$(nproc)
