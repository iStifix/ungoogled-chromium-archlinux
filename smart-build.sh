#!/bin/bash
# Smart incremental build script for ungoogled-chromium-baikal
# Native ARM64 build for Baikal-M (Cortex-A57 r1p3)
# Runs inside Docker container (Arch Linux ARM aarch64)

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

DOCKER_CONTAINER_NAME="${DOCKER_CONTAINER_NAME:-chromium-arm64-builder}"

if [[ -f "PKGBUILD" ]]; then
    CHROMIUM_VERSION=$(grep '^pkgver=' PKGBUILD | cut -d= -f2)
    if [[ -z "$CHROMIUM_VERSION" ]]; then
        echo -e "${RED}[ERROR]${NC} Failed to detect Chromium version from PKGBUILD"
        exit 1
    fi
    echo -e "${GREEN}[INFO]${NC} Detected Chromium version: ${CHROMIUM_VERSION}"
else
    echo -e "${RED}[ERROR]${NC} PKGBUILD not found. Please run this script from ungoogled-chromium directory"
    exit 1
fi
export CHROMIUM_VERSION

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

is_inside_docker() {
    [[ -f /.dockerenv ]]
}

docker_container_online() {
    command -v docker >/dev/null 2>&1 || return 1
    docker ps --format '{{.Names}}' | grep -Fxq "$DOCKER_CONTAINER_NAME"
}

run_in_builder_container() {
    local cmd="$1"
    if ! docker_container_online; then
        log_warning "Docker container ${DOCKER_CONTAINER_NAME} is not running; cannot execute: $cmd"
        return 1
    fi
    docker exec -u builder -w "$DOCKER_WORKDIR" "$DOCKER_CONTAINER_NAME" bash -lc "$cmd"
}

