#!/usr/bin/env bash
# build_hunter_from_release.sh
#
# Rebuild the patched Husky Hunter MAME subtarget from a clean upstream MAME tree.
#
# Intended release use:
#   - This script may be distributed publicly.
#   - It does NOT include or download Husky ROMs, HCOM binaries, or any proprietary firmware.
#   - Place your legally obtained EPROM0.BIN-EPROM5.BIN files in the roms/ folder before
#     running this script.  hunter.zip will be built automatically from them.
#
# Typical MSYS2 MinGW64 usage from the release repository root:
#   ./build/build_hunter_from_release.sh
#
# Optional version pinning:
#   MAME_REF=mame0287 ./build/build_hunter_from_release.sh
#   MAME_REF=<exact-commit-sha> ./build/build_hunter_from_release.sh
#
# Output (relative to the RELEASE repo root):
#   output/mame/           MAME source tree (cloned + patched)
#   output/runtime/        sdlhunter.exe
#   output/runtime/roms/   hunter.zip  (built from roms/EPROM*.BIN, if present)
#   roms/hunter.zip        copy placed here for immediate launcher use

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_ROOT="${BUILD_ROOT:-$REPO_ROOT/output}"
MAME_DIR="${MAME_DIR:-$BUILD_ROOT/mame}"
MAME_REPO="${MAME_REPO:-https://github.com/mamedev/mame.git}"
MAME_REF="${MAME_REF:-mame0287}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
SUBTARGET="hunter"
PATCH_DIR="$REPO_ROOT/patches"
RUNTIME_DIR="$BUILD_ROOT/runtime"
ROM_OUT_DIR="$RUNTIME_DIR/roms"

msg() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

# require_cmd NAME [INSTALL_HINT]
require_cmd() {
    command -v "$1" >/dev/null 2>&1 || \
        fail "Required command not found: $1${2:+  -- install with: $2}"
}

# ---------------------------------------------------------------------------
# Dependency check
#
# All commands must be run inside an MSYS2 MinGW64 (or UCRT64) shell.
# Install missing packages with pacman from an MSYS2 terminal:
#
#   pacman -S git make patch zip
#   pacman -S mingw-w64-x86_64-gcc
#   pacman -S mingw-w64-x86_64-python
#   pacman -S mingw-w64-x86_64-SDL2        # required by OSD=sdl
#   pacman -S mingw-w64-x86_64-pkg-config  # used to verify SDL2
#
# A full MAME build also requires several hundred MB of MinGW64 toolchain
# packages (binutils, headers, etc.) that are pulled in as dependencies of
# mingw-w64-x86_64-gcc.  Total disk space for MAME source + build: ~12 GB.
# ---------------------------------------------------------------------------
msg "Checking tools"
require_cmd git     "pacman -S git"
require_cmd make    "pacman -S make"
require_cmd patch   "pacman -S patch"
require_cmd python3 "pacman -S mingw-w64-x86_64-python"
require_cmd zip     "pacman -S zip"
require_cmd g++     "pacman -S mingw-w64-x86_64-gcc"

# SDL2 dev headers are required for OSD=sdl at compile time.
# Check now so the user gets a clear message before a 20-minute build attempt.
if command -v pkg-config >/dev/null 2>&1; then
    pkg-config --exists sdl2 2>/dev/null || \
        fail "SDL2 dev headers not found (pkg-config sdl2 failed).  Install with: pacman -S mingw-w64-x86_64-SDL2"
else
    command -v sdl2-config >/dev/null 2>&1 || \
        msg "Warning: cannot verify SDL2 headers (pkg-config not found).  If the build fails, run: pacman -S mingw-w64-x86_64-SDL2 mingw-w64-x86_64-pkg-config"
fi

