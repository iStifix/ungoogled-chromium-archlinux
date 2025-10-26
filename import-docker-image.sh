#!/bin/bash
# Import preconfigured Chromium ARM64 build environment from archive
# Use this on a new machine after downloading from GitHub

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

# Archive name
ARCHIVE_NAME="${1:-chromium-arm64-builder-prebuilt.tar.gz}"

log_info "Importing Docker image from archive"
log_info "Archive: $ARCHIVE_NAME"

# Check if archive exists
if [[ ! -f "$ARCHIVE_NAME" ]]; then
    log_error "Archive not found: $ARCHIVE_NAME"
    log_error "Usage: $0 [archive_name.tar.gz]"
    log_error "Download from GitHub first!"
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

# Import image
log_info "Importing image (this will take several minutes)..."
log_info "Progress: gunzip -> docker load"

gunzip -c "$ARCHIVE_NAME" | docker load

# Verify
IMAGE_NAME="chromium-baikal-m:compile-64pct-rtc-fixed"
if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${IMAGE_NAME}$"; then
    IMAGE_SIZE=$(docker images --format "{{.Size}}" "$IMAGE_NAME")
    log_success "Image imported: $IMAGE_NAME"
    log_success "Image size: $IMAGE_SIZE"
    log_info ""
    log_info "Start container:"
    log_info "./start-arm64-docker-prebuilt.sh"
else
    log_error "Image import failed"
    exit 1
fi
