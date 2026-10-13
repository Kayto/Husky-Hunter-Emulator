# Husky Hunter Emulator Release

This project is an independent, unofficial patch/build workflow for the **Husky Hunter** driver and is not affiliated with, endorsed by, or sponsored by the MAME project or its contributors. It is intended as a clean, redistributable release containing source patches, documentation, scripts and build instructions only. It does **not** include proprietary Husky ROMs or other third-party firmware/software.

This release is fully self-contained: everything needed to reproduce the modified driver -- patches, the canonical driver source, documentation, and build tooling -- is in this repository. No prior release or external project history is required.

See Licensing.

The aim is to make the modified MAME Husky Hunter driver reproducible from a fresh upstream MAME source tree while keeping the release suitable for public GitHub distribution.

> **New here?** Start with **[QUICKSTART.md](QUICKSTART.md)** -- run a prebuilt binary or build from source in a few steps.

- - -

## Release

| Field | Value |
| ----- | ----- |
| Revision | 1.0 |
| Status | First public release |
| Release date | 2026-06-19 |
| Upstream base | MAME 0.287 (upstream tag `mame0287`) |

- - -

## What this project provides

This release contains:

* Documentation explaining the driver changes and fix history.
* Patch files against upstream MAME 0.287.
* A canonical patched Hunter driver source file for reference/build override.
* Build tooling for MSYS2/MinGW64 on Windows.
* Launch scripts for running the user built Hunter-only MAME binary.
* Utility scripts for serial bridging and local ROM preparation.
* Licence and third-party notice files.
* A corresponding source-code file explaining how to reconstruct the modified MAME source used for a binary build.

The main technical changes are documented in `CHANGES.md` and include:

* Addition of the 1983 six-EPROM DEMOS 2.2 BIOS option.
* ROM banking fixes required for the six-chip ROM set.
* MinGW/SDL link-order fix.
* HD61830 font CRC support for a locally generated font image.
* RS-232 default baud change for HCOM compatibility.
* RTC correction from MM58274C to MM58174A.
* RTC default-running behaviour.
* Hunter-specific day-of-week remapping.
* NSC810 Timer 1 prescaler variable fix (upstream bug in `nsc810.cpp`).
* Serial RX interrupt (`rxd_w`) corrected to fire only on start-bit falling edge, enabling `ON COM GOSUB` / `LINCHR` under MAME.
* NSC810 Timer 0 mode 4 output: `timer_tick` now fires NMI for Timer 0 in auto-reload interval mode (mode bits = 0x04), enabling the firmware's LOPCHR serial-TX path (upstream bug in `nsc810.cpp`).
* NMI vector fetch in paged-RAM mode: a permanent ROM read-shadow at 0x0066 plus a port-0x80 (POWSAV) bank-to-ROM handler during NMI service, so serial transmit, receive-interrupt and full-duplex behaviour match real Hunter hardware under MAME.
* DSR handshake read corrected to inverted polarity (the Hunter inverts its RS-232 control inputs), so the firmware's pre-transmit DSR wait no longer loops forever under MAME.

A full per-feature fidelity assessment -- the [OK]/[PARTIAL]/[GAP]/[UNKNOWN] coverage matrix and the validated real-hardware-vs-MAME parity outcomes -- is provided in `MAME_STATUS_RELEASE.md`. The headline: across a comprehensive set of test programs the ROM<->MAME hardware contract held end-to-end, with no ROM-derived hardware-contract gaps observed -- bounded by what was tested (the document lists the untested paths), not a proof of completeness.

- - -

ROM dumps (`EPROM*.BIN`), generated `roms/hunter.zip`, and NVRAM are not included. ROM images must be supplied by the user.

- - -

## Repository layout

