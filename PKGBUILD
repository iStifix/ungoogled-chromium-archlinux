# Maintainer: Ungoogled Software Contributors
# Maintainer: networkException <git@nwex.de>

# Based on extra/chromium, with ungoogled-chromium patches

# Maintainer: Evangelos Foutras <foutrelis@archlinux.org>
# Maintainer: Christian Heusel <gromit@archlinux.org>
# Contributor: Pierre Schmitz <pierre@archlinux.de>
# Contributor: Jan "heftig" Steffens <jan.steffens@gmail.com>
# Contributor: Daniel J Griffiths <ghost1227@archlinux.us>

pkgbase=ungoogled-chromium-baikal
pkgname=("$pkgbase")
pkgver=141.0.7390.122
pkgrel=1
_launcher_ver=8
_manual_clone=1
_system_clang=1
# ungoogled chromium variables
_pkgname=ungoogled-chromium
_uc_usr=ungoogled-software
_uc_ver=141.0.7390.122-1
pkgdesc="A lightweight approach to removing Google web service dependency"
arch=('x86_64' 'aarch64')
url="https://github.com/ungoogled-software/ungoogled-chromium"
license=('BSD-3-Clause')
# MODERNIZED: Added missing dependencies for modern Arch Linux build
depends=('gtk3' 'nss' 'alsa-lib' 'xdg-utils' 'libxss' 'libcups' 'libgcrypt'
         'ttf-liberation' 'systemd' 'dbus' 'libpulse' 'pciutils' 'libva' 'libva-mesa-driver'
         'libffi' 'desktop-file-utils' 'hicolor-icon-theme' 'mesa' 'libdrm' 'aom' 'dav1d'
         'libvpx' 'opus' 'flac' 'harfbuzz' 'freetype2' 'fontconfig' 'libpng' 'libjpeg-turbo'
         'libwebp' 'libxml2' 'libxslt' 'brotli' 'zlib' 'zstd' 'wayland' 'wayland-protocols'
         'libxkbcommon')
makedepends=('python' 'gn' 'ninja' 'clang' 'lld' 'gperf' 'nodejs' 'pipewire'
             'rust' 'rust-bindgen' 'qt6-base' 'java-runtime-headless'
             'git' 'cups' 'compiler-rt')
optdepends=('pipewire: WebRTC desktop sharing under Wayland'
            'kdialog: support for native dialogs in Plasma'
            'gtk4: for --gtk-version=4 (GTK4 IME might work better on Wayland)'
            'org.freedesktop.secrets: password storage backend on GNOME / Xfce'
            'kwallet: support for storing passwords in KWallet on Plasma'
            'upower: Battery Status API support')
provides=("chromium=$pkgver" "chromedriver=$pkgver" "${_pkgname}=$pkgver")
conflicts=("${_pkgname}")
options=('!lto') # Chromium adds its own flags for ThinLTO
backup=('etc/chromium-flags.conf')
source=(https://commondatastorage.googleapis.com/chromium-browser-official/chromium-$pkgver-lite.tar.xz
        $_pkgname-$_uc_ver.tar.gz::https://github.com/$_uc_usr/ungoogled-chromium/archive/$_uc_ver.tar.gz
        https://github.com/foutrelis/chromium-launcher/archive/v$_launcher_ver/chromium-launcher-$_launcher_ver.tar.gz
        compiler-rt-adjust-paths.patch
        increase-fortify-level.patch
        use-oauth2-client-switches-as-default.patch
        0001-adjust-buffer-format-order.patch
        0001-enable-linux-unstable-deb-target.patch
        0001-ozone-wayland-implement-text_input_manager_v3.patch
        0001-ozone-wayland-implement-text_input_manager-fixes.patch
        0001-vaapi-flag-ozone-wayland.patch
        chromium-138-nodejs-version-check.patch
        chromium-138-rust-1.86-mismatched_lifetime_syntaxes.patch
        chromium-141-cssstylesheet-iwyu.patch
        chromium-141-remove-telemetry-deps.patch
        chromium-rx550-device-names.patch
        libvpx-ratectrl.patch
        chromium-libvpx-rtc-static.patch
        chromium-libaom-rtc-static.patch
        vaapi-hardware-acceleration.patch
        fetch-libvpx-rtc.sh
        baikal-chromium-launcher.py
        baikal-chromium-flags.conf)
