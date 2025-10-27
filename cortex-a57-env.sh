#!/bin/bash
# Оптимизации компилятора для Baikal-M Cortex-A57 (ARMv8-A, 1.5GHz, L3 8MB)
# Эти флаги задаются через переменные окружения для clang

# Базовые оптимизации ARM64 для нативной сборки
# NOTE: -O2 (NOT -O3) — для графических приложений/compositor'ов (стабильность WebGL/Canvas!)
# NOTE: -ffast-math REMOVED — unsafe for OpenGL/WebGL/VA-API (causes rendering artifacts)
export CFLAGS="-march=armv8-a -mtune=cortex-a57 -O2 -ftree-vectorize -pipe -fno-plt -fexceptions -fomit-frame-pointer -fno-semantic-interposition"
export CXXFLAGS="${CFLAGS}"

# Rust оптимизации для ARM64 Cortex-A57
# NOTE: codegen-units=1 — лучшая оптимизация (медленнее компиляция, быстрее runtime)
# NOTE: lto=no — избежать конфликтов с Chromium ThinLTO
export RUSTFLAGS="-C target-cpu=cortex-a57 -C target-feature=+neon,+crc -C opt-level=3 -C codegen-units=1 -C lto=no"

# Link-time optimizations (безопасны для Chromium)
# NOTE: -fuse-ld=lld — LLVM linker (быстрее GNU ld, особенно для Chromium)
export LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now -fuse-ld=lld"

echo "[INFO] Установлены оптимизации для Baikal-M Cortex-A57 (native ARM64 build):"
echo "  CFLAGS: ${CFLAGS}"
echo "  CXXFLAGS: ${CXXFLAGS}"
echo "  RUSTFLAGS: ${RUSTFLAGS}"
