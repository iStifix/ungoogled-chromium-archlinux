#!/bin/bash
# Оптимизации компилятора для Baikal-M Cortex-A57 (ARMv8-A, 1.5GHz, L3 8MB)
# Эти флаги задаются через переменные окружения для clang

# Базовые оптимизации ARM64 для нативной сборки
# NOTE: -ffast-math REMOVED — unsafe for OpenGL/WebGL/VA-API (causes rendering artifacts)
export CFLAGS="-march=armv8-a -mtune=cortex-a57 -O3 -ftree-vectorize -pipe -fno-plt -fexceptions"
export CXXFLAGS="${CFLAGS}"

# Rust оптимизации для ARM64 Cortex-A57
export RUSTFLAGS="-C target-cpu=cortex-a57 -C target-feature=+neon,+crc -C opt-level=3"

# Link-time optimizations (если достаточно RAM)
# export LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now"

echo "[INFO] Установлены оптимизации для Baikal-M Cortex-A57 (native ARM64 build):"
echo "  CFLAGS: ${CFLAGS}"
echo "  CXXFLAGS: ${CXXFLAGS}"
echo "  RUSTFLAGS: ${RUSTFLAGS}"