sha256sums=('f8136322daf003564966d00ae82b7347cd74f143f54866bdf0d7dbae8f983647'
            '6592c09f06a2adcbfc8dba3e216dc3a08ca2f8c940fc2725af90c5d042404be9'
            '213e50f48b67feb4441078d50b0fd431df34323be15be97c55302d3fdac4483a'
            'ec8e49b7114e2fa2d359155c9ef722ff1ba5fe2c518fa48e30863d71d3b82863'
            'd634d2ce1fc63da7ac41f432b1e84c59b7cceabf19d510848a7cff40c8025342'
            'e6da901e4d0860058dc2f90c6bbcdc38a0cf4b0a69122000f62204f24fa7e374'
            '8ba5c67b7eb6cacd2dbbc29e6766169f0fca3bbb07779b1a0a76c913f17d343f'
            '2a44756404e13c97d000cc0d859604d6848163998ea2f838b3b9bb2c840967e3'
            'd9974ddb50777be428fd0fa1e01ffe4b587065ba6adefea33678e1b3e25d1285'
            'a2da75d0c20529f2d635050e0662941c0820264ea9371eb900b9d90b5968fa6a'
            '9a5594293616e1390462af1f50276ee29fd6075ffab0e3f944f6346cb2eb8aec'
            '90017978b686a0ce5c82e4a88e073ac8e7c620b2650019f3a99dc0dcc8339914'
            '11a96ffa21448ec4c63dd5c8d6795a1998d8e5cd5a689d91aea4d2bdd13fb06e'
            '5480b4c519f36915d72016a02bc45dd4fba93442728d129c4337c89230bd9efd'
            'c9a70a6f26d5275db5a1692f0fa2f39ecc54e0c200209aa8e49653aea9e9c69a'
            '2f9b2011543b02d2ccd2deec61edfa4614532a88e1acdd03a86e7773c536c668'
            '5abc8611463b3097fc5ce58017ef918af8b70d616ad093b8b486d017d021bbdf'
            'de5c873564b09713b65dd9e6a0b9049d7b3cf8f881436f36e1c091824b63e876'
            '519c13cab4e41042970a525fc16e8f4ba0d41f008711e2d64e0a4c6014a10d50'
            'b0462759c6d8a56a3a2516dad6b1cc621a98b2399c0cb458031cf7743012f395'
            '6f178493285330020d4c47b83487f1dd2ea077ca349772d3d4009c8e2bd749b7'
            'f3e7874db0042561e474d1e3eb67a3764bd4c3a119e1175c45b9599b13c77457')

if (( _manual_clone )); then
  source[0]=fetch-chromium-release
  makedepends+=('python-httplib2' 'python-pyparsing' 'python-six' 'npm' 'rsync')
fi

# Possible replacements are listed in build/linux/unbundle/replace_gn_files.py
# Keys are the names in the above script; values are the dependencies in Arch
# MODERNIZED: Using ALL modern system libraries (no old Debian Bullseye sysroot)
declare -gA _system_libs=(
  [brotli]=brotli
  [dav1d]=dav1d
  #[ffmpeg]=ffmpeg    # YouTube playback stopped working in Chromium 120
  [flac]=flac
  [fontconfig]=fontconfig
  [freetype]=freetype2
  [harfbuzz-ng]=harfbuzz
  #[icu]=icu
  #[jsoncpp]=jsoncpp  # needs libstdc++
  #[libaom]=aom       # Commented out but aom is in depends
  #[libavif]=libavif  # needs -DAVIF_ENABLE_EXPERIMENTAL_GAIN_MAP=ON
  [libjpeg]=libjpeg-turbo
  [libpng]=libpng
  [libvpx]=libvpx
  [libwebp]=libwebp
  [libxml]=libxml2
  [libxslt]=libxslt
  [opus]=opus
  #[re2]=re2          # needs libstdc++
  #[snappy]=snappy    # needs libstdc++
  #[woff2]=woff2      # needs libstdc++
  [zlib]=minizip
)
# REMOVED: Old code that disabled all system_libs for ARM64
# We now use modern Arch Linux libraries for ALL architectures

