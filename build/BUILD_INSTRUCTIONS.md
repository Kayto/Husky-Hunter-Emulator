# Build Instructions -- Husky Hunter MAME Release

This release is intended to rebuild the patched Husky Hunter MAME subtarget from a clean upstream MAME checkout without redistributing proprietary Husky firmware.

## Files required in the public release

Include:

- `build_hunter_from_release.sh`
- `README.md`
- `CHANGES.md`
- `MAME_STATUS_RELEASE.md`
- `SOURCE-CODE.md`
- `THIRD_PARTY_NOTICES.md`
- `LICENSE`
- `patches/`
- `scripts/`
- `src/mame/husky/husky-hunter2.cpp`

(The release also ships usage helpers -- `config/`, `launchers/`, `HuskyHCOM/`,
`roms/ROMS_README.md`, and `build/` itself -- but the items above are what the
source rebuild needs.)

Not included (proprietary, generated, or user-supplied):

- `roms/EPROM*.BIN`, `roms/hunter.zip` -- ROM dumps and packaged ROM set; user-supplied only
- `nvram/`, `cfg/`, `config/ui.ini` -- generated at runtime
- `output/` -- build artefacts; produced locally by the build script
- `output/mame/` -- upstream MAME source tree, cloned during the build
- HCOM binaries

## Windows / MSYS2 MinGW64 build

1. Install [MSYS2](https://www.msys2.org/).
2. Open the **MSYS2 MinGW64** shell (`C:\msys64\mingw64.exe`).
3. Install the expected build tools if not already present:

```bash
pacman -S --needed git make python zip patch mingw-w64-x86_64-gcc mingw-w64-x86_64-SDL2
```

4. From the MSYS2 MinGW64 shell, change to the folder and run the script. MSYS2 mounts your Windows drives under `/<drive-letter>/`, so the path looks like this for my E: drive (replace `e` with your drive). Navigate to the release repository root and run the build script:

```bash
cd /e/GitHub/Husky-Hunter-Emulator   # adjust path to match your checkout
./build/build_hunter_from_release.sh
```

Alternatively, launch it directly from **PowerShell** without opening a separate MSYS2 window:

```powershell
$env:MSYSTEM = "MINGW64"; C:\msys64\usr\bin\bash.exe -l -c "cd /e/GitHub/Husky-Hunter-Emulator && ./build/build_hunter_from_release.sh"
```

The binary and required runtime DLLs are copied to:

```text
output/runtime/
```

### Build script options

| Variable | Default | Effect |
|---|---|---|
| `MAME_REF` | `mame0287` | Git tag or commit to build |
| `CHECK_ONLY` | *(unset)* | Set to `1` to verify dependencies only, without building |
| `JOBS` | CPU count | Parallel make jobs |

> **Post-build interactive steps:** after the build and ROM packaging complete,
> the script pauses with three prompts:
>
> 1. **Test pause** -- launch the emulator, verify it boots, press Enter to continue.
> 2. **Source tree cleanup** -- optionally remove the ~12 GB MAME source tree
>    (can be re-cloned by re-running the script).
> 3. **HCOM setup** -- optionally chain into `HuskyHCOM/setup_hcom.sh` to install
>    `HCOM.COM` into the NVRAM. This requires a **freshly formatted** Hunter image
>    (i.e. `FORMAT` run on the Hunter but no other files created yet). If you have
>    already been using the emulator, skip this and install HCOM later via the
>    serial bridge (see `HuskyHCOM/HCOM_SETUP.md`, Option B).

Examples:

```bash
# Pin a specific MAME version
MAME_REF=mame0288 ./build/build_hunter_from_release.sh

# Check dependencies only
CHECK_ONLY=1 ./build/build_hunter_from_release.sh
```

## ROM set generation (automatic)

The release must not include Husky ROMs. To generate a local-only `hunter.zip`,
place your legally obtained `EPROM0.BIN`-`EPROM5.BIN` files in the `roms/` folder
before running the script:

```text
roms/
  EPROM0.BIN
  EPROM1.BIN
  EPROM2.BIN
  EPROM3.BIN
  EPROM4.BIN
  EPROM5.BIN
```

The build script detects them automatically, renames them to the MAME-expected
`eprom*.ic5x` filenames, concatenates them into a combined image, extracts the
HD61830 chargen font, packages everything into `hunter.zip`, and places it in both:

```text
output/runtime/roms/hunter.zip
roms/hunter.zip
```

The `EPROM*.BIN` files are listed in `.gitignore` and will not be committed.
Do not redistribute `hunter.zip` unless you have explicit rights to do so.

See `roms/ROMS_README.md` for the expected filenames, CRC32 values, and a manual
packaging procedure if you prefer not to use the build script.

## Run

Use the provided launcher from the repository root (recommended):

```powershell
.\launchers\LaunchHunterMAME.ps1
```

Or run directly:

```powershell
.\output\runtime\sdlhunter.exe hunter -bios 4 -window -ramsize 352K -rompath roms -inipath config
```

The `sdlhunter.exe` binary expects to be launched from the **repository root** so that `-rompath roms` and `-inipath config` resolve correctly. The launcher handles this automatically.

## Cleaning up

Run `clean.ps1` from the repository root to remove all build artefacts and restore the folder to its pre-build state:

```powershell
.\build\clean.ps1              # prompts for confirmation
.\build\clean.ps1 -Force       # skips confirmation
.\build\clean.ps1 -KeepHcom    # keep the HCOM downloads
.\build\clean.ps1 -KeepRuntime # Track A: keep the prebuilt exe, ROMs and HCOM
```

This removes `output/`, `roms/hunter.zip`, `cfg/`, `nvram/`, and `config/ui.ini`. Your `EPROM*.BIN` ROM dumps are not removed.

Use `-KeepRuntime` if you run a **prebuilt** binary (Track A) and cannot rebuild it without MSYS2: it clears the MAME source tree and runtime state but keeps `output/runtime/` (the binary + DLLs), `roms/hunter.zip`, and the HCOM downloads. `clean.bat` offers the same choices from a menu (`F`/`K`/`R`/`B`).

## Binary redistribution note

If you distribute the generated binary, include the corresponding source code or exact upstream reference plus complete patch set, licence texts, notices, and these build instructions. Do not impose extra restrictions on the MAME binary.
