#!/bin/bash
# Script to set up Arch Linux Docker container for ungoogled-chromium build
# MODERNIZED: Uses fresh Arch Linux libraries instead of old Debian Bullseye sysroot

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Check if running as root in container
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root inside the Docker container!"
    exit 1
fi

log_info "Setting up Arch Linux Docker container for ungoogled-chromium build..."
log_info "MODERN BUILD: Using fresh Arch Linux libraries (not old Debian Bullseye)"

# Step 1: Initialize pacman
log_info "Step 1: Initializing pacman..."

# Fix mirrorlist for old Arch Linux ARM images
log_info "Updating mirrorlist to current Arch Linux ARM mirrors..."
cat > /etc/pacman.d/mirrorlist << 'EOF'
# Arch Linux ARM - aarch64
Server = http://mirror.archlinuxarm.org/$arch/$repo
Server = http://de.mirror.archlinuxarm.org/$arch/$repo
Server = http://fl.us.mirror.archlinuxarm.org/$arch/$repo
EOF
log_success "Mirrorlist updated"

# Initialize and populate keys (including Arch Linux ARM)
log_info "Initializing pacman keyring with Arch Linux ARM keys..."
pacman-key --init
pacman-key --populate archlinux archlinuxarm
log_success "Keyring initialized"

# Import Arch Linux ARM builder key manually if needed
log_info "Ensuring Arch Linux ARM Build System key is trusted..."
pacman-key --keyserver keyserver.ubuntu.com --recv-keys 68B3537F39A313B3E574D06777193F152BDBE6A6 || true
pacman-key --lsign-key 68B3537F39A313B3E574D06777193F152BDBE6A6 || true

# Full system upgrade with signature checks bypassed for first run
log_info "Upgrading system packages (first sync may require --disable-download-timeout)..."
pacman -Syyu --noconfirm --disable-download-timeout
log_success "Pacman initialized and system upgraded"

# Step 2: Install build dependencies
log_info "Step 2: Installing build dependencies..."
log_info "Installing compiler toolchain, build tools, and ALL development libraries"

PACKAGES=(
    # Core build tools
    base-devel
    git
    clang
    llvm
    lld
    rustup
    python
    gn
    ninja
    gperf
    nodejs
    npm
    nasm
    patchelf
    ccache
    cmake
    pkgconf

    # Java for build scripts (use specific package to avoid prompt)
    jre-openjdk-headless

    # System utilities
    rsync
    wget
    curl
    unzip

    # Development headers and libraries for Chromium dependencies
    # CRITICAL: These are MODERN Arch Linux versions, not old Debian Bullseye!

    # Graphics and GPU
    mesa
    libva
    libva-mesa-driver
    libdrm
    libglvnd
    vulkan-icd-loader
    vulkan-headers

    # Wayland and display
    wayland
    wayland-protocols
    libxkbcommon

    # X11 (for XWayland compatibility)
    libx11
    libxext
    libxrandr
    libxcomposite
    libxdamage
    libxfixes
    libxi
    libxtst
    libxss

    # GUI toolkit
    gtk3
    gtk4
    at-spi2-core

    # Audio and video
    pipewire
    libpulse
    alsa-lib
    opus
    libvpx
    dav1d
    aom
    libwebp

    # Image libraries
    libjpeg-turbo
    libpng

    # Text rendering
    harfbuzz
    freetype2
    fontconfig
    pango
    cairo

    # System libraries
    nss
    cups
    dbus
    systemd-libs
    libcap
    libevent
    snappy
    re2
    minizip
    zlib
    brotli
    zstd

    # XML/XSLT
    libxml2
    libxslt

    # Other utilities
    lcms2
    fribidi

    # Python packages
    python-httplib2
    python-pyparsing
    python-six

    # Rust bindgen
    rust-bindgen

    # Qt6 for KDE integration
    qt6-base
)

if ! pacman -S --needed --noconfirm "${PACKAGES[@]}"; then
    log_error "Failed to install required packages"
    exit 1
fi
log_success "Build dependencies installed (modern Arch Linux libraries)"

# Step 3: Set up Rust stable toolchain
log_info "Step 3: Setting up Rust 1.86.0 stable toolchain..."
export RUSTUP_HOME=/opt/rust
export CARGO_HOME=/opt/rust
mkdir -p /opt/rust

log_info "Installing Rust 1.86.0 stable toolchain..."
# Chromium requires stable Rust 1.86.0 to avoid __rust_no_alloc_shim_is_unstable errors
rustup toolchain install 1.86.0 --profile minimal
rustup default 1.86.0

log_info "Adding ARM64 target for cross-compilation..."
rustup target add aarch64-unknown-linux-gnu

# Make /opt/rust readable by all users
log_info "Setting permissions on /opt/rust..."
chmod -R a+rX /opt/rust

# Make rust available system-wide
echo 'export RUSTUP_HOME=/opt/rust' > /etc/profile.d/rust.sh
echo 'export CARGO_HOME=/opt/rust' >> /etc/profile.d/rust.sh
echo 'export PATH="/opt/rust/bin:$PATH"' >> /etc/profile.d/rust.sh
chmod +x /etc/profile.d/rust.sh

# Verify installation
log_info "Verifying Rust installation..."
rustc --version
log_success "Rust stable 1.86.0 configured with ARM64 support"

# Step 4: Verify clang resource directory
log_info "Step 4: Verifying clang resource directory..."
CLANG_VERSION_FULL=$(clang --version | head -1 | sed 's/.*version \([0-9.]*\).*/\1/')
CLANG_VERSION_MAJOR=$(echo "$CLANG_VERSION_FULL" | cut -d. -f1)
CLANG_ACTUAL_DIR="/usr/lib/clang/${CLANG_VERSION_MAJOR}"
CLANG_RESOURCE_DIR="${CLANG_ACTUAL_DIR}/include"

