#!/bin/bash
# Fetch minimal libvpx/libaom rate control source files for VA-API
# This script must be run during the prepare stage before GN configuration

set -euo pipefail

CHROMIUM_SRC="${1:-src/chromium-140.0.7339.207}"
LIBVPX_DIR="$CHROMIUM_SRC/third_party/libvpx/source/libvpx"
LIBVPX_INCLUDE_DIR="$CHROMIUM_SRC/third_party/libvpx/include"
LIBAOM_DIR="$CHROMIUM_SRC/third_party/libaom/source/libaom"

# Libvpx version used by Chromium 140
LIBVPX_COMMIT="ae12d1648c11163f73c63cf36f4fffe5a2d22a7e"  # libvpx main branch
LIBAOM_COMMIT="v3.11.0"  # AOM release tag

echo "Fetching libvpx RTC source files..."

# Create directories
mkdir -p "$LIBVPX_DIR/vp8"
mkdir -p "$LIBVPX_DIR/vp9"
mkdir -p "$LIBVPX_DIR/vpx"
mkdir -p "$LIBVPX_DIR/vpx/internal"
mkdir -p "$LIBVPX_DIR/vpx_util"
mkdir -p "$LIBVPX_INCLUDE_DIR/vpx/internal"
mkdir -p "$LIBAOM_DIR/av1"

# Fetch libvpx public API headers (needed for WebRTC integration)
echo "  - Fetching vpx/vpx_ext_ratectrl.h..."
curl -sL "https://raw.githubusercontent.com/webmproject/libvpx/main/vpx/vpx_ext_ratectrl.h" -o "$LIBVPX_DIR/vpx/vpx_ext_ratectrl.h"

echo "  - Fetching vpx/internal/vpx_ratectrl_rtc.h (CRITICAL for RTC)..."
curl -sL "https://raw.githubusercontent.com/webmproject/libvpx/main/vpx/internal/vpx_ratectrl_rtc.h" -o "$LIBVPX_DIR/vpx/internal/vpx_ratectrl_rtc.h"

# Mirror internal RTC header into include/ for GN shim builds using system libvpx.
cp "$LIBVPX_DIR/vpx/internal/vpx_ratectrl_rtc.h" "$LIBVPX_INCLUDE_DIR/vpx/internal/vpx_ratectrl_rtc.h"


echo "  - Fetching vpx_util/vpx_thread.h..."
curl -sL "https://raw.githubusercontent.com/webmproject/libvpx/main/vpx_util/vpx_thread.h" -o "$LIBVPX_DIR/vpx_util/vpx_thread.h"

# Fetch libvpx VP8 RTC files (using raw format)
echo "  - Fetching vp8_ratectrl_rtc.h..."
curl -sL "https://raw.githubusercontent.com/webmproject/libvpx/main/vp8/vp8_ratectrl_rtc.h" -o "$LIBVPX_DIR/vp8/vp8_ratectrl_rtc.h"

echo "  - Fetching vp8_ratectrl_rtc.cc..."
curl -sL "https://raw.githubusercontent.com/webmproject/libvpx/main/vp8/vp8_ratectrl_rtc.cc" -o "$LIBVPX_DIR/vp8/vp8_ratectrl_rtc.cc"

# Fetch libvpx VP9 RTC files
echo "  - Fetching vp9/ratectrl_rtc.h..."
curl -sL "https://raw.githubusercontent.com/webmproject/libvpx/main/vp9/ratectrl_rtc.h" -o "$LIBVPX_DIR/vp9/ratectrl_rtc.h"

echo "  - Fetching vp9/ratectrl_rtc.cc..."
curl -sL "https://raw.githubusercontent.com/webmproject/libvpx/main/vp9/ratectrl_rtc.cc" -o "$LIBVPX_DIR/vp9/ratectrl_rtc.cc"

# Fetch libaom AV1 RTC files (REQUIRED for VA-API AV1 hardware acceleration)
echo "Fetching libaom RTC source files..."

# Get libaom revision from README.chromium
LIBAOM_REVISION=$(grep "^Revision:" "$CHROMIUM_SRC/third_party/libaom/README.chromium" 2>/dev/null | awk '{print $2}')
if [[ -z "$LIBAOM_REVISION" ]]; then
    LIBAOM_REVISION="e91b7aa26d6d0979bba2bee5e1c27a7a695e0226"  # Fallback to known good revision
    echo "  Warning: Using fallback revision $LIBAOM_REVISION"
fi

echo "  - Fetching av1/ratectrl_rtc.h from Google Source..."
curl -sL "https://aomedia.googlesource.com/aom/+/${LIBAOM_REVISION}/av1/ratectrl_rtc.h?format=TEXT" | base64 -d > "$LIBAOM_DIR/av1/ratectrl_rtc.h"

echo "  - Fetching av1/ratectrl_rtc.cc from Google Source..."
curl -sL "https://aomedia.googlesource.com/aom/+/${LIBAOM_REVISION}/av1/ratectrl_rtc.cc?format=TEXT" | base64 -d > "$LIBAOM_DIR/av1/ratectrl_rtc.cc"

echo "✓ Rate control source files fetched successfully"
echo ""
echo "Files created:"
echo "  $LIBVPX_DIR/vpx/vpx_ext_ratectrl.h"
echo "  $LIBVPX_DIR/vpx/internal/vpx_ratectrl_rtc.h"
echo "  $LIBVPX_DIR/vpx_util/vpx_thread.h"
echo "  $LIBVPX_DIR/vp8/vp8_ratectrl_rtc.{h,cc}"
echo "  $LIBVPX_DIR/vp9/ratectrl_rtc.{h,cc}"
echo "  $LIBAOM_DIR/av1/ratectrl_rtc.{h,cc}"
echo ""
echo "Next steps:"
echo "  1. Apply libvpx-ratectrl.patch to unbundle/*.gn files"
echo "  2. Run GN configuration: gn gen out/Release"
echo "  3. Build VA-API: ninja -C out/Release media/gpu/vaapi"
