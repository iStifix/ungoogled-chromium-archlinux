#!/bin/bash
# Start preconfigured ARM64 Chromium build container
# This uses the prebuilt image with all dependencies installed
# No setup needed - ready to compile immediately

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

IMAGE_NAME="chromium-baikal-m:optimized"

log_info "Starting preconfigured ARM64 Chromium build container"
log_info "Image: $IMAGE_NAME (all dependencies pre-installed, optimized)"

# Check if image exists
if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${IMAGE_NAME}$"; then
    log_error "Image $IMAGE_NAME not found!"
    log_error ""
    log_error "Import image first:"
    log_error "  ./import-docker-image.sh chromium-arm64-builder-prebuilt.tar.gz"
    log_error ""
    log_error "Or download from GitHub:"
    log_error "  wget https://github.com/YOUR_USER/YOUR_REPO/releases/download/TAG/chromium-arm64-builder-prebuilt.tar.gz"
    log_error "  ./import-docker-image.sh chromium-arm64-builder-prebuilt.tar.gz"
    exit 1
fi

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

# Stop old container if running
OLD_CONTAINER=$(docker ps -a -q -f "name=chromium-arm64-builder" 2>/dev/null || true)
if [[ -n "$OLD_CONTAINER" ]]; then
    log_info "Stopping old container: $OLD_CONTAINER"
    docker stop "$OLD_CONTAINER" 2>/dev/null || true
    docker rm "$OLD_CONTAINER" 2>/dev/null || true
fi

# Current directory
WORK_DIR="$(pwd)"

# Get host user UID/GID to avoid permission issues
HOST_UID=$(id -u)
HOST_GID=$(id -g)

log_info "Starting container..."
log_info "Work directory: $WORK_DIR"
log_info "Host UID:GID = $HOST_UID:$HOST_GID"
log_info ""
log_info "QEMU Performance Optimizations:"
log_info "  ✓ tmpfs for /tmp (4GB RAM disk for temporary files)"
log_info "  ✓ Increased shared memory (2GB)"
log_info "  ✓ ccache mounted from host (~/.ccache)"
log_success "Container is ready to build Chromium (no setup needed!)"

# Optional: Create tmpfs ramdisk for extra performance
# Uncomment and run manually if you want:
# sudo mkdir -p /mnt/ramdisk
# sudo mount -t tmpfs -o size=8G tmpfs /mnt/ramdisk

# Ensure ccache directory exists
mkdir -p "$HOME/.ccache"

# Run container with QEMU performance optimizations
# NOTE: No --rm flag - container persists between runs
# This allows continuing the build where you left off
docker run -it \
    --name chromium-arm64-builder \
    --tmpfs /tmp:rw,size=4g \
    --shm-size=2g \
    -v "$WORK_DIR":/work \
    -v "$HOME/.ccache":/home/builder/.ccache \
    -w /work \
    -e HOST_UID=$HOST_UID \
    -e HOST_GID=$HOST_GID \
    -e CCACHE_DIR=/home/builder/.ccache \
    -e CCACHE_MAXSIZE=100G \
    -e TMPDIR=/tmp \
    "$IMAGE_NAME" \
    /bin/bash

log_success "Container exited"
log_info "To continue build later, run: docker start -ai chromium-arm64-builder"
