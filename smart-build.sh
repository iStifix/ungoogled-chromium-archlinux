#!/bin/bash
# Smart incremental build script for ungoogled-chromium-baikal
# Supports partial rebuilds and selective compilation

set -euo pipefail

# Export Rust environment variables GLOBALLY at the start
# These must be set before ANY Rust compilation happens
export RUSTC_BOOTSTRAP=1
export RUSTUP_HOME=/opt/rust
export CARGO_HOME=/opt/rust
export PATH="/opt/rust/bin:$PATH"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_stage() {
    echo -e "${CYAN}[STAGE]${NC} $1"
}

# Check if we're in the right directory
if [[ ! -f "PKGBUILD" ]]; then
    log_error "Please run this script from the ungoogled-chromium-archlinux directory"
    log_error "PKGBUILD file not found"
    exit 1
fi

# Load Cortex-A57 optimizations
if [[ -f "cortex-a57-env.sh" ]]; then
    source cortex-a57-env.sh
else
    log_warning "cortex-a57-env.sh not found - building without Cortex-A57 optimizations"
fi

# Smart build system - uses makepkg directly for all operations

# Set architecture
export ARCH=aarch64

# Build configuration
CHROMIUM_VERSION="140.0.7339.207"
SRC_DIR="src/chromium-${CHROMIUM_VERSION}"
OUT_DIR="${SRC_DIR}/out/Release"
STATE_DIR=".build"
TIMESTAMPS_FILE="${STATE_DIR}/timestamps"

# Create state directory
mkdir -p "$STATE_DIR"