case "${MSYSTEM:-}" in
    MINGW64|UCRT64|CLANG64)
        msg "MSYS2 environment detected: ${MSYSTEM}"
        ;;
    *)
        msg "Warning: MSYSTEM is '${MSYSTEM:-unset}' -- this script must run inside an MSYS2 MinGW64 shell."
        msg "  To fix: open 'MSYS2 MinGW 64-bit' from the Windows Start menu (search for MSYS2),"
        msg "  navigate to this repo root, and re-run:  ./build/build_hunter_from_release.sh"
        msg "  Do NOT run from PowerShell, CMD, Git Bash, or a plain MSYS2 (non-MinGW) shell."
        ;;
esac

msg "Dependency check passed."
if [[ -n "${CHECK_ONLY:-}" ]]; then
    msg "CHECK_ONLY=1: stopping after dependency check."
    exit 0
fi

msg "Creating build folder: $BUILD_ROOT"
mkdir -p "$BUILD_ROOT" "$RUNTIME_DIR" "$ROM_OUT_DIR"

if [[ ! -d "$MAME_DIR/.git" ]]; then
    msg "Cloning MAME into $MAME_DIR"
    git clone --depth 1 --branch "$MAME_REF" "$MAME_REPO" "$MAME_DIR" || {
        msg "Branch/tag '$MAME_REF' was not available as a shallow branch; retrying generic clone then checkout"
        rm -rf "$MAME_DIR"
        git clone "$MAME_REPO" "$MAME_DIR"
        git -C "$MAME_DIR" checkout "$MAME_REF"
    }
else
    msg "Using existing MAME tree: $MAME_DIR"
    git -C "$MAME_DIR" fetch --tags --depth 1 origin "$MAME_REF" || true
    git -C "$MAME_DIR" checkout "$MAME_REF"
fi

msg "Resetting MAME tree to a clean state"
git -C "$MAME_DIR" reset --hard
git -C "$MAME_DIR" clean -fdx

msg "Applying release patches"
[[ -d "$PATCH_DIR" ]] || fail "Patch directory not found: $PATCH_DIR"

# Patch files apply to upstream files outside the Hunter driver, or to
# device files (nsc810, mm58174, null_modem, hd61830, sdl.lua). The patches
# below cover FIX-1..9 and FIX-12. FIX-10, FIX-11 (reverted), FIX-13 and FIX-14 live
# entirely inside the canonical Hunter driver (src/mame/husky/husky-hunter2.cpp)
# which is copied verbatim after the patches are applied -- so no patch file
# is needed for those fixes.
patches=(
    "FIX-1-2-6-8-hunter2.cpp.patch"
    "FIX-3-sdl.lua.patch"
    "FIX-4-hd61830.cpp.patch"
    "FIX-5-null_modem.cpp.patch"
    "FIX-7-mm58174.cpp.patch"
    "FIX-9-nsc810.cpp.patch"
    "FIX-12-nsc810-timer0-mode4.patch"
)

for p in "${patches[@]}"; do
    [[ -f "$PATCH_DIR/$p" ]] || fail "Missing patch: $PATCH_DIR/$p"
    msg "Applying $p"
    # Normalize CRLF -> LF at apply time. git's autocrlf (and a Windows/GitHub
    # checkout) can reintroduce CRLF into the .patch files, which makes the strict
    # `git apply` reject every hunk (patch line-endings != the LF MAME source). Strip
    # CR bytes (octal \015 -- POSIX tr guarantees octal escapes; the \r form is not
    # reliable on every tr) into a temp, so `git apply` applies cleanly regardless of
    # how the patch was checked out. The patch -p1 fallback (for any real context
    # drift, e.g. FIX-3 / FIX-12) reads the same normalized temp.
    norm="$(mktemp)"
    tr -d '\015' < "$PATCH_DIR/$p" > "$norm"
    git -C "$MAME_DIR" apply --whitespace=nowarn "$norm" || {
        msg "git apply failed; retrying with patch -p1 for $p"
        (cd "$MAME_DIR" && patch -p1 < "$norm")
    }
    rm -f "$norm"
done

