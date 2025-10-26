#!/bin/bash
# Split large archive into parts for GitHub Release upload
# GitHub has 2GB limit per file, so we split into 1.9GB parts

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

ARCHIVE_NAME="chromium-arm64-builder-prebuilt.tar.gz"

log_info "Splitting archive for GitHub Release upload"
log_info "Archive: $ARCHIVE_NAME"
log_info "Part size: 1900 MB (GitHub limit: 2048 MB)"

# Check if archive exists
if [[ ! -f "$ARCHIVE_NAME" ]]; then
    log_error "Archive not found: $ARCHIVE_NAME"
    log_error "Run ./export-docker-image.sh first"
    exit 1
fi

# Get archive size
ARCHIVE_SIZE=$(du -h "$ARCHIVE_NAME" | cut -f1)
ARCHIVE_SIZE_MB=$(du -m "$ARCHIVE_NAME" | cut -f1)

log_info "Archive size: $ARCHIVE_SIZE ($ARCHIVE_SIZE_MB MB)"

if [[ $ARCHIVE_SIZE_MB -le 2048 ]]; then
    log_success "Archive is small enough for GitHub (<2GB)"
    log_success "No need to split - upload $ARCHIVE_NAME directly"
    exit 0
fi

log_info "Archive is too large for GitHub (>2GB), splitting..."

# Split into 1900MB parts
split -b 1900M "$ARCHIVE_NAME" "${ARCHIVE_NAME}.part-"

# List parts
PARTS=$(ls "${ARCHIVE_NAME}.part-"* 2>/dev/null || true)
if [[ -z "$PARTS" ]]; then
    log_error "No parts created!"
    exit 1
fi

log_success "Archive split into parts:"
for part in $PARTS; do
    PART_SIZE=$(du -h "$part" | cut -f1)
    echo "  - $part ($PART_SIZE)"
done

log_info ""
log_info "Upload to GitHub Release:"
log_info "1. Create new Release on GitHub"
log_info "2. Attach ALL parts as release assets:"
for part in $PARTS; do
    echo "   - $part"
done

log_info ""
log_info "To reconstruct on another machine:"
log_info "cat ${ARCHIVE_NAME}.part-* > $ARCHIVE_NAME"
log_info "./import-docker-image.sh $ARCHIVE_NAME"
