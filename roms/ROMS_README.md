# roms/

Place your legally obtained `EPROM0.BIN`-`EPROM5.BIN` files here, then run the
build script.  It will automatically build `hunter.zip` and copy it back to this
folder.  The launchers use `-rompath roms` so MAME picks up `hunter.zip` from here.

---

## What goes here

```
roms/
  EPROM0.BIN  \
  EPROM1.BIN   |  raw ROM dumps -- place these here before building
  EPROM2.BIN   |  (ignored by .gitignore, never committed)
  EPROM3.BIN   |
  EPROM4.BIN   |
  EPROM5.BIN  /
  hunter.zip    generated automatically by the build script
```

---

## Contents of hunter.zip (bios 4 -- DEMOS 2.2 9G06h, 6 ROMs)

The launchers use `-bios 4`. `hunter.zip` must contain these seven files:

| Filename in zip | Source file  | CRC32      | Size       |
|-----------------|--------------|------------|------------|
| `eprom0.ic50`   | `EPROM0.BIN` | `ad861c35` | 8192 bytes |
| `eprom1.ic51`   | `EPROM1.BIN` | `c8c2fae8` | 8192 bytes |
| `eprom2.ic52`   | `EPROM2.BIN` | `b301621f` | 8192 bytes |
| `eprom3.ic53`   | `EPROM3.BIN` | `be6f196a` | 8192 bytes |
| `eprom4.ic54`   | `EPROM4.BIN` | `7a0d2228` | 8192 bytes |
| `eprom5.ic55`   | `EPROM5.BIN` | `48526702` | 8192 bytes |
| `hd61830.bin`   | extracted from `EPROM5.BIN` | `85497474` | 1472 bytes |

The source `EPROM*.BIN` files are the raw dumps from the physical ICs. They must
be renamed to the `*.ic5x` names shown above when packaged into the zip -- MAME
looks up files by name and CRC.

---

## Creating hunter.zip from the EPROM*.BIN files

### Option A -- automated (recommended)

Place `EPROM0.BIN`-`EPROM5.BIN` directly in this `roms/` folder, then run the
build script.  It detects them automatically, renames them, extracts the font,
builds `hunter.zip`, and copies it back here.

```bash
# From the RELEASE root (MSYS2 MinGW64 shell):
./build/build_hunter_from_release.sh
# Result: roms/hunter.zip  (also copied to output/runtime/roms/)
```

The `EPROM*.BIN` files are ignored by `.gitignore` and will not be committed.

### Option B -- manual (from individual EPROM*.BIN files)

From an MSYS2 or Git Bash shell, with the six `EPROM*.BIN` files in a working folder:

```bash
WORK=/tmp/hunter_roms
mkdir -p "$WORK"

# Rename EPROMs to the names MAME expects
cp EPROM0.BIN "$WORK/eprom0.ic50"
cp EPROM1.BIN "$WORK/eprom1.ic51"
cp EPROM2.BIN "$WORK/eprom2.ic52"
cp EPROM3.BIN "$WORK/eprom3.ic53"
cp EPROM4.BIN "$WORK/eprom4.ic54"
cp EPROM5.BIN "$WORK/eprom5.ic55"

# The font extractor reads the full 48K combined image at offset 0xB43A
# (= 0xA000 + 0x143A, EPROM5 / CPU address B43AH), so concatenate the six
# EPROMs first, then extract the HD61830 chargen font (96 chars x 7 bytes).
cat "$WORK/eprom0.ic50" "$WORK/eprom1.ic51" "$WORK/eprom2.ic52" \
    "$WORK/eprom3.ic53" "$WORK/eprom4.ic54" "$WORK/eprom5.ic55" > "$WORK/combined.rom"
python3 /path/to/release/scripts/extract_hd61830_font.py \
    --rom "$WORK/combined.rom" \
    --out "$WORK/hd61830.bin"

# Package (combined.rom is scratch -- the eprom*.ic* glob does not match it)
(cd "$WORK" && zip -9 hunter.zip eprom*.ic* hd61830.bin)
cp "$WORK/hunter.zip" roms/
```

### Option C -- Windows, no MSYS2 (Python)

If you have a prebuilt `sdlhunter.exe` and don't want the MSYS2 build, use the
Python setup helper -- it needs only Python 3 (no compiler, no extra packages).
Put `EPROM0.BIN`-`EPROM5.BIN` in this `roms/` folder, then from the repository
root run:

```powershell
python scripts\setup_hunter.py
```

It renames the EPROMs, extracts the HD61830 font, verifies every CRC32 against
the table above, and writes `roms\hunter.zip` (also copied into
`output\runtime\roms\` if a prebuilt runtime is present). It then offers the
one-time first-run setup and optional HCOM install -- see
[`../QUICKSTART.md`](../QUICKSTART.md), Track A.

---

## Redistribution

Do not redistribute `hunter.zip` or its contents unless you have explicit
redistribution rights for the Husky Hunter firmware.

This `README.md` is part of the public release and is licensed under the
BSD 3-Clause Licence. The ROM files themselves are proprietary.
