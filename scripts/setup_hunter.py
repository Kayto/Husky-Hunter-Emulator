#!/usr/bin/env python3
"""setup_hunter.py - One-stop setup for a prebuilt Husky Hunter build (no MSYS2).
By Kayto. Licensed under the MIT License. See LICENSE file for details.

For users who already have a prebuilt sdlhunter.exe and do NOT want the
MSYS2/MinGW64 build toolchain. This mirrors the post-build steps of
build/build_hunter_from_release.sh, but in pure Python 3 (stdlib only):

  1. Package roms/EPROM*.BIN  ->  roms/hunter.zip  (font extracted, CRCs checked)
  2. Optionally launch MAME for the one-time FORMAT / CLCK first-run setup
  3. Optionally install HCOM.COM into the NVRAM, injecting from a copy of HCOM
     that YOU supply (this repo does not include or download HCOM -- see
     HuskyHCOM/HCOM_SETUP.md, "Obtaining HCOM")

Only Python 3 is required -- no MSYS2, no compiler, no extra packages.

Run from the repository root:
    python scripts\\setup_hunter.py
"""
from __future__ import annotations

import os
import subprocess
import sys
import zipfile
import zlib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
ROM_DIR = REPO_ROOT / "roms"
RUNTIME_DIR = REPO_ROOT / "output" / "runtime"

# EPROM source -> MAME ic-name + expected CRC32 (see roms/ROMS_README.md).
EPROMS = [
    ("EPROM0.BIN", "eprom0.ic50", 0xAD861C35),
    ("EPROM1.BIN", "eprom1.ic51", 0xC8C2FAE8),
    ("EPROM2.BIN", "eprom2.ic52", 0xB301621F),
    ("EPROM3.BIN", "eprom3.ic53", 0xBE6F196A),
    ("EPROM4.BIN", "eprom4.ic54", 0x7A0D2228),
    ("EPROM5.BIN", "eprom5.ic55", 0x48526702),
]
EPROM_SIZE = 8192
FONT_OFFSET = 0xB43A          # EPROM5 / CPU B43AH in the 48K combined image (FIX-4)
FONT_BYTES = 96 * 7           # 672
FONT_TARGET = 0x5C0           # 1472 (zero-padded)
FONT_CRC = 0x85497474

NVRAM_CANDIDATES = [
    REPO_ROOT / "nvram" / "hunter_3" / "nvram",
    REPO_ROOT / "nvram" / "hunter" / "nvram",
]


# -- small helpers -------------------------------------------------------------

def crc32(data: bytes) -> int:
    return zlib.crc32(data) & 0xFFFFFFFF


def ask(prompt: str, default: str = "y") -> bool:
    """Yes/no prompt; non-interactive (EOF) and empty input take the default."""
    try:
        ans = input(prompt).strip().lower()
    except EOFError:
        ans = ""
    if not ans:
        ans = default
    return ans.startswith("y")


def section(title: str) -> None:
    print(f"\n==> {title}")


# -- step 1: ROM / font packaging ---------------------------------------------

def package_roms(rom_dir: Path = ROM_DIR, force: bool = False) -> bool:
    """Build <rom_dir>/hunter.zip from EPROM*.BIN. Returns True if a zip exists."""
    section("Packaging ROMs")
    zip_out = rom_dir / "hunter.zip"

    present = [f for f, _, _ in EPROMS if (rom_dir / f).is_file()]
    if len(present) < len(EPROMS):
        if zip_out.is_file():
            print(f"  EPROM*.BIN not all present -- keeping existing {zip_out.name}.")
            return True
        missing = [f for f, _, _ in EPROMS if f not in present]
        print("  Cannot build hunter.zip -- missing EPROM dumps:")
        for m in missing:
            print(f"    {rom_dir / m}")
        print("  Place your six EPROM0.BIN..EPROM5.BIN in roms/ (see roms/ROMS_README.md).")
        return False

    if zip_out.is_file() and not force:
        if not ask(f"  {zip_out.name} already exists. Rebuild it? [y/N]: ", default="n"):
            print("  Keeping existing hunter.zip.")
            return True

    # read + verify EPROMs
    rom_bytes: dict[str, bytes] = {}
    for src, ic, exp_crc in EPROMS:
        data = (rom_dir / src).read_bytes()
        if len(data) != EPROM_SIZE:
            print(f"  ERROR: {src} is {len(data)} bytes, expected {EPROM_SIZE}.")
            return False
        crc = crc32(data)
        if crc != exp_crc:
            print(f"  ERROR: {src} CRC32 {crc:08x} != expected {exp_crc:08x} "
                  f"(not the DEMOS 2.2 9G06h 6-ROM set).")
            return False
        print(f"  OK  {src:<11} -> {ic}   (CRC {crc:08x})")
        rom_bytes[ic] = data

    # extract HD61830 font from the 48K combined image (FIX-4)
    combined = b"".join(rom_bytes[ic] for _, ic, _ in EPROMS)
    font = combined[FONT_OFFSET:FONT_OFFSET + FONT_BYTES]
    font = font + bytes(FONT_TARGET - len(font))
    font_crc = crc32(font)
    if font_crc != FONT_CRC:
        print(f"  ERROR: extracted hd61830.bin CRC32 {font_crc:08x} != {FONT_CRC:08x}.")
        return False
    print(f"  OK  {'EPROM5.BIN':<11} -> hd61830.bin  (CRC {font_crc:08x})")

    # write hunter.zip with all seven files at the archive root
    rom_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_out, "w", zipfile.ZIP_DEFLATED) as zf:
        for _, ic, _ in EPROMS:
            zf.writestr(ic, rom_bytes[ic])
        zf.writestr("hd61830.bin", font)
    print(f"  Created {zip_out}")

    if RUNTIME_DIR.is_dir():
        runtime_roms = RUNTIME_DIR / "roms"
        runtime_roms.mkdir(parents=True, exist_ok=True)
        (runtime_roms / "hunter.zip").write_bytes(zip_out.read_bytes())
        print(f"  Copied to {runtime_roms / 'hunter.zip'}")

    print("  Reminder: hunter.zip contains proprietary Husky firmware -- do not redistribute it.")
    return True


