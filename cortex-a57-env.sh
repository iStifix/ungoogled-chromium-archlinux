#!/bin/bash
# Оптимизации компилятора для Baikal-M Cortex-A57 (ARMv8-A, 1.5GHz, L3 8MB)
# Эти флаги задаются через переменные окружения для clang

# Базовые оптимизации ARM64
export CFLAGS="-march=armv8-a+crc+crypto -mtune=cortex-a57 -O3 -pipe -fno-plt -fexceptions"
export CXXFLAGS="${CFLAGS}"

# Rust оптимизации для ARM64 Cortex-A57
export RUSTFLAGS="-C target-cpu=cortex-a57 -C target-feature=+neon,+crc,+crypto -C opt-level=3"

# Link-time optimizations (если достаточно RAM)
# export LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now"

# Library search path for x86_64 host libraries
export LIBRARY_PATH="/usr/lib/x86_64-linux-gnu${LIBRARY_PATH:+:$LIBRARY_PATH}"

echo "[INFO] Установлены оптимизации для Baikal-M Cortex-A57:"
echo "  CFLAGS: ${CFLAGS}"
echo "  CXXFLAGS: ${CXXFLAGS}"
echo "  RUSTFLAGS: ${RUSTFLAGS}"