# Function to get file modification time
get_mtime() {
    local file="$1"
    if [[ -f "$file" ]]; then
        stat -c %Y "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to check if rebuild is needed
check_rebuild_needed() {
    local component="$1"
    local check_files=("${@:2}")

    # If timestamps file doesn't exist, full rebuild needed
    if [[ ! -f "$TIMESTAMPS_FILE" ]]; then
        echo "true"
        return
    fi

    # Get last build time for component
    local last_build=$(grep "^${component}:" "$TIMESTAMPS_FILE" 2>/dev/null | cut -d: -f2 || echo "0")

    # Check if any of the files are newer than last build
    for file in "${check_files[@]}"; do
        if [[ $(get_mtime "$file") -gt $last_build ]]; then
            echo "true"
            return
        fi
    done

    echo "false"
}

# Function to update timestamp
update_timestamp() {
    local component="$1"
    local current_time=$(date +%s)

    # Remove old entry and add new one
    if [[ -f "$TIMESTAMPS_FILE" ]]; then
        grep -v "^${component}:" "$TIMESTAMPS_FILE" > "${TIMESTAMPS_FILE}.tmp" || true
        mv "${TIMESTAMPS_FILE}.tmp" "$TIMESTAMPS_FILE"
    fi

    echo "${component}:${current_time}" >> "$TIMESTAMPS_FILE"
}

# Function to show build status
show_build_status() {
    log_info "Build Status Dashboard"
    echo "===================="

    # Check each component
    local components=("prepare" "sysroot" "configure" "compile" "package")

    for comp in "${components[@]}"; do
        local status="❌ Not done"
        if [[ -f "$TIMESTAMPS_FILE" ]] && grep -q "^${comp}:" "$TIMESTAMPS_FILE"; then
            local timestamp=$(grep "^${comp}:" "$TIMESTAMPS_FILE" | cut -d: -f2)
            local date_str=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")
            status="✅ Done ($date_str)"
        fi
        printf "%-12s: %s\n" "$comp" "$status"
    done

    echo ""

    # Show disk usage
    if [[ -d "$SRC_DIR" ]]; then
        local src_size=$(du -sh "$SRC_DIR" 2>/dev/null | cut -f1 || echo "Unknown")
        log_info "Source directory size: $src_size"
    fi

    if [[ -d "$OUT_DIR" ]]; then
        local out_size=$(du -sh "$OUT_DIR" 2>/dev/null | cut -f1 || echo "Unknown")
        log_info "Build output size: $out_size"
    fi

    # Show available space
    local available=$(df -h . | awk 'NR==2 {print $4}')
    log_info "Available disk space: $available"
}

# Function to prepare environment
stage_prepare() {
    log_stage "STAGE 1: Prepare Environment"

    local build_files=("PKGBUILD" "*.patch" "baikal-chromium-*")
    local need_rebuild=$(check_rebuild_needed "prepare" "${build_files[@]}")

    # Check if essential files are missing (domain substitution fixes)
    local missing_files=false
    if [[ -d "$SRC_DIR" ]]; then
        if [[ ! -f "$SRC_DIR/v8/tools/builtins-pgo/profiles/meta.json" ]] || \
           [[ ! -e "$SRC_DIR/third_party/harfbuzz-subset" ]] || \
           [[ ! -f "$SRC_DIR/third_party/rust-toolchain/VERSION" ]] || \
           [[ ! -f "$SRC_DIR/third_party/llvm-build/Release+Asserts/cr_build_revision" ]]; then
            missing_files=true
        fi
    fi

    # If no rebuild needed, patches applied, and no missing files, skip completely
    if [[ "$need_rebuild" == "false" ]] && [[ -d "$SRC_DIR" ]] && [[ -f "$SRC_DIR/.patches_applied" ]] && [[ "$missing_files" == "false" ]]; then
        log_success "Prepare stage: UP TO DATE (skipping)"
        return 0
    fi

    log_info "Preparing build environment..."

    # Set up environment for ARM64 cross-compilation
    export ARCH=aarch64

    # Use makepkg directly with ARM64 configuration
    if [[ -f ".makepkg-aarch64.conf" ]]; then
        MAKEPKG_CONF=".makepkg-aarch64.conf"
    else
        MAKEPKG_CONF="/etc/makepkg.conf"
    fi

    # Check if sources are already extracted and patched
    local patches_applied=false
    if [[ -d "$SRC_DIR" ]] && [[ -f "$SRC_DIR/.patches_applied" ]]; then
        patches_applied=true
        log_info "Sources already extracted and patched, skipping extraction..."
    fi

    if [[ "$patches_applied" == "true" ]]; then
        # Sources already prepared, just apply domain substitution fixes if needed
        if [[ "$missing_files" == "true" ]]; then
            log_info "Applying missing domain substitution fixes..."

            # Create missing meta.json file
            if [[ -d "$SRC_DIR/v8/tools/builtins-pgo/profiles" ]] && [[ ! -f "$SRC_DIR/v8/tools/builtins-pgo/profiles/meta.json" ]]; then
                echo '{}' > "$SRC_DIR/v8/tools/builtins-pgo/profiles/meta.json"
                echo "✓ Created $SRC_DIR/v8/tools/builtins-pgo/profiles/meta.json"
            fi

            # Create harfbuzz-subset symlink
            if [[ -d "$SRC_DIR/third_party/harfbuzz-ng" ]] && [[ ! -e "$SRC_DIR/third_party/harfbuzz-subset" ]]; then
                cd "$SRC_DIR/third_party"
                ln -sf harfbuzz-ng harfbuzz-subset
                cd - > /dev/null
                echo "✓ Created symlink $SRC_DIR/third_party/harfbuzz-subset -> harfbuzz-ng"
            fi

            # Create rust-toolchain VERSION file and symlinks
            if [[ -d "$SRC_DIR/third_party/rust-toolchain" ]] && [[ ! -f "$SRC_DIR/third_party/rust-toolchain/VERSION" ]]; then
                echo "rustc 1.86.0 stable" > "$SRC_DIR/third_party/rust-toolchain/VERSION"
                echo "✓ Created $SRC_DIR/third_party/rust-toolchain/VERSION"
            fi

            # Create symlinks to system Rust toolchain (needed for rust-src)
            if [[ -d "$SRC_DIR/third_party/rust-toolchain" ]]; then
                # Get Rust version and determine sysroot
                local rustc_version=$(rustc --version 2>/dev/null | awk '{print $2}' || echo "1.86.0")
                # Prefer /opt/rust for Docker builds (accessible to builder user)
                local rust_sysroot="/opt/rust/toolchains/${rustc_version}-x86_64-unknown-linux-gnu"
                if [[ ! -d "$rust_sysroot" ]]; then
                    # Fallback to rustc sysroot if /opt/rust doesn't exist
                    rust_sysroot=$(rustc --print sysroot 2>/dev/null || echo "")
                fi

                if [[ -n "$rust_sysroot" ]] && [[ -d "$rust_sysroot" ]]; then
                    # Create symlink for rust-src library directory
                    if [[ ! -e "$SRC_DIR/third_party/rust-toolchain/lib" ]]; then
                        mkdir -p "$SRC_DIR/third_party/rust-toolchain/lib/rustlib/src"
                        ln -sf "$rust_sysroot/lib/rustlib/src/rust" "$SRC_DIR/third_party/rust-toolchain/lib/rustlib/src/rust"
                        echo "✓ Created symlink $SRC_DIR/third_party/rust-toolchain/lib/rustlib/src/rust -> $rust_sysroot/lib/rustlib/src/rust"
                    fi

                    # Ensure rust-src component is installed
                    if ! rustup component list | grep -q "rust-src (installed)"; then
                        log_info "Installing rust-src component..."
                        rustup component add rust-src
                        echo "✓ Installed rust-src component"
                    fi
                fi
            fi

            # Create llvm-build revision file for system clang
            if [[ ! -d "$SRC_DIR/third_party/llvm-build/Release+Asserts" ]]; then
                mkdir -p "$SRC_DIR/third_party/llvm-build/Release+Asserts"
            fi
            if [[ ! -f "$SRC_DIR/third_party/llvm-build/Release+Asserts/cr_build_revision" ]]; then
                clang --version | head -1 | sed 's/.*version \([0-9.]*\).*/\1/' > "$SRC_DIR/third_party/llvm-build/Release+Asserts/cr_build_revision"
                echo "✓ Created $SRC_DIR/third_party/llvm-build/Release+Asserts/cr_build_revision"
            fi

            # Ensure rustup default is set (needed for rustc to work)
            if ! rustc --version >/dev/null 2>&1; then
                log_info "Setting rustup default toolchain to 1.86.0..."
                rustup default 1.86.0
                echo "✓ Set rustup default to 1.86.0"
            fi

            # Ensure rust-src component is installed (needed for stdlib)
            if ! rustup component list --installed 2>/dev/null | grep -q "rust-src"; then
                log_info "Installing rust-src component..."
                rustup component add rust-src
                echo "✓ Installed rust-src component"
            fi

            # Ensure aarch64 target is installed (needed for cross-compilation)
            if ! rustup target list --installed 2>/dev/null | grep -q "aarch64-unknown-linux-gnu"; then
                log_info "Installing aarch64-unknown-linux-gnu target..."
                rustup target add aarch64-unknown-linux-gnu
                echo "✓ Installed aarch64-unknown-linux-gnu target"
            fi

            # Update rust-toolchain VERSION with actual rustc version
            if [[ -d "$SRC_DIR/third_party/rust-toolchain" ]]; then
                local actual_rustc_version=$(rustc --version 2>/dev/null || echo "rustc 1.86.0")
                echo "$actual_rustc_version" > "$SRC_DIR/third_party/rust-toolchain/VERSION"
                echo "✓ Updated $SRC_DIR/third_party/rust-toolchain/VERSION to: $actual_rustc_version"
            fi
        fi

        update_timestamp "prepare"
        log_success "Prepare stage: COMPLETED (reused existing sources)"
    else
        # Fresh extraction and patching needed
        # If sources exist but patches failed before, clean them selectively
        if [[ -d "$SRC_DIR" ]] && [[ ! -f "$SRC_DIR/.patches_applied" ]]; then
            log_info "Cleaning partially prepared sources (preserving git repos)..."
            # Remove chromium source but preserve git checkouts
            if [[ -d "src/chromium-checkout" ]]; then
                # Preserve git checkout, only remove chromium source
                rm -rf "$SRC_DIR"
                rm -rf src/ungoogled-chromium-*
                rm -rf src/chromium-launcher-*
            else
                # No git checkout to preserve, remove everything
                rm -rf src/
            fi
        fi

        if MAKEPKG_CONF="$MAKEPKG_CONF" makepkg --nobuild --skipinteg --nodeps; then
            # Mark patches as applied
            touch "$SRC_DIR/.patches_applied"

            update_timestamp "prepare"
            log_success "Prepare stage: COMPLETED"
        else
            log_error "Prepare stage: FAILED"
            return 1
        fi
    fi
}

# Function to fix sysroot
stage_sysroot() {
    log_stage "STAGE 2: Fix ARM64 Sysroot"

    local target_sysroot="${SRC_DIR}/build/linux/debian_bullseye_arm64-sysroot"
    local target_marker="${target_sysroot}/etc/debian_version"
    local target_opus_pc="${target_sysroot}/usr/lib/pkgconfig/opus.pc"
    local target_ready=true

    if [[ ! -d "${target_sysroot}" ]] || [[ ! -f "${target_marker}" ]] || [[ ! -f "${target_opus_pc}" ]]; then
        target_ready=false
    fi

    local host_ready=true
    local host_sysroot="${SRC_DIR}/build/linux/debian_bullseye_amd64-sysroot"
    local build_arch=$(uname -m)
    if [[ "${build_arch}" =~ ^(x86_64|amd64)$ ]]; then
        if [[ ! -f "${host_sysroot}/etc/debian_version" ]]; then
            host_ready=false
        fi
    fi

    # Check if sysroot stage is already complete
    if [[ "$target_ready" == "true" ]] && [[ "$host_ready" == "true" ]]; then
        log_success "Sysroot stage: UP TO DATE (skipping)"
        return 0
    fi

    log_info "Fixing ARM64 sysroot dependencies..."

    # Create symlink for clang resource directory to fix relative path issues
    local clang_version=$(clang --version | head -1 | sed 's/.*version \([0-9]*\).*/\1/' || echo "21")
    local clang_link_path="${SRC_DIR}/usr/lib/clang/${clang_version}"
    if [[ ! -e "$clang_link_path" ]]; then
        mkdir -p "${SRC_DIR}/usr/lib/clang"
        ln -sf "/usr/lib/clang/${clang_version}" "$clang_link_path"
        log_info "Created symlink for clang resource directory: $clang_link_path -> /usr/lib/clang/${clang_version}"
    fi

    if [[ "$target_ready" == "false" ]]; then
        log_info "Downloading/updating Debian ARM64 sysroot..."
        if (cd "$SRC_DIR" && python3 build/linux/sysroot_scripts/install-sysroot.py --arch=arm64); then
            log_success "Downloaded Debian ARM64 sysroot"
        else
            log_error "Failed to download Debian ARM64 sysroot"
            return 1
        fi
    fi

    if [[ "$host_ready" == "false" ]]; then
        log_info "Downloading/updating Debian AMD64 sysroot (host)..."
        if (cd "$SRC_DIR" && python3 build/linux/sysroot_scripts/install-sysroot.py --arch=amd64); then
            log_success "Downloaded Debian AMD64 sysroot"
        else
            log_error "Failed to download Debian AMD64 sysroot"
            return 1
        fi
    fi

    # Fix bindgen clang resource-dir to use absolute path
    local bindgen_gni="${SRC_DIR}/build/rust/rust_bindgen_generator.gni"
    if [[ -f "$bindgen_gni" ]]; then
        if grep -q 'rebase_path(clang_base_path + "/lib/clang/"' "$bindgen_gni"; then
            log_info "Patching rust_bindgen_generator.gni to use absolute clang resource-dir..."
            sed -i '/clang_resource_dir =/,/root_build_dir)/c\    # Patched for cross-compilation: use absolute path instead of relative\n    # because bindgen with relative paths cannot find clang headers\n    clang_resource_dir = clang_base_path + "/lib/clang/" + clang_version' "$bindgen_gni"
            log_success "Patched rust_bindgen_generator.gni"
        else
            log_info "rust_bindgen_generator.gni already patched"
        fi
    fi

    # Remove unicode_width from stdlib_files (removed in Rust nightly)
    local rust_std_build="${SRC_DIR}/build/rust/std/BUILD.gn"
    if [[ -f "$rust_std_build" ]]; then
        if grep -q '"unicode_width",' "$rust_std_build"; then
            log_info "Removing unicode_width from Rust stdlib list (integrated into std in nightly)..."
            sed -i 's/"unicode_width",/# "unicode_width",  # Removed in Rust nightly, integrated into std/' "$rust_std_build"
            log_success "Patched build/rust/std/BUILD.gn"
        else
            log_info "build/rust/std/BUILD.gn already patched"
        fi
    fi

    # Patch run_build_script.py to pass PATH to build scripts
    # Prepend rustc directory to PATH so build scripts use actual rustc, not rustup proxy
    local run_build_script="${SRC_DIR}/build/rust/gni_impl/run_build_script.py"
    if [[ -f "$run_build_script" ]]; then
        if ! grep -q '# Patched: Add PATH' "$run_build_script"; then
            log_info "Patching run_build_script.py to pass PATH environment..."
            # Use a temporary file for complex multi-line sed
            sed -i '/env\["CARGO_MANIFEST_DIR"\] = os.path.abspath(args.src_dir)/a\    # Patched: Add PATH so build scripts can find rustc (needed for rustversion)\n    # Prepend the rustc binary directory to PATH so build scripts use the actual\n    # rustc binary, not the rustup proxy\n    rustc_dir = os.path.dirname(os.path.abspath(rustc_path))\n    if "PATH" in os.environ:\n      env["PATH"] = rustc_dir + ":" + os.environ["PATH"]\n    else:\n      env["PATH"] = rustc_dir\n    if "RUSTUP_HOME" in os.environ:\n      env["RUSTUP_HOME"] = os.environ["RUSTUP_HOME"]\n    if "CARGO_HOME" in os.environ:\n      env["CARGO_HOME"] = os.environ["CARGO_HOME"]' "$run_build_script"
            log_success "Patched build/rust/gni_impl/run_build_script.py"
        else
            log_info "run_build_script.py already patched"
        fi
    fi

    # Patch rustc_wrapper.py to pass RUSTC_BOOTSTRAP environment variable
    # This is needed to allow stable Rust to use -Z flags (nightly features)
    local rustc_wrapper="${SRC_DIR}/build/rust/gni_impl/rustc_wrapper.py"
    if [[ -f "$rustc_wrapper" ]]; then
        if ! grep -q 'RUSTC_BOOTSTRAP' "$rustc_wrapper"; then
            log_info "Patching rustc_wrapper.py to pass RUSTC_BOOTSTRAP..."
            # Find the line with 'env = os.environ.copy()' and add RUSTC_BOOTSTRAP after it
            # Python uses 2-space indentation in this file
            sed -i '/env = os.environ.copy()/a\  # Patched: Allow stable Rust to use -Z flags\n  env["RUSTC_BOOTSTRAP"] = "1"' "$rustc_wrapper"
            log_success "Patched build/rust/gni_impl/rustc_wrapper.py"
        else
            log_info "rustc_wrapper.py already patched"
        fi
    fi

    # Patch Rust allocator for multiple Rust versions (adds both alloc shim symbols)
    # Chromium 140 has _v2 by default, but Rust 1.86.0 stable stdlib expects non-_v2
    local allocator_lib="${SRC_DIR}/build/rust/allocator/lib.rs"
    if [[ -f "$allocator_lib" ]]; then
        # Check if we need to add the non-_v2 version (for Rust 1.86.0 stable)
        if ! grep -q 'fn __rust_no_alloc_shim_is_unstable() {}' "$allocator_lib"; then
            log_info "Patching Rust allocator for Rust 1.86.0 stable compatibility..."

            # Add non-_v2 version of alloc shim (before the _v2 version)
            # The allocator already has __rust_alloc_error_handler_should_panic (non-_v2)
            # but is missing __rust_no_alloc_shim_is_unstable (non-_v2)
            sed -i '/fn __rust_no_alloc_shim_is_unstable_v2() {}/i\
    /// Stable Rust 1.86.0 stdlib expects this symbol (without _v2)\n    #[rustc_std_internal_symbol]\n    #[linkage = "weak"]\n    fn __rust_no_alloc_shim_is_unstable() {}\n' "$allocator_lib"

            log_success "Added __rust_no_alloc_shim_is_unstable to build/rust/allocator/lib.rs"
        else
            log_info "build/rust/allocator/lib.rs already has both alloc shim symbol versions"
        fi
    fi

    # Fix HarfBuzz submodule after domain substitution
    # Domain substitution removes all source files from harfbuzz-ng/src
    # We need to restore them from the git submodule
    local harfbuzz_src="${SRC_DIR}/third_party/harfbuzz-ng/src"
    if [[ -d "$harfbuzz_src" ]] && [[ ! -f "$harfbuzz_src/src/hb-cplusplus.hh" ]]; then
        log_info "Restoring HarfBuzz submodule after domain substitution..."
        (
            cd "$SRC_DIR"
            rm -rf third_party/harfbuzz-ng/src
            git submodule update --init --recursive third_party/harfbuzz-ng/src
        )
        if [[ -f "$harfbuzz_src/src/hb-cplusplus.hh" ]]; then
            log_success "Restored HarfBuzz source files from git submodule"
        else
            log_error "Failed to restore HarfBuzz submodule"
            return 1
        fi
    else
        log_info "HarfBuzz submodule already present"
    fi

    # Disable use_system_harfbuzz because system version is too old
    local harfbuzz_gni="${SRC_DIR}/third_party/harfbuzz-ng/harfbuzz.gni"
    if [[ -f "$harfbuzz_gni" ]]; then
        if grep -q "use_system_harfbuzz = true" "$harfbuzz_gni"; then
            log_info "Disabling use_system_harfbuzz (system version too old)..."
            sed -i 's/use_system_harfbuzz = true/use_system_harfbuzz = false  # Disabled: system harfbuzz too old/' "$harfbuzz_gni"
            log_success "Disabled use_system_harfbuzz in harfbuzz.gni"
        else
            log_info "use_system_harfbuzz already disabled"
        fi
    fi

    # libxml2/libxslt const incompatibility is avoided by using bundled versions
    # (removed from system-libraries list above)

    # Disable BrotliDecoderAttachDictionary for old Brotli (Debian Bullseye)
    # System Brotli doesn't have BrotliDecoderAttachDictionary function
    local brotli_source="${SRC_DIR}/net/filter/brotli_source_stream.cc"
    if [[ -f "$brotli_source" ]] && grep -q "BrotliDecoderAttachDictionary" "$brotli_source" | head -1 | grep -qv "^//"; then
        log_info "Disabling BrotliDecoderAttachDictionary for old Brotli..."
        # Comment out the dictionary attachment code (lines 45-50)
        sed -i '/if (dictionary_) {/,/CHECK(result);/s/^/\/\/ DISABLED for old Brotli: /' "$brotli_source"
        log_success "Disabled BrotliDecoderAttachDictionary in brotli_source_stream.cc"
    else
        log_info "BrotliDecoderAttachDictionary already disabled or not needed"
    fi

    # Additional AMD64 sysroot fixes for host build tools
    local host_sysroot_pkgconfig="${SRC_DIR}/build/linux/debian_bullseye_amd64-sysroot/usr/lib/pkgconfig"

    # Update harfbuzz to match system version (Debian Bullseye has 2.7.4, we need 12.0.0+)
    if [[ -d "${host_sysroot_pkgconfig}" ]]; then
        if [[ -f "/usr/lib/pkgconfig/harfbuzz.pc" ]]; then
            install -Dm644 /usr/lib/pkgconfig/harfbuzz.pc "${host_sysroot_pkgconfig}/harfbuzz.pc"
            log_info "Updated harfbuzz.pc in AMD64 sysroot from host system"
        fi
    fi

    if [[ -d "${host_sysroot_pkgconfig}" ]] && [[ ! -f "${host_sysroot_pkgconfig}/harfbuzz-subset.pc" ]]; then
        if [[ -f "/usr/lib/pkgconfig/harfbuzz-subset.pc" ]]; then
            install -Dm644 /usr/lib/pkgconfig/harfbuzz-subset.pc "${host_sysroot_pkgconfig}/harfbuzz-subset.pc"
            log_info "Added harfbuzz-subset.pc to AMD64 sysroot from host system"
        else
            cat > "${host_sysroot_pkgconfig}/harfbuzz-subset.pc" <<'EOF'
prefix=/usr
exec_prefix=/usr
libdir=/usr/lib
includedir=/usr/include

Name: harfbuzz-subset
Description: HarfBuzz text shaping library (subset)
Version: 8.3.0
Requires.private: harfbuzz
Libs: -L${libdir} -lharfbuzz-subset
Cflags: -I${includedir}/harfbuzz
EOF
            log_info "Created minimal harfbuzz-subset.pc in AMD64 sysroot"
        fi
    fi

    if [[ -d "${host_sysroot_pkgconfig}" ]] && [[ ! -f "${host_sysroot_pkgconfig}/libsharpyuv.pc" ]]; then
        if [[ -f "/usr/lib/pkgconfig/libsharpyuv.pc" ]]; then
            install -Dm644 /usr/lib/pkgconfig/libsharpyuv.pc "${host_sysroot_pkgconfig}/libsharpyuv.pc"
            log_info "Added libsharpyuv.pc to AMD64 sysroot from host system"
        else
            cat > "${host_sysroot_pkgconfig}/libsharpyuv.pc" <<'EOF'
prefix=/usr
exec_prefix=/usr
libdir=/usr/lib
includedir=/usr/include

Name: libsharpyuv
Description: WebP RGB to YUV converter
Version: 1.4.0
Requires.private:
Libs: -L${libdir} -lsharpyuv
Cflags: -I${includedir}/sharpyuv
EOF
            log_info "Created minimal libsharpyuv.pc in AMD64 sysroot"
        fi
    fi

    update_timestamp "sysroot"
    log_success "Sysroot stage: COMPLETED"
}

# Function to check build dependencies (especially for cross-compilation)
check_build_dependencies() {
    log_info "Checking build dependencies..."

    local missing_deps=()
    local required_pkgconfig=(
        "libpulse"
        "libva"
        "pangocairo"
        "gtk+-3.0"
        "nss"
        "cups"
    )

    for pkg in "${required_pkgconfig[@]}"; do
        if ! pkg-config --exists "$pkg" 2>/dev/null; then
            log_warning "Missing pkg-config package: $pkg"
            missing_deps+=("$pkg")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies for Chromium build"
        log_error "Install with: sudo pacman -S libpulse libva pango cairo gtk3 nss cups"
        return 1
    fi

    log_success "All build dependencies present"
    return 0
}

# Function to configure build
stage_configure() {
    log_stage "STAGE 3: Configure Build"

    local config_files=("PKGBUILD" "${SRC_DIR}/out/Release/args.gn")
    local need_rebuild=$(check_rebuild_needed "configure" "${config_files[@]}")

    if [[ "$need_rebuild" == "false" ]] && [[ -f "${OUT_DIR}/build.ninja" ]]; then
        log_success "Configure stage: UP TO DATE (skipping)"
        return 0
    fi

    # Check dependencies before configuring
    check_build_dependencies || return 1

    log_info "Configuring build (running gn gen)..."

    # Extract and run just the configure part
    cd "$SRC_DIR"

    # Set up environment variables from PKGBUILD
    export CC=clang
    export CXX=clang++
    export AR=ar
    export NM=nm

    # Rust environment variables are already set globally at script start

    # Verify Rust is using /opt/rust
    local current_sysroot=$(rustc --print sysroot 2>/dev/null || echo "")
    if [[ "$current_sysroot" != "/opt/rust/toolchains/"* ]]; then
        log_warning "Rust sysroot is $current_sysroot, expected /opt/rust/toolchains/*"
        log_info "This may cause permission issues. Ensure RUSTUP_HOME=/opt/rust is set."
    fi

    # Set LIBCLANG_PATH for bindgen to find clang headers
    local clang_version=$(clang --version | head -1 | sed 's/.*version \([0-9]*\).*/\1/' || echo "21")
    export CLANG_RESOURCE_DIR="/usr/lib/clang/${clang_version}"

    local clang_version=$(clang --version | grep -m1 version | sed 's/.* \([0-9.]*\).*/\1/' || echo "0")

    # Get Rust version and sysroot
    local rustc_version=$(rustc --version 2>/dev/null | awk '{print $2}' || echo "1.86.0")
    # Always use /opt/rust for Docker builds (accessible to builder user)
    # Don't use rustc --print sysroot as it may point to /root/.rustup
    local rust_sysroot="/opt/rust/toolchains/${rustc_version}-x86_64-unknown-linux-gnu"
    if [[ ! -d "$rust_sysroot" ]]; then
        # Fallback to system rustc sysroot if /opt/rust doesn't exist
        rust_sysroot=$(rustc --print sysroot 2>/dev/null || echo "")
    fi

    local build_arch=$(uname -m)
    if [[ "${build_arch}" =~ ^(aarch64|arm64)$ ]]; then
        # Cortex-A57 tuning for Baikal-M hosts
        local baikal_flags="-mcpu=cortex-a57 -mtune=cortex-a57 -fomit-frame-pointer -fno-semantic-interposition"
        CFLAGS+=" ${baikal_flags}"
        CXXFLAGS+=" ${baikal_flags}"
        export CFLAGS CXXFLAGS
    fi

    # Use standard clang toolchains (consistent with chromium build system)
    local custom_toolchain="//build/toolchain/linux:clang_arm64"
    local host_toolchain="//build/toolchain/linux:clang_x64"
    if [[ "${build_arch}" =~ ^(aarch64|arm64)$ ]]; then
        host_toolchain="//build/toolchain/linux:clang_arm64"
    fi

    # Clean stale GN state so updated arguments take effect
    rm -f out/Release/args.gn out/Release/build.ninja

    # Clean Rust artifacts ONLY if they were built without RUSTC_BOOTSTRAP=1
    # Check for the telltale sign: missing __rust_no_alloc_shim_is_unstable symbol
    local need_rust_clean=false
    if [[ -f "out/Release/clang_x64/obj/build/rust/allocator/libbuild_srust_sallocator_callocator.rlib" ]]; then
        # Check if allocator was built correctly (should not need external __rust_no_alloc_shim_is_unstable)
        if nm out/Release/clang_x64/obj/build/rust/allocator/libbuild_srust_sallocator_callocator.rlib 2>/dev/null | grep -q "U __rust_no_alloc_shim_is_unstable"; then
            need_rust_clean=true
            log_warning "Detected Rust artifacts built without RUSTC_BOOTSTRAP=1"
        fi
    fi

    if [[ "$need_rust_clean" == "true" ]] || [[ ! -f "out/Release/clang_x64/prebuilt_rustc_sysroot/lib/rustlib/x86_64-unknown-linux-gnu/lib/libstd.rlib" ]]; then
        # Clean Rust artifacts to force rebuild with RUSTC_BOOTSTRAP=1
        # This fixes __rust_no_alloc_shim_is_unstable linker errors
        log_info "Cleaning Rust artifacts to ensure RUSTC_BOOTSTRAP=1 is applied"
        rm -rf out/Release/clang_x64/prebuilt_rustc_sysroot 2>/dev/null || true
        rm -rf out/Release/clang_x64/obj/build/rust 2>/dev/null || true
        rm -rf out/Release/clang_x64/obj/third_party/rust 2>/dev/null || true
        rm -rf out/Release/clang_x64_v8_arm64/prebuilt_rustc_sysroot 2>/dev/null || true
        rm -rf out/Release/clang_x64_v8_arm64/obj/build/rust 2>/dev/null || true
        rm -rf out/Release/clang_x64_v8_arm64/obj/third_party/rust 2>/dev/null || true
    else
        log_info "Rust artifacts are clean, keeping them for incremental build"
    fi

    # Reset GN library overrides first
    python3 build/linux/unbundle/replace_gn_files.py --undo >/dev/null 2>&1 || true

    # Restore brotli/harfbuzz/libdrm to bundled versions BEFORE replace_gn_files.py
    # (Debian Bullseye sysroot has too old versions)
    log_info "Restoring bundled brotli, harfbuzz, and libdrm (Debian Bullseye versions too old)"
    git restore third_party/brotli/ third_party/harfbuzz-ng/harfbuzz.gni third_party/libdrm/ 2>/dev/null || true

    # Use system libraries for everything EXCEPT brotli, harfbuzz, libdrm, libxml, libxslt
    # This allows build tools to link against /usr/lib (Arch Linux) instead of sysroot (Debian Bullseye)
    # which avoids dynamic linker incompatibility (elf_machine_rela_relative errors)
    # libxml/libxslt: Use bundled versions to avoid const incompatibility between
    #   Arch libxml2 2.15.0 (const xmlError*) vs Debian Bullseye 2.9.10 (non-const)
    log_info "Configuring to use system libraries (except brotli, harfbuzz, libdrm, libxml, libxslt)"
    python3 build/linux/unbundle/replace_gn_files.py --system-libraries \
        fontconfig freetype libjpeg libpng libwebp \
        opus zlib 2>&1 | head -5

    # Create compatibility symlinks: Build tools expect Debian naming but we give them Arch libraries
    # libjpeg: sysroot uses .62, Arch uses .8 -> symlink .62 to Arch version
    # libffi_pic.a: Host toolchain (x86_64) needs static PIC version from AMD64 sysroot
    log_info "Creating library compatibility symlinks for build tools"
    sudo ln -sf /usr/lib/libjpeg.so.8.3.2 /usr/lib/libjpeg.so.62 2>/dev/null || true
    sudo ln -sf "${SRC_DIR}/build/linux/debian_bullseye_amd64-sysroot/usr/lib/x86_64-linux-gnu/libffi_pic.a" /usr/lib/libffi_pic.a 2>/dev/null || true

    # Apply FLAC compatibility patch for Debian Bullseye
    if grep -q "FLAC__STREAM_DECODER_ERROR_STATUS_BAD_METADATA" media/audio/flac_audio_handler.cc 2>/dev/null; then
        log_info "Applying FLAC compatibility patch for Debian Bullseye"
        sed -i 's/FLAC__STREAM_DECODER_ERROR_STATUS_BAD_METADATA/FLAC__STREAM_DECODER_ERROR_STATUS_UNPARSEABLE_STREAM/g' media/audio/flac_audio_handler.cc
    fi

    # Run gn configuration with system toolchains and ungoogled flags
    local _flags=(
        "target_os=\"linux\""
        "target_cpu=\"arm64\""
        "custom_toolchain=\"${custom_toolchain}\""
        "host_toolchain=\"${host_toolchain}\""
        "is_official_build=true"
        "symbol_level=0"
        "treat_warnings_as_errors=false"
        "fatal_linker_warnings=false"
        "disable_fieldtrial_testing_config=true"
        "blink_enable_generated_code_formatting=false"
        "use_custom_libcxx=true"
        "use_sysroot=true"
        "use_system_libffi=true"
        "use_vaapi=true"
        "rtc_use_pipewire=true"
        "link_pulseaudio=true"
        "ffmpeg_branding=\"Chrome\""
        "proprietary_codecs=true"
        "enable_widevine=true"
        "enable_vulkan=true"
        "enable_platform_hevc=true"
        "enable_hevc_parser_and_hw_decoder=true"
        "use_dawn=true"
        "dawn_enable_vulkan=true"
        "enable_gpu_service_logging=false"
        "clang_use_chrome_plugins=false"
        "clang_base_path=\"/usr\""
        "chrome_pgo_phase=0"
        "rust_bindgen_root=\"/usr\""
        "is_cfi=false"
        "v8_snapshot_toolchain=\"//build/toolchain/linux:clang_x64\""
        # Note: Cortex-A57 optimizations passed via CFLAGS from cortex-a57-env.sh
        #       (-march=armv8-a+crc+crypto -mtune=cortex-a57)
        #       arm_float_abi and arm_use_neon are auto-set to "hard" and true for ARM64
    )

    local ungoogled_flags_file="../ungoogled-chromium-${CHROMIUM_VERSION}-1/flags.gn"
    if [[ -f "${ungoogled_flags_file}" ]]; then
        while IFS= read -r line; do
            [[ -z "${line}" ]] && continue
            _flags+=("${line}")
        done < "${ungoogled_flags_file}"
    fi


    local gn_cmd=${GN_BINARY:-gn}
    if ! command -v "${gn_cmd}" >/dev/null 2>&1; then
        if [[ -x "${SRC_DIR}/buildtools/linux64/gn" ]]; then
            gn_cmd="${SRC_DIR}/buildtools/linux64/gn"
        elif [[ -x "${SRC_DIR}/../chromium-checkout/buildtools/linux64/gn" ]]; then
            gn_cmd="${SRC_DIR}/../chromium-checkout/buildtools/linux64/gn"
        else
            cd - > /dev/null
            log_error "Configure stage: gn binary not found"
            log_info "Install the system 'gn' package or run tools/gn/bootstrap/bootstrap.py"
            return 1
        fi
    fi

    # Generate args.gn with base flags
    if ! "${gn_cmd}" gen out/Release --args="${_flags[*]}"; then
        cd - > /dev/null
        log_error "Configure stage: FAILED"
        return 1
    fi

    # Cross-compilation fix: Detect x86_64 → ARM64 and fix sysroot usage
    if [[ "$(uname -m)" == "x86_64" ]] && grep -q 'target_cpu = "arm64"' out/Release/args.gn; then
        log_info "Cross-compilation detected (x86_64 host → ARM64 target)"

        # Check if fix is needed (use_sysroot = true means host tools use Debian sysroot)
        if grep -q 'use_sysroot = true' out/Release/args.gn; then
            log_warning "Detected use_sysroot=true - this causes library version conflicts"
            log_info "Applying cross-compilation fix..."

            # Fix 1: Host tools should NOT use Debian Bullseye sysroot
            # (avoids glibc/library version conflicts with Arch Linux)
            sed -i 's/use_sysroot = true/use_sysroot = false/' out/Release/args.gn

            # Fix 2: Target binaries MUST still use ARM64 sysroot
            if ! grep -q 'target_sysroot' out/Release/args.gn; then
                echo '' >> out/Release/args.gn
                echo '# Cross-compilation: ARM64 target uses Debian sysroot, x86_64 host tools use system libraries' >> out/Release/args.gn
                echo 'target_sysroot = "//build/linux/debian_bullseye_arm64-sysroot"' >> out/Release/args.gn
            fi

            log_success "Applied cross-compilation sysroot fix"

            # Regenerate build files with corrected configuration
            log_info "Regenerating build files with cross-compilation fix..."
            if "${gn_cmd}" gen out/Release; then
                log_success "Build files regenerated with correct sysroot configuration"
            else
                cd - > /dev/null
                log_error "Failed to regenerate build files after cross-compilation fix"
                return 1
            fi
        else
            log_info "Cross-compilation fix already applied (use_sysroot=false)"
        fi
    fi

    # Always add Rust sysroot configuration to args.gn after initial generation
    if [[ -n "$rust_sysroot" ]] && [[ -d "$rust_sysroot" ]]; then
        log_info "Configuring Rust toolchain: $rustc_version at $rust_sysroot"

        # Remove any existing Rust configuration to avoid duplicates
        sed -i '/^rust_sysroot_absolute/d' out/Release/args.gn
        sed -i '/^rustc_version/d' out/Release/args.gn

        # Add Rust configuration
        echo "rust_sysroot_absolute = \"$rust_sysroot\"" >> out/Release/args.gn
        echo "rustc_version = \"$rustc_version\"" >> out/Release/args.gn
        log_success "Added Rust configuration to args.gn"

        # Regenerate build.ninja with Rust configuration
        if "${gn_cmd}" gen out/Release; then
            log_success "Regenerated build files with Rust configuration"
        else
            cd - > /dev/null
            log_error "Configure stage: Failed to regenerate with Rust config"
            return 1
        fi
    else
        log_warning "Rust sysroot not found at $rust_sysroot, skipping Rust configuration"
    fi

    # Add Qt6 configuration for KDE integration (with cross-compilation support)
    log_info "Configuring Qt6 support for KDE Plasma integration"
    sed -i '/^use_qt5/d' out/Release/args.gn
    sed -i '/^use_qt6/d' out/Release/args.gn
    sed -i '/^moc_qt6_path/d' out/Release/args.gn

    echo 'use_qt5 = false' >> out/Release/args.gn
    echo 'use_qt6 = true' >> out/Release/args.gn
    echo 'moc_qt6_path = "/usr/lib/qt6"' >> out/Release/args.gn
    log_success "Added Qt6 configuration to args.gn"

    # Regenerate build.ninja with Qt6 configuration
    if "${gn_cmd}" gen out/Release; then
        log_success "Regenerated build files with Qt6 configuration"
    else
        cd - > /dev/null
        log_error "Configure stage: Failed to regenerate with Qt6 config"
        return 1
    fi

    # Verify cross-compilation configuration is correct
    if [[ "$(uname -m)" == "x86_64" ]] && grep -q 'target_cpu = "arm64"' out/Release/args.gn; then
        log_info "Verifying cross-compilation configuration..."

        # Verify args.gn configuration directly (more reliable than ninja -t commands)
        # Check 1: use_sysroot must be false (host tools use system libraries)
        if grep -q 'use_sysroot = true' out/Release/args.gn; then
            log_error "VERIFICATION FAILED: use_sysroot is still true!"
            log_error "Host x64 tools will use Debian sysroot (causes library conflicts)"
            cd - > /dev/null
            return 1
        fi

        # Check 2: target_sysroot must be set for ARM64 target
        if ! grep -q 'target_sysroot.*debian_bullseye_arm64' out/Release/args.gn; then
            log_error "VERIFICATION FAILED: target_sysroot is not set for ARM64!"
            log_error "ARM64 target will not use correct sysroot for cross-compilation"
            cd - > /dev/null
            return 1
        fi

        log_success "✓ Cross-compilation configuration verified correctly"
        log_success "  - use_sysroot = false (x86_64 host tools use /usr/lib)"
        log_success "  - target_sysroot set to debian_bullseye_arm64-sysroot"
    fi

    cd - > /dev/null
    update_timestamp "configure"
    log_success "Configure stage: COMPLETED"
}

# Function to compile
stage_compile() {
    log_stage "STAGE 4: Compile Chromium"

    # Rust environment variables are already set globally at script start

    local targets=("chrome" "chrome_sandbox" "chromedriver")
    local target="${1:-chrome}"

    if [[ ! -f "${OUT_DIR}/build.ninja" ]]; then
        log_error "Build not configured. Run configure stage first."
        return 1
    fi

    log_info "Compiling target: $target"

    # Create compatibility symlinks for build tools (in case configure was skipped)
    # libjpeg: sysroot uses .62, Arch uses .8 -> symlink .62 to Arch version
    sudo ln -sf /usr/lib/libjpeg.so.8.3.2 /usr/lib/libjpeg.so.62 2>/dev/null || true

    # Clean old Rust stdlib artifacts that may have wrong paths FIRST
    # These .d files cache paths to Rust libraries and can have stale /root/.rustup paths
    local old_paths=$(find "${OUT_DIR}" -name "stdlib.d" -exec grep -l "/root/.rustup" {} \; 2>/dev/null || true)
    if [[ -n "$old_paths" ]]; then
        log_warning "Found Rust stdlib artifacts with old paths, cleaning..."
        # Remove all Rust stdlib artifacts recursively
        cd "${OUT_DIR}"
        find . -path "*/obj/build/rust/std" -type d -exec rm -rf {} + 2>/dev/null || true
        find . -path "*/prebuilt_rustc_sysroot" -type d -exec rm -rf {} + 2>/dev/null || true
        cd - > /dev/null
        log_success "Cleaned all Rust stdlib artifacts"
    fi

    # Create rustc wrapper to ensure RUSTUP_HOME is set even in subprocess calls
    # This is needed because ninja's regeneration calls rustc without inheriting env vars
    local wrapper_dir="${SRC_DIR}/.local-bin"
    mkdir -p "$wrapper_dir"

    # Preserve RUSTFLAGS from environment (Cortex-A57 optimizations)
    local current_rustflags="${RUSTFLAGS:-}"

    cat > "$wrapper_dir/rustc" << EOF
#!/bin/bash
export RUSTUP_HOME=/opt/rust
export CARGO_HOME=/opt/rust
export RUSTC_BOOTSTRAP=1
# Preserve RUSTFLAGS if set
if [[ -z "\$RUSTFLAGS" ]] && [[ -n "$current_rustflags" ]]; then
    export RUSTFLAGS="$current_rustflags"
fi
exec /usr/sbin/rustc "\$@"
EOF
    chmod +x "$wrapper_dir/rustc"

    # Prepend wrapper to PATH so it's used instead of system rustc
    export PATH="$wrapper_dir:$PATH"
    log_info "Created rustc wrapper in $wrapper_dir"

    # DEPRECATED: RPATH patching no longer needed with proper use_sysroot=false in args.gn
    # The cross-compilation fix in stage_configure() ensures build tools use system libraries
    # which avoids glibc/library version conflicts automatically

    # Verify Rust environment is correct
    local current_rust_sysroot=$(rustc --print sysroot 2>/dev/null || echo "")
    log_info "Using Rust sysroot: $current_rust_sysroot"

    # Optimize ninja settings
    local ninja_jobs=$(nproc)
    local available_mem=$(free -m | awk 'NR==2{printf "%d", $7}')

    if [[ $available_mem -lt 8000 ]]; then
        ninja_jobs=4
        log_warning "Limited memory detected. Using $ninja_jobs parallel jobs."
    fi

    cd "$SRC_DIR"

    # Show compilation progress
    export NINJA_STATUS="[%f/%t %o/s %es] "

    if ninja -C out/Release -j$ninja_jobs "$target"; then
        cd - > /dev/null
        update_timestamp "compile"
        log_success "Compile stage: COMPLETED ($target)"
    else
        cd - > /dev/null
        log_error "Compile stage: FAILED ($target)"
        return 1
    fi
}

# Function to package
stage_package() {
    log_stage "STAGE 5: Create Package"

    local package_files=("${OUT_DIR}/chrome" "${OUT_DIR}/chrome_sandbox" "${OUT_DIR}/chromedriver")
    local need_rebuild=$(check_rebuild_needed "package" "${package_files[@]}")

    if [[ "$need_rebuild" == "false" ]]; then
        local existing_pkg=$(find pkgdest/ -name "ungoogled-chromium-baikal-*.pkg.tar.*" 2>/dev/null | head -1)
        if [[ -n "$existing_pkg" ]]; then
            log_success "Package stage: UP TO DATE (skipping)"
            log_info "Existing package: $(basename "$existing_pkg")"
            return 0
        fi
    fi

    log_info "Creating installation package..."

    # Set up environment
    export ARCH=aarch64

    # Create makepkg config for ARM64 cross-compilation if not exists
    if [[ ! -f ".makepkg-aarch64.conf" ]]; then
        log_info "Creating .makepkg-aarch64.conf for cross-compilation..."
        cat > .makepkg-aarch64.conf << 'EOF'
#
# makepkg configuration for ARM64 cross-compilation
#

CARCH="aarch64"
CHOST="aarch64-unknown-linux-gnu"

# Package formats
PKGEXT='.pkg.tar.zst'
SRCEXT='.src.tar.gz'

# Disable stripping for cross-compilation (native strip corrupts ARM64 binaries)
OPTIONS=(!strip docs libtool staticlibs emptydirs !zipman !purge !debug !lto)

# Use parallel compression
COMPRESSZST=(zstd -c -T0 --ultra -20 -)

# Package destinations
PKGDEST="${PKGDEST:-pkgdest}"
EOF
    fi

    # Use makepkg for packaging
    MAKEPKG_CONF=".makepkg-aarch64.conf"

    if MAKEPKG_CONF="$MAKEPKG_CONF" makepkg -e --noprepare --nocheck --repackage --nodeps; then
        update_timestamp "package"
        log_success "Package stage: COMPLETED"
    else
        log_error "Package stage: FAILED"
        return 1
    fi
}

# Function to create build summary
create_build_summary() {
    local build_mode="${1:-auto}"

    # Check if package was created
    local package_file=$(find pkgdest/ -name "ungoogled-chromium-baikal-*.pkg.tar.*" 2>/dev/null | head -1)

    if [[ -n "$package_file" ]]; then
        local package_size=$(du -h "$package_file" | cut -f1)
        log_success "Package created: $(basename "$package_file") (${package_size})"
        log_info "Package location: $package_file"

        # Create a summary file
        cat > build-summary.txt << EOF
Build Summary for ungoogled-chromium-baikal
==========================================

Build completed: $(date)
Architecture: $ARCH
Package: $(basename "$package_file")
Size: $package_size
Location: $package_file

Installation command for target system:
sudo pacman -U "$package_file"

Post-installation:
sudo usermod -a -G video \$USER

Optimizations included:
- Baikal-M Cortex-A57 specific optimizations
- AMD RX550 GPU identification and acceleration
- VA-API hardware video decoding
- Vulkan support
- Enhanced runtime flags for performance

Build mode: $build_mode

Build stages status:
EOF

        # Add build status to summary
        if [[ -f "$TIMESTAMPS_FILE" ]]; then
            echo "" >> build-summary.txt
            local components=("prepare" "sysroot" "configure" "compile" "package")
            for comp in "${components[@]}"; do
                if grep -q "^${comp}:" "$TIMESTAMPS_FILE"; then
                    local timestamp=$(grep "^${comp}:" "$TIMESTAMPS_FILE" | cut -d: -f2)
                    local date_str=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")
                    printf "%-12s: ✅ Done (%s)\n" "$comp" "$date_str" >> build-summary.txt
                else
                    printf "%-12s: ❌ Not done\n" "$comp" >> build-summary.txt
                fi
            done
        fi

        log_success "Build summary saved to build-summary.txt"
        return 0
    else
        log_warning "Package file not found in expected location"
        return 1
    fi
}

# Main execution logic
main() {
    local command="${1:-auto}"

    case "$command" in
        "status")
            show_build_status
            ;;
        "clean")
            log_info "Cleaning build artifacts..."
            rm -rf src pkg build .build
            rm -f .makepkg-*.conf *.pkg.tar.*
            rm -f "$TIMESTAMPS_FILE"
            log_success "Clean completed"
            ;;
        "clean-soft")
            log_info "Cleaning build artifacts (preserving git repos)..."
            # Preserve git checkouts
            if [[ -d "src/chromium-checkout" ]]; then
                # Remove everything except git checkouts
                find src/ -maxdepth 1 -type d ! -name "chromium-checkout" ! -name "src" -exec rm -rf {} +
                find src/ -maxdepth 1 -type f -exec rm -f {} +
                find src/ -maxdepth 1 -type l -exec rm -f {} +
            else
                rm -rf src
            fi
            rm -rf pkg build .build
            rm -f .makepkg-*.conf *.pkg.tar.*
            rm -f "$TIMESTAMPS_FILE"
            log_success "Soft clean completed (git repos preserved)"
            ;;
        "prepare")
            stage_prepare
            ;;
        "sysroot")
            stage_sysroot
            ;;
        "configure")
            stage_configure
            ;;
        "compile")
            local target="${2:-chrome}"
            stage_compile "$target"
            ;;
        "package")
            stage_package
            ;;
        "ninja")
            # Quick ninja rebuild for code changes
            local target="${2:-chrome}"
            log_info "Quick ninja rebuild: $target"
            if [[ -f "${OUT_DIR}/build.ninja" ]]; then
                # Rust environment variables are already set globally at script start
                # Verify Rust environment before building
                log_info "Rust sysroot: $(rustc --print sysroot)"

                cd "$SRC_DIR"
                ninja -C out/Release "$target"
                cd - > /dev/null
                log_success "Ninja rebuild completed"
            else
                log_error "Build not configured. Run 'configure' first."
            fi
            ;;
        "auto"|"")
            log_info "Starting smart incremental build..."
            if stage_prepare && \
               stage_sysroot && \
               stage_configure && \
               stage_compile && \
               stage_package; then
                create_build_summary "auto"
                log_success "Smart incremental build completed!"
            else
                log_error "Smart incremental build failed"
                exit 1
            fi
            ;;
        "full")
            log_warning "Starting full rebuild (cleaning first)..."
            # Clean everything first
            rm -rf src pkg build .build
            rm -f .makepkg-*.conf *.pkg.tar.*
            rm -f "$TIMESTAMPS_FILE"
            log_success "Cleaned all artifacts"

            # Full rebuild
            if stage_prepare && \
               stage_sysroot && \
               stage_configure && \
               stage_compile && \
               stage_package; then
                create_build_summary "full"
                log_success "Full rebuild completed!"
            else
                log_error "Full rebuild failed"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  auto      - Smart incremental build (default)"
            echo "  full      - Full rebuild from scratch"
            echo "  status    - Show build status"
            echo "  clean     - Clean all build artifacts"
            echo "  clean-soft - Clean build artifacts (preserve git repos)"
            echo ""
            echo "Individual stages:"
            echo "  prepare   - Prepare build environment"
            echo "  sysroot   - Fix ARM64 sysroot dependencies"
            echo "  configure - Configure build (gn gen)"
            echo "  compile [target] - Compile (default: chrome)"
            echo "  package   - Create installation package"
            echo ""
            echo "Quick operations:"
            echo "  ninja [target] - Quick ninja rebuild"
            echo ""
            echo "Examples:"
            echo "  $0                    # Smart incremental build"
            echo "  $0 status             # Show what's been built"
            echo "  $0 compile chrome     # Just recompile chrome"
            echo "  $0 ninja chrome       # Quick ninja rebuild"
            echo "  $0 full              # Full clean rebuild"
            ;;
    esac
}

main "$@"
