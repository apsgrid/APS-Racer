#!/usr/bin/env python3
import io
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LINUX = ROOT / "builds" / "linux"
OUT = LINUX / "APSRacer-Linux-x86_64.tar.gz"

files = [
    (LINUX / "APSRacer.x86_64", "APSRacer/APSRacer.x86_64", 0o755),
    (LINUX / "APSRacer.pck", "APSRacer/APSRacer.pck", 0o644),
]

launcher = """#!/usr/bin/env bash
set -e
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
exec "$HERE/APSRacer.x86_64" "$@"
"""

deck = """APS Racer - Linux / Arch / Steam Deck

RUN ON LINUX / ARCH
1. Extract this archive.
2. Run ./APSRacer.x86_64
   or ./run-aps-racer.sh

STEAM DECK / STEAMOS
1. Switch to Desktop Mode and extract this archive somewhere under /home/deck.
2. In Steam: Games -> Add a Non-Steam Game.
3. Browse to APSRacer.x86_64 and add it.
4. Return to Gaming Mode and launch APS Racer from the Non-Steam library.

The build is Linux x86_64 and uses the normal Steam Deck gamepad via Steam Input.
No Godot installation is required.
"""

with tarfile.open(OUT, "w:gz") as tar:
    for src, arcname, mode in files:
        info = tar.gettarinfo(str(src), arcname=arcname)
        info.mode = mode
        with src.open("rb") as fh:
            tar.addfile(info, fh)

    for content, arcname, mode in [
        (launcher.encode("utf-8"), "APSRacer/run-aps-racer.sh", 0o755),
        (deck.encode("utf-8"), "APSRacer/STEAM_DECK.txt", 0o644),
    ]:
        info = tarfile.TarInfo(arcname)
        info.size = len(content)
        info.mode = mode
        info.mtime = 0
        tar.addfile(info, io.BytesIO(content))

print(OUT)
print(OUT.stat().st_size)