# Copy the canonical patched Hunter driver over the MAME tree after all patch
# files have been applied. This is where FIX-10 (serial RX start-bit guard),
# FIX-13 (NMI vector ROM shadow + powsav_w bank-force) and FIX-14 (DSR handshake
# read inversion) live -- all are Hunter-driver-local with no separate patch
# file. Without this copy step the resulting build would lack those fixes and the
# serial transmit / receive-interrupt / full-duplex paths would break.
if [[ -f "$REPO_ROOT/src/mame/husky/husky-hunter2.cpp" ]]; then
    msg "Copying canonical patched Hunter driver into MAME tree (includes FIX-10, FIX-13, FIX-14)"
    mkdir -p "$MAME_DIR/src/mame/husky"
    cp "$REPO_ROOT/src/mame/husky/husky-hunter2.cpp" "$MAME_DIR/src/mame/husky/hunter2.cpp"

    # Verify the copied driver has the expected FIX-13 v4 markers (powsav_w,
    # install_nmi_vector_shadow). The markers are function definitions that
    # would only be missing if the canonical driver was somehow incomplete
    # or stale. Failing fast here is much better than a 20-minute build
    # producing a binary with broken serial TX / RX / full-duplex behaviour.
    TREE_DRIVER="$MAME_DIR/src/mame/husky/hunter2.cpp"
    if ! grep -q "void hunter2_state::powsav_w" "$TREE_DRIVER"; then
        fail "Canonical driver in MAME tree is missing powsav_w() -- FIX-13 v4 not present"
    fi
    if ! grep -q "install_nmi_vector_shadow" "$TREE_DRIVER"; then
        fail "Canonical driver in MAME tree is missing install_nmi_vector_shadow() -- FIX-13 v4 not present"
    fi
    msg "Canonical driver verified (FIX-13 v4 markers present)"
else
    fail "Canonical driver not found at $REPO_ROOT/src/mame/husky/husky-hunter2.cpp -- the release build will be missing FIX-10, FIX-13 and FIX-14"
fi

msg "Building MAME Hunter subtarget"
(
    cd "$MAME_DIR"
    make MINGW64="${MINGW64:-/mingw64}" \
         SUBTARGET="$SUBTARGET" \
         SOURCES=src/mame/husky/hunter2.cpp \
         OSD=sdl \
         PTR64=1 \
         SYMBOLS=0 \
         OPTIMIZE=3 \
         NOWERROR=1 \
         windows_x64 \
         -j"$JOBS"
)