_unwanted_bundled_libs=(
  $(printf "%s\n" ${!_system_libs[@]} | sed 's/^libjpeg$/&_turbo/')
)
depends+=(${_system_libs[@]})

prepare() {
  if (( _manual_clone )); then
    if [[ ! -d chromium-$pkgver ]]; then
      # Prevent sysroot download for native ARM64 build
      export GYP_DEFINES="use_sysroot=0"
      ./fetch-chromium-release $pkgver

      # fetch-chromium-release creates chromium-checkout/src
      # Use symlink instead of rename to let gclient sync complete in background
      if [[ -d chromium-checkout/src ]]; then
        msg2 'Creating symlink chromium-$pkgver -> chromium-checkout/src...'
        ln -sfn chromium-checkout/src chromium-$pkgver
      fi
    else
      msg2 'Skipping fetch-chromium-release; existing checkout detected.'
    fi
  fi
  cd chromium-$pkgver

  # Remove Debian sysroot if it was downloaded (we don't need it for native ARM64)
  if [[ -d "build/linux/debian_bullseye_arm64-sysroot" ]]; then
    msg2 'Removing unnecessary Debian Bullseye ARM64 sysroot...'
    rm -rf build/linux/debian_bullseye_arm64-sysroot
  fi

  local _target_cpu="${CARCH:-$(uname -m)}"
  case "${_target_cpu}" in
    aarch64|arm64) _target_cpu=arm64 ;;
    x86_64|amd64) _target_cpu=x64 ;;
  esac

  # REMOVED: Old Debian Bullseye sysroot download for ARM64
  # We now use system libraries from /usr/lib for all architectures
  # No need to download old sysroot or install cups-config to it

  # Allow building against system libraries in official builds
  sed -i 's/OFFICIAL_BUILD/GOOGLE_CHROME_BUILD/' \
    tools/generate_shim_headers/generate_shim_headers.py

  # https://crbug.com/893950
  sed -i -e 's/\<xmlMalloc\>/malloc/' -e 's/\<xmlFree\>/free/' \
         -e '1i #include <cstdlib>' \
    third_party/blink/renderer/core/xml/*.cc \
    third_party/blink/renderer/core/xml/parser/xml_document_parser.cc \
    third_party/libxml/chromium/*.cc

  # Use the --oauth2-client-id= and --oauth2-client-secret= switches for
  # setting GOOGLE_DEFAULT_CLIENT_ID and GOOGLE_DEFAULT_CLIENT_SECRET at
  # runtime -- this allows signing into Chromium without baked-in values
  patch -Np1 -i ../use-oauth2-client-switches-as-default.patch

  # Upstream fixes

  # Fixes from Gentoo
  patch -Np1 -i ../chromium-138-nodejs-version-check.patch
  patch -Np1 -i ../chromium-141-cssstylesheet-iwyu.patch

  # Fix telemetry dependencies removed by ungoogled-chromium
  patch -Np1 -i ../chromium-141-remove-telemetry-deps.patch

  # Fixes from NixOS
  patch -Np1 -i ../chromium-138-rust-1.86-mismatched_lifetime_syntaxes.patch

  # Allow libclang_rt.builtins from compiler-rt >= 16 to be used
  patch -Np1 -i ../compiler-rt-adjust-paths.patch

  # Increase _FORTIFY_SOURCE level to match Arch's default flags
  patch -Np1 -i ../increase-fortify-level.patch

  # Ensure AMD Polaris (RX550) is identified correctly
  patch -Np1 -i ../chromium-rx550-device-names.patch

  # VA-API hardware acceleration patches (CRITICAL for Baikal M)
  # Apply libvpx/libaom RTC patches for hardware encoding/decoding support
  patch -Np1 -i ../libvpx-ratectrl.patch
  patch -Np1 -i ../chromium-libvpx-rtc-static.patch
  patch -Np1 -i ../chromium-libaom-rtc-static.patch

  # NOTE: chromium-rust-allocator-duplicate-attrs.patch REMOVED
  # Chromium 141+ already has correct __rust_no_alloc_shim_is_unstable_v2() implementation
  # smart-build.sh adds missing __rust_no_alloc_shim_is_unstable() (without _v2) in stage_sysroot

  # Fixes for building with libstdc++ instead of libc++

  if (( !_system_clang )); then
    # Use prebuilt rust as system rust cannot be used due to the error:
    #   error: the option `Z` is only accepted on the nightly compiler
    ./tools/rust/update_rust.py

    # To link to rust libraries we need to compile with prebuilt clang
    ./tools/clang/scripts/update.py
  fi

  # Ungoogled Chromium changes
  _ungoogled_repo="$srcdir/$_pkgname-$_uc_ver"
  _utils="${_ungoogled_repo}/utils"
  msg2 'Pruning binaries'
  python "$_utils/prune_binaries.py" ./ "$_ungoogled_repo/pruning.list" || echo "some errors"
  msg2 'Applying patches'
  python "$_utils/patches.py" apply ./ "$_ungoogled_repo/patches"
  msg2 'Applying domain substitution'
  python "$_utils/domain_substitution.py" apply -r "$_ungoogled_repo/domain_regex.list" \
    -f "$_ungoogled_repo/domain_substitution.list" -c domainsubcache.tar.gz ./

  # Fix ungoogled-chromium domain substitution issues
  msg2 'Fixing domain substitution issues'

  # Create missing meta.json file
  if [[ -d "v8/tools/builtins-pgo/profiles" ]] && [[ ! -f "v8/tools/builtins-pgo/profiles/meta.json" ]]; then
    echo '{}' > "v8/tools/builtins-pgo/profiles/meta.json"
    echo "✓ Created v8/tools/builtins-pgo/profiles/meta.json"
  fi

  # Create harfbuzz-subset symlink
  if [[ -d "third_party/harfbuzz-ng" ]] && [[ ! -e "third_party/harfbuzz-subset" ]]; then
    cd third_party
    ln -sf harfbuzz-ng harfbuzz-subset
    cd ..
    echo "✓ Created symlink third_party/harfbuzz-subset -> harfbuzz-ng"
  fi

  # Create rust-toolchain VERSION file
  if [[ -d "third_party/rust-toolchain" ]] && [[ ! -f "third_party/rust-toolchain/VERSION" ]]; then
    echo "rustc 1.86.0 stable" > "third_party/rust-toolchain/VERSION"
    echo "✓ Created third_party/rust-toolchain/VERSION"
  fi

  # Create llvm-build revision file for system clang
  if [[ ! -d "third_party/llvm-build/Release+Asserts" ]]; then
    mkdir -p "third_party/llvm-build/Release+Asserts"
  fi
  if [[ ! -f "third_party/llvm-build/Release+Asserts/cr_build_revision" ]]; then
    clang --version | head -1 | sed 's/.*version \([0-9.]*\).*/\1/' > "third_party/llvm-build/Release+Asserts/cr_build_revision"
    echo "✓ Created third_party/llvm-build/Release+Asserts/cr_build_revision"
  fi

  # Link to system tools required by the build
  local _build_arch="${CARCH:-$(uname -m)}"
  case "${_build_arch}" in
    aarch64|arm64)
      mkdir -p third_party/node/linux/node-linux-arm64/bin/ third_party/jdk/current/bin/
      ln -s /usr/bin/node third_party/node/linux/node-linux-arm64/bin/
      ;;
    *)
      mkdir -p third_party/node/linux/node-linux-x64/bin/ third_party/jdk/current/bin/
      ln -s /usr/bin/node third_party/node/linux/node-linux-x64/bin/
      ;;
  esac
  ln -s /usr/bin/java third_party/jdk/current/bin/

  # Fetch libvpx/libaom RTC source files for VA-API
  if [[ -x "$srcdir/fetch-libvpx-rtc.sh" ]]; then
    msg2 'Fetching libvpx/libaom RTC source files for VA-API'
    "$srcdir/fetch-libvpx-rtc.sh" "$srcdir/chromium-$pkgver"
  fi

  # Remove bundled libraries for which we will use the system copies
  # Native ARM64 build also uses system libraries (use_sysroot=false)
  local _lib
  for _lib in ${_unwanted_bundled_libs[@]}; do
    find "third_party/$_lib" -type f \
      \! -path "third_party/$_lib/chromium/*" \
      \! -path "third_party/$_lib/google/*" \
      \! -path "third_party/harfbuzz-ng/utils/hb_scoped.h" \
      \! -regex '.*\.\(gn\|gni\|isolate\)' \
      -delete
  done

  ./build/linux/unbundle/replace_gn_files.py \
    --system-libraries "${!_system_libs[@]}"

}

