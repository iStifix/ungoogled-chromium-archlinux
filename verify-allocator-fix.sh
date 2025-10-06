#!/bin/bash
# Verification script for Rust allocator fix
# Run this after applying the fix to verify it worked

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/src/chromium-140.0.7339.207"
ALLOCATOR_LIB="${SRC_DIR}/build/rust/allocator/lib.rs"
ALLOCATOR_RLIB="${SRC_DIR}/out/Release/clang_x64/obj/build/rust/allocator/libbuild_srust_sallocator_callocator.rlib"

echo "================================================================================"
echo "Rust Allocator Fix Verification"
echo "================================================================================"
echo ""

# Check 1: Source file exists
echo "[1/4] Checking allocator source file..."
if [[ ! -f "$ALLOCATOR_LIB" ]]; then
    echo "❌ ERROR: Allocator source not found: $ALLOCATOR_LIB"
    echo "Run './smart-build.sh prepare' first"
    exit 1
fi
echo "✅ Source file exists"
echo ""

# Check 2: Source has both symbol versions
echo "[2/4] Checking source code for both symbol versions..."
HAS_V1=$(grep -c 'fn __rust_no_alloc_shim_is_unstable() {}' "$ALLOCATOR_LIB" || true)
HAS_V2=$(grep -c 'fn __rust_no_alloc_shim_is_unstable_v2() {}' "$ALLOCATOR_LIB" || true)

echo "   __rust_no_alloc_shim_is_unstable():    $HAS_V1 occurrence(s)"
echo "   __rust_no_alloc_shim_is_unstable_v2(): $HAS_V2 occurrence(s)"

if [[ $HAS_V1 -eq 0 ]]; then
    echo "❌ ERROR: Missing non-_v2 symbol in source"
    echo "The patch was not applied. Run './smart-build.sh prepare' to apply patches."
    exit 1
fi

if [[ $HAS_V2 -eq 0 ]]; then
    echo "❌ ERROR: Missing _v2 symbol in source"
    echo "Unexpected state - Chromium 140 should have _v2 by default"
    exit 1
fi

echo "✅ Source has both symbols"
echo ""

# Check 3: Show source context
echo "[3/4] Source code context (lines 85-100):"
sed -n '85,100p' "$ALLOCATOR_LIB" | sed 's/^/   /'
echo ""

# Check 4: Compiled rlib (if exists)
echo "[4/4] Checking compiled allocator library..."
if [[ ! -f "$ALLOCATOR_RLIB" ]]; then
    echo "⚠️  WARNING: Compiled allocator not found (not built yet)"
    echo "   Expected: $ALLOCATOR_RLIB"
    echo ""
    echo "To build the allocator, run:"
    echo "   cd src/chromium-140.0.7339.207/out/Release"
    echo "   ninja clang_x64/obj/build/rust/allocator/libbuild_srust_sallocator_callocator.rlib"
else
    echo "✅ Compiled library exists"
    echo ""
    echo "Symbols in compiled allocator:"
    nm "$ALLOCATOR_RLIB" | grep '__rust_no_alloc' | sed 's/^/   /' || true
    echo ""

    RLIB_V1=$(nm "$ALLOCATOR_RLIB" | grep -c ' __rust_no_alloc_shim_is_unstable$' || true)
    RLIB_V2=$(nm "$ALLOCATOR_RLIB" | grep -c ' __rust_no_alloc_shim_is_unstable_v2$' || true)

    if [[ $RLIB_V1 -eq 0 ]]; then
        echo "❌ ERROR: Compiled library missing non-_v2 symbol!"
        echo "Rebuild the allocator:"
        echo "   rm -rf src/chromium-140.0.7339.207/out/Release/clang_x64/obj/build/rust/allocator/"
        echo "   cd src/chromium-140.0.7339.207/out/Release"
        echo "   ninja clang_x64/obj/build/rust/allocator/libbuild_srust_sallocator_callocator.rlib"
        exit 1
    fi

    if [[ $RLIB_V2 -eq 0 ]]; then
        echo "❌ ERROR: Compiled library missing _v2 symbol!"
        echo "Rebuild the allocator (see above)"
        exit 1
    fi

    echo "✅ Compiled library has both symbols"
fi

echo ""
echo "================================================================================"
echo "Verification Summary"
echo "================================================================================"
echo "✅ Source file has both symbol versions"
if [[ -f "$ALLOCATOR_RLIB" ]]; then
    echo "✅ Compiled library has both symbol versions"
    echo ""
    echo "🎉 Allocator fix is correctly applied and compiled!"
    echo ""
    echo "You can now continue the build:"
    echo "   ./smart-build.sh compile"
else
    echo "⚠️  Allocator not compiled yet (source is patched correctly)"
    echo ""
    echo "Next steps:"
    echo "   1. Run: ./smart-build.sh compile"
    echo "   2. Or manually build: cd src/chromium-140.0.7339.207/out/Release && ninja"
fi
echo "================================================================================"
