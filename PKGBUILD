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
pkgver=140.0.7339.207
pkgrel=2
_launcher_ver=8
_manual_clone=1
_system_clang=1
# ungoogled chromium variables
_pkgname=ungoogled-chromium
_uc_usr=ungoogled-software
_uc_ver=140.0.7339.207-1
pkgdesc="A lightweight approach to removing Google web service dependency"
arch=('x86_64' 'aarch64')
url="https://github.com/ungoogled-software/ungoogled-chromium"
license=('BSD-3-Clause')
depends=('gtk3' 'nss' 'alsa-lib' 'xdg-utils' 'libxss' 'libcups' 'libgcrypt'
         'ttf-liberation' 'systemd' 'dbus' 'libpulse' 'pciutils' 'libva'
         'libffi' 'desktop-file-utils' 'hicolor-icon-theme')
makedepends=('python' 'gn' 'ninja' 'clang' 'lld' 'gperf' 'nodejs' 'pipewire'
             'rustup' 'rust-bindgen' 'qt6-base' 'java-runtime-headless'
             'git' 'cups')
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
        chromium-140.0.7339.41-rust.patch
        chromium-rx550-device-names.patch
        chromium-libxml2-const.patch
        chromium-libffi-hybrid.patch
        chromium-disable-arm-sme.patch
        chromium-qt6-cross-compile.patch
        baikal-chromium-launcher.py
        baikal-chromium-flags.conf)
sha256sums=('f8136322daf003564966d00ae82b7347cd74f143f54866bdf0d7dbae8f983647'
            '6592c09f06a2adcbfc8dba3e216dc3a08ca2f8c940fc2725af90c5d042404be9'
            '213e50f48b67feb4441078d50b0fd431df34323be15be97c55302d3fdac4483a'
            '75681c815bb2a8c102f0d7af3a3790b5012adbbce38780716b257b7da2e1c3d5'
            'd634d2ce1fc63da7ac41f432b1e84c59b7cceabf19d510848a7cff40c8025342'
            'e6da901e4d0860058dc2f90c6bbcdc38a0cf4b0a69122000f62204f24fa7e374'
            '8ba5c67b7eb6cacd2dbbc29e6766169f0fca3bbb07779b1a0a76c913f17d343f'
            '2a44756404e13c97d000cc0d859604d6848163998ea2f838b3b9bb2c840967e3'
            'd9974ddb50777be428fd0fa1e01ffe4b587065ba6adefea33678e1b3e25d1285'
            'a2da75d0c20529f2d635050e0662941c0820264ea9371eb900b9d90b5968fa6a'
            '9a5594293616e1390462af1f50276ee29fd6075ffab0e3f944f6346cb2eb8aec'
            '11a96ffa21448ec4c63dd5c8d6795a1998d8e5cd5a689d91aea4d2bdd13fb06e'
            '5abc8611463b3097fc5ce58017ef918af8b70d616ad093b8b486d017d021bbdf'
            '0eb47afd031188cf5a3f0502f3025a73a1799dfa52dff9906db5a3c2af24e2eb'
            'SKIP'
            'SKIP'
            'SKIP'
            'SKIP'
            '3f4cff32af16655646c3cf914ca79599e5e3ae94860fdafe4258990775bf8f21'
            '6bea934add6ec817e9ebdf0e5a397f2aa96034c0c9f0ead960d309d418feef1c'
            'f8e14cef310dd5ad36fa20f20949762c26cbd1387b5ecf337a63efca6f42f59e')

if (( _manual_clone )); then
  source[0]=fetch-chromium-release
  makedepends+=('python-httplib2' 'python-pyparsing' 'python-six' 'npm' 'rsync')
fi

# Possible replacements are listed in build/linux/unbundle/replace_gn_files.py
# Keys are the names in the above script; values are the dependencies in Arch
declare -gA _system_libs=(
  [brotli]=brotli
  #[dav1d]=dav1d
  #[ffmpeg]=ffmpeg    # YouTube playback stopped working in Chromium 120
  [flac]=flac
  [fontconfig]=fontconfig
  [freetype]=freetype2
  [harfbuzz-ng]=harfbuzz
  #[icu]=icu
  #[jsoncpp]=jsoncpp  # needs libstdc++
  #[libaom]=aom
  #[libavif]=libavif  # needs -DAVIF_ENABLE_EXPERIMENTAL_GAIN_MAP=ON
  [libjpeg]=libjpeg-turbo
  [libpng]=libpng
  #[libvpx]=libvpx
  [libwebp]=libwebp
  [libxml]=libxml2
  [libxslt]=libxslt
  [opus]=opus
  #[re2]=re2          # needs libstdc++
  #[snappy]=snappy    # needs libstdc++
  #[woff2]=woff2      # needs libstdc++
  [zlib]=minizip
)
if [[ ${CARCH:-$(uname -m)} =~ ^(aarch64|arm64)$ ]]; then
  for _key in "${!_system_libs[@]}"; do
    unset "_system_libs[$_key]"
  done
