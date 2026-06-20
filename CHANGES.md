# MAME Hunter Driver - Changes vs Upstream

**As of:** 2026-06-18

All changes are relative to upstream MAME `src/mame/husky/hunter2.cpp`
at tag `mame0287`, unless otherwise stated. Five source-level fixes were
required before the emulator would boot to a working DEMOS 2.2 prompt using
the original 6x8 K ROM dumps with a correct real-time clock, plus a sixth
(RTC device class), a seventh (RTC default running state), an eighth
(day-of-week host-encoding remap), a ninth (NSC810 Timer 1 clock-select
upstream bug), a tenth (serial RX `rxd_w` start-bit guard), an eleventh
(Timer A/B wiring -- verified correct, no code change), a twelfth (NSC810
Timer 0 mode 4 timer-tick output) and a thirteenth (NMI vector fetch in
paged-RAM mode). HCOM file transfer (DOSBox-X <-> MAME null_modem at 4800
baud) and serial transmit, receive-interrupt and full-duplex operation all match
real-Hunter behaviour with these fixes in place.

### Summary

| # | What changed | Why it mattered | Scope |
|---|--------------|-----------------|-------|
| ROM set | Added the 1983 six-chip EPROM set as a new BIOS option | Without it, there was no ROM set that matched the physical hardware | Setup only -- registering our hardware variant |
| FIX-1 | The emulator was loading the wrong ROM chips into the upper memory window at start-up | Caused a completely blank screen -- the CPU ran off into garbage immediately | 6-EPROM set only -- other BIOS variants were unaffected |
| FIX-2 | A bounds check used the wrong size limit, allowing an out-of-range bank to appear valid | Could silently map garbage memory during banking | 6-EPROM set only -- padding coincidence masked the bug for other variants |
| FIX-3 | A linker script had two libraries in the wrong order for MinGW | The build failed entirely with an "undefined reference to WinMain" error | Build system only -- affects anyone building on Windows with MinGW, any ROM set |
| FIX-4 | Replaced a placeholder character font (typed in from a datasheet by a MAME contributor) with the actual font extracted from EPROM5 | Characters on screen were wrong glyphs -- the Hunter has its own character layout, not the generic HD61830 default | Upstream bug -- affects all Hunter BIOS variants |
| FIX-5 | Changed the `null_modem` RS-232 device default baud from 9600 to 4800 | HCOM on the Hunter is hardcoded to 4800 baud and slot defaults can't be set on the CLI; without this, every byte over the emulated serial link is dropped | Required for HCOM <-> DOSBox-X file transfer; unrelated to display/boot |
| FIX-6 | Swapped the RTC device from MM58274C (binary) to MM58174A (BCD) to match the Hunter hardware | `PRINT TIME$` and `PRINT DATE$` reported corrupt values at digit-boundary rollovers (e.g. hour `24` instead of wrapping at 23->00, garbled month/day-of-week) because the firmware writes BCD into ports the wrong device interprets as binary, with different register offsets for day-of-week, months and leap-year status | Upstream bug -- affects all Hunter BIOS variants; previously listed as a known TODO in upstream `hunter2.cpp` |
| FIX-7 | Default the MM58174A's STOP/START control register to *running* in `device_start()` | Without it, after FIX-6 the clock would freeze at boot until the user typed `TIME$ = "hh:mm:ss"` (which writes `0x01` to port 4EH). Real hardware preserves the run bit across power-down via the VBB battery-backup pin; MAME's RTC framework has no chip-level NVRAM, so the run bit must be primed at startup or `TIME$` shows a frozen value loaded from the host wallclock. **Side-effect:** time and date now resync to the host system clock at every MAME launch; user-set `TIME$ = "..."` is not retained across restarts | Upstream MAME quirk -- affects every system using `mm58174_device` |
| FIX-8 | Remap host day-of-week to the Hunter firmware's encoding (`1=Mon..7=Sun`) in `hunter2_state::machine_reset()` | The MM58174A `DAY_OF_WEEK` register (port 4AH) was off-by-one. MAME's `device_rtc_interface::set_current_time()` seeds the chip with `weekday + 1` (POSIX `0=Sun..6=Sat`), giving `1=Sun..7=Sat`; Hunter firmware expects `1=Mon..7=Sun`. The remap converts `1 -> 7` and `2..7 -> 1..6`. Placed in `machine_reset` because `set_rtc_datetime()` re-seeds the chip after `machine_start` | Hunter-driver-local; encoding is system-specific so no upstream change is appropriate |
| FIX-9 | NSC810 `REG_TIMER1_START` used `m_timer_mode[0]` and `m_timer_clock[0]` (Timer 0 variables) instead of the Timer 1 equivalents | If Timer 0 and Timer 1 are running simultaneously with different mode bits the /2 prescaler selection for Timer 1 is wrong. Both Hunter timer clocks are identical (4 MHz each) so the clock-index error is harmless for Hunter, but the mode-index error is a latent correctness bug | Upstream bug in `nsc810.cpp` |
| FIX-10 | `rxd_w()` asserted `NSC800_RSTB` on every RXD bit edge; `cts_w()` contained a live `popmessage()` debug call | `rxd_w` firing on all 10 bit-edges of an 8N1 byte caused the COM ISR to re-enter mid-byte, breaking `ON COM GOSUB` / LINCHR under MAME (the received-byte counter never advanced). `cts_w` popmessage flooded the MAME OSD during serial sessions | Hunter-driver-local; lives in canonical `src/mame/husky/husky-hunter2.cpp` (no separate patch file) |
| FIX-11 | *(Verified correct, no code change)* Timer A/B wiring confirmed by ROM analysis | Timer A (NSC810 Timer 0) -> NMI is the serial TX baud clock. Timer B (NSC810 Timer 1) -> RSTA at ~61 Hz drives the system housekeeping callback (keyboard scan + sound). Upstream wiring was correct. | Documentation only -- no driver change |
| FIX-12 | NSC810 `timer_tick` only fired the output callback for timer mode bits 0x01 and 0x02; Hunter ROM `SOUND_MODE_INIT` programs Timer 0 mode = 0x6CH (bits 2:0 = 0x04) | Timer 0 started and counted but never asserted its output, so NMI never reached the CPU and LOPCHR spun forever on the F7E0H spin-lock -- serial TX froze immediately | Upstream bug in `nsc810.cpp` |
| FIX-13 | NMI vector fetch at 0x0066 read paged-RAM garbage when foreground was in paged-RAM mode | Real Hunter hardware auto-switches bank1 to ROM on NMI ack; MAME's NSC800 (inherits Z80) has no equivalent callback. Fixed with a permanent ROM read-shadow at 0x0066-0x0068 plus a port-0x80 (POWSAV) handler that switches bank1 to ROM inside NMI service. Serial transmit, receive-interrupt and full-duplex behaviour all match real Hunter | Hunter-driver-local; lives in canonical `src/mame/husky/husky-hunter2.cpp` (no separate patch file) |
| FIX-14 | DSR hardware handshaking read with inverted polarity, so the firmware's pre-transmit DSR wait looped forever under MAME | The Hunter inverts its RS-232 control inputs (Port C 0-3 are documented "inverted from RS-232 line"); `portb_r` read DSR non-inverted, and the rs232 unconnected default `m_dsr=1` left Port B bit 7 = 1, so `SERIAL_TX_PREP`'s "wait while bit7=1" spun forever. Inverted the DSR read. **Fixed and verified 2026-06-18** (release build: the default/unconnected line now reads bit 7 = 0 "ready" -> TX proceeds, vs bit 7 = 1 pre-fix; no HCOM/TERM regression). Latent -- only DSR-handshaking programs reach it | Hunter-driver-local; canonical `src/mame/husky/husky-hunter2.cpp` (no separate patch file) |

