# llamabox

Davincibox-style project that streamlines building and running [llama.cpp](https://github.com/ggml-org/llama.cpp) on Linux using [Distrobox](https://github.com/89luca89/distrobox).

## Features

- **Multi-backend support**: Vulkan, CUDA, ROCm, and SYCL.
- **Atomic/Immutable Friendly**: Designed for Fedora Silverblue, Bazzite, etc.
- **Arch Linux based**: Rolling release containers for latest dependencies.
- **Easy Setup**: Single host-side script for GPU detection and container creation.

## Quick Start

```bash
curl -sSL https://raw.githubusercontent.com/mienaiKnife/llamabox/main/setup.sh | bash
```

## Usage

See [GEMINI.md](GEMINI.md) for detailed architecture and contribution guidelines.