build() {

  cd chromium-$pkgver

  # Set Cortex-A57 optimizations for ARM64 native build
  local _build_arch="${CARCH:-$(uname -m)}"
  case "${_build_arch}" in
    aarch64|arm64)
      # Cortex-A57 r1p3 (ARMv8.0-A baseline) - SAFE FLAGS ONLY
      # NOTE: -O2 (NOT -O3) — для графических приложений/compositor'ов (стабильность WebGL/Canvas!)
      # NOTE: -ffast-math REMOVED — unsafe for OpenGL/WebGL/VA-API (causes rendering artifacts)
      export CFLAGS="-march=armv8-a -mtune=cortex-a57 -O2 -pipe -fno-plt -fexceptions -ftree-vectorize -fomit-frame-pointer -fno-semantic-interposition"
      export CXXFLAGS="${CFLAGS}"
      export RUSTFLAGS="-C target-cpu=cortex-a57 -C target-feature=+neon,+crc -C opt-level=3 -C codegen-units=1 -C lto=no"
      export RUSTC_BOOTSTRAP=1
      ;;
  esac

  if (( _system_clang )); then
    export CC=clang
    export CXX=clang++
    export AR=ar
    export NM=nm
  else
    local _clang_path="$PWD/third_party/llvm-build/Release+Asserts/bin"
    export CC=$_clang_path/clang
    export CXX=$_clang_path/clang++
    export AR=$_clang_path/llvm-ar
    export NM=$_clang_path/llvm-nm
  fi

  local _target_cpu="x64"
  local _custom_toolchain="//build/toolchain/linux/unbundle:default"
  local _host_toolchain="//build/toolchain/linux/unbundle:default"
  local _use_sysroot=false

  case "${_build_arch}" in
    aarch64|arm64)
      _target_cpu="arm64"
      _custom_toolchain="//build/toolchain/linux:clang_arm64"
      _host_toolchain="//build/toolchain/linux:clang_arm64"
      _use_sysroot=false  # Native ARM64 build uses system libraries
      ;;
  esac

  local _flags=(
    "target_os=\"linux\""
    "target_cpu=\"$_target_cpu\""
    "custom_toolchain=\"$_custom_toolchain\""
    "host_toolchain=\"$_host_toolchain\""
    "is_official_build=true" # implies is_cfi=true on x86_64
    "symbol_level=0" # sufficient for backtraces on x86(_64)
    "treat_warnings_as_errors=false"
    "fatal_linker_warnings=false"
    "disable_fieldtrial_testing_config=true"
    "blink_enable_generated_code_formatting=false"
    "use_custom_libcxx=true" # https://github.com/llvm/llvm-project/issues/61705
    "use_sysroot=$_use_sysroot"
    "use_system_libffi=true"
    "use_vaapi=true"
    "rtc_use_pipewire=true"
    "link_pulseaudio=true"
    "ffmpeg_branding=\"Chrome\""
    "proprietary_codecs=true"
    "enable_widevine=true"
    "use_qt5=false"
    "use_qt6=true"
    "moc_qt6_path=\"/usr/lib/qt6\""
    "enable_platform_hevc=true"
    "enable_hevc_parser_and_hw_decoder=true"
    'use_clang_modules=false'
  )

  if [[ $_target_cpu == "arm64" ]]; then
    _flags+=("is_cfi=false")
    _flags+=("v8_snapshot_toolchain=\"//build/toolchain/linux:clang_arm64\"")
    _flags+=("enable_nacl=false")  # NaCl not supported on ARM64
    _flags+=("use_thin_lto=false")  # Disabled: causes issues with OpenGL/EGL driver calls
    _flags+=("concurrent_links=1")  # Prevent OOM on 8GB RAM system (linking requires ~6-8GB per process)
    # Note: Cortex-A57 optimizations passed via CFLAGS (-march=armv8-a -mtune=cortex-a57)
    #       -O2 used instead of -O3 (stability for WebGL/Canvas rendering!)
    #       -ffast-math REMOVED (unsafe for OpenGL/WebGL/VA-API)
    #       arm_float_abi and arm_use_neon are auto-set to "hard" and true for ARM64
    # GPU acceleration optimizations for AMD RX550
    _flags+=("enable_vulkan=true")
    _flags+=("use_dawn=true")
    _flags+=("dawn_enable_vulkan=true")
    _flags+=("enable_gpu_service_logging=false")
    # Modern codecs and features
    _flags+=("rtc_use_h264=true")  # H.264 for WebRTC (video calls)
    _flags+=("enable_av1_decoder=true")  # AV1 decoder (via dav1d)
    # HD Audio formats (critical for HDMI 4K display)
    _flags+=("enable_platform_ac3_eac3_audio=true")  # AC3/EAC3 Dolby Digital/Plus
    _flags+=("enable_platform_dts_audio=true")  # DTS/DTS-HD audio
    # HDR video support
    _flags+=("enable_platform_dolby_vision=true")  # Dolby Vision HDR
    # Streaming support
    _flags+=("enable_hls_demuxer=true")  # HLS streaming (YouTube, Twitch, etc.)
    _flags+=("enable_mse_mpeg2ts_stream_parser=true")  # MPEG-TS parser (required for HLS)
  fi

  if [[ -n ${_system_libs[icu]+set} ]]; then
    _flags+=('icu_use_data_file=false')
  fi

  # Append ungoogled chromium flags to _flags array
  _ungoogled_repo="$srcdir/$_pkgname-$_uc_ver"
  readarray -t -O ${#_flags[@]} _flags < "${_ungoogled_repo}/flags.gn"

  if (( _system_clang )); then
    local _clang_version=$(
      clang --version | grep -m1 version | sed 's/.* \([0-9]\+\).*/\1/')

    _flags+=(
      'clang_base_path="/usr"'
      'clang_use_chrome_plugins=false'
      "clang_version=\"$_clang_version\""
      'chrome_pgo_phase=0' # needs newer clang to read the bundled PGO profile
    )

    # Allow the use of nightly features with stable Rust compiler
    # https://github.com/ungoogled-software/ungoogled-chromium/pull/2696#issuecomment-1918173198
    export RUSTC_BOOTSTRAP=1

    _flags+=(
      'rust_sysroot_absolute="/usr"'
      'rust_bindgen_root="/usr"'
      "rustc_version=\"$(rustc --version)\""
    )
  fi

  # Facilitate deterministic builds (taken from build/config/compiler/BUILD.gn)
  CFLAGS+='   -Wno-builtin-macro-redefined'
  CXXFLAGS+=' -Wno-builtin-macro-redefined'
  CPPFLAGS+=' -D__DATE__=  -D__TIME__=  -D__TIMESTAMP__='

  # Do not warn about unknown warning options
  CFLAGS+='   -Wno-unknown-warning-option'
  CXXFLAGS+=' -Wno-unknown-warning-option'

  # Let Chromium set its own symbol level
  CFLAGS=${CFLAGS/-g }
  CXXFLAGS=${CXXFLAGS/-g }

  # https://github.com/ungoogled-software/ungoogled-chromium-archlinux/issues/123
  CFLAGS=${CFLAGS/-fexceptions}
  CFLAGS=${CFLAGS/-fcf-protection}
  CXXFLAGS=${CXXFLAGS/-fexceptions}
  CXXFLAGS=${CXXFLAGS/-fcf-protection}

  # This appears to cause random segfaults when combined with ThinLTO
  # https://bugs.archlinux.org/task/73518
  CFLAGS=${CFLAGS/-fstack-clash-protection}
  CXXFLAGS=${CXXFLAGS/-fstack-clash-protection}

  # https://crbug.com/957519#c122
  CXXFLAGS=${CXXFLAGS/-Wp,-D_GLIBCXX_ASSERTIONS}

  msg2 'Configuring Chromium'
  gn gen out/Release --args="${_flags[*]}"
  msg2 'Building Chromium'

  # Use optimal parallelism for Cortex-A57 (8 physical cores, no SMT)
  case "${_build_arch}" in
    aarch64|arm64)
      ninja -j8 -C out/Release chrome chrome_sandbox chromedriver
      ;;
    *)
      ninja -C out/Release chrome chrome_sandbox chromedriver
      ;;
  esac
}

