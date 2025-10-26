#!/bin/bash
# Join split archive parts from GitHub Release
# Use this after downloading all parts from GitHub

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

ARCHIVE_NAME="chromium-arm64-builder-prebuilt.tar.gz"

log_info "Joining archive parts from GitHub Release"
log_info "Target archive: $ARCHIVE_NAME"

# Check if parts exist
PARTS=$(ls "${ARCHIVE_NAME}.part-"* 2>/dev/null || true)
if [[ -z "$PARTS" ]]; then
    log_error "No parts found!"
    log_error "Expected files: ${ARCHIVE_NAME}.part-aa, ${ARCHIVE_NAME}.part-ab, ..."
    log_error ""
    log_error "Download from GitHub Release first:"
    log_error "  wget https://github.com/YOUR_USER/YOUR_REPO/releases/download/TAG/${ARCHIVE_NAME}.part-aa"
    log_error "  wget https://github.com/YOUR_USER/YOUR_REPO/releases/download/TAG/${ARCHIVE_NAME}.part-ab"
    exit 1
fi

log_info "Found parts:"
for part in $PARTS; do
    PART_SIZE=$(du -h "$part" | cut -f1)
    echo "  - $part ($PART_SIZE)"
done

# Check if target archive already exists
if [[ -f "$ARCHIVE_NAME" ]]; then
    log_warning "Archive $ARCHIVE_NAME already exists"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        exit 0
    fi
    rm -f "$ARCHIVE_NAME"
fi

# Join parts
log_info "Joining parts..."
cat "${ARCHIVE_NAME}.part-"* > "$ARCHIVE_NAME"

# Verify
if [[ -f "$ARCHIVE_NAME" ]]; then
    ARCHIVE_SIZE=$(du -h "$ARCHIVE_NAME" | cut -f1)
    log_success "Archive created: $ARCHIVE_NAME"
    log_success "Archive size: $ARCHIVE_SIZE"
    log_info ""
    log_info "Next steps:"
    log_info "1. Import Docker image: ./import-docker-image.sh $ARCHIVE_NAME"
    log_info "2. Start container: ./start-arm64-docker-prebuilt.sh"
    log_info ""
    log_info "Optional: Remove parts to save disk space"
    log_info "  rm ${ARCHIVE_NAME}.part-*"
else
    log_error "Failed to create archive"
    exit 1
fi
