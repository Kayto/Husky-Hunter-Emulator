# MAME source patches -- Husky Hunter

**As of:** 2026-06-18

Reproducible record of the source-level changes applied to upstream MAME for
this project. Generated with `git diff` against the shallow upstream checkout
in `../output/mame`.

**Base:** MAME 0.287 (upstream tag `mame0287`, commit `f39eb8da6be6e827fa7ba3ecc60be66a82dff27b`)

For full narrative on each fix see [`../CHANGES.md`](../CHANGES.md).

## Patch index

| Fix | Patch file | Upstream path | Symptom | Scope |
|---|---|---|---|---|
| FIX-1 | [`FIX-1-2-6-8-hunter2.cpp.patch`](FIX-1-2-6-8-hunter2.cpp.patch) | `src/mame/husky/hunter2.cpp` | Wrong ROM chips loaded into upper memory window at start-up -- completely blank screen, CPU runs into garbage | 6-EPROM set only |
| FIX-2 | [`FIX-1-2-6-8-hunter2.cpp.patch`](FIX-1-2-6-8-hunter2.cpp.patch) | `src/mame/husky/hunter2.cpp` | Bounds check used wrong size limit, allowing out-of-range bank to appear valid (could silently map garbage) | 6-EPROM set only -- padding coincidence masked it for other variants |
| FIX-3 | [`FIX-3-sdl.lua.patch`](FIX-3-sdl.lua.patch) | `scripts/src/osd/sdl.lua` | Linker `undefined reference to WinMain` on MinGW (mingw32 must precede SDL2main) | Build system only -- Windows MinGW, any ROM set |
| FIX-4 | [`FIX-4-hd61830.cpp.patch`](FIX-4-hd61830.cpp.patch) | `src/devices/video/hd61830.cpp` | Wrong glyphs on screen -- upstream `hd61830.bin` was a `BAD_DUMP` placeholder typed in from the datasheet; replaced with the actual Hunter font extracted from EPROM5 (`B43AH`) | All Hunter BIOS variants (upstream bug) |
| FIX-5 | [`FIX-5-null_modem.cpp.patch`](FIX-5-null_modem.cpp.patch) | `src/devices/bus/rs232/null_modem.cpp` | HCOM <-> DOSBox-X serial drops every byte at 9600 baud; Hunter HCOM is hardcoded to 4800 and slot defaults can't be set on the CLI | HCOM file transfer only |
| FIX-6 | [`FIX-1-2-6-8-hunter2.cpp.patch`](FIX-1-2-6-8-hunter2.cpp.patch) | `src/mame/husky/hunter2.cpp` | RTC device wrong: hardware is MM58174A (BCD) but driver wires up MM58274C (binary). `TIME$`/`DATE$` corrupt at digit boundaries (e.g. hour `24` instead of wrapping at 23->00) and DATE$ reads wrong registers due to layout differences | All Hunter BIOS variants (upstream bug, was an upstream TODO) |
| FIX-7 | [`FIX-7-mm58174.cpp.patch`](FIX-7-mm58174.cpp.patch) | `src/devices/machine/mm58174.cpp` | After FIX-6, `TIME$` was frozen at every MAME launch until the user set it once via BASIC. The MM58174A model gates ticking on its STOP/START control bit, which defaults to 0; real hardware keeps that bit set across power cycles via the VBB battery-backup pin. Defaulting `m_control = CTL_CLKRUN` in `device_start()` lets the chip auto-tick from the host wallclock loaded by `device_rtc_interface` | Any system using `mm58174_device` (upstream candidate) |
| FIX-8 | [`FIX-1-2-6-8-hunter2.cpp.patch`](FIX-1-2-6-8-hunter2.cpp.patch) | `src/mame/husky/hunter2.cpp` | Day-of-week in MM58174A port 4AH was off by one. MAME's `device_rtc_interface::set_current_time()` seeds the chip with `weekday + 1` (POSIX `0=Sun..6=Sat`), giving `1=Sun..7=Sat`; Hunter firmware expects `1=Mon..7=Sun`. Hunter-driver-local remap in `machine_reset()` translates `1 -> 7` and `2..7 -> 1..6`. Placed in `machine_reset` because `set_rtc_datetime()` re-seeds the chip after `machine_start` | Hunter-driver-local; encoding is system-specific |
| FIX-9 | [`FIX-9-nsc810.cpp.patch`](FIX-9-nsc810.cpp.patch) | `src/devices/machine/nsc810.cpp` | `REG_TIMER1_START` handler checked `m_timer_mode[0]` and used `m_timer_clock[0]` (Timer 0 variables) instead of the Timer 1 equivalents. Both Hunter timer clocks happen to be 4 MHz so the rate is harmless, but any program running both timers simultaneously with differing prescaler mode bits (`0x08`) would get the wrong tick rate on Timer 1 | Upstream bug -- affects any system using `nsc810_device` with both timers active |
| FIX-10 | *(no patch -- driver-local)* | `src/mame/husky/hunter2.cpp` | `rxd_w()` asserted `NSC800_RSTB` on every RXD state change rather than only on the falling edge (start bit), re-entering the COM ISR up to 10 times per 8N1 byte and causing `LINCHR` to read garbage. Corrected to assert on falling edge only. Also removed a `popmessage()` debug call left in `cts_w()` that flooded the OSD on every CTS toggle | Hunter-driver-local; serial RX |
| FIX-11 | *(no patch -- verification only)* | `src/mame/husky/hunter2.cpp` | ROM analysis confirmed upstream Timer A -> NMI / Timer B -> RSTA wiring is correct. An earlier proposal to swap them was investigated and rejected. No code change. | Documentation only |
| FIX-12 | [`FIX-12-nsc810-timer0-mode4.patch`](FIX-12-nsc810-timer0-mode4.patch) | `src/devices/machine/nsc810.cpp` | `timer_tick` only fired the timer output callback for mode bits 0x01 and 0x02. Hunter ROM `SOUND_MODE_INIT` programs Timer 0 mode = 0x6CH (bits 2:0 = 0x04). The timer started and counted but never fired NMI, so `LOPCHR` spun forever on the F7E0H spin-lock. Mode 4 is an auto-reload interval mode identical in MAME behaviour to mode 2 | Upstream bug -- affects any system using Timer 0 in mode 4 |
| FIX-13 | *(no patch -- driver-local)* | `src/mame/husky/hunter2.cpp` | NMI vector fetch at 0x0066 read paged-RAM garbage when foreground was in paged-RAM mode (NMI_PHASE=0x80); real Hunter hardware switches bank1 to ROM on NMI ack but MAME's NSC800 has no equivalent callback. Fixed by installing a permanent ROM read-shadow at 0x0066-0x0068 plus a port-0x80 (POWSAV) write handler that switches bank1 to ROM inside NMI service. Serial transmit, receive-interrupt and full-duplex behaviour all match real-Hunter behaviour | Hunter-driver-local |
| FIX-14 | *(no patch -- driver-local; verified)* | `src/mame/husky/hunter2.cpp` | DSR read with inverted polarity: `portb_r` read Port B bit7 = `dsr_r()` non-inverted, but the Hunter inverts its RS-232 control inputs (like the documented Port C bits 0-3). With the rs232 unconnected default `m_dsr=1`, bit7 stayed 1 so the firmware's pre-TX DSR wait (`SERIAL_TX_PREP` 6BF0H -- "wait while bit7=1") looped forever for any DSR-handshaking program. Fixed by reading DSR inverted (`if(!m_rs232->dsr_r())`). **Fixed and verified 2026-06-18** (release build: default DSR reads bit 7 = 0 "ready"; no HCOM/TERM regression). | Hunter-driver-local |