# Locate the built binary. MAME layouts vary slightly by version/config.
# Release builds produce a non-suffixed name (sdlhunter.exe); DEBUG=1 builds
# produce sdlhunterd.exe (with 'd' suffix). Look for the non-suffixed forms
# only. If multiple candidates are present (e.g. from previous incremental
# builds), pick the most recently modified one to avoid copying a stale binary.
msg "Locating output binary"
mapfile -t candidates < <(find "$MAME_DIR" -maxdepth 4 -type f \( -name 'sdlhunter.exe' -o -name 'mamehunter.exe' -o -name 'hunter.exe' \) 2>/dev/null || true)
if (( ${#candidates[@]} == 0 )); then
    fail "Build completed but no Hunter executable was found under $MAME_DIR"
fi

# Pick the most recently modified candidate.
BIN="$(printf '%s\n' "${candidates[@]}" | xargs ls -t 2>/dev/null | head -n1)"
[[ -n "$BIN" ]] || BIN="${candidates[0]}"

msg "Built binary: $BIN"
cp "$BIN" "$RUNTIME_DIR/$(basename "$BIN")"
msg "Copied binary to: $RUNTIME_DIR/$(basename "$BIN")"

# Sanity check: the binary timestamp should be more recent than the source
# canonical driver. If it isn't, make silently no-op'd and we have a stale
# binary (e.g. a previous build's output still sitting in the MAME tree).
SRC_DRIVER="$REPO_ROOT/src/mame/husky/husky-hunter2.cpp"
TARGET_EXE="$RUNTIME_DIR/$(basename "$BIN")"
if [[ -f "$SRC_DRIVER" && -f "$TARGET_EXE" ]]; then
    if [[ "$SRC_DRIVER" -nt "$TARGET_EXE" ]]; then
        msg "WARNING: $TARGET_EXE is older than the canonical driver source."
        msg "  The build may have used a cached object file and not picked up your changes."
        msg "  Recovery: cd $MAME_DIR && make clean, then re-run this script."
    else
        msg "Binary freshness check: PASSED (binary newer than canonical source)"
    fi
fi

# Copy required MinGW/SDL runtime DLLs so the binary runs outside MSYS2.
msg "Copying runtime DLLs"
MINGW_BIN="${MINGW_BIN:-/mingw64/bin}"
for dll in libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll SDL2.dll; do
    if [[ -f "$MINGW_BIN/$dll" ]]; then
        cp "$MINGW_BIN/$dll" "$RUNTIME_DIR/$dll"
        msg "  copied $dll"
    else
        msg "  WARNING: $dll not found in $MINGW_BIN -- you may need to copy it manually"
    fi
done

# ---------------------------------------------------------------------------
# Patch Windows PE version info on the built binary.
#
# Uses rcedit (https://github.com/electron/rcedit) -- a small standalone
# Windows executable that works natively in MSYS2 MinGW64.
# If rcedit is not already present it is downloaded automatically via curl.
# Set RCEDIT=/path/to/rcedit-x64.exe to override the download.
# Set SKIP_VERPATCH=1 to skip this step entirely.
# ---------------------------------------------------------------------------
if [[ -z "${SKIP_VERPATCH:-}" ]]; then
    msg "Patching Windows PE version info"

    RCEDIT_EXE="${RCEDIT:-}"
    RCEDIT_CACHE="$BUILD_ROOT/tools/rcedit-x64.exe"
    RCEDIT_URL="https://github.com/electron/rcedit/releases/latest/download/rcedit-x64.exe"

    # Locate rcedit: explicit env var > cached download > PATH
    if [[ -z "$RCEDIT_EXE" ]]; then
        if [[ -f "$RCEDIT_CACHE" ]]; then
            RCEDIT_EXE="$RCEDIT_CACHE"
        elif command -v rcedit-x64.exe >/dev/null 2>&1; then
            RCEDIT_EXE="$(command -v rcedit-x64.exe)"
        elif command -v rcedit.exe >/dev/null 2>&1; then
            RCEDIT_EXE="$(command -v rcedit.exe)"
        fi
    fi

    # Auto-download if still not found
    if [[ -z "$RCEDIT_EXE" ]]; then
        if command -v curl >/dev/null 2>&1; then
            msg "rcedit not found -- downloading from GitHub Releases"
            mkdir -p "$(dirname "$RCEDIT_CACHE")"
            if curl -fsSL -o "$RCEDIT_CACHE" "$RCEDIT_URL"; then
                RCEDIT_EXE="$RCEDIT_CACHE"
                msg "rcedit downloaded to $RCEDIT_CACHE"
            else
                msg "Warning: rcedit download failed -- version info will not be patched"
                msg "  To retry manually: curl -fsSL -o $RCEDIT_CACHE $RCEDIT_URL"
            fi
        else
            msg "Warning: rcedit not found and curl unavailable -- version info will not be patched"
            msg "  Install curl (pacman -S curl) or place rcedit-x64.exe at: $RCEDIT_CACHE"
        fi
    fi

    TARGET_EXE="$RUNTIME_DIR/$(basename "$BIN")"
    if [[ -n "$RCEDIT_EXE" && -f "$TARGET_EXE" ]]; then
        # File version must be four dot-separated integers (Major.Minor.Patch.Build).
        # Product version is a free-form string.
        # Language (English US = 0x0409) and FileType (Application) are set by
        # rcedit automatically when writing the StringFileInfo block.
        if "$RCEDIT_EXE" "$TARGET_EXE" \
            --set-version-string "FileDescription"  "Unofficial Husky Hunter build of MAME" \
            --set-version-string "ProductName"       "Husky Hunter Emulator Build based on MAME" \
            --set-version-string "LegalCopyright"    "(c) 1997-2026 MAMEdev and contributors; modifications (c) 2026 kayto https://github.com/Kayto" \
            --set-version-string "OriginalFilename"  "sdlhunter.exe" \
            --set-version-string "Comments"          "Unofficial modified MAME build. Not affiliated with or endorsed by the MAME project." \
            --set-file-version    "0.287.0.1" \
            --set-product-version "0.287-hunter.1"; then
            msg "Version info patched on $TARGET_EXE"
        else
            msg "Warning: rcedit failed to patch version info -- binary is still functional"
        fi
    fi

    # Remove the tools dir (rcedit) now that patching is done.
    TOOLS_DIR="$(dirname "$RCEDIT_CACHE")"
    if [[ -d "$TOOLS_DIR" ]]; then
        rm -rf "$TOOLS_DIR"
        msg "Removed tools dir: $TOOLS_DIR"
    fi
fi

# Build hunter.zip from individual EPROM*.BIN files placed in roms/ by the user.
ROM_SRC_DIR="$REPO_ROOT/roms"
EPROM_BINS=("EPROM0.BIN" "EPROM1.BIN" "EPROM2.BIN" "EPROM3.BIN" "EPROM4.BIN" "EPROM5.BIN")
IC_NAMES=("eprom0.ic50" "eprom1.ic51" "eprom2.ic52" "eprom3.ic53" "eprom4.ic54" "eprom5.ic55")

# package_roms: build roms/hunter.zip from EPROM*.BIN, or reuse an existing
# hunter.zip. Defined as a function so the missing-ROM check below can re-run it
# after the user drops the files in.
package_roms() {
all_eproms=true
for f in "${EPROM_BINS[@]}"; do
    [[ -f "$ROM_SRC_DIR/$f" ]] || { all_eproms=false; break; }
done

if $all_eproms; then
    msg "Found EPROM*.BIN files in roms/ -- building hunter.zip"
    WORK_ROM_DIR="$BUILD_ROOT/hunter_rom_work/hunter"
    rm -rf "$BUILD_ROOT/hunter_rom_work"
    mkdir -p "$WORK_ROM_DIR"

    for i in "${!EPROM_BINS[@]}"; do
        cp "$ROM_SRC_DIR/${EPROM_BINS[$i]}" "$WORK_ROM_DIR/${IC_NAMES[$i]}"
    done

    # Concatenate all 6 EPROMs into a combined image for font extraction.
    # extract_hd61830_font.py expects the full 48K combined image at offset 0xB43A.
    COMBINED_ROM="$WORK_ROM_DIR/combined.rom"
    cat "$WORK_ROM_DIR/eprom0.ic50" "$WORK_ROM_DIR/eprom1.ic51" "$WORK_ROM_DIR/eprom2.ic52" \
        "$WORK_ROM_DIR/eprom3.ic53" "$WORK_ROM_DIR/eprom4.ic54" "$WORK_ROM_DIR/eprom5.ic55" \
        > "$COMBINED_ROM"

    # Extract HD61830 chargen font (offset 0xB43A in combined image, 96 chars x 7 bytes)
    if [[ -f "$REPO_ROOT/scripts/extract_hd61830_font.py" ]]; then
        python3 "$REPO_ROOT/scripts/extract_hd61830_font.py" \
            --rom "$COMBINED_ROM" \
            --out "$WORK_ROM_DIR/hd61830.bin"
    else
        python3 - "$COMBINED_ROM" "$WORK_ROM_DIR/hd61830.bin" <<'PY'
import pathlib, sys
rom_path = pathlib.Path(sys.argv[1])
out_path = pathlib.Path(sys.argv[2])
rom = rom_path.read_bytes()
FONT_OFFSET = 0xB43A
font = rom[FONT_OFFSET:FONT_OFFSET + 96*7]
if len(font) != 96*7:
    raise SystemExit(f"Could not extract 96x7 font from {rom_path} offset 0x{FONT_OFFSET:X} (file is {len(rom)} bytes)")
out_path.write_bytes(font + bytes(0x5C0 - len(font)))
PY
    fi
    rm -f "$COMBINED_ROM"

    (cd "$WORK_ROM_DIR" && zip -9 -q "$ROM_OUT_DIR/hunter.zip" eprom*.ic* hd61830.bin)
    # Also place the zip in roms/ so the launchers can find it immediately
    cp "$ROM_OUT_DIR/hunter.zip" "$ROM_SRC_DIR/hunter.zip"
    msg "Created ROM set: $ROM_OUT_DIR/hunter.zip"
    msg "Copied to: $ROM_SRC_DIR/hunter.zip"
    msg "Do not redistribute this ROM set unless you have explicit rights."
elif [[ -f "$ROM_SRC_DIR/hunter.zip" ]]; then
    msg "No EPROM*.BIN files found in roms/ -- using existing roms/hunter.zip"
    cp "$ROM_SRC_DIR/hunter.zip" "$ROM_OUT_DIR/hunter.zip"
else
    msg "No EPROM*.BIN files found in roms/ and no hunter.zip present."
    msg "Place EPROM0.BIN--EPROM5.BIN in: $ROM_SRC_DIR"
    msg "See roms/README.md for details."
fi
}

package_roms

# ---------------------------------------------------------------------------
# Missing-ROM check -- pause before the test launch so the user can add ROMs.
# MAME cannot start the Hunter without roms/hunter.zip, so loop here until it
# exists (or the user chooses to skip the test launch).
# ---------------------------------------------------------------------------
ROM_READY=1
while [[ ! -f "$ROM_SRC_DIR/hunter.zip" ]]; do
    printf '\n'
    printf '==> No ROM set found -- roms/hunter.zip is missing.\n'
    printf '    The Hunter cannot start without it, so the test launch below would fail.\n'
    printf '    Place your six EPROM dumps in:\n'
    printf '      %s\n' "$ROM_SRC_DIR"
    printf '        EPROM0.BIN  EPROM1.BIN  EPROM2.BIN  EPROM3.BIN  EPROM4.BIN  EPROM5.BIN\n'
    printf '    (or drop a prebuilt hunter.zip there instead).\n'
    printf '\n'
    read -r -p "Press Enter to retry once the files are in place, or type S to skip: " _rom_retry
    if [[ "${_rom_retry:-}" =~ ^[Ss] ]]; then
        msg "No ROM set -- skipping the test launch and HCOM setup."
        msg "Add EPROM*.BIN to roms/ and re-run this script (or a launcher) later."
        ROM_READY=0
        break
    fi
    package_roms
done

# ---------------------------------------------------------------------------
# Post-build cleanup
# ---------------------------------------------------------------------------

# Always remove the temporary ROM staging directory.
if [[ -d "$BUILD_ROOT/hunter_rom_work" ]]; then
    msg "Removing temporary ROM work directory"
    rm -rf "$BUILD_ROOT/hunter_rom_work"
fi

msg "Build complete.  Runtime folder: $RUNTIME_DIR"

# ---------------------------------------------------------------------------
# Step 1 -- test the build and do one-time Hunter setup.
# The user should launch the emulator now and verify it works.
# (Skipped if no ROM set is available -- see the missing-ROM check above.)
# ---------------------------------------------------------------------------
if [[ "$ROM_READY" == "1" ]]; then
printf '\n'
printf '==> First launch -- test the build and set up the Hunter.\n'
printf '    Launch via:  ./launchers/LaunchHunterMAME.ps1   (or LaunchHunterMAME.bat)\n'
printf '\n'
printf '    Once the Hunter boots to the DEMOS prompt, do these one-time steps:\n'
printf '      1. Type FORMAT and press Enter, then answer Y.\n'
printf '         This initialises the DEMOS filing system (required for HCOM injection).\n'
printf '      2. Type CLCK and set the date and time.\n'
printf '      3. Verify the Hunter is working, then quit MAME.\n'
printf '\n'
read -r -p "Press Enter once you have done the above and quit MAME..."
else
    msg "Test launch skipped -- no ROM set available. Add ROMs to roms/ then run a launcher to test."
fi

# ---------------------------------------------------------------------------
# Step 2 -- optional source tree cleanup (~12 GB).
# The MAME source tree can be re-cloned by re-running this script.
# ---------------------------------------------------------------------------
printf '\n'
printf 'If the Hunter is working, you can optionally remove the MAME source tree.\n'
read -r -p "Remove the MAME source tree to reclaim ~12 GB disk space? [Y/n]: " _keep_src
if [[ "${_keep_src:-}" =~ ^[Nn] ]]; then
    msg "Keeping MAME source tree at $MAME_DIR"
else
    msg "Removing MAME source tree"
    rm -rf "$MAME_DIR"
fi

# ---------------------------------------------------------------------------
# Step 3 -- optional HCOM setup.
#
# setup_hcom.sh installs HCOM.COM by injecting it directly into the MAME NVRAM
# file -- no serial connection needed.  This only works on a FRESHLY FORMATTED
# NVRAM (i.e. one where FORMAT has been run on the Hunter but no other files
# have been created).
#
# If you have already been using the emulator and created files on the Hunter,
# the NVRAM is no longer clean enough for safe injection.  Skip this step and
# install HCOM manually later via the serial bridge (Option B in HCOM_SETUP.md).
# ---------------------------------------------------------------------------
if [[ "$ROM_READY" != "1" ]]; then
    msg "Skipping HCOM setup -- no ROM set / Hunter not tested."
    msg "After adding ROMs and formatting the Hunter, run: cd HuskyHCOM && bash setup_hcom.sh"
else
printf '\n'
cat <<'HCOMINFO'
==> HCOM Setup (optional)

    HCOM is the file-transfer utility for the Hunter.  setup_hcom.sh can
    install HCOM.COM automatically by injecting it directly into the MAME NVRAM.

    IMPORTANT: injection requires a FRESHLY FORMATTED NVRAM.
      - If you ran FORMAT during the first launch above and quit MAME,
        the NVRAM is ready.  Answer Y and setup_hcom.sh will inject immediately.
      - If you forgot to FORMAT, Launch via:  ./launchers/LaunchHunterMAME.ps1   
        (or LaunchHunterMAME.bat), then return here and answer Y.
        setup_hcom.sh will inject immediately.

      - If you been using the emulator and created files, and dont want to lose them, 
        skip this now. Install HCOM manually via the serial bridge instead 
        (see HuskyHCOM/HCOM_SETUP.md, Option B).

HCOMINFO
read -r -p "Run HuskyHCOM/setup_hcom.sh now to install HCOM.COM? [Y/n]: " _setup_hcom
if [[ ! "${_setup_hcom:-}" =~ ^[Nn] ]]; then
    if [[ -f "$REPO_ROOT/HuskyHCOM/setup_hcom.sh" ]]; then
        (cd "$REPO_ROOT/HuskyHCOM" && bash setup_hcom.sh)
    else
        msg "setup_hcom.sh not found at $REPO_ROOT/HuskyHCOM/ -- skipping"
        msg "To run it manually later:  cd HuskyHCOM && bash setup_hcom.sh"
    fi
else
    msg "Skipping HCOM setup."
    printf '\n'
    printf '    To set up HCOM later:\n'
    printf '      cd HuskyHCOM && bash setup_hcom.sh\n'
    printf '    Remember: NVRAM injection needs a freshly formatted Hunter image.\n'
    printf '    If you have existing Hunter files, use the serial bridge instead\n'
    printf '    (see HuskyHCOM/HCOM_SETUP.md, Option B).\n'
fi
fi

printf '\n'
printf 'Release reminder:\n'
printf '  - You may distribute this build script and patches.\n'
printf '  - Do not distribute Husky ROMs, firmware/font binaries, HCOM binaries, or NVRAM images\n'
printf '    unless you have explicit redistribution rights.\n'
printf '  - If distributing the binary, include source/patches, licence texts and build instructions.\n'