package() {
  install -Dm755 "$srcdir/baikal-chromium-launcher.py" "$pkgdir/usr/bin/chromium"
  install -Dm644 "$srcdir/chromium-launcher-$_launcher_ver/LICENSE" \
    "$pkgdir/usr/share/licenses/chromium/LICENSE.launcher"

  cd chromium-$pkgver

  install -D out/Release/chrome "$pkgdir/usr/lib/chromium/chromium"
  install -D out/Release/chromedriver "$pkgdir/usr/bin/chromedriver"
  install -Dm4755 out/Release/chrome_sandbox "$pkgdir/usr/lib/chromium/chrome-sandbox"

  install -Dm644 chrome/installer/linux/common/desktop.template \
    "$pkgdir/usr/share/applications/chromium.desktop"
  install -Dm644 chrome/app/resources/manpage.1.in \
    "$pkgdir/usr/share/man/man1/chromium.1"
  sed -i \
    -e 's/@@MENUNAME@@/Chromium/g' \
    -e 's/@@PACKAGE@@/chromium/g' \
    -e 's/@@USR_BIN_SYMLINK_NAME@@/chromium/g' \
    "$pkgdir/usr/share/applications/chromium.desktop" \
    "$pkgdir/usr/share/man/man1/chromium.1"

  # Fill in common Chrome/Chromium AppData template with Chromium info
  (
    tmpl_file=chrome/installer/linux/common/appdata.xml.template
    info_file=chrome/installer/linux/common/chromium-browser.info
    . $info_file; PACKAGE=chromium
    export $(grep -o '^[A-Z_]*' $info_file)
    sed -E -e 's/@@([A-Z_]*)@@/\${\1}/g' -e '/<update_contact>/d' $tmpl_file | envsubst
  ) \
  | install -Dm644 /dev/stdin "$pkgdir/usr/share/metainfo/chromium.appdata.xml"

  local toplevel_files=(
    chrome_100_percent.pak
    chrome_200_percent.pak
    chrome_crashpad_handler
    libqt6_shim.so
    resources.pak
    v8_context_snapshot.bin

    # ANGLE
    libEGL.so
    libGLESv2.so

    # SwiftShader ICD
    libvk_swiftshader.so
    libvulkan.so.1
    vk_swiftshader_icd.json
  )

  if [[ -z ${_system_libs[icu]+set} ]]; then
    toplevel_files+=(icudtl.dat)
  fi

  cp "${toplevel_files[@]/#/out/Release/}" "$pkgdir/usr/lib/chromium/"
  install -Dm644 -t "$pkgdir/usr/lib/chromium/locales" out/Release/locales/*.pak

  for size in 24 48 64 128 256; do
    install -Dm644 "chrome/app/theme/chromium/product_logo_$size.png" \
      "$pkgdir/usr/share/icons/hicolor/${size}x${size}/apps/chromium.png"
  done

  for size in 16 32; do
    install -Dm644 "chrome/app/theme/default_100_percent/chromium/product_logo_$size.png" \
      "$pkgdir/usr/share/icons/hicolor/${size}x${size}/apps/chromium.png"
  done

  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/chromium/LICENSE"
  install -Dm644 "$srcdir/baikal-chromium-flags.conf" "$pkgdir/etc/chromium-flags.conf"
}

# vim:set ts=2 sw=2 et:
