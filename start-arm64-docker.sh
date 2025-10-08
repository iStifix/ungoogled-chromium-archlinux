#!/bin/bash
# Script to start ARM64 Arch Linux container with QEMU emulation
# This allows NATIVE ARM64 compilation on x86_64 host

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "Starting ARM64 Arch Linux container with QEMU emulation"
log_info "This will run natively on ARM64 (emulated by QEMU)"
log_info "Using official Arch Linux ARM from archlinuxarm.org"

# Check QEMU is available
if ! which qemu-aarch64-static >/dev/null 2>&1; then
    log_error "QEMU aarch64 not found!"
    log_error "Install with: sudo pacman -S qemu-user-static qemu-user-static-binfmt"
    exit 1
fi

log_success "QEMU aarch64 found: $(which qemu-aarch64-static)"

# Check binfmt_misc is configured
if [[ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]]; then
    log_error "binfmt_misc not configured for ARM64!"
    log_error "Enable with: sudo systemctl restart systemd-binfmt"
    exit 1
fi

log_success "binfmt_misc configured for ARM64"

# Check if archlinux-arm64 image exists
if ! docker images archlinux-arm64:latest | grep -q archlinux-arm64; then
    log_info "archlinux-arm64 image not found, creating from archlinuxarm.org..."

    # Create temp directory
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT

    log_info "Downloading Arch Linux ARM rootfs..."
    curl -L -o "$TEMP_DIR/ArchLinuxARM-aarch64-latest.tar.gz" \
        "http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"

    log_info "Importing as Docker image..."
    cat "$TEMP_DIR/ArchLinuxARM-aarch64-latest.tar.gz" | docker import - archlinux-arm64:latest

    log_success "archlinux-arm64 image created"
else
    log_success "Using existing archlinux-arm64:latest image"
fi

# Stop old container if running
OLD_CONTAINER=$(docker ps -a -q -f "name=chromium-arm64-builder" 2>/dev/null || true)
if [[ -n "$OLD_CONTAINER" ]]; then
    log_info "Stopping old container: $OLD_CONTAINER"
    docker stop "$OLD_CONTAINER" 2>/dev/null || true
    docker rm "$OLD_CONTAINER" 2>/dev/null || true
fi

# Current directory
WORK_DIR="$(pwd)"

log_info "Starting ARM64 Arch Linux container..."
log_info "Work directory: $WORK_DIR"

# Run ARM64 container
# NOTE: No --platform flag needed - QEMU binfmt_misc handles ARM64 automatically
# Uses official Arch Linux ARM from archlinuxarm.org
docker run -it --rm \
    --name chromium-arm64-builder \
    -v "$WORK_DIR":/work \
    -w /work \
    archlinux-arm64:latest \
    /bin/bash

log_success "Container exited"