fi

_unwanted_bundled_libs=(
  $(printf "%s\n" ${!_system_libs[@]} | sed 's/^libjpeg$/&_turbo/')
)
depends+=(${_system_libs[@]})

prepare() {
  if (( _manual_clone )); then
    if [[ ! -d chromium-$pkgver ]]; then
      ./fetch-chromium-release $pkgver
    else
      msg2 'Skipping fetch-chromium-release; existing checkout detected.'
    fi
  fi
  cd chromium-$pkgver

  local _target_cpu="${CARCH:-$(uname -m)}"
  case "${_target_cpu}" in
    aarch64|arm64) _target_cpu=arm64 ;;
    x86_64|amd64) _target_cpu=x64 ;;
  esac

  if [[ $_target_cpu == arm64 ]]; then
    ./build/linux/sysroot_scripts/install-sysroot.py --arch=arm64
    install -Dm755 /usr/bin/cups-config build/linux/debian_bullseye_arm64-sysroot/usr/bin/cups-config
  fi

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

  # Fixes from NixOS
  patch -Np1 -i ../chromium-138-rust-1.86-mismatched_lifetime_syntaxes.patch
  patch -Np1 -i ../chromium-140.0.7339.41-rust.patch

  # Allow libclang_rt.builtins from compiler-rt >= 16 to be used
  patch -Np1 -i ../compiler-rt-adjust-paths.patch

  # Increase _FORTIFY_SOURCE level to match Arch's default flags
  patch -Np1 -i ../increase-fortify-level.patch

  # Ensure AMD Polaris (RX550) is identified correctly
  patch -Np1 -i ../chromium-rx550-device-names.patch

  # Cross-compilation fixes for Baikal-M (ARM64)
  msg2 'Applying Baikal-M cross-compilation fixes'
  patch -Np1 -i ../chromium-libxml2-const.patch
  patch -Np1 -i ../chromium-libffi-hybrid.patch
  patch -Np1 -i ../chromium-disable-arm-sme.patch
  patch -Np1 -i ../chromium-qt6-cross-compile.patch

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
  mkdir -p third_party/node/linux/node-linux-x64/bin/ third_party/jdk/current/bin/
  ln -s /usr/bin/node third_party/node/linux/node-linux-x64/bin/
  ln -s /usr/bin/java third_party/jdk/current/bin/

  # Remove bundled libraries for which we will use the system copies; this
  # *should* do what the remove_bundled_libraries.py script does, with the
  # added benefit of not having to list all the remaining libraries
  local _lib
  if [[ $_target_cpu != arm64 ]]; then
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
  fi

}

build() {
  rustup toolchain install 1.86.0
  rustup default 1.86.0

  cd chromium-$pkgver

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

  local _build_arch="${CARCH:-$(uname -m)}"
  local _target_cpu="x64"
  local _custom_toolchain="//build/toolchain/linux/unbundle:default"
  local _host_toolchain="//build/toolchain/linux/unbundle:default"
  local _use_sysroot=false

  case "${_build_arch}" in
    aarch64|arm64)
      _target_cpu="arm64"
      _custom_toolchain="//build/toolchain/linux:clang_arm64"
      _use_sysroot=true
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
  )

  if [[ $_target_cpu == "arm64" ]]; then
    _flags+=("is_cfi=false")
    _flags+=("v8_snapshot_toolchain=\"//build/toolchain/linux:clang_x64\"")
    # Note: Cortex-A57 optimizations passed via CFLAGS (-march=armv8-a -mtune=cortex-a57)
    #       arm_float_abi and arm_use_neon are auto-set to "hard" and true for ARM64
    # GPU acceleration optimizations for AMD RX550
    _flags+=("enable_vulkan=true")
    _flags+=("use_dawn=true")
    _flags+=("dawn_enable_vulkan=true")
    _flags+=("enable_gpu_service_logging=false")
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
  ninja -C out/Release chrome chrome_sandbox chromedriver
}

package() {
  install -Dm755 "$srcdir/baikal-chromium-launcher.py" "$pkgdir/usr/bin/chromium"
  install -Dm644 chromium-launcher-$_launcher_ver/LICENSE \
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
