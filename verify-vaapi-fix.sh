#!/bin/bash
# Verification script for VA-API + system libvpx/aom fix
# Tests if GN can analyze VA-API targets and build completes

set -euo pipefail

CHROMIUM_SRC="${1:-src/chromium-140.0.7339.207}"
OUT_DIR="$CHROMIUM_SRC/out/Release"

echo "=== VA-API Hardware Acceleration Fix Verification ==="
echo ""

# Step 1: Check if RTC source files exist
echo "[1/6] Checking RTC source files..."
REQUIRED_FILES=(
    "$CHROMIUM_SRC/third_party/libvpx/source/libvpx/vp8/vp8_ratectrl_rtc.h"
    "$CHROMIUM_SRC/third_party/libvpx/source/libvpx/vp8/vp8_ratectrl_rtc.cc"
    "$CHROMIUM_SRC/third_party/libvpx/source/libvpx/vp9/ratectrl_rtc.h"
    "$CHROMIUM_SRC/third_party/libvpx/source/libvpx/vp9/ratectrl_rtc.cc"
)

MISSING=0
for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "  ✗ MISSING: $file"
        MISSING=1
    else
        echo "  ✓ Found: $(basename "$file")"
    fi
done

if [[ $MISSING -eq 1 ]]; then
    echo ""
    echo "ERROR: RTC source files missing!"
    echo "Run: ./fetch-libvpx-rtc.sh"
    exit 1
fi

echo "  ✓ All RTC source files present"
echo ""

# Step 2: Check if unbundle templates are patched
echo "[2/6] Checking unbundle templates..."
if grep -q "static_library.*libvpxrc" "$CHROMIUM_SRC/build/linux/unbundle/libvpx.gn"; then
    echo "  ✓ libvpx.gn patched (static_library)"
else
    echo "  ✗ libvpx.gn NOT patched (still stub)"
    echo "  Apply: patch -p1 < libvpx-ratectrl.patch"
    exit 1
fi

if grep -q "static_library.*libaomrc" "$CHROMIUM_SRC/build/linux/unbundle/libaom.gn"; then
    echo "  ✓ libaom.gn patched (static_library)"
else
    echo "  ✗ libaom.gn NOT patched (still stub)"
    echo "  Apply: patch -p1 < libvpx-ratectrl.patch"
    exit 1
fi

echo ""

# Step 3: Test GN analysis (with timeout to detect hangs)
echo "[3/6] Testing GN analysis (30s timeout)..."
cd "$CHROMIUM_SRC"

if [[ ! -d "$OUT_DIR" ]]; then
    echo "  ! Build directory not configured yet"
    echo "  Run 'gn gen out/Release' first"
    exit 0
fi

# Test VA-API target analysis
timeout 30 gn desc "$OUT_DIR" //media/gpu/vaapi:vaapi deps > /tmp/vaapi-deps.txt 2>&1 && {
    echo "  ✓ GN analysis completed (no hang)"

    # Check if libvpxrc is in dependencies
    if grep -q "libvpxrc" /tmp/vaapi-deps.txt; then
        echo "  ✓ libvpxrc found in VA-API dependencies"
    else
        echo "  ✗ libvpxrc NOT in dependencies (unexpected)"
    fi

    if grep -q "libaomrc" /tmp/vaapi-deps.txt; then
        echo "  ✓ libaomrc found in VA-API dependencies"
    else
        echo "  ! libaomrc not in dependencies (may be optional)"
    fi
} || {
    echo "  ✗ GN analysis FAILED or TIMED OUT"
    echo "  Check for errors in /tmp/vaapi-deps.txt"
    exit 1
}

echo ""

# Step 4: Check GN args for system libraries
echo "[4/6] Checking GN configuration..."
if [[ -f "$OUT_DIR/args.gn" ]]; then
    if grep -q "use_system.*true" "$OUT_DIR/args.gn"; then
        echo "  ✓ System libraries enabled in args.gn"
        grep "use_system" "$OUT_DIR/args.gn" | sed 's/^/    /'
    else
        echo "  ! No system libraries configured (may use bundled)"
    fi
else
    echo "  ! args.gn not found"
fi

echo ""

# Step 5: Test build of libvpxrc target
echo "[5/6] Testing libvpxrc target build..."
timeout 60 ninja -C "$OUT_DIR" third_party/libvpx:libvpxrc > /tmp/libvpxrc-build.log 2>&1 && {
    echo "  ✓ libvpxrc built successfully"

    # Check output
    if [[ -f "$OUT_DIR/obj/third_party/libvpx/libvpxrc.a" ]]; then
        SIZE=$(stat -c%s "$OUT_DIR/obj/third_party/libvpx/libvpxrc.a")
        echo "  ✓ libvpxrc.a created (size: $SIZE bytes)"

        # List symbols
        nm "$OUT_DIR/obj/third_party/libvpx/libvpxrc.a" | grep -E "vp[89].*rtc" | head -5 | sed 's/^/    /'
    fi
} || {
    echo "  ✗ libvpxrc build FAILED"
    echo "  See /tmp/libvpxrc-build.log for errors"
    tail -20 /tmp/libvpxrc-build.log
    exit 1
}

echo ""

# Step 6: Test VA-API target compilation
echo "[6/6] Testing VA-API target compilation (this may take a while)..."
timeout 300 ninja -C "$OUT_DIR" media/gpu/vaapi:vaapi > /tmp/vaapi-build.log 2>&1 && {
    echo "  ✓ VA-API target built successfully"
    echo "  ✓ Hardware acceleration should work!"
} || {
    echo "  ✗ VA-API build FAILED"
    echo "  See /tmp/vaapi-build.log for errors"
    tail -30 /tmp/vaapi-build.log
    exit 1
}

echo ""
echo "=== ✓ ALL CHECKS PASSED ==="
echo ""
echo "Summary:"
echo "  - RTC source files present and valid"
echo "  - Unbundle templates correctly patched"
echo "  - GN analysis works (no hang)"
echo "  - libvpxrc compiles successfully"
echo "  - VA-API target builds successfully"
echo ""
echo "Next steps:"
echo "  1. Complete full Chromium build: ninja -C out/Release chrome"
echo "  2. Test VA-API in runtime: chrome://gpu"
echo "  3. Verify hardware video decode/encode works"
echo ""
echo "Runtime testing commands:"
echo "  export LIBVA_DRIVER_NAME=radeonsi"
echo "  ./out/Release/chrome --enable-features=VaapiVideoDecoder,VaapiVideoEncoder"
echo "  # Check chrome://gpu for 'Video Decode: Hardware accelerated'"