# -- step 2: first-run launch --------------------------------------------------

def find_launcher() -> Path | None:
    for name in ("LaunchHunterMAME.ps1", "LaunchHunterMAME.bat"):
        p = REPO_ROOT / "launchers" / name
        if p.is_file():
            return p
    return None


def first_run() -> None:
    section("First run (one-time)")
    if any(p.is_file() for p in NVRAM_CANDIDATES):
        print("  An NVRAM already exists, so first-run setup looks done. Skipping.")
        return
    print("  On first launch the Hunter needs FORMAT (filing system) and CLCK (clock).")
    if not ask("  Launch MAME now to do this? [Y/n]: "):
        print("  Skipped. Launch later with launchers\\LaunchHunterMAME.ps1, then run FORMAT and CLCK.")
        return

    print("  In the Hunter window: type FORMAT (answer Y), then CLCK to set the clock,")
    print("  then quit MAME to return here.")

    launcher = find_launcher()
    waited = False
    if launcher is None:
        print("  Could not find a launcher under launchers/. Start the emulator manually.")
    else:
        print(f"  Launching {launcher.name} (MAME's console output is hidden) ...")
        if launcher.suffix == ".ps1":
            cmd = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(launcher)]
            use_shell = False
        else:
            cmd = [str(launcher)]
            use_shell = True
        try:
            # Block until MAME is closed, and discard MAME's console chatter.
            result = subprocess.run(cmd, shell=use_shell,
                                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            waited = True
            if result.returncode != 0:
                print(f"  (Launcher exited with code {result.returncode} -- if MAME did not open,")
                print(f"   run launchers\\{launcher.name} directly to see the error.)")
        except OSError as exc:
            print(f"  Could not launch automatically ({exc}). Start it manually, then quit it.")

    if waited:
        print("  MAME has closed.")
        prompt = "  Press Enter to continue..."
    else:
        prompt = "  Press Enter once you have quit MAME to continue..."
    try:
        input(prompt)
    except EOFError:
        pass


# -- step 3: HCOM install (user-supplied) -------------------------------------

def setup_hcom() -> None:
    section("HCOM file transfer (optional)")

    nvram = next((p for p in NVRAM_CANDIDATES if p.is_file()), None)
    if nvram is None:
        print("  No NVRAM found yet -- run the first-run setup above first, then re-run this script.")
        return

    # HCOM is proprietary and user-supplied: locate HUNTER.BIN via inject_hcom's
    # own search (HuskyHCOM/hcomw/HCOM.DOS/HUNTER.BIN), do not download anything.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import inject_hcom  # local module

    # Locate HCOM (user-supplied). HCOM is proprietary and not bundled here, so
    # if it is missing we pause and let the user drop hcomw/ in place now, rather
    # than make them re-run the whole script.
    while True:
        try:
            hunter_bin = inject_hcom.find_hunter_bin(None)
            break
        except FileNotFoundError:
            print("  HCOM is not included with this project -- supply your own copy.")
            print("  Download hcomw.zip and extract it to HuskyHCOM/hcomw/ as described")
            print("  in HuskyHCOM/HCOM_SETUP.md (\"Obtaining HCOM\").")
            try:
                ans = input("  Press Enter once HCOM is in place to continue, or S to skip: ").strip().lower()
            except EOFError:
                ans = "s"
            if ans.startswith("s"):
                print("  Skipped HCOM. Install it later by re-running this script, or over the")
                print("  serial bridge (HCOM_SETUP.md, Option B).")
                return

    print(f"  Found HCOM: {hunter_bin}")

    # Ensure the HSYNC staging folder exists (HCOM's D: drive for transfers),
    # mirroring HuskyHCOM/setup_hcom.sh.
    hsync = REPO_ROOT / "HuskyHCOM" / "HSYNC"
    if not hsync.is_dir():
        hsync.mkdir(parents=True, exist_ok=True)
        print(f"  Created HCOM transfer folder: {hsync}")

    print("  Injection requires a freshly formatted NVRAM (FORMAT run, no other files yet).")
    if not ask("  Inject HCOM.COM into the NVRAM now? [Y/n]: "):
        print("  Skipped. You can also install HCOM over the serial bridge (HCOM_SETUP.md, Option B).")
        return

    inject_hcom.inject_hcom(str(nvram), inplace=True)
    print("  HCOM.COM installed. See HuskyHCOM/HCOM_SETUP.md for day-to-day use.")


# -- main ----------------------------------------------------------------------

def main() -> int:
    print("Husky Hunter setup (prebuilt binary, no MSYS2)")
    print(f"  repo root: {REPO_ROOT}")

    have_roms = package_roms()
    if not have_roms:
        print("\nAdd your EPROM dumps to roms/ and re-run this script.")
        return 1

    first_run()
    setup_hcom()

    print("\nDone. Play any time with:  .\\launchers\\LaunchHunterMAME.ps1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