``` text
.
+-- README.md
+-- QUICKSTART.md                # fast-start: run a prebuilt binary or build from source
+-- CHANGES.md
+-- MAME_STATUS_RELEASE.md       # emulation fidelity / coverage assessment
+-- SOURCE-CODE.md
+-- THIRD_PARTY_NOTICES.md
+-- LICENSE
+-- build/
|   +-- build_hunter_from_release.sh
|   +-- clean.ps1
|   +-- clean.bat
|   `-- BUILD_INSTRUCTIONS.md
+-- launchers/
|   +-- LaunchHunterMAME.ps1
|   +-- LaunchHunterMAME.bat
|   `-- LaunchHunter-Term.bat
+-- config/
|   +-- mame.ini
|   `-- TERATERM-hunter-mame.INI
+-- patches/
|   +-- FIX-3-sdl.lua.patch
|   +-- FIX-4-hd61830.cpp.patch
|   +-- FIX-5-null_modem.cpp.patch
|   +-- FIX-7-mm58174.cpp.patch
|   +-- FIX-9-nsc810.cpp.patch
|   +-- FIX-12-nsc810-timer0-mode4.patch
|   `-- PATCHES_README.md
+-- scripts/
|   +-- extract_hd61830_font.py
|   +-- inject_hcom.py
|   +-- serial_bridge.py
|   `-- setup_hunter.py          # no-MSYS2 Track A: package ROMs, first-run, HCOM install
+-- src/
|   `-- mame/husky/
|       +-- husky-hunter2.cpp
|       `-- README.md
+-- roms/
|   `-- ROMS_README.md            # instructions only; user supplies ROMs locally
+-- HuskyHCOM/
|   +-- LaunchHCOM-MAME.bat       # double-click to start HCOM bridge
|   +-- LaunchHCOM-MAME.ps1
|   +-- dosbox-hcom-mame.conf
|   +-- setup_hcom.sh             # automated setup: downloads hcomw, injects HCOM.COM into NVRAM
|   +-- HCOM_SETUP.md             # detailed setup and workflow guide
|   `-- hcomw/                    # not included; created at setup by user or setup_hcom.sh
```

Build output is generated under `output/` and is not included in the repository.

- - -

## Prerequisites

The automated build workflow is intended for **Windows with MSYS2 MinGW64**.

Install MSYS2, then from an MSYS2 MinGW64 shell install the expected build tools. A typical starting point is:

``` bash
pacman -Syu
pacman -S --needed git make python zip unzip mingw-w64-x86_64-gcc mingw-w64-x86_64-SDL2
```

MAME has a substantial build dependency set. If the build fails because a tool is missing, install the missing MSYS2 package and rerun the build script. Also, expect 60mins and over 12Gb spare space!

- - -

## Supplying ROMs locally

ROMs are not included. To run the emulator, place your own legally obtained Husky Hunter ROM images in `roms/`.

The expected six-EPROM set is:

| File | Expected use |
| ---- | ------------ |
| `EPROM0.BIN` | EPROM 0 / IC50 |
| `EPROM1.BIN` | EPROM 1 / IC51 |
| `EPROM2.BIN` | EPROM 2 / IC52 |
| `EPROM3.BIN` | EPROM 3 / IC53 |
| `EPROM4.BIN` | EPROM 4 / IC54 |
| `EPROM5.BIN` | EPROM 5 / IC55; also used locally to extract the HD61830 font |

Place these files in `roms/` and rerun the build script. The script generates a local `hunter.zip` for use by MAME. That generated zip is for local runtime use only and is not included in the repository.

- - -

## "Quick" build

Within MSYS2 MinGW64, **change into the repository root first**, then run the
build script. MSYS2 mounts your Windows drives under `/<drive-letter>/`, so an
`E:\GitHub\Husky-Hunter-Emulator` checkout is reached as below (replace `e` and
the path to match your own checkout):

``` bash
cd /e/GitHub/Husky-Hunter-Emulator   # adjust to match your checkout
./build/build_hunter_from_release.sh
```

> The `cd` is what makes the relative `./build/...` invocation resolve. The script
> itself locates its inputs and `output/` relative to its own location, so ROMs and
> build artifacts always resolve correctly regardless of where you launch it.

The script should:

1. Clone or prepare upstream MAME 0.287 under `output/mame/`.
2. Apply the patches in `patches/`.
3. Copy the canonical patched Hunter driver source if required.
4. Build the Hunter-only MAME subtarget.
5. Place runtime output under `output/runtime/`.

After the build the script pauses for three interactive steps:

* **Step 1 -- First launch:** launches MAME so you can run `FORMAT` and `CLCK` (the one-time first-run setup -- see [First run](#first-run) below). Quit MAME when done.
* **Step 2 -- Source cleanup:** optionally removes the cloned MAME source tree to recover disk space.
* **Step 3 -- HCOM optional setup:** optionally downloads and runs `setup_hcom.sh`, which injects `HCOM.COM` directly into the NVRAM file (no serial connection needed).

See `build/BUILD_INSTRUCTIONS.md` for the detailed build procedure.

- - -

## Running the emulator

After building, the binary is at `output/runtime/sdlhunter.exe`. Use the `.bat` launcher or in powershell:

``` powershell
.\launchers\LaunchHunterMAME.ps1
```

`-bios 4` selects the added **DEMOS 2.2 9G06h (6 ROMs)** BIOS entry.

- - -

## First run

On the very first launch the Hunter's emulated battery-backed RAM is blank. Two one-time steps create a stable state that persists across all future restarts via MAME's NVRAM save.

### 1 -- Format the RAM disk

From the DEMOS file-manager prompt type:

```
FORMAT
```

DEMOS prompts `FORMAT?: Are you sure (Y/N)`. Press `Y` then Enter. This initialises the filing system, leaving only the built-in system files. Without this step the file system may be inconsistent on subsequent restarts.

### 2 -- Set the clock

From the DEMOS prompt type:

```
CLCK
```

The clock-setting screen appears showing date and time fields. Use **cursor left / cursor right** to move between fields and **cursor up / cursor down** to change each value. Seconds are always reset to zero on synchronisation.

* Set **minutes** one minute ahead of the current time, then press **Enter**.
* DEMOS displays `Press ENTER to synchronise`. When the minute ticks over, press **Enter** to latch the clock at zero seconds.

> **Year display:** the ROM unconditionally prepends `"19"` to the two-digit year, so setting the year to `26` will show as `1926` in `DATE$`. This is a known ROM limitation. 

### 3 -- Configure the serial port (only if using the serial terminal or HCOM)

If you plan to use the serial terminal or HCOM file transfer, set the Hunter's
serial parameters now -- like the steps above, they persist in NVRAM. From the
DEMOS prompt type:

```
COMS
```

Set **both** the transmission and receiving parameters to **4800 8N1** (not the
2400 shown in the official Husky documentation -- 2400 corrupts over the MAME
serial bridge). For the exact field-by-field values see
`HuskyHCOM/HCOM_SETUP.md` -> **Hunter serial port settings**.

Once these steps are done, quit MAME. MAME writes the NVRAM state to `nvram/hunter_3/` on exit. Subsequent launches will have a clean file system and a running clock (plus your serial settings, if set) without any further setup.

> **Installing HCOM.COM via NVRAM injection?** If you built from source using `build/build_hunter_from_release.sh`, the script handles this automatically as Step 3 -- quit MAME when prompted and let it run. If setting up manually, quit MAME after completing both steps above, then run `scripts/inject_hcom.py` (see [HCOM file transfer](#hcom-file-transfer-dosbox-x) below). The injection writes directly to the NVRAM file on disk and must be done while MAME is not running. 

- - -

## Serial terminal / HCOM bridge

Two separate workflows are available:

### Terminal session (Tera Term / PuTTY)

A dumb-terminal connection to the Hunter's serial port via MAME's bitbanger:

* `scripts/serial_bridge.py` -- TCP relay that sits between MAME's bitbanger socket and a terminal emulator. MAME connects as a client; the terminal emulator connects as a client on a second port; the bridge proxies bytes between them.
* `launchers/LaunchHunter-Term.bat` -- starts the bridge, opens Tera Term, then launches MAME.
* `config/TERATERM-hunter-mame.INI` -- Tera Term preset (raw TCP, 127.0.0.1:5707).

### HCOM file transfer (DOSBox-X)

Full HCOM file transfer between the emulated Hunter and the host PC requires **DOSBox-X** -- standard DOSBox 0.74 does not have TCP nullmodem support and will not work.

The `HuskyHCOM/` workflow is documented in `HCOM_SETUP.md` for local use; HCOM binaries are not included. `HCOM_SETUP.md` details the setup needed to use the provided launchers and configs provided as follows;

* `dosbox-hcom-mame.conf` -- DOSBox-X config with `serial1=nullmodem port:5705 transparent:1 rxdelay:1000`. DOSBox-X listens on TCP 5705; MAME connects as client with `-serial null_modem -bitb socket.127.0.0.1:5705`.
* `LaunchHCOM-MAME.ps1` -- starts DOSBox-X with the HCOM conf, waits for it to begin listening, then launches MAME. Expected DOSBox-X install path: `C:\DOSBox-X\dosbox-x.exe`.

**First-time install of `HCOM.COM` on the emulated Hunter:** a fresh Hunter image does not yet have `HCOM.COM`. The easiest route is to let `scripts/inject_hcom.py` write it directly into the MAME NVRAM file -- no serial connection needed:

```sh
python3 scripts/inject_hcom.py nvram/hunter_3/nvram --inplace
```

MAME must have been run once first (and `FORMAT` typed on the Hunter) to create the NVRAM file. `HuskyHCOM/setup_hcom.sh` automates the whole process including downloading hcomw and offering to launch MAME for you. Alternatively, `HCOM.COM` can be installed over the serial bridge via HCOM's built-in *Software Download* feature -- see `HuskyHCOM/HCOM_SETUP.md`. If using the serial method, the Hunter must be configured to **4800 8N1**, not the 2400 8N1 in the official Husky documentation; 2400 produces corruption over the MAME serial bridge.

**Day-to-day order:** start HCOM on the Hunter (in MAME) first, then run `HCOM` at the DOSBox-X prompt.

This repository does not distribute HCOM binaries or DOSBox-X. DOSBox-X is available at [dosbox-x.com](https://dosbox-x.com).

- - -

## Licensing

### Trademark and non-affiliation notice

MAME is a registered trademark of Gregory Ember. This project is an
independent, unofficial patch/build workflow for the Husky Hunter driver and
is not affiliated with, endorsed by, or sponsored by the MAME project or its
contributors.

The MAME name is used only to identify the upstream emulator and source tree
that this project patches. This repository does not claim ownership of the
MAME name, logo, wordmark, or branding, and does not distribute the MAME logo.

- - -

Original documentation, scripts and release tooling in this repository are provided under the **BSD 3-Clause Licence**, unless a file states otherwise.

MAME-derived source files and patches remain subject to the licence terms of the upstream MAME files they modify. MAME as a combined project is distributed under **GPL-2.0-or-later** because it contains code under multiple GPL-compatible licences.

If this repository is used to distribute a built `sdlhunter.exe`, the corresponding modified MAME source is made available via `SOURCE-CODE.md`. See:

* `SOURCE-CODE.md`
* `THIRD_PARTY_NOTICES.md`
* `build/BUILD_INSTRUCTIONS.md`

No licence in this repository covers redistribution of Husky Hunter ROMs, firmware, HCOM software, or other third-party proprietary files.

### Optional binary release

A binary release may include `sdlhunter.exe` only alongside the complete corresponding modified MAME source and build instructions. ROMs are not bundled.

- - -

## Further reading

* `CHANGES.md` -- detailed fix log and root-cause explanations.
* `MAME_STATUS_RELEASE.md` -- emulation fidelity assessment and validated real-hardware-vs-MAME parity outcomes.
* `SOURCE-CODE.md` -- GPL source code details.
* `THIRD_PARTY_NOTICES.md` -- third-party licence notes.
* `roms/ROMS_README.md` -- local ROM placement and verification notes.