ensure_codec_rate_control_libs() {
    local deps_dir="$PWD/deps"
    mkdir -p "$deps_dir/lib" "$deps_dir/include"

    local build_script
    build_script=$(cat <<EOF
set -euo pipefail

CHROMIUM_VERSION="${CHROMIUM_VERSION}"
DEPS_DIR="/work/deps"
SRC_DEPS_DIR="/work/src/chromium-\${CHROMIUM_VERSION}/deps"
LIBVPX_DIR="/work/external/libvpx-rtc"
LIBAOM_DIR="/work/external/libaom-rtc"
EXPECTED_LIBVPX_COMMIT="4c1801be20dd53900d2a7cd74f6fc91a9ae353be"
EXPECTED_LIBAOM_COMMIT="8ed60aac823eaf760cf858bc83b89649e148f043"
NPROC=\$(echo 7)

mkdir -p "\$DEPS_DIR/lib" \
         "\$DEPS_DIR/include/aom" \
         "\$DEPS_DIR/include/av1" \
         "\$DEPS_DIR/include/vpx" \
         "\$DEPS_DIR/include/vpx/internal"

mkdir -p "\$SRC_DEPS_DIR/lib" \
         "\$SRC_DEPS_DIR/include/aom" \
         "\$SRC_DEPS_DIR/include/av1" \
         "\$SRC_DEPS_DIR/include/vpx" \
         "\$SRC_DEPS_DIR/include/vpx/internal"

mkdir -p /work/external

current_libvpx_commit=""
if [[ -f "\$DEPS_DIR/.libvpxrc_commit" ]]; then
    current_libvpx_commit=\$(cat "\$DEPS_DIR/.libvpxrc_commit")
fi

if [[ "\$current_libvpx_commit" != "\$EXPECTED_LIBVPX_COMMIT" ]]; then
    rm -rf "\$LIBVPX_DIR"
fi

if [[ ! -d "\$LIBVPX_DIR/.git" ]]; then
    rm -rf "\$LIBVPX_DIR"
    git clone https://chromium.googlesource.com/webm/libvpx "\$LIBVPX_DIR"
fi

(
    cd "\$LIBVPX_DIR"
    git fetch origin "\$EXPECTED_LIBVPX_COMMIT" --quiet || true
    git checkout "\$EXPECTED_LIBVPX_COMMIT"
    repo_commit=\$(git rev-parse HEAD)

    if [[ "\$current_libvpx_commit" != "\$repo_commit" ]] || \
       [[ ! -f "\$DEPS_DIR/lib/libvpxrc.a" ]] || \
       [[ ! -f "\$SRC_DEPS_DIR/lib/libvpxrc.a" ]]; then
        make distclean >/dev/null 2>&1 || true
        CC=clang CXX=clang++ AR=llvm-ar NM=llvm-nm RANLIB=llvm-ranlib \
            ./configure --target=arm64-linux-gcc \
                        --enable-vp9 \
                        --enable-vp8 \
                        --enable-vp9-highbitdepth \
                        --disable-examples \
                        --disable-docs \
                        --disable-unit-tests \
                        --prefix=/work/external/libvpx-rtc/install
        make -j"\$NPROC"

        install -Dm644 libvpxrc.a "\$DEPS_DIR/lib/libvpxrc.a"
        install -Dm644 libvpxrc.a "\$SRC_DEPS_DIR/lib/libvpxrc.a"
        install -Dm644 libvpx.a "\$DEPS_DIR/lib/libvpx.a"
        install -Dm644 libvpx.a "\$SRC_DEPS_DIR/lib/libvpx.a"
        install -Dm644 vpx/vpx_ext_ratectrl.h "\$DEPS_DIR/include/vpx/vpx_ext_ratectrl.h"
        install -Dm644 vpx/vpx_ext_ratectrl.h "\$SRC_DEPS_DIR/include/vpx/vpx_ext_ratectrl.h"
        install -Dm644 vpx/internal/vpx_ratectrl_rtc.h "\$DEPS_DIR/include/vpx/internal/vpx_ratectrl_rtc.h"
        install -Dm644 vpx/internal/vpx_ratectrl_rtc.h "\$SRC_DEPS_DIR/include/vpx/internal/vpx_ratectrl_rtc.h"

        echo "\$repo_commit" > "\$DEPS_DIR/.libvpxrc_commit"
    fi
)

current_libaom_commit=""
if [[ -f "\$DEPS_DIR/.libaom_rc_commit" ]]; then
    current_libaom_commit=\$(cat "\$DEPS_DIR/.libaom_rc_commit")
fi

if [[ "\$current_libaom_commit" != "\$EXPECTED_LIBAOM_COMMIT" ]]; then
    rm -rf "\$LIBAOM_DIR"
fi

if [[ ! -d "\$LIBAOM_DIR/.git" ]]; then
    rm -rf "\$LIBAOM_DIR"
    git clone https://aomedia.googlesource.com/aom "\$LIBAOM_DIR"
fi

(
    cd "\$LIBAOM_DIR"
    git fetch origin "\$EXPECTED_LIBAOM_COMMIT" --quiet || true
    git checkout "\$EXPECTED_LIBAOM_COMMIT"
    repo_commit=\$(git rev-parse HEAD)

    if [[ "\$current_libaom_commit" != "\$repo_commit" ]] || \
       [[ ! -f "\$DEPS_DIR/lib/libaom_av1_rc.a" ]] || \
       [[ ! -f "\$SRC_DEPS_DIR/lib/libaom_av1_rc.a" ]]; then
        rm -rf out-rtc
        CC=clang CXX=clang++ cmake -S . -B out-rtc \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=/work/external/libaom-rtc/install \
            -DBUILD_SHARED_LIBS=OFF \
            -DENABLE_DOCS=OFF \
            -DENABLE_TESTS=OFF \
            -DENABLE_EXAMPLES=OFF \
            -DAOM_EXTRA_WARNINGS=OFF \
            -DCONFIG_AV1_ENCODER=1 \
            -DCONFIG_AV1_DECODER=0

        cmake --build out-rtc --target aom_av1_rc -j"\$NPROC"

        install -Dm644 out-rtc/libaom_av1_rc.a "\$DEPS_DIR/lib/libaom_av1_rc.a"
        install -Dm644 out-rtc/libaom_av1_rc.a "\$SRC_DEPS_DIR/lib/libaom_av1_rc.a"
        install -Dm644 out-rtc/libaom.a "\$DEPS_DIR/lib/libaom.a"
        install -Dm644 out-rtc/libaom.a "\$SRC_DEPS_DIR/lib/libaom.a"
        install -Dm644 av1/ratectrl_rtc.h "\$DEPS_DIR/include/av1/ratectrl_rtc.h"
        install -Dm644 av1/ratectrl_rtc.h "\$SRC_DEPS_DIR/include/av1/ratectrl_rtc.h"
        install -Dm644 aom/aom_ext_ratectrl.h "\$DEPS_DIR/include/aom/aom_ext_ratectrl.h"
        install -Dm644 aom/aom_ext_ratectrl.h "\$SRC_DEPS_DIR/include/aom/aom_ext_ratectrl.h"

        echo "\$repo_commit" > "\$DEPS_DIR/.libaom_rc_commit"
    fi
)
EOF
)

    if is_inside_docker; then
        bash -lc "$build_script"
    else
        if ! docker_container_online; then
            log_warning "Docker container ${DOCKER_CONTAINER_NAME} is not running; skipping codec RTC libraries build"
            return 0
        fi
        run_in_builder_container "$build_script"
    fi
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

SRC_DIR="src/chromium-${CHROMIUM_VERSION}"
OUT_DIR="${SRC_DIR}/out/Release"
STATE_DIR=".build"
TIMESTAMPS_FILE="${STATE_DIR}/timestamps"
DOCKER_WORKDIR="/work/src/chromium-${CHROMIUM_VERSION}"

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

    # Create state directory if it doesn't exist
    mkdir -p "$STATE_DIR"

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
        ensure_codec_rate_control_libs || return 1
        update_timestamp "prepare"
        return 0
    fi

    log_info "Preparing build environment..."

    # Set up environment for native ARM64 build
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
                # Get Rust version and determine sysroot for native ARM64
                local rustc_version=$(rustc --version 2>/dev/null | awk '{print $2}' || echo "1.86.0")
                # Prefer /opt/rust for Docker builds (accessible to builder user)
                local rust_sysroot="/opt/rust/toolchains/${rustc_version}-aarch64-unknown-linux-gnu"
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

            # Fetch libvpx/libaom RTC source files for VA-API (if missing or corrupted)
            local need_fetch=false

            # Check if files are missing
            if [[ ! -f "$SRC_DIR/third_party/libvpx/source/libvpx/vpx/vpx_ext_ratectrl.h" ]] || \
               [[ ! -f "$SRC_DIR/third_party/libvpx/source/libvpx/vpx_util/vpx_thread.h" ]]; then
                need_fetch=true
            fi

            # Check if libaom RTC files contain "404: Not Found" (download error)
            if [[ -f "$SRC_DIR/third_party/libaom/source/libaom/av1/ratectrl_rtc.cc" ]]; then
                if grep -q "404: Not Found" "$SRC_DIR/third_party/libaom/source/libaom/av1/ratectrl_rtc.cc" 2>/dev/null; then
                    log_warning "Detected corrupted libaom RTC files (404 error), will re-download"
                    rm -f "$SRC_DIR/third_party/libaom/source/libaom/av1/ratectrl_rtc.cc"
                    rm -f "$SRC_DIR/third_party/libaom/source/libaom/av1/ratectrl_rtc.h"
                    need_fetch=true
                fi
            else
                need_fetch=true
            fi

            if [[ "$need_fetch" == "true" ]]; then
                log_info "Fetching libvpx/libaom RTC source files for VA-API..."
                if [[ -x "fetch-libvpx-rtc.sh" ]]; then
                    ./fetch-libvpx-rtc.sh
                    echo "✓ Fetched libvpx/libaom RTC source files"
                else
                    log_warning "fetch-libvpx-rtc.sh not found or not executable"
                fi
            fi
        fi

        ensure_codec_rate_control_libs || return 1
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

            # Fetch libvpx/libaom RTC source files for VA-API (CRITICAL for hardware acceleration)
            log_info "Fetching libvpx/libaom RTC source files for VA-API..."
            if [[ -x "fetch-libvpx-rtc.sh" ]]; then
                ./fetch-libvpx-rtc.sh

                # Verify libaom RTC files were downloaded correctly
                if [[ -f "$SRC_DIR/third_party/libaom/source/libaom/av1/ratectrl_rtc.cc" ]]; then
                    if grep -q "404: Not Found" "$SRC_DIR/third_party/libaom/source/libaom/av1/ratectrl_rtc.cc" 2>/dev/null; then
                        log_error "Failed to download libaom RTC files (404 error)"
                        log_error "This will break VA-API AV1 hardware acceleration!"
                        return 1
                    else
                        echo "✓ Fetched libvpx/libaom RTC source files successfully"
                    fi
                else
                    log_error "libaom RTC files missing after fetch"
                    return 1
                fi
            else
                log_warning "fetch-libvpx-rtc.sh not found or not executable"
            fi
            ensure_codec_rate_control_libs || return 1
            update_timestamp "prepare"
            log_success "Prepare stage: COMPLETED"
        else
            log_error "Prepare stage: FAILED"
            return 1
        fi
    fi
}