> **Note on FIX-1, FIX-2, FIX-6 and FIX-8:** all four edits live in `hunter2.cpp`
> and ship in the in-repo working copy at
> `../src/mame/husky/husky-hunter2.cpp` (renamed for clarity in this fork).
> They are bundled into the single `FIX-1-2-6-8-hunter2.cpp.patch` because
> `git diff` against an upstream checkout produces them together. The patch
> in this folder targets the original upstream filename
> (`src/mame/husky/hunter2.cpp`) for easy `git apply`.
>
> **Note on FIX-10, FIX-13 and FIX-14 (driver-local, no patch files):** all live in
> `../src/mame/husky/husky-hunter2.cpp` only. The build script
> (`../build/build_hunter_from_release.sh`) applies the patch files first,
> then copies the canonical driver verbatim over `src/mame/husky/hunter2.cpp`
> in the upstream tree. That copy step is what brings FIX-10, FIX-13 and FIX-14 into
> the build. The patch-file edits for FIX-1/2/6/8 are still applied first so
> the canonical driver is consistent with what `git diff` would produce.
> **FIX-14 is in the canonical driver and verified** (2026-06-18, release build: the
> default DSR line reads bit 7 = 0 "ready"; no HCOM/TERM regression; see `../CHANGES.md` section FIX-14).
>
> **Note on FIX-11 (no code change):** ROM analysis confirmed that the
> upstream `timer0_out` / `timer1_out` wiring is already correct. A previous
> proposal to swap them broke keyboard input and was reverted. The entry is
> retained in the index for completeness so the FIX-N numbering stays
> contiguous with `CHANGES.md`.