---

## Emulation status

Across a comprehensive set of test programs the ROM<->MAME hardware contract held
end-to-end: paged-RAM banking, overlay loading, bank-switching, interrupt arming, and
interrupt-vector fetching all behaved correctly, with **no ROM-derived hardware-contract
gaps observed** (bounded by test coverage -- see the [UNKNOWN] paths in
`MAME_STATUS_RELEASE.md` -- not a proof none remain). One known
modelling nuance: FIX-13's NMI-vector shadow at `0x0066-0x0068` is a *permanent*
read-shadow (broader than the hardware's interrupt-acknowledge-timed override) --
identical for the NMI vector fetch, an open question only for a *data* read of those
three bytes.

For the full fidelity assessment -- the [OK]/[PARTIAL]/[GAP]/[UNKNOWN] coverage matrix,
the validated real-vs-MAME parity outcomes, and the open items -- see
[`MAME_STATUS_RELEASE.md`](MAME_STATUS_RELEASE.md) (alongside this file).

---

## ROM set added: BIOS 4 - "DEMOS 2.2 9G06h (6 ROMs)"

**File:** `src/mame/husky/hunter2.cpp`

A new BIOS entry (internal index 3, selected with `-bios 4`) was added for the physical
six-chip EPROM set dumped from a real 1983 Husky Hunter.  The upstream driver already
had three BIOS entries for other ROM variants but none matched this hardware.  CRC32s
match the 1983 Hunter ROM set from
[TheEPROM9/Husky-Computer-ROM-Images](https://github.com/TheEPROM9/Husky-Computer-ROM-Images).

```cpp
ROM_SYSTEM_BIOS(3, "4", "DEMOS 2.2 9G06h (6 ROMs)")
ROMX_LOAD( "eprom0.ic50", 0x0000, 0x2000, CRC(ad861c35) SHA1(...), ROM_BIOS(3) )
ROMX_LOAD( "eprom1.ic51", 0x2000, 0x2000, CRC(c8c2fae8) SHA1(...), ROM_BIOS(3) )
ROMX_LOAD( "eprom2.ic52", 0x4000, 0x2000, CRC(b301621f) SHA1(...), ROM_BIOS(3) )
ROMX_LOAD( "eprom3.ic53", 0x6000, 0x2000, CRC(be6f196a) SHA1(...), ROM_BIOS(3) )
ROMX_LOAD( "eprom4.ic54", 0x8000, 0x2000, CRC(7a0d2228) SHA1(...), ROM_BIOS(3) )
ROMX_LOAD( "eprom5.ic55", 0xa000, 0x2000, CRC(48526702) SHA1(...), ROM_BIOS(3) )
```

---

## FIX-1 - bank2 reset offset: 0x4000 -> 0x8000 (blank screen on boot)

**File:** `src/mame/husky/hunter2.cpp`, function `machine_reset()`
**Patch:** none -- driver-local; built from canonical `src/mame/husky/husky-hunter2.cpp` (before/after below is the diff)

**Symptom:** MAME displayed a completely blank screen immediately after launch.  The
emulator appeared to run (it consumed CPU time) but nothing was ever written to the
display.

**Root cause:** `machine_reset()` initialised `bank2` (the 0x8000-0xBFFF window) to
`ROM + 0x4000` -- pointing at EPROMs 2-3 instead of EPROMs 4-5.  On the 6-EPROM 1983
Hunter the physical ROM map is:

```
0x0000-0x7FFF  EPROMs 0-3  (bank1, 32 K)
0x8000-0xBFFF  EPROMs 4-5  (bank2, 16 K)
```

With the wrong base, the CPU fetched garbage at 0x8000-0xBFFF and jumped to an invalid
address before the very first `OUT(E0H)` memory-mapping instruction at 0x020A could
correct the bank assignment.  The machine halted silently with no display output.

**Fix:**

```cpp
// Before (WRONG - points at EPROMs 2-3):
m_bank2->set_base(m_rom->base() + 0x4000);

// After (CORRECT - points at EPROMs 4-5):
m_bank2->set_base(m_rom->base() + 0x8000);
```

---

## FIX-2 - memmap_w() ROM range guard: m_rom->bytes() -> 0xC000

**File:** `src/mame/husky/hunter2.cpp`, function `memmap_w()`
**Patch:** none -- driver-local; built from canonical `src/mame/husky/husky-hunter2.cpp` (before/after below is the diff)

**Symptom:** When BASIC paged in ROM bank 2, it could appear to succeed but silently
mapped an uninitialised/0xFF region instead of raising an out-of-range error.

**Root cause:** The ROM region is declared as 0x10000 (64 K) and filled with 0xFF
padding by `ROMREGION_ERASEFF`, but only 0xC000 (48 K) of it is populated.
`m_rom->bytes()` returns 0x10000.  The range guard was:

```cpp
if ((0x8000 + (0x4000 * bank)) < m_rom->bytes())  // 0x10000 -- always true for bank=2!
```

With the old guard, bank=2 gave `0x8000 + 0x8000 = 0x10000`, which is not `< 0x10000`,
but the unsigned comparison can wrap or the guard was effectively always true depending
on the compiler.  More importantly, the correct architectural limit is 0xC000 regardless
of padding.

**Fix:**

```cpp
// Before (used padded region size -- masked the bug above and let invalid banks through):
if ((0x8000 + (0x4000 * bank)) < m_rom->bytes())

// After (correct architectural ROM limit for the 6-EPROM build):
if ((0x8000 + (0x4000 * bank)) < 0xc000)
```

---

## FIX-3 - sdl.lua: mingw32 must precede SDL2main in link order

**File:** `scripts/src/osd/sdl.lua`
**Patch:** `patches/FIX-3-sdl.lua.patch`

**Symptom:** Linking `sdlhunter.exe` under MSYS2 MinGW64 failed with:

```
undefined reference to `WinMain'
```

**Root cause:** The upstream `sdl.lua` listed `SDL2main` before `mingw32` in the
`links {}` block.  Under MinGW `--start-group`/`--end-group` linking, `WinMain` is
supplied by `libmingw32.a` but `SDL2main` references it as an external.  The linker
resolves symbols left-to-right, so `SDL2main` must come _after_ `mingw32`.

**Fix:** Inserted `"mingw32"` before `"SDL2main"` in the `mingw*` link list:

```lua
-- Before:
links { "SDL2main", "SDL2", "imm32", "version" }

-- After:
links { "mingw32", "SDL2main", "SDL2", "imm32", "version" }
```

---

## FIX-4 - hd61830.bin: supply actual Hunter font to replace BAD_DUMP placeholder

**File:** `src/devices/video/hd61830.cpp`
**Patch:** `patches/FIX-4-hd61830.cpp.patch` (source ref only; the `hd61830.bin` font binary is extracted, not patched -- see below)
**Data file:** `roms/hunter.zip` -> `hd61830.bin`

**Background:** The upstream `hd61830.bin` was flagged `BAD_DUMP` with the comment
"typed in from manual" -- character data transcribed from the HD61830 datasheet, not
the actual Hunter font.  The Hunter has no dedicated character-ROM chip; the firmware
copies its own font from EPROM5 into the HD61830's internal RAM at boot.  The upstream
placeholder was therefore not the actual ROM glyphs.

**Font location:** EPROM5, CPU address **B43AH** (file offset **0x143A**).
96 characters x 7 bytes (rows 0-6 of a 7x8 cell), 672 bytes total.

**Extraction:** 96 x 7 bytes read from EPROM5 at file offset **0x143A**, padded to
0x5C0 (1472 bytes).  CRC32 `85497474`,
SHA1 `734b6c8e399b758ce9e3b2356d47e3730aef0850`.

**hd61830.cpp change:**

```cpp
// Before (upstream BAD_DUMP -- generic datasheet transcription):
ROM_LOAD( "hd61830.bin", 0x000, 0x5c0, BAD_DUMP CRC(06a934da) SHA1(bf3f074db5dc92e6f530cb18d6c013563099a87d) ) // typed in from manual

// After (Hunter font extracted from EPROM5):
ROM_LOAD( "hd61830.bin", 0x000, 0x5c0, CRC(85497474) SHA1(734b6c8e399b758ce9e3b2356d47e3730aef0850) ) // Hunter font extracted from EPROM5 B43AH
```

---

## FIX-5 - `null_modem` default baud changed to 4800 (HCOM compatibility)

**File:** `src/devices/bus/rs232/null_modem.cpp`
**Patch:** `patches/FIX-5-null_modem.cpp.patch`

The MAME `null_modem` RS232 device defaults its TX/RX baud rates to 9600.  The Hunter
runs HCOM at a hardcoded 4800 baud (per the Husky `LaunchHCOM.ps1` device table for
"Husky Hunter / Hunter 2"), and the framing simply does not align at 9600 -- every byte
is dropped.  Slot defaults are not overridable from the MAME CLI, so the source default
was patched:

```cpp
// Before:
PORT_RS232_BAUD("RS232_TXBAUD", RS232_BAUD_9600, "TX Baud", null_modem_device, update_serial)
PORT_RS232_BAUD("RS232_RXBAUD", RS232_BAUD_9600, "RX Baud", null_modem_device, update_serial)

// After:
PORT_RS232_BAUD("RS232_TXBAUD", RS232_BAUD_4800, "TX Baud", null_modem_device, update_serial)
PORT_RS232_BAUD("RS232_RXBAUD", RS232_BAUD_4800, "RX Baud", null_modem_device, update_serial)
```

This unblocks the bridge to DOSBox-X + `HCOM.EXE`, allowing the Hunter (running the
resident `HUNTER.BIN` HCOM client at 4800 baud) to file-transfer with a real
`HCOM.EXE` running in DOSBox-X over a TCP `nullmodem` connection on port 5705.

The Hunter ROM's own serial driver (used by `LPRINT` / `INP` / `COMS`) is configurable
at runtime, so this lower default does not break ROM-level tests at 1200 / 2400 -- the
Hunter side is set via `COMS` to match.

---

## FIX-6 - RTC device: MM58274C (binary) -> MM58174A (BCD)

**File:** `src/mame/husky/hunter2.cpp`
**Patch:** none -- driver-local; built from canonical `src/mame/husky/husky-hunter2.cpp` (before/after below is the diff)

**Symptom:** From BASIC, `PRINT TIME$` and `PRINT DATE$` returned partly-correct values
that broke at any digit-boundary rollover. For example, with the clock at 24-hour
local time `18:00:00`, `TIME$` returned `"24:00:00"` (binary `0x18` = decimal 24,
displayed verbatim instead of as BCD `18`). The date showed nonsense like
`"60-04-1926"` because the day-of-week and months registers are at different offsets
on the two chips.

**Root cause:** The Husky Hunter is wired with a National Semiconductor **MM58174A**
real-time clock (confirmed by hardware documentation and the MM58174A datasheet).
The MM58174A stores all time/date fields as **BCD** split into separate units/tens
registers. The upstream MAME driver wired up an **MM58274C** instead, which is a
binary-encoded RTC with a different register layout from offset 0x0a onwards:

| Port | MM58174A (correct)        | MM58274C (wrong)        |
|------|---------------------------|-------------------------|
| 0x0a | DAY_OF_WEEK               | UNITS_OF_MONTHS         |
| 0x0b | UNITS_OF_MONTHS           | TENS_OF_MONTHS          |
| 0x0c | TENS_OF_MONTHS            | UNITS_OF_YEARS          |
| 0x0d | LEAP_YEAR_STATUS (W only) | TENS_OF_YEARS           |
| 0x0e | STOP_START (W only)       | DAY_OF_WEEK             |

The two effects compound:

1. **Encoding mismatch.** The firmware writes BCD digits to registers the MM58274C
   stores as raw binary, then reads them back. For values 0-9 BCD and binary
   coincide, so small numbers look correct -- but at any digit boundary (10, 20, 24...)
   the value diverges.
2. **Register-layout mismatch.** Firmware writes day-of-week to port 0x4A
   (MM58174A's DAY_OF_WEEK) which the MM58274C interprets as UNITS_OF_MONTHS;
   leap-year status writes to 0x4D land in MM58274C's TENS_OF_YEARS. The DATE$
   readout is therefore garbage even before BCD/binary conversion.

**Fix:** Swap the device class, the include, and the I/O map handler. The MM58174A
has no `set_mode24()` or `set_day1()` configuration methods, so those two upstream
config calls are removed:

```cpp
// Before:
#include "machine/mm58274c.h"
...
map(0x40, 0x4f).mirror(0x10).rw("rtc", FUNC(mm58274c_device::read), FUNC(mm58274c_device::write));
...
mm58274c_device &rtc(MM58274C(config, "rtc", 32.768_kHz_XTAL));
rtc.set_mode24(0); // 12 hour
rtc.set_day1(1);   // monday

// After:
#include "machine/mm58174.h"
...
map(0x40, 0x4f).mirror(0x10).rw("rtc", FUNC(mm58174_device::read), FUNC(mm58174_device::write));
...
mm58174_device &rtc(MM58174(config, "rtc", 32.768_kHz_XTAL)); // MM58174A -- BCD RTC
```

The MM58174A device is already implemented upstream (`src/devices/machine/mm58174.{h,cpp}`),
so no new device file is needed.

**Verification:** After the swap, `PRINT TIME$` reports correctly across the 09->10,
19->20 and 23->00 hour rollovers, and `PRINT DATE$` produces a valid `dd-mm-yyyy` string
that increments through month boundaries.

---

## FIX-7 - MM58174A: default the clock to running at `device_start()`

**File:** `src/devices/machine/mm58174.cpp`
**Patch:** `patches/FIX-7-mm58174.cpp.patch`

**Symptom:** After FIX-6 (the device-class swap), `PRINT TIME$` returned a frozen
value at every MAME launch. The displayed time was correct *for the moment of launch*
(host wallclock loaded into the RTC by MAME's `device_rtc_interface` framework) but
did not advance.

**Root cause:** `mm58174_device::clock_tick()` only increments the seconds counter
when `m_control & CTL_CLKRUN` is set. `m_control` is zero at `device_start()`, so the
clock is parked. The bit only flips to 1 when the firmware writes `0x01` to port
0x4EH (the chip's STOP/START register) -- only reachable via the BASIC `TIME$ = "..."`
assignment path.

On real hardware this is fine: the MM58174A has a `VBB` battery-backup pin that
preserves all 14 internal registers (including STOP/START) across power cycles.
MAME's `device_rtc_interface` has no per-chip NVRAM equivalent -- each `device_start()`
is a clean slate. The previously-used `mm58274c_device` masked this issue because its
`clock_tick()` callback has no run/stop gate.

**Fix:** Set `m_control = CTL_CLKRUN` at the top of `device_start()` so the chip
boots in run mode, matching the steady-state of any battery-backed install. The
firmware can still toggle the bit at runtime via port 0x4EH; this only changes the
power-on default.

```cpp
void mm58174_device::device_start()
{
    m_rtc_timer = timer_alloc(FUNC(mm58174_device::clock_tick), this);
    m_rtc_timer->adjust(attotime::zero, 0, attotime::from_msec(100));
    m_interrupt_timer = timer_alloc(FUNC(mm58174_device::scheduler_sync), this);

    // FIX-7: default to running so the RTC auto-advances from the host wallclock
    // loaded by device_rtc_interface. Real hardware retains m_control across
    // power-down via the VBB battery-backup pin; MAME's RTC framework has no
    // per-chip NVRAM, so without this the clock is frozen at boot.
    m_control = CTL_CLKRUN;
    ...
}
```

**Side-effect:** because MAME has no NVRAM persistence for the MM58174A's internal
registers, the chip is re-seeded from the host system clock at every `device_start()`.
User-set `TIME$ = "..."` / `DATE$ = "..."` values do **not** persist across MAME
restarts. For Husky Hunter use this is generally desirable (TIME$/DATE$ are always
current without user intervention).

**Upstreaming:** Independent of the Hunter driver and would benefit any other system
using `mm58174_device`.

---

## FIX-8 -- RTC day-of-week host encoding remap

**File:** `src/mame/husky/hunter2.cpp` (Hunter-driver-local; no upstream device change)
**Patch:** none -- driver-local; built from canonical `src/mame/husky/husky-hunter2.cpp` (before/after below is the diff)

**Problem:** Software reading MM58174A port 4AH gets a value one day off the
host wallclock (e.g. a Monday host reports Tuesday).

**Root cause:** `device_rtc_interface::set_current_time()` seeds every battery-backed
RTC by calling `set_time(... weekday + 1 ...)` where `weekday` is POSIX
`0=Sun..6=Sat`. The MM58174A stores this verbatim in `m_wday`, so port 4AH holds
`1=Sun..7=Sat`. The Hunter firmware expects `1=Mon..7=Sun`. The MM58174A's
`DAY_OF_WEEK` register is application-defined, so the encoding choice belongs in the
system driver, not the device.

**Fix:** In `hunter2_state::machine_reset()`, derive the weekday from
`machine().base_datetime()` and write it to port 4AH through the chip's public write
handler with the translation `1 -> 7`, `2..7 -> 1..6`:

```cpp
system_time systime;
machine().base_datetime(systime);
int posix_wday = systime.local_time.weekday;          // 0=Sun..6=Sat
uint8_t hunter_dow = (posix_wday == 0) ? 7 : (uint8_t)posix_wday;
m_rtc->write(0x0a, hunter_dow);
```

A `required_device<mm58174_device> m_rtc` member is added so the driver can write to
the chip directly.

**Placement:** must be `machine_reset()`, not `machine_start()`. `running_machine::run()`
runs `start()` -> `nvram_load()` -> `set_rtc_datetime()` -> `soft_reset()`. A write in
`machine_start()` is overwritten by the subsequent `set_rtc_datetime()` seed;
`machine_reset()` runs after the seed.

**Upstreaming:** Not appropriate. The encoding is Hunter-specific.

---

## FIX-9 - NSC810 Timer 1 Start: wrong clock/mode variables

**File:** `src/devices/machine/nsc810.cpp`
**Patch:** `patches/FIX-9-nsc810.cpp.patch`

**Root cause:** In `nsc810_device::write()`, the `REG_TIMER1_START` case computes
the timer tick rate using `m_timer_mode[0]` and `m_timer_clock[0]` -- the Timer 0
variables -- instead of the Timer 1 equivalents.

```cpp
// Before (wrong -- reads Timer 0 mode/clock for Timer 1):
case REG_TIMER1_START:
    ...
    if (m_timer_mode[0] & 0x08)       // should be m_timer_mode[1]
        rate = m_timer_clock[0] / 2;  // should be m_timer_clock[1]
    else
        rate = m_timer_clock[0];      // should be m_timer_clock[1]

// After (correct):
    if (m_timer_mode[1] & 0x08)
        rate = m_timer_clock[1] / 2;
    else
        rate = m_timer_clock[1];
```

**Impact on Hunter:** Both Hunter timer clocks are wired to the same 4 MHz source
(`8_MHz_XTAL / 2`), so the clock index is immaterial here. The mode index (`0x08`
prescaler check) would give a wrong /2 prescaler selection if Timer 0 and Timer 1
are programmed with different mode bits at the same time -- a latent correctness bug.

**Upstreaming:** Appropriate -- this is an upstream bug not specific to the Hunter.

---

## FIX-10 - Serial receive: `rxd_w` start-bit edge guard + `cts_w` debug cleanup

**File:** `src/mame/husky/husky-hunter2.cpp` (canonical driver, no separate patch)

### rxd_w -- assert RSTB on start-bit falling edge only

**Symptom:** `rxd_w()` asserted `NSC800_RSTB` on every RXD state change, ignoring
the `state` parameter. MAME's `null_modem` device serialises each byte into
individual bit transitions at 4800 baud; a single 8N1 byte produces up to 10 calls.
RSTB was therefore asserted up to 10 times per received byte, re-entering the COM ISR
mid-byte before `LINCHR` had finished reading it.

**Fix:** Assert only on the falling edge (`state == 0`), which is the start bit.
`LINCHR` bit-bangs the remaining 8 data bits by polling Port C bit 0 directly and
does not need further RSTB assertions during that window.

```cpp
// Before (fires on every bit transition):
void hunter2_state::rxd_w(int state)
{
    if(BIT(m_irq_mask, 2))
        m_maincpu->set_input_line(NSC800_RSTB, ASSERT_LINE);
}

// After (start-bit falling edge only):
void hunter2_state::rxd_w(int state)
{
    if(state == 0 && BIT(m_irq_mask, 2))
        m_maincpu->set_input_line(NSC800_RSTB, ASSERT_LINE);
}
```

### cts_w -- debug popmessage removed

The original `cts_w()` contained a `popmessage()` displaying "CTS: RSTC set N"
on the MAME OSD on every CTS transition -- debug scaffolding left in upstream.
Removed; the interrupt line assertion is kept.

---

## FIX-11 - Timer A/B wiring: upstream confirmed correct (no code change)

**File:** `src/mame/husky/husky-hunter2.cpp` -- `timer0_out()` / `timer1_out()`
**Net change:** none -- ROM analysis confirmed the upstream wiring; no modification needed.

### Correct hardware wiring (documented from ROM analysis)

| Signal  | NSC810 device | Ports | Role |
|---------|---------------|-------|------|
| **NMI** | Timer A (Timer 0) | 0x10/0x11 count, 0x14 stop, 0x15 start, 0x18 mode | Serial TX baud clock. Programmed by V24_INIT (LOPCHR) or SOUND_MODE_INIT (tape). Each NMI tick the installed NMI handler at `0xF814H` advances the serial-TX state machine. |
| **RSTA** | Timer B (Timer 1) | 0x12/0x13 count, 0x16 stop, 0x17 start, 0x19 mode | 61 Hz system housekeeping. `TIMER_B_INIT` programs count=0xFFFF, mode=0x01, starts via `OUT(17H)`. Each tick asserts RSTA -> the NSC800's dedicated **RSTA vector at `0x003C`** -> `JP 0FDFBH` -> `TIMER_AB_ISR`, the active ~61 Hz handler that drives **keyboard scanning** and system housekeeping. RSTA is de-asserted by reading Timer 1 (0x13H) inside the ISR. (The Z80 IM 1 vector at `0x0038H` -> `JP_TRAMPOLINE` (0xFAC6H) -> `SOUND_CALLBACK` (0xE674H) is a **separate, conditional** path -- see note below -- not how the NSC800 routes RSTA.) |

**The `0x0038`/`JP_TRAMPOLINE`/`SOUND_CALLBACK` path is separate from RSTA.**
`JP_TRAMPOLINE` (0xFAC6H) -> `SOUND_CALLBACK` (0xE674H) is populated by `SOUND_MODE_INIT`
only in tape / baud-10 sound mode (which also sets Timer A mode 0x6CH and `IM 1`). It is
**not** the RSTA dispatch path -- the NSC800 vectors RSTA through its dedicated `0x003C`
entry (above), and `0x0038`/`FAC6` is dormant at the idle prompt (`FAC6` reads `3F`).
Confirmed by MAME read-watchpoints: int-ack fetches land at `0x003C`, never `0x0038`.

### RSTA mask bit

`timer1_out` checks `m_irq_mask & 0x08` before passing state to `NSC800_RSTA`.
The ICR value 0x0CH (`OUT(0BBH),0x0CH` at `L_618DH`) sets bit 3 (RSTA enable)
and bit 2 (RSTB enable). `m_irq_mask` is loaded from the ICR write at port 0xBBH.

### Unchanged code (matches upstream)

```cpp
void hunter2_state::timer0_out(int state)
{
    if(state == ASSERT_LINE)
        m_maincpu->pulse_input_line(INPUT_LINE_NMI, attotime::zero);
}

void hunter2_state::timer1_out(int state)
{
    if(m_irq_mask & 0x08)
        m_maincpu->set_input_line(NSC800_RSTA, state);
}
```

---

## FIX-12 - NSC810 Timer 0 mode 4: `timer_tick` output not firing

**File:** `src/devices/machine/nsc810.cpp`
**Patch:** `patches/FIX-12-nsc810-timer0-mode4.patch`

**Symptom:** serial TX froze immediately after `RUN`. LOPCHR set its
spin-lock at `F7E0H = 0x01`, started Timer 0 via `OUT (15H), A`, then waited
forever for an NMI from Timer 0 to clear the lock. The NMI never came.

**Root cause:** ROM `SOUND_MODE_INIT` writes `OUT (18H), 6CH` -> NSC810 Timer 0
mode register = 0x6C (bits 2:0 = **0x04**, auto-reload interval mode,
/2 prescaler). The MAME `nsc810_device::timer_tick` template only fires
`m_timer_out[Timer](ASSERT_LINE)` when `mode bits == 0x01 or 0x02`. Mode 4
passed the start gate (mode bits != 0x00 and != 0x07 so the timer counted) but
never fired its output. Mode 4 is behaviourally identical to mode 2 in the
MAME model (decrement to zero, fire output, auto-reload from `m_timer_base`).

**Fix:** add mode 4 to the `timer_tick` output-fire condition alongside modes
1 and 2:

```cpp
// Before:
if ((m_timer_mode[Timer] & 0x07) == 0x01 || (m_timer_mode[Timer] & 0x07) == 0x02)

// After (FIX-12):
if ((m_timer_mode[Timer] & 0x07) == 0x01 || (m_timer_mode[Timer] & 0x07) == 0x02
    || (m_timer_mode[Timer] & 0x07) == 0x04)
```

**Upstreaming:** Appropriate -- affects any system using Timer 0 in mode 4.

---

## FIX-13 - NMI vector fetch in paged-RAM mode

**File:** `src/mame/husky/husky-hunter2.cpp` (canonical driver, no separate patch)

**Symptom:** After FIX-12 the Timer 0 NMI fires correctly and `bp 0x0066` does
break, but on entering the NMI vector at `0x0066` the CPU reads paged-RAM bytes
(`F2 00 01 ...` = `JP P, $0100`) instead of the ROM's `C3 14 F8` (`JP F814H` --
the entry to the installed NMI handler template at `0xF814H`). The CPU then jumps
into uninitialised paged-RAM code and bounces through garbage, never reaching the
TX handler. The serial transmit, receive-interrupt and full-duplex paths all freeze the same way.

**Root cause:** Real Hunter hardware has an NMI-detection circuit that switches
`bank1` to ROM automatically on NMI ack. This guarantees the vector fetch at
`0x0066` reads `JP F814H` even when the foreground was running in paged-RAM mode
(`OUT (E0H), 0x80`). MAME's NSC800 inherits Z80 NMI semantics (`take_nmi` in
`src/devices/cpu/z80/z80.lst:888`) with no callback at NMI-ack -- there is no
hook the driver can use to swap banks at NMI dispatch time.

A bank switch at NMI **assertion** (in the `timer0_out` callback) was tried first
but introduced a foreground race: `pulse_input_line` queues NMI for the next
instruction boundary, so the bank switch took effect during the remaining cycles
of the current foreground instruction. Foreground bank1 reads during that window
returned ROM bytes instead of the expected RAM, and the corruption surfaced as
intermittent freezes mid-test.

**Fix:** three Hunter-driver-local pieces that together avoid the race:

**1. Permanent ROM read-shadow at `0x0066-0x0068`.** Installed in
`machine_reset()` and re-installed inside `memmap_w` and `powsav_w` (because
each `install_*_bank` call clobbers it). The CPU's NMI vector fetch always reads
ROM bytes from this shadow regardless of bank1 state -- foreground does not use
these three bytes as application data.

```cpp
void hunter2_state::install_nmi_vector_shadow()
{
    address_space &prog_space = m_maincpu->space(AS_PROGRAM);
    prog_space.install_read_handler(0x0066, 0x0068,
        read8sm_delegate(*this, FUNC(hunter2_state::nmi_vector_rom_r)));
}

uint8_t hunter2_state::nmi_vector_rom_r(offs_t offset)
{
    return m_rom->base()[0x0066 + offset];
}
```

**2. `powsav_w` handler on port 0x80.** Previously `noprw()` in upstream. The NMI
handler template at `0xF814H` issues `OUT (80H), 0` at offset F81D -- `inside`
NMI service, after the CPU has already left foreground. The handler switches
`bank1` to ROM via `set_base` + `install_read_bank`. The `install_read_bank`
call is required: `memory_bank::set_base()` in MAME 0.287 only updates the
bank's anonymous entry pointer and does not invalidate the CPU's cached
page->host translations.

```cpp
void hunter2_state::powsav_w(uint8_t data)
{
    address_space &prog_space = m_maincpu->space(AS_PROGRAM);
    m_bank1->set_base(m_rom->base());
    prog_space.install_read_bank(0x0000, 0x7fff, m_bank1);
    install_nmi_vector_shadow();
}
```

**3. Re-install the shadow after every `install_*_bank` call.** Both `memmap_w`
(foreground `OUT (E0H)`) and `powsav_w` (NMI-time `OUT (80H)`) call
`install_*_bank` over a range covering `0x0066-0x0068`, which would otherwise
clobber the shadow. The single `install_nmi_vector_shadow()` call at the end of
each restores it.

The `OUT (E0H), saved_NMI_PHASE` at the end of the NMI handler template (offset
`F82A`) restores the foreground page state via `memmap_w` when NMI service ends.
`timer0_out` is unchanged from upstream -- no bank switching at NMI assertion,
no foreground race.

**Verification:** serial transmit, receive-interrupt and full-duplex behaviour all
run correctly under MAME and match real-Hunter behaviour when no serial server is
listening on the bridge.

**Upstreaming:** Not appropriate -- the fix is specific to Hunter's
hardware-driven bank-on-NMI behaviour and uses Hunter-specific port 0x80.

---

## FIX-14 - DSR handshake read inverted (driver-local), VERIFIED

**File:** `src/mame/husky/husky-hunter2.cpp`, `portb_r()` (canonical driver, no separate patch)
**Status:** **Fixed and verified 2026-06-18** (release build).

**Symptom:** A program that enables **DSR hardware handshaking** (`POKE 63485,1`)
hangs after starting to transmit: the display keeps refreshing but no bytes go out.

**Root cause:** The firmware's `SERIAL_TX_PREP` (ROM `6BF0H`) busy-waits **while Port B
bit 7 (DSR) = 1**, i.e. until DSR is asserted, before transmitting. The Hunter inverts its
RS-232 control inputs at the receiver (the driver documents Port C bits 0-3 as "inverted
from RS-232 line"; Port B/DSR shares that receiver), so on real hardware an asserted DSR
reads as bit 7 = 0 -> the wait exits -> TX proceeds. MAME read DSR **non-inverted**
(`portb_r`: `if(m_rs232->dsr_r()) res |= 0x80;`), and the rs232 port's unconnected default is
`m_dsr = 1` (set in `rs232_port_device::device_resolve_objects()`; `null_modem` drives no DSR),
so bit 7 stayed 1 and the wait looped forever.

**Fix:** read DSR inverted, matching the documented Port C control-input inversions:

```cpp
// Before:
if(m_rs232->dsr_r())  res |= 0x80;
// After (FIX-14):
if(!m_rs232->dsr_r()) res |= 0x80;
```

Now the unconnected default (DSR "ready") gives bit 7 = 0 -> TX proceeds; a peer that
de-asserts DSR gives bit 7 = 1 -> the firmware waits, as on real hardware.

**Why latent until now:** the DSR wait is gated by the terminal-mode flag `F7FD`, which the
verified scenarios (serial TX, RX-interrupt, full-duplex, HCOM, and TERM via the bridge echo test) never set,
so none reached it. CTS handshaking (HCOM) is independent (peer-driven via `cts_w` -> RSTC)
and unaffected.

**Validation (2026-06-18, release build):** FIX-14 changes *every* Port B bit-7 (DSR) read,
including the non-blocking `SERIAL_DSR_CHK` guard (ROM `007CH`). (a) **No regression**: TERM
(bridge echo) and HCOM still work. (b) **Read polarity confirmed in-emulator** at
`SERIAL_DSR_CHK` (`007CH`): on the default/unconnected line (`m_dsr = 1`) the DSR read now
returns bit 7 = 0 ("ready", TX proceeds): `IN A,(01H); AND 80H` gives `A = 00`, versus `A = 80`
(bit 7 = 1) on the pre-fix binary; a `null_modem` (which drives DSR = 0) reads bit 7 = 1
(correctly waits). The blocking spin in `SERIAL_TX_PREP` (`6BF0H`) is gated by the terminal-mode
flag `F7FD`, which no stock program arms, so verification used the ungated `007CH` gate. The
real-HW DSR polarity is strongly implied (firmware wait-logic + Port C inversions) but not
schematic-confirmed.

**Upstreaming:** Not appropriate, Hunter-specific RS-232 control-input inversion.

---

## Known remaining issues (upstream TODO, not addressed)

These are pre-existing gaps in the upstream MAME driver that were noted but not changed as part of this work.

| Issue | Detail |
|-------|--------|
| No storage device emulation | The Hunter had an external storage interface (HCOM/tape). No image device is wired up in the driver, so software can only be loaded via NVRAM injection -- there is no way to load a file from a virtual drive inside MAME itself. |
| HD61830 clock unknown | The LCD controller is clocked at `XTAL(4'915'200)/2/2` (~1.23 MHz) -- this is a guess, not confirmed from hardware measurements. Affects timing accuracy of display operations. |