# Function to prepare build environment (native ARM64 build)
stage_sysroot() {
    log_stage "STAGE 2: Prepare Build Environment"

    # Native ARM64 build - use system libraries from /usr/lib
    if [[ -f "$TIMESTAMPS_FILE" ]] && grep -q "^sysroot:" "$TIMESTAMPS_FILE"; then
        log_success "Sysroot stage: UP TO DATE (skipping)"
        return 0
    fi

    log_info "Preparing build environment for native ARM64 build"

    # Create symlink for clang resource directory
    local clang_version=$(clang --version | head -1 | sed 's/.*version \([0-9]*\).*/\1/' || echo "21")
    local clang_link_path="${SRC_DIR}/usr/lib/clang/${clang_version}"
    if [[ ! -e "$clang_link_path" ]]; then
        mkdir -p "${SRC_DIR}/usr/lib/clang"
        ln -sf "/usr/lib/clang/${clang_version}" "$clang_link_path"
        log_success "Created clang resource directory symlink"
    fi

    # Patch bindgen to use absolute clang resource-dir
    local bindgen_gni="${SRC_DIR}/build/rust/rust_bindgen_generator.gni"
    if [[ -f "$bindgen_gni" ]]; then
        if grep -q 'rebase_path(clang_base_path + "/lib/clang/"' "$bindgen_gni"; then
            sed -i '/clang_resource_dir =/,/root_build_dir)/c\    # Patched: use absolute path to clang headers\n    clang_resource_dir = clang_base_path + "/lib/clang/" + clang_version' "$bindgen_gni"
            log_success "Patched rust_bindgen_generator.gni"
        fi
    fi

    # Patch run_build_script.py to pass environment
    local run_build_script="${SRC_DIR}/build/rust/gni_impl/run_build_script.py"
    if [[ -f "$run_build_script" ]]; then
        if ! grep -q '# Patched: Add PATH' "$run_build_script"; then
            sed -i '/env\["CARGO_MANIFEST_DIR"\] = os.path.abspath(args.src_dir)/a\    # Patched: Add PATH so build scripts can find rustc (needed for rustversion)\n    # Prepend the rustc binary directory to PATH so build scripts use the actual\n    # rustc binary, not the rustup proxy\n    rustc_dir = os.path.dirname(os.path.abspath(rustc_path))\n    if "PATH" in os.environ:\n      env["PATH"] = rustc_dir + ":" + os.environ["PATH"]\n    else:\n      env["PATH"] = rustc_dir\n    if "RUSTUP_HOME" in os.environ:\n      env["RUSTUP_HOME"] = os.environ["RUSTUP_HOME"]\n    if "CARGO_HOME" in os.environ:\n      env["CARGO_HOME"] = os.environ["CARGO_HOME"]' "$run_build_script"
            log_success "Patched build/rust/gni_impl/run_build_script.py"
        fi
    fi

    # Patch rustc_wrapper.py to pass RUSTC_BOOTSTRAP
    local rustc_wrapper="${SRC_DIR}/build/rust/gni_impl/rustc_wrapper.py"
    if [[ -f "$rustc_wrapper" ]]; then
        if ! grep -q 'RUSTC_BOOTSTRAP' "$rustc_wrapper"; then
            sed -i '/env = os.environ.copy()/a\  # Patched: Allow stable Rust to use -Z flags\n  env["RUSTC_BOOTSTRAP"] = "1"' "$rustc_wrapper"
            log_success "Patched build/rust/gni_impl/rustc_wrapper.py"
        fi
    fi

    # Patch Rust allocator
    local allocator_lib="${SRC_DIR}/build/rust/allocator/lib.rs"
    if [[ -f "$allocator_lib" ]]; then
        if ! grep -q 'fn __rust_no_alloc_shim_is_unstable() {}' "$allocator_lib"; then
            sed -i '/fn __rust_no_alloc_shim_is_unstable_v2() {}/i\
    /// Stable Rust 1.86.0 stdlib expects this symbol (without _v2)\n    #[rustc_std_internal_symbol]\n    #[linkage = "weak"]\n    fn __rust_no_alloc_shim_is_unstable() {}\n' "$allocator_lib"
            log_success "Added __rust_no_alloc_shim_is_unstable to build/rust/allocator/lib.rs"
        fi
    fi

    update_timestamp "sysroot"
    log_success "Sysroot stage: COMPLETED"
}

