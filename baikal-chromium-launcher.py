#!/usr/bin/env python3
import os
import shlex
import sys
from pathlib import Path

CHROMIUM_BINARY = "/usr/lib/chromium/chromium"
SYSTEM_FLAGS = Path("/etc/chromium-flags.conf")
USER_FLAGS = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "chromium-flags.conf"


def load_flags(path: Path) -> list[str]:
    flags: list[str] = []
    try:
        with path.open(encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                flags.extend(shlex.split(line))
    except FileNotFoundError:
        pass
    return flags


def main() -> None:
    extra_flags: list[str] = []
    extra_flags.extend(load_flags(SYSTEM_FLAGS))
    extra_flags.extend(load_flags(USER_FLAGS))

    env = os.environ.copy()
    env.setdefault("CHROME_WRAPPER", sys.argv[0])
    env.setdefault("CHROME_DESKTOP", "chromium.desktop")
    env.setdefault("CHROME_VERSION_EXTRA", "Arch Linux (Baikal)")
    # VA-API configuration for AMD RX550
    env.setdefault("LIBVA_DRIVER_NAME", "radeonsi")
    env.setdefault("LIBVA_DRIVERS_PATH", "/usr/lib/dri")
    env.setdefault("LIBVA_MESSAGING_LEVEL", "1")
    # AMD GPU optimizations
    env.setdefault("MESA_LOADER_DRIVER_OVERRIDE", "radeonsi")
    # GPU memory and threading optimizations for Baikal-M
    env.setdefault("MALLOC_ARENA_MAX", "2")
    env.setdefault("MESA_GLTHREAD", "true")
    # Force hardware acceleration
    env.setdefault("CHROMIUM_FLAGS", "--disable-gpu-sandbox")

    os.execve(CHROMIUM_BINARY, [CHROMIUM_BINARY, *extra_flags, *sys.argv[1:]], env)


if __name__ == "__main__":
    main()
