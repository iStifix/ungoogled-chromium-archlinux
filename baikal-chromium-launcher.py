#!/usr/bin/env python3
"""
Chromium launcher for Baikal-M (Cortex-A57 + AMD RX550)

This launcher configures environment variables specific to Baikal-M hardware:
- VA-API hardware video decode/encode for AMD RX550
- Mesa radeonsi driver optimizations
- Memory optimizations for 8GB RAM system

The launcher also loads custom flags from:
- /etc/chromium-flags.conf (system-wide)
- ~/.config/chromium-flags.conf (user-specific)
"""
import os
import shlex
import sys
from pathlib import Path

CHROMIUM_BINARY = "/usr/lib/chromium/chromium"
SYSTEM_FLAGS = Path("/etc/chromium-flags.conf")
USER_FLAGS = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "chromium-flags.conf"


def load_flags(path: Path) -> list[str]:
    """Load flags from a configuration file.

    Args:
        path: Path to the flags configuration file

    Returns:
        List of parsed flags (empty list if file not found)
    """
    flags: list[str] = []
    try:
        with path.open(encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                # Skip empty lines and comments
                if not line or line.startswith("#"):
                    continue
                # Parse line using shell quoting rules
                flags.extend(shlex.split(line))
    except FileNotFoundError:
        pass
    return flags


def main() -> None:
    """Main launcher entry point."""
    # Load custom flags from system and user configs
    extra_flags: list[str] = []
    extra_flags.extend(load_flags(SYSTEM_FLAGS))
    extra_flags.extend(load_flags(USER_FLAGS))

    # Prepare environment variables
    env = os.environ.copy()

    # Standard Chromium launcher variables
    env.setdefault("CHROME_WRAPPER", sys.argv[0])
    env.setdefault("CHROME_DESKTOP", "chromium.desktop")
    env.setdefault("CHROME_VERSION_EXTRA", "Arch Linux (Baikal)")

    # VA-API configuration for AMD RX550 (Polaris 12)
    # CRITICAL: Required for hardware video decode/encode
    env.setdefault("LIBVA_DRIVER_NAME", "radeonsi")
    env.setdefault("LIBVA_DRIVERS_PATH", "/usr/lib/dri")
    env.setdefault("LIBVA_MESSAGING_LEVEL", "1")  # Enable VA-API logging

    # Mesa radeonsi driver optimizations for RX550
    env.setdefault("MESA_LOADER_DRIVER_OVERRIDE", "radeonsi")  # Force radeonsi (no fallback)
    env.setdefault("MESA_GLTHREAD", "true")  # Separate thread for GL commands (performance)

    # Memory optimizations for 8GB RAM system (Baikal-M)
    # MALLOC_ARENA_MAX=2 reduces memory fragmentation on ARM64
    env.setdefault("MALLOC_ARENA_MAX", "2")

    # Execute Chromium with merged flags: [extra_flags] + [command-line args]
    os.execve(CHROMIUM_BINARY, [CHROMIUM_BINARY, *extra_flags, *sys.argv[1:]], env)


if __name__ == "__main__":
    main()