if [[ -d "$CLANG_RESOURCE_DIR" ]]; then
    log_info "Clang resource directory exists at $CLANG_RESOURCE_DIR"
    if [[ ! -f "$CLANG_RESOURCE_DIR/stddef.h" ]]; then
        log_error "stddef.h not found in clang resource directory!"
        exit 1
    fi
    log_info "stddef.h found in clang resource directory"
else
    log_error "Clang resource directory not found at $CLANG_RESOURCE_DIR"
    exit 1
fi

# Create symlinks for compatibility
for ver in 19 20 21 22; do
    if [[ "$ver" != "$CLANG_VERSION_MAJOR" ]] && [[ ! -e "/usr/lib/clang/$ver" ]]; then
        ln -sf "$CLANG_VERSION_MAJOR" "/usr/lib/clang/$ver"
        log_info "Created symlink /usr/lib/clang/$ver -> $CLANG_VERSION_MAJOR"
    fi
done

log_success "Clang configuration verified"

# Step 5: Create symlinks for Rust tools
log_info "Step 5: Creating Rust tool symlinks in /usr/bin..."
for tool in rustc cargo rustup rustdoc; do
    if [[ -f "/opt/rust/bin/$tool" ]] && [[ ! -e "/usr/bin/$tool" ]]; then
        ln -sf "/opt/rust/bin/$tool" "/usr/bin/$tool"
        log_info "Created symlink /usr/bin/$tool -> /opt/rust/bin/$tool"
    fi
done
log_success "Rust tool symlinks created"

# Step 6: Set up machine ID
log_info "Step 6: Setting up machine ID..."
systemd-machine-id-setup
log_success "Machine ID configured"

# Step 7: Create builder user (with host UID/GID to avoid permission issues)
log_info "Step 7: Creating builder user..."
if ! id "builder" &>/dev/null; then
    # Use HOST_UID/HOST_GID from Docker environment if provided
    # This ensures files created by builder have correct ownership on host
    if [[ -n "${HOST_UID:-}" ]] && [[ -n "${HOST_GID:-}" ]]; then
        log_info "Creating builder with UID=$HOST_UID GID=$HOST_GID (matching host user)"

        # Check if UID/GID already exist (e.g. default 'alarm' user in Arch Linux ARM)
        EXISTING_USER=$(getent passwd "$HOST_UID" | cut -d: -f1 || true)
        if [[ -n "$EXISTING_USER" ]]; then
            log_info "User '$EXISTING_USER' already has UID=$HOST_UID, renaming to 'builder'"
            usermod -l builder "$EXISTING_USER"
            groupmod -n builder "$EXISTING_USER" 2>/dev/null || true
            usermod -d /home/builder -m builder 2>/dev/null || true
        else
            groupadd -g "$HOST_GID" builder 2>/dev/null || true
            useradd -m -u "$HOST_UID" -g "$HOST_GID" builder
        fi
    else
        log_info "Creating builder with default UID/GID"
        useradd -m builder
    fi
    log_success "Builder user created"
else
    log_info "Builder user already exists"
fi

# Step 8: Set up permissions
log_info "Step 8: Setting up permissions..."
chown -R builder:builder /work
echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder
chmod 0440 /etc/sudoers.d/builder

# Add Rust environment to builder's bashrc
cat >> /home/builder/.bashrc << 'BASHRC_EOF'

# Load Rust environment
if [ -f /etc/profile.d/rust.sh ]; then
    source /etc/profile.d/rust.sh
fi
BASHRC_EOF
chown builder:builder /home/builder/.bashrc

log_success "Permissions configured"

# Step 9: Create startup script
log_info "Step 9: Creating startup script..."
cat > /home/builder/start-build.sh << 'EOF'
#!/bin/bash
# Load Rust environment
if [ -f /etc/profile.d/rust.sh ]; then
    source /etc/profile.d/rust.sh
fi
cd /work
echo "==================================================================="
echo "ungoogled-chromium-baikal Build Environment Ready"
echo "==================================================================="
echo ""
echo "MODERN BUILD SYSTEM:"
echo "  - Uses fresh Arch Linux libraries (NOT old Debian Bullseye)"
echo "  - Fixed --use-gl parameter bug"
echo "  - All dependencies are up-to-date"
echo ""
echo "To start the build process, run:"
echo "  ./smart-build.sh auto       # Smart incremental build"
echo "  ./smart-build.sh full       # Full rebuild from scratch"
echo "  ./smart-build.sh status     # Show build status"
echo ""
echo "Current directory: $(pwd)"
echo "Available disk space: $(df -h . | awk 'NR==2 {print $4}')"
echo "Available memory: $(free -h | awk 'NR==2 {print $7}')"
echo "CPU cores: $(nproc)"
echo ""
echo "Installed library versions:"
echo "  Mesa: $(pacman -Q mesa | awk '{print $2}')"
echo "  libva: $(pacman -Q libva | awk '{print $2}')"
echo "  harfbuzz: $(pacman -Q harfbuzz | awk '{print $2}')"
echo "  ffmpeg: $(pacman -Q ffmpeg | awk '{print $2}')"
echo ""
echo "==================================================================="
exec /bin/bash
EOF

chmod +x /home/builder/start-build.sh
chown builder:builder /home/builder/start-build.sh
log_success "Startup script created"

# Step 10: Summary
log_success "Docker container setup completed!"
echo ""
echo "=========================================="
echo "MODERN BUILD ENVIRONMENT READY"
echo "=========================================="
echo ""
echo "To start building, switch to builder user:"
echo "  su - builder"
echo "  cd /work"
echo "=========================================="
su - builder
cd /work