## Applying the patches

From a clean upstream checkout (`mamedev/mame` at the base commit above):

```bash
cd /path/to/mame
git apply /path/to/Husky-Hunter-Emulator/patches/FIX-1-2-6-8-hunter2.cpp.patch
git apply /path/to/Husky-Hunter-Emulator/patches/FIX-3-sdl.lua.patch
git apply /path/to/Husky-Hunter-Emulator/patches/FIX-4-hd61830.cpp.patch
git apply /path/to/Husky-Hunter-Emulator/patches/FIX-5-null_modem.cpp.patch
git apply /path/to/Husky-Hunter-Emulator/patches/FIX-7-mm58174.cpp.patch
git apply /path/to/Husky-Hunter-Emulator/patches/FIX-9-nsc810.cpp.patch
git apply /path/to/Husky-Hunter-Emulator/patches/FIX-12-nsc810-timer0-mode4.patch
# Then overlay the canonical driver to pick up FIX-10 and FIX-13:
cp /path/to/Husky-Hunter-Emulator/src/mame/husky/husky-hunter2.cpp \
   src/mame/husky/hunter2.cpp
```

The release build script (`../build/build_hunter_from_release.sh`) automates
the apply-then-copy sequence above.

## Regenerating the patches

From the working `output/mame` tree (after patches have been applied and any
further edits made):

```bash
cd output/mame
git diff --output=../../patches/FIX-1-2-6-8-hunter2.cpp.patch       -- src/mame/husky/hunter2.cpp
git diff --output=../../patches/FIX-3-sdl.lua.patch                 -- scripts/src/osd/sdl.lua
git diff --output=../../patches/FIX-4-hd61830.cpp.patch             -- src/devices/video/hd61830.cpp
git diff --output=../../patches/FIX-5-null_modem.cpp.patch          -- src/devices/bus/rs232/null_modem.cpp
git diff --output=../../patches/FIX-7-mm58174.cpp.patch             -- src/devices/machine/mm58174.cpp
git diff --output=../../patches/FIX-9-nsc810.cpp.patch              -- src/devices/machine/nsc810.cpp
# FIX-12 is incremental on FIX-9: regenerate from the FIX-9 applied state
git diff --output=../../patches/FIX-12-nsc810-timer0-mode4.patch    -- src/devices/machine/nsc810.cpp
```

> **Use `git diff --output=...`, not PowerShell `>` redirection.** PowerShell's
> pipeline splits stdout into a string array on LF, then re-joins it without
> separators when writing -- producing a single-line patch that `git apply` will
> reject. `git diff --output=FILE` writes the file directly with proper LF line
> endings.

## FIX-4 chargen ROM (`hd61830.bin`)

FIX-4 patches the source reference, but MAME also needs the matching binary
(`hd61830.bin`, 1472 bytes / `0x5C0`). It is **not** a patch -- it is extracted
from the Husky firmware ROM (EPROM5 at CPU address `B43AH`, 96 chars x 7 bytes,
zero-padded to `0x5C0`).

A reproducible extractor is provided at
[`../scripts/extract_hd61830_font.py`](../scripts/extract_hd61830_font.py):

```powershell
# from the repo root -- no arguments needed
.\.venv\Scripts\python.exe scripts\extract_hd61830_font.py

# verify an existing file without rewriting
.\.venv\Scripts\python.exe scripts\extract_hd61830_font.py --check-only --out path\to\hd61830.bin
```

Expected output hashes:

| Field | Value |
|---|---|
| Size  | 1472 bytes (`0x5C0`) |
| CRC32 | `85497474` |
| SHA1  | `734b6c8e399b758ce9e3b2356d47e3730aef0850` |

The shipping copy used by `sdlhunter.exe` lives **inside**
`../roms/hunter.zip`. The script writes a loose copy to
`../roms/hunter/hd61830.bin`; if `hunter.zip` ever needs to be rebuilt, that
loose file is the source.
