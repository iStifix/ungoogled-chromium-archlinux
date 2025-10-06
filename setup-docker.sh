#!/bin/bash
# Script to set up Arch Linux Docker container for ungoogled-chromium build

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

# Step 1: Initialize pacman
log_info "Step 1: Initializing pacman..."
pacman-key --init
pacman-key --populate archlinux
pacman -Sy archlinux-keyring --noconfirm
pacman -Syu --noconfirm
log_success "Pacman initialized"

# Step 2: Install required packages
log_info "Step 2: Installing build dependencies..."
PACKAGES=(
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
    pipewire
    libpulse
    libva
    gtk3
    libxss
    qt6-base
    java-runtime-headless
    rsync
    cups
    dbus
    systemd-libs
    libcap
    python-httplib2
    python-pyparsing
    # Runtime libraries needed for v8_context_snapshot_generator
    libjpeg-turbo
    libxml2
    libxslt
    libwebp
    opus
    minizip
    python-six
    rust-bindgen
    # Build tools
    nasm
    patchelf
)

if ! pacman -S --needed --noconfirm "${PACKAGES[@]}"; then
    log_error "Failed to install required packages"
    exit 1
fi
log_success "Build dependencies installed"

# Create symlinks for build tools (x86_64) library dependencies
# These will be resolved at build time from the sysroot:
# - libffi_pic.a: Required for SwiftShader (Vulkan software renderer) linking
# - Other libraries: Created by smart-build.sh during configure stage
log_info "Library symlinks for build tools will be created during configure stage"
log_info "smart-build.sh will create symlinks for: libjpeg.so.62, libffi_pic.a"
log_success "Build tool library configuration completed"

# Step 3: Set up Rust nightly toolchain
log_info "Step 3: Setting up Rust nightly toolchain..."
# In Arch Linux, rustup is provided by the rustup package
# We need to initialize it for the root user and make it system-wide
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
log_success "Rust nightly toolchain configured with ARM64 support"

# Step 3.5: Ensure clang resource directory has required headers
log_info "Setting up clang resource directory..."
CLANG_VERSION_FULL=$(clang --version | head -1 | sed 's/.*version \([0-9.]*\).*/\1/')
CLANG_VERSION_MAJOR=$(echo "$CLANG_VERSION_FULL" | cut -d. -f1)
CLANG_ACTUAL_DIR="/usr/lib/clang/${CLANG_VERSION_MAJOR}"
CLANG_RESOURCE_DIR="${CLANG_ACTUAL_DIR}/include"

if [[ -d "$CLANG_RESOURCE_DIR" ]]; then
    log_info "Clang resource directory exists at $CLANG_RESOURCE_DIR"
    # Check for stddef.h
    if [[ ! -f "$CLANG_RESOURCE_DIR/stddef.h" ]]; then
        log_error "stddef.h not found in clang resource directory!"
        log_info "This usually means clang package is incomplete."
        log_info "Try: pacman -S --needed clang"
        exit 1
    fi
    log_info "stddef.h found in clang resource directory"
else
    log_error "Clang resource directory not found at $CLANG_RESOURCE_DIR"
    log_info "Clang version: $CLANG_VERSION_FULL (major: $CLANG_VERSION_MAJOR)"
    exit 1
fi

# GN might use different major version, create symlinks for compatibility
# For example, clang 20.1.8 but GN expects /usr/lib/clang/21
for ver in 19 20 21 22; do
    if [[ "$ver" != "$CLANG_VERSION_MAJOR" ]] && [[ ! -e "/usr/lib/clang/$ver" ]]; then
        ln -sf "$CLANG_VERSION_MAJOR" "/usr/lib/clang/$ver"
        log_info "Created symlink /usr/lib/clang/$ver -> $CLANG_VERSION_MAJOR"
    fi
done

log_success "Clang configuration verified"

# Step 3.6: Create symlinks for Rust tools in /usr/bin
log_info "Creating Rust tool symlinks in /usr/bin..."
for tool in rustc cargo rustup rustdoc; do
    if [[ -f "/opt/rust/bin/$tool" ]] && [[ ! -e "/usr/bin/$tool" ]]; then
        ln -sf "/opt/rust/bin/$tool" "/usr/bin/$tool"
        log_info "Created symlink /usr/bin/$tool -> /opt/rust/bin/$tool"
    fi
done
log_success "Rust tool symlinks created"

# Step 4: Set up machine ID
log_info "Step 4: Setting up machine ID..."
systemd-machine-id-setup
log_success "Machine ID configured"

# Step 5: Create builder user
log_info "Step 5: Creating builder user..."
if ! id "builder" &>/dev/null; then
    useradd -m builder
    log_success "Builder user created"
else
    log_info "Builder user already exists"
fi

# Step 6: Set up permissions
log_info "Step 6: Setting up permissions..."
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

# Step 7: Create startup script for builder
log_info "Step 7: Creating startup script..."
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
echo "To start the automated build process, run:"
echo "  ./smart-build.sh auto       # Smart incremental build"
echo "  ./smart-build.sh full       # Full rebuild from scratch"
echo "  ./smart-build.sh status     # Show build status"
echo ""
echo "This will:"
echo "  1. Prepare the build environment"
echo "  2. Fix ARM64 sysroot dependencies"
echo "  3. Start the Chromium compilation (takes several hours)"
echo "  4. Create the package file"
echo "  5. Skip already completed stages for faster rebuilds"
echo ""
echo "Manual commands are also available:"
echo "  ./smart-build.sh prepare    # Prepare sources and patches"
echo "  ./smart-build.sh sysroot    # Fix ARM64 dependencies"
echo "  ./smart-build.sh compile    # Compile Chromium"
echo "  ./smart-build.sh ninja chrome # Quick rebuild (5-15 min)"
echo "  ./smart-build.sh package    # Create installation package"
echo "  ./smart-build.sh clean      # Clean all artifacts"
echo ""
echo "Current directory: $(pwd)"
echo "Available disk space: $(df -h . | awk 'NR==2 {print $4}')"
echo "Available memory: $(free -h | awk 'NR==2 {print $7}')"
echo "CPU cores: $(nproc)"
echo ""
echo "==================================================================="
exec /bin/bash
EOF

chmod +x /home/builder/start-build.sh
chown builder:builder /home/builder/start-build.sh
log_success "Startup script created"

log_success "Docker container setup completed!"
log_info "To start building, switch to builder user:"
log_info "  su - builder"
log_info "Or run the startup script directly:"
log_info "  su - builder -c '/home/builder/start-build.sh'"
