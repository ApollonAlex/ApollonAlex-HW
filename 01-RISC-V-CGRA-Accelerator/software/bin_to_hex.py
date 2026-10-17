#!/usr/bin/env python3
"""Convert a flat RV32 little-endian .bin into 16,384 word hex RAM image."""
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit("Usage: python3 bin_to_hex.py firmware.bin firmware.hex")
b = Path(sys.argv[1]).read_bytes()
if len(b) > 65536:
    raise SystemExit(f"Binary too large for 64 KiB RAM: {len(b)} bytes")
with Path(sys.argv[2]).open("w") as f:
    for i in range(0, 65536, 4):
        chunk = b[i:i+4].ljust(4, b"\0")
        f.write(f"{int.from_bytes(chunk, 'little'):08x}\n")
