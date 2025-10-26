#!/bin/bash
# Export preconfigured Chromium ARM64 build environment to archive
# This archive can be uploaded to GitHub and used on another machine

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
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Container and image names
CONTAINER_NAME="chromium-arm64-builder"
IMAGE_NAME="chromium-baikal-m:compile-64pct-rtc-fixed"
IMAGE_NAME_OPTIMIZED="chromium-baikal-m:optimized"
ARCHIVE_NAME="chromium-arm64-builder-prebuilt.tar.gz"

log_info "Exporting Docker image to archive for GitHub"
log_info "Container: $CONTAINER_NAME"
log_info "Image: $IMAGE_NAME"
log_info "Archive: $ARCHIVE_NAME"

# Check if container is running
if ! docker ps -q -f "name=^${CONTAINER_NAME}$" | grep -q .; then
    log_warning "Container $CONTAINER_NAME is not running"
    log_info "Looking for stopped container..."

    if ! docker ps -a -q -f "name=^${CONTAINER_NAME}$" | grep -q .; then
        log_error "Container $CONTAINER_NAME not found!"
        log_error "Please start the container first with start-arm64-docker.sh"
        exit 1
    fi

    log_info "Starting container $CONTAINER_NAME..."
    docker start "$CONTAINER_NAME"
    sleep 2
fi

# Get original image size
ORIGINAL_SIZE=$(docker images --format "{{.Size}}" "$IMAGE_NAME" 2>/dev/null || echo "N/A")
log_info "Original image size: $ORIGINAL_SIZE"

# Optimize container before commit
log_info ""
log_info "Step 1: Optimizing container (cleaning caches and documentation)..."
log_info "This will reduce image size significantly"

# Clean pacman cache
log_info "  - Cleaning pacman cache..."
docker exec "$CONTAINER_NAME" bash -c "pacman -Scc --noconfirm 2>&1 | head -5" || true

# Clean documentation
log_info "  - Removing documentation (man pages, info, locales)..."
docker exec "$CONTAINER_NAME" bash -c "rm -rf /usr/share/doc /usr/share/man /usr/share/info 2>&1" || true

# Clean additional caches
log_info "  - Cleaning additional caches..."
docker exec "$CONTAINER_NAME" bash -c "rm -rf /var/cache/pacman/pkg/* /tmp/* 2>&1" || true

log_success "Container optimized!"

# Create optimized image
log_info ""
log_info "Step 2: Creating optimized Docker image..."
log_info "Committing container as $IMAGE_NAME_OPTIMIZED..."

docker commit \
    -m "Optimized Chromium build environment (cleaned caches and docs)" \
    "$CONTAINER_NAME" \
    "$IMAGE_NAME_OPTIMIZED"

# Get optimized image size
OPTIMIZED_SIZE=$(docker images --format "{{.Size}}" "$IMAGE_NAME_OPTIMIZED")
log_success "Optimized image created: $IMAGE_NAME_OPTIMIZED"
log_success "New size: $OPTIMIZED_SIZE (was: $ORIGINAL_SIZE)"

# Export optimized image
log_info ""
log_info "Step 3: Exporting optimized image to archive..."
log_info "This will take several minutes (compressing with gzip -9)..."
log_info "Progress: docker save $IMAGE_NAME_OPTIMIZED -> gzip -9 -> $ARCHIVE_NAME"

docker save "$IMAGE_NAME_OPTIMIZED" | gzip -9 > "$ARCHIVE_NAME"

# Check result
if [[ -f "$ARCHIVE_NAME" ]]; then
    ARCHIVE_SIZE=$(du -h "$ARCHIVE_NAME" | cut -f1)
    log_success "Archive created: $ARCHIVE_NAME"
    log_success "Archive size: $ARCHIVE_SIZE"

    log_info ""
    log_success "=== Optimization Summary ==="
    log_info "Original image:  $ORIGINAL_SIZE ($IMAGE_NAME)"
    log_info "Optimized image: $OPTIMIZED_SIZE ($IMAGE_NAME_OPTIMIZED)"
    log_info "Archive:         $ARCHIVE_SIZE (compressed)"
    log_info ""
    log_info "Optimizations applied:"
    log_info "  ✓ Cleaned pacman cache"
    log_info "  ✓ Removed man pages, documentation, locales"
    log_info "  ✓ Cleaned temporary files"

    log_info ""
    log_info "Upload to GitHub:"
    log_info "1. Create GitHub Release"
    log_info "2. Attach $ARCHIVE_NAME as release asset"
    log_info "3. Or use Git LFS if you have it configured"
    log_info ""
    log_info "Download on another machine:"
    log_info "wget https://github.com/YOUR_USER/YOUR_REPO/releases/download/TAG/$ARCHIVE_NAME"
    log_info ""
    log_info "Import on another machine:"
    log_info "./import-docker-image.sh $ARCHIVE_NAME"
else
    log_error "Failed to create archive"
    exit 1
fi
