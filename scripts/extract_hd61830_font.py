#!/usr/bin/env python3
"""extract_hd61830_font.py - Extract the Husky Hunter character font from the firmware ROM
and write it as the MAME ``hd61830.bin`` chargen image (FIX-4).
By Kayto 04/05/2026
Licensed under the MIT License. See LICENSE file for details.

Source : roms/husky1983.rom  (concatenated 6-EPROM image; repo-root default, override with --rom)
Offset : 0xB43A  (= 0xA000 + 0x143A, EPROM5 / ic55, CPU address B43AH)
Layout : 96 characters x 7 bytes/char = 672 bytes, padded with 0x00 to 0x5C0
Output : roms/hd61830.bin  (repo-root default; override with --out)

Expected hashes:
    size  = 1472 bytes (0x5C0)
    CRC32 = 85497474
    SHA1  = 734b6c8e399b758ce9e3b2356d47e3730aef0850

Run with no arguments from the repo root, or pass --help.
"""
from __future__ import annotations

import argparse
import hashlib
import sys
import zlib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]  # scripts/extract...py -> repo root (RELEASE layout)
DEFAULT_ROM = REPO_ROOT / "roms" / "husky1983.rom"   # build script always passes --rom explicitly
DEFAULT_OUT = REPO_ROOT / "roms" / "hd61830.bin"     # build script always passes --out explicitly

FONT_OFFSET = 0xB43A
FONT_CHARS = 96
FONT_ROWS = 7
FONT_BYTES = FONT_CHARS * FONT_ROWS  # 672
TARGET_SIZE = 0x5C0                  # 1472

EXPECTED_CRC32 = 0x85497474
EXPECTED_SHA1 = "734b6c8e399b758ce9e3b2356d47e3730aef0850"


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--rom", type=Path, default=DEFAULT_ROM, help=f"Source ROM (default: {DEFAULT_ROM})")
    p.add_argument("--out", type=Path, default=DEFAULT_OUT, help=f"Output file (default: {DEFAULT_OUT})")
    p.add_argument("--check-only", action="store_true", help="Verify the existing output file without writing")
    args = p.parse_args()

    if args.check_only:
        if not args.out.is_file():
            print(f"error: {args.out} does not exist", file=sys.stderr)
            return 1
        data = args.out.read_bytes()
    else:
        if not args.rom.is_file():
            print(f"error: source ROM not found: {args.rom}", file=sys.stderr)
            return 1
        rom = args.rom.read_bytes()
        if len(rom) < FONT_OFFSET + FONT_BYTES:
            print(f"error: ROM is too short ({len(rom)} bytes)", file=sys.stderr)
            return 1
        font = rom[FONT_OFFSET : FONT_OFFSET + FONT_BYTES]
        data = font + bytes(TARGET_SIZE - len(font))
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_bytes(data)
        print(f"wrote {len(data)} bytes -> {args.out}")

    crc = zlib.crc32(data) & 0xFFFFFFFF
    sha1 = hashlib.sha1(data).hexdigest()
    print(f"size  = {len(data)} bytes (0x{len(data):X})")
    print(f"CRC32 = {crc:08x}  (expected {EXPECTED_CRC32:08x})")
    print(f"SHA1  = {sha1}")
    print(f"        {'(expected '+EXPECTED_SHA1+')'}")

    ok = len(data) == TARGET_SIZE and crc == EXPECTED_CRC32 and sha1 == EXPECTED_SHA1
    if not ok:
        print("MISMATCH: hashes do not match expected FIX-4 values", file=sys.stderr)
        return 2
    print("OK: matches expected FIX-4 hashes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