# Function to check build dependencies
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

    # Get Rust version and sysroot for native ARM64
    local rustc_version=$(rustc --version 2>/dev/null | awk '{print $2}' || echo "1.86.0")
    # Always use /opt/rust for Docker builds (accessible to builder user)
    local rust_sysroot="/opt/rust/toolchains/${rustc_version}-aarch64-unknown-linux-gnu"
    if [[ ! -d "$rust_sysroot" ]]; then
        # Fallback to system rustc sysroot if /opt/rust doesn't exist
        rust_sysroot=$(rustc --print sysroot 2>/dev/null || echo "")
    fi

    # Verify we're running on ARM64 (native build)
    local build_arch=$(uname -m)
    if [[ ! "${build_arch}" =~ ^(aarch64|arm64)$ ]]; then
        log_error "This script is for native ARM64 builds only!"
        log_error "Current architecture: $build_arch"
        cd - > /dev/null
        return 1
    fi

    export CFLAGS CXXFLAGS

    # Use standard clang ARM64 toolchain (native build)
    local custom_toolchain="//build/toolchain/linux:clang_arm64"
    local host_toolchain="//build/toolchain/linux:clang_arm64"

    # Clean stale GN state so updated arguments take effect
    rm -f out/Release/args.gn out/Release/build.ninja

    # Clean Rust artifacts ONLY if they were built without RUSTC_BOOTSTRAP=1
    # Check for the telltale sign: missing __rust_no_alloc_shim_is_unstable symbol
    local need_rust_clean=false
    if [[ -f "out/Release/clang_arm64/obj/build/rust/allocator/libbuild_srust_sallocator_callocator.rlib" ]]; then
        # Check if allocator was built correctly (should not need external __rust_no_alloc_shim_is_unstable)
        if nm out/Release/clang_arm64/obj/build/rust/allocator/libbuild_srust_sallocator_callocator.rlib 2>/dev/null | grep -q "U __rust_no_alloc_shim_is_unstable"; then
            need_rust_clean=true
            log_warning "Detected Rust artifacts built without RUSTC_BOOTSTRAP=1"
        fi
    fi

    if [[ "$need_rust_clean" == "true" ]] || [[ ! -f "out/Release/clang_arm64/prebuilt_rustc_sysroot/lib/rustlib/aarch64-unknown-linux-gnu/lib/libstd.rlib" ]]; then
        # Clean Rust artifacts to force rebuild with RUSTC_BOOTSTRAP=1
        # This fixes __rust_no_alloc_shim_is_unstable linker errors
        log_info "Cleaning Rust artifacts to ensure RUSTC_BOOTSTRAP=1 is applied"
        rm -rf out/Release/clang_arm64/prebuilt_rustc_sysroot 2>/dev/null || true
        rm -rf out/Release/clang_arm64/obj/build/rust 2>/dev/null || true
        rm -rf out/Release/clang_arm64/obj/third_party/rust 2>/dev/null || true
    else
        log_info "Rust artifacts are clean, keeping them for incremental build"
    fi

    # Reset GN library overrides first
    python3 build/linux/unbundle/replace_gn_files.py --undo >/dev/null 2>&1 || true

    log_info "Configuring to use system libraries (bundled: dav1d, libdrm, libvpx, libaom)"
    python3 build/linux/unbundle/replace_gn_files.py --system-libraries \
        fontconfig freetype harfbuzz-ng libjpeg libpng libwebp libxml libxslt \
        opus flac zlib brotli 2>&1 | head -5

    log_success "Configured to use Arch Linux ARM libraries (native)"

    # Create Node.js symlinks (GN hardcodes x64 path even on ARM64)
    log_info "Creating Node.js symlinks for both x64 and arm64 paths"
    mkdir -p third_party/node/linux/node-linux-x64/bin
    mkdir -p third_party/node/linux/node-linux-arm64/bin
    ln -sf /usr/bin/node third_party/node/linux/node-linux-x64/bin/node 2>/dev/null || true
    ln -sf /usr/bin/node third_party/node/linux/node-linux-arm64/bin/node 2>/dev/null || true
    log_success "Node.js symlinks configured"

    # Run gn configuration for native ARM64 build with ungoogled flags
    # IMPORTANT: use_sysroot=false means we use /usr/lib (Arch Linux ARM native)
    local _flags=(
        "target_os=\"linux\""
        "target_cpu=\"arm64\""
        "custom_toolchain=\"${custom_toolchain}\""
        "host_toolchain=\"${host_toolchain}\""
        "is_official_build=true"
        "symbol_level=0"
        "treat_warnings_as_errors=false"
        "fatal_linker_warnings=false"
        "use_sysroot=false"
        "disable_fieldtrial_testing_config=true"
        "blink_enable_generated_code_formatting=false"
        "use_custom_libcxx=true"
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
        "use_system_libvpx=false"  # Use bundled libvpx with RTC API from deps/lib/
        "use_system_libaom=false"   # Use bundled libaom with RTC API from deps/lib/
        "is_cfi=false"
        "enable_nacl=false"
        "use_thin_lto=false"  # Disabled: causes issues with OpenGL/EGL driver calls
        "concurrent_links=1"  # Prevent OOM on 8GB RAM system (linking requires ~6-8GB per process)
        "v8_snapshot_toolchain=\"${host_toolchain}\""
        # Modern codecs and features
        "rtc_use_h264=true"  # H.264 for WebRTC (video calls)
        "enable_av1_decoder=true"  # AV1 decoder (via dav1d)
        # HD Audio formats (critical for HDMI 4K display)
        "enable_platform_ac3_eac3_audio=true"  # AC3/EAC3 Dolby Digital/Plus
        "enable_platform_dts_audio=true"  # DTS/DTS-HD audio
        # HDR video support
        "enable_platform_dolby_vision=true"  # Dolby Vision HDR
        # Streaming support
        "enable_hls_demuxer=true"  # HLS streaming (YouTube, Twitch, etc.)
        "enable_mse_mpeg2ts_stream_parser=true"  # MPEG-TS parser (required for HLS)
        # AI/ML features (required for on-device model inference)
        "build_with_tflite_lib=true"  # TensorFlow Lite for optimization guide
    )

    # Add Rust sysroot configuration
    if [[ -n "$rust_sysroot" ]] && [[ -d "$rust_sysroot" ]]; then
        _flags+=("rust_sysroot_absolute=\"$rust_sysroot\"")
        _flags+=("rustc_version=\"$rustc_version\"")
    fi

    # Add Qt6 configuration for KDE integration
    _flags+=("use_qt5=false")
    _flags+=("use_qt6=true")
    _flags+=("moc_qt6_path=\"/usr/lib/qt6\"")

    # Read ungoogled-chromium flags.gn (avoid duplicates by using associative array)
    declare -A gn_flags_map
    # First, add all base flags to map
    for flag in "${_flags[@]}"; do
        key="${flag%%=*}"
        gn_flags_map["$key"]="$flag"
    done

    # Then merge ungoogled flags (will override duplicates)
    # Path relative to $SRC_DIR (/work/src/chromium-checkout/src in Docker)
    # ungoogled-chromium is in /work/src/ungoogled-chromium-VERSION-1/
    local ungoogled_flags_file="../../ungoogled-chromium-${CHROMIUM_VERSION}-1/flags.gn"
    if [[ -f "${ungoogled_flags_file}" ]]; then
        log_info "Merging ungoogled-chromium flags from ${ungoogled_flags_file}"
        while IFS= read -r line; do
            [[ -z "${line}" ]] && continue
            [[ "${line}" =~ ^[[:space:]]*# ]] && continue  # Skip comments
            key="${line%%=*}"
            gn_flags_map["$key"]="$line"
        done < "${ungoogled_flags_file}"
        log_success "Merged $(grep -v '^#' "${ungoogled_flags_file}" | grep -c '=' || echo 0) ungoogled flags"
    else
        log_warning "ungoogled-chromium flags.gn not found at ${ungoogled_flags_file}"
        log_warning "Will use base flags only (missing safe_browsing_mode=0!)"
    fi

    # Create args.gn file directly (faster than --args for large configs)
    mkdir -p out/Release
    {
        for key in "${!gn_flags_map[@]}"; do
            echo "${gn_flags_map[$key]}"
        done
    } > out/Release/args.gn

    log_info "Generated args.gn with $(wc -l < out/Release/args.gn) flags (Rust + Qt6 + ungoogled)"

    # Find gn binary
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

    # Run gn gen ONCE to generate build.ninja
    log_info "Running 'gn gen out/Release' (this may take 10-30 min on QEMU)..."
    if ! "${gn_cmd}" gen out/Release; then
        cd - > /dev/null
        log_error "Configure stage: FAILED"
        return 1
    fi

    log_success "GN configuration completed"

    cd - > /dev/null
    update_timestamp "configure"
    log_success "Configure stage: COMPLETED"
}

# Function to compile
stage_compile() {
    log_stage "STAGE 4: Compile Chromium"

    # Rust environment variables are already set globally at script start

    local targets=("chrome" "chrome_sandbox" "chromedriver")
    # По умолчанию собирать все targets для полного пакета
    local target="${1:-chrome chrome_sandbox chromedriver}"

    if [[ ! -f "${OUT_DIR}/build.ninja" ]]; then
        log_error "Build not configured. Run configure stage first."
        return 1
    fi

    log_info "Compiling target: $target"

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

    # Verify Rust environment is correct
    local current_rust_sysroot=$(rustc --print sysroot 2>/dev/null || echo "")
    log_info "Using Rust sysroot: $current_rust_sysroot"

    # Optimize ninja settings for Baikal-M (8 physical cores, no SMT)
    local ninja_jobs=8
    local available_mem=$(free -m | awk 'NR==2{printf "%d", $7}')

    if [[ $available_mem -lt 4000 ]]; then
        ninja_jobs=4
        log_warning "Limited memory detected. Using $ninja_jobs parallel jobs."
    fi

    log_info "Using $ninja_jobs parallel jobs (8 Cortex-A57 cores available)"

    cd "$SRC_DIR"

    # Show compilation progress
    export NINJA_STATUS="[%f/%t %o/s %es] "

    # Передаём targets без кавычек для раскрытия в несколько аргументов
    if ninja -C out/Release -j$ninja_jobs $target; then
        cd - > /dev/null
        update_timestamp "compile"
        log_success "Compile stage: COMPLETED ($target)"
        ensure_navigation_api_artifacts
    else
        cd - > /dev/null
        log_error "Compile stage: FAILED ($target)"
        return 1
    fi
}

ensure_navigation_api_artifacts() {
    # Skip when running inside the container; the build step already ran there
    if is_inside_docker; then
        return 0
    fi

    local obj_path="${OUT_DIR}/obj/third_party/blink/renderer/core/core/navigation_api.o"
    local snapshot_path="${OUT_DIR}/v8_context_snapshot_generator"

    # If the object exists but is empty, rebuild it inside the container so the thin archive stays valid.
    if [[ -f "$obj_path" ]] && [[ ! -s "$obj_path" ]]; then
        log_warning "Detected empty navigation_api.o; rebuilding inside ${DOCKER_CONTAINER_NAME}"
        run_in_builder_container "ninja -C out/Release obj/third_party/blink/renderer/core/core/navigation_api.o" || \
            log_error "Failed to rebuild navigation_api.o inside ${DOCKER_CONTAINER_NAME}"
    fi

    # Ensure the snapshot generator binary is present since the linker previously failed when built on host.
    if [[ ! -f "$snapshot_path" ]] || [[ ! -s "$snapshot_path" ]]; then
        log_warning "Ensuring v8_context_snapshot_generator exists inside ${DOCKER_CONTAINER_NAME}"
        run_in_builder_container "ninja -C out/Release v8_context_snapshot_generator" || \
            log_error "Failed to build v8_context_snapshot_generator inside ${DOCKER_CONTAINER_NAME}"
    fi

    # If we touched anything, record the compile timestamp again so dashboard reflects the fix.
    if [[ -s "$obj_path" ]] && [[ -s "$snapshot_path" ]]; then
        update_timestamp "compile"
        log_success "Navigation API artifacts verified (via ${DOCKER_CONTAINER_NAME})"
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

    # Create makepkg config for native ARM64 build if not exists
    if [[ ! -f ".makepkg-aarch64.conf" ]]; then
        log_info "Creating .makepkg-aarch64.conf for native ARM64 build..."
        cat > .makepkg-aarch64.conf << 'EOF'
#
# makepkg configuration for native ARM64 build
#

CARCH="aarch64"
CHOST="aarch64-unknown-linux-gnu"

# Package formats
PKGEXT='.pkg.tar.zst'
SRCEXT='.src.tar.gz'

# Standard options for native ARM64 build
OPTIONS=(strip docs libtool staticlibs emptydirs !zipman !purge !debug !lto)

# Use parallel compression (all 8 Cortex-A57 cores)
COMPRESSZST=(zstd -c -T8 --ultra -20 -)

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
            # По умолчанию собирать все targets для полного пакета
            local target="${2:-chrome chrome_sandbox chromedriver}"
            stage_compile "$target"
            ;;
        "package")
            stage_package
            ;;
        "ninja")
            # Quick ninja rebuild for code changes
            # По умолчанию собирать все targets для полного пакета
            local target="${2:-chrome chrome_sandbox chromedriver}"
            log_info "Quick ninja rebuild: $target"
            if [[ -f "${OUT_DIR}/build.ninja" ]]; then
                # Rust environment variables are already set globally at script start
                # Verify Rust environment before building
                log_info "Rust sysroot: $(rustc --print sysroot)"

                cd "$SRC_DIR"
                # Передаём targets без кавычек для раскрытия в несколько аргументов
                ninja -C out/Release -j7 $target
                cd - > /dev/null
                log_success "Ninja rebuild completed"
            else
                log_error "Build not configured. Run 'configure' first."
            fi
            ;;
        "auto"|"")
            log_info "Starting smart incremental build (native ARM64)..."
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
            log_warning "Starting full rebuild (cleaning first, native ARM64)..."
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
            echo "Native ARM64 build for Baikal-M (Cortex-A57 r1p3)"
            echo "Runs inside Docker container (Arch Linux ARM aarch64)"
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
            echo "  sysroot   - Prepare native ARM64 build environment"
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
