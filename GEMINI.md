# AGENTS.md

This file describes the project structure, conventions, and guidance for AI agents
(and human contributors) working on llamabox.

---

## Project Overview

**llamabox** is a Davincibox-style project that streamlines building and running
[llama.cpp](https://github.com/ggml-org/llama.cpp) on Linux using
[Distrobox](https://github.com/89luca89/distrobox). It is primarily aimed at users
of immutable/atomic Linux distributions (Fedora Silverblue, Bazzite, etc.) where
installing GPU compute toolkits on the host is undesirable, but it works on any
distro that supports Distrobox.

The project produces four container image variants, one per GPU backend:

| Variant | Image tag | Backend |
|---------|-----------|---------|
| Vulkan | `llamabox:vulkan` | Vulkan (universal fallback) |
| NVIDIA | `llamabox:cuda` | CUDA via NVCC |
| AMD | `llamabox:rocm` | ROCm / HIP |
| Intel | `llamabox:sycl` | oneAPI SYCL / DPC++ |

All images are Arch Linux-based and hosted on `ghcr.io`.


---

## Repository Structure

```
llamabox/
├── Containerfile.vulkan       # Vulkan build environment (universal fallback)
├── Containerfile.cuda         # NVIDIA CUDA build environment
├── Containerfile.rocm         # AMD ROCm build environment
├── Containerfile.sycl         # Intel oneAPI SYCL build environment
├── setup.sh                   # Host-side setup script (GPU detection + container creation)
├── scripts/
│   ├── build-llama.sh         # Build script baked into all images at /usr/bin/build-llama
│   ├── build-llama-vulkan.sh  # Vulkan-specific build flags
│   ├── build-llama-cuda.sh    # CUDA-specific build flags
│   ├── build-llama-rocm.sh    # ROCm-specific build flags
│   └── build-llama-sycl.sh    # SYCL-specific build flags (sources oneAPI env)
├── .github/
│   └── workflows/
│       └── build.yml          # Builds and pushes all four image variants to ghcr.io
└── README.md
```

---

## Containerfiles

### Base Conventions

- All images use `archlinux:latest` as the base (`FROM archlinux:latest`).
- Each `RUN` layer should be as consolidated as possible: install packages, clean
  the pacman cache (`pacman -Scc --noconfirm`), and copy scripts all in as few
  layers as practical to keep image size down.
- The build helper script must be copied to `/usr/bin/build-llama` and made
  executable inside the image.
- Do **not** run `pacman -Syu` (full upgrade) in CI — pin the base image digest
  in `build.yml` if reproducibility matters, otherwise accept rolling updates.

### Package Naming

Use official Arch repo package names where possible; fall back to AUR only when
necessary (ROCm and SYCL packages may require AUR). Avoid AUR helpers inside
Containerfiles — use `makepkg` directly or a pre-built binary from the AUR if
needed.

### GPU-Specific Notes

- **Vulkan**: Requires `vulkan-icd-loader`, `vulkan-headers`, and `shaderc` (for
  `glslc`, which compiles GLSL shaders at build time). No vendor-specific driver
  libraries are needed in the image — Distrobox passes `/dev/dri` through from
  the host, so the host's Vulkan ICD (e.g. `vulkan-radeon`, `vulkan-intel`,
  `nvidia-utils`) is used automatically.
- **CUDA**: Requires the `cuda` package (AUR). The NVCC compiler should be on
  `PATH` after installation. Do not bundle NVIDIA driver libraries — Distrobox
  passes these through from the host.
- **ROCm**: Use `rocm-hip-sdk` from the official Arch repos where available.
  `ROCM_PATH` should be set to `/opt/rocm` in the image environment.
- **SYCL**: `intel-oneapi-basekit` from the AUR is large (~5 GB installed).
  The build script must source `/opt/intel/oneapi/setvars.sh` before invoking
  CMake. The DPC++ compilers `icx`/`icpx` must be used instead of GCC.

---

## setup.sh

`setup.sh` is the primary user-facing script. It runs on the **host**, not inside
the container.

### Responsibilities

1. Check that `distrobox`, `podman`, and `lshw` are available; print a friendly
   error and exit if not.
2. Detect the GPU vendor using `lshw -C display` and select the appropriate image
   tag (`cuda`, `rocm`, `sycl`, or `vulkan` as fallback).
3. Handle the case where Intel integrated graphics is present alongside a discrete
   AMD or NVIDIA GPU — prefer the discrete card. Allow the user to override with
   a `--backend` flag.
4. Create the Distrobox container:
   ```bash
   distrobox create --name llamabox --image ghcr.io/yourname/llamabox:$BACKEND --yes
   ```
5. Run the build inside the container:
   ```bash
   distrobox enter llamabox -- /usr/bin/build-llama
   ```
6. Export the built binaries to the host via `distrobox-export`:
   ```bash
   distrobox enter llamabox -- distrobox-export --bin /usr/local/bin/llama-cli
   ```
7. Support `setup.sh remove` and `setup.sh upgrade` subcommands, mirroring
   Davincibox's approach.

### Exit Codes

- `0` — success
- `1` — missing dependency
- `2` — GPU detection failed / unknown hardware
- `3` — container creation or build failed

---

## build-llama.sh Scripts

These scripts live inside the container at `/usr/bin/build-llama`. They are
responsible for cloning or updating llama.cpp and running the CMake build.

### Shared Logic (all variants)

```bash
LLAMA_DIR="$HOME/llama.cpp"

if [ ! -d "$LLAMA_DIR" ]; then
    git clone https://github.com/ggml-org/llama.cpp "$LLAMA_DIR"
fi

cd "$LLAMA_DIR" && git pull
```

After cloning/updating, each variant script runs its own CMake invocation (see
below) and then symlinks built binaries to `/usr/local/bin/`.

### CMake Flags per Variant

| Variant | Key flags |
|---------|-----------|
| `vulkan` | `-DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release` |
| `cuda` | `-DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release` |
| `rocm` | `-DGGML_HIPBLAS=ON -DCMAKE_BUILD_TYPE=Release` |
| `sycl` | `-DGGML_SYCL=ON -DCMAKE_C_COMPILER=icx -DCMAKE_CXX_COMPILER=icpx -DCMAKE_BUILD_TYPE=Release` |

Always pass `-j$(nproc)` to `cmake --build`.

---

## GitHub Actions (build.yml)

The workflow builds and pushes all four image variants on every push to `main`
and on a weekly schedule (to pick up upstream Arch package updates).

- Use a matrix strategy over `[vulkan, rocm, cuda, sycl]`.
- Authenticate to `ghcr.io` using `GITHUB_TOKEN` — no extra secrets needed.
- Tag images as both `:$variant` and `:$variant-$sha` for traceability.
- The `sycl` job should be expected to take significantly longer and may need a
  larger runner due to the oneAPI package size.

---

## Conventions for Contributors and Agents

### Making Changes to Containerfiles

- Always test a changed `Containerfile` locally with `podman build` before
  pushing. A build that fails in CI wastes time.
- If you add a new package, document why it is needed in a comment on the same
  `RUN` line.
- Do not install packages that are only needed at runtime if Distrobox already
  provides them via host passthrough (e.g., NVIDIA userspace drivers).

### Making Changes to setup.sh

- `setup.sh` must remain POSIX-compatible (`#!/usr/bin/env bash` is fine, but
  avoid bashisms that break on older bash versions shipped by some distros).
- GPU detection logic lives in a single `detect_gpu()` function. Keep all
  detection logic there — do not scatter `lshw` calls elsewhere in the script.
- Always test the `--backend` override flag when changing detection logic.

### Making Changes to build-llama Scripts

- The scripts are baked into the image at build time. A change here requires
  rebuilding and pushing the image before it takes effect for users.
- Keep the clone/update logic identical across all four variants to avoid drift.
  If you need to change it, change it in all four (or refactor into a shared
  sourced snippet).
- Do not hardcode the llama.cpp version or commit. Always build from the latest
  `HEAD` of the default branch so users get current GGUF and model support.

### What Agents Should Not Do

- Do not modify `setup.sh` to require Docker instead of Podman. Podman's
  rootless model is the reason Distrobox works cleanly on atomic distros.
- Do not add GUI components, desktop launchers, or `.desktop` files. llamabox
  is a CLI tool — llama.cpp binaries are invoked from the terminal.
- Do not pin llama.cpp to a specific release tag in the build scripts without
  a corresponding issue or user request documenting why.
- Do not add a fifth image variant without first opening an issue to discuss
  the GPU backend and verifying that llama.cpp's CMake supports it cleanly.

---

## Testing

There is currently no automated test suite for the built binaries. Manual testing
checklist after any change:

1. `setup.sh` runs cleanly on a fresh system with no existing `llamabox` container.
2. `setup.sh remove` cleanly removes the container and exported binaries.
3. `setup.sh upgrade` recreates the container and rebuilds without residual state.
4. `llama-cli` is callable from the host shell after setup (verify `distrobox-export` worked).
5. A small GGUF model (e.g., a quantized Qwen or Llama 3.2 1B) runs without errors.
6. GPU utilisation is visible in `nvtop`/`radeontop`/`intel_gpu_top` during inference
   for the respective GPU variant. For Vulkan, confirm device selection with
   `vulkaninfo` inside the container.

---

## Useful References

- [llama.cpp CMake build docs](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md)
- [Distrobox documentation](https://distrobox.it/)
- [davincibox](https://github.com/zelikos/davincibox) — the inspiration for this project
- [Arch Linux Vulkan wiki](https://wiki.archlinux.org/title/Vulkan)
- [Arch Linux ROCm wiki](https://wiki.archlinux.org/title/GPGPU#ROCm)
- [Intel oneAPI on Arch (AUR)](https://aur.archlinux.org/packages/intel-oneapi-basekit)
