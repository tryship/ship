# Runtime Install Guide

Platform-specific installation instructions for language runtimes.
Read this when Phase 0 detects a missing runtime.

## Node.js / npm

| Platform | Command |
|----------|---------|
| macOS | `brew install node` or download from https://nodejs.org |
| Linux (Ubuntu/Debian) | `curl -fsSL https://deb.nodesource.com/setup_20.x \| sudo -E bash - && sudo apt-get install -y nodejs` |
| Linux (generic) | `curl -fsSL https://fnm.vercel.app/install \| bash && fnm install 20` |
| Windows | `winget install OpenJS.NodeJS.LTS` |

## Python

| Platform | Command |
|----------|---------|
| macOS | `brew install python` or download from https://python.org |
| Linux (Ubuntu/Debian) | `sudo apt install python3 python3-pip python3-venv` |
| Windows | `winget install Python.Python.3.12` |

Prefer `uv` over `pip` for modern Python projects:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Go

| Platform | Command |
|----------|---------|
| macOS | `brew install go` or download from https://go.dev/dl/ |
| Linux | `curl -LO https://go.dev/dl/go1.22.0.linux-amd64.tar.gz && sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz` |
| Windows | `winget install GoLang.Go` |

## Rust

| Platform | Command |
|----------|---------|
| All | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |

## Java / Kotlin

| Platform | Command |
|----------|---------|
| macOS | `brew install openjdk` or `brew install kotlin` |
| Linux | `sudo apt install default-jdk` |
| Windows | `winget install EclipseAdoptium.Temurin.21.JDK` |

## Verifying installation

After installing any runtime, verify with:
```bash
node --version && npm --version   # Node.js
python3 --version && pip --version # Python
go version                         # Go
cargo --version                    # Rust
java --version                     # Java
```
