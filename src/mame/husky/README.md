# src/mame/husky/

## Why is the file named `husky-hunter2.cpp` and not `hunter2.cpp`?

The upstream MAME source file is `src/mame/husky/hunter2.cpp`.

This copy is named `husky-hunter2.cpp` deliberately so it cannot be accidentally
confused with, or overwritten by, the upstream file. The different name makes it
immediately clear this is the patched fork version when browsing the repository.

The build script (`build/build_hunter_from_release.sh`) copies it over the upstream
file at build time:

```sh
cp src/mame/husky/husky-hunter2.cpp \
   <mame-src>/src/mame/husky/hunter2.cpp
```

There is **no driver patch file**. Every Hunter-driver fix lives only in this
canonical `husky-hunter2.cpp`, and the copy step above is the sole mechanism that
brings them into the build (the shared device/build fixes are the ones shipped as
`patches/*.patch`).

## Driver-local fixes that live only in this file

All Hunter-driver fixes have **no separate patch file** -- they exist only in this
canonical `husky-hunter2.cpp`, and the copy step above is what brings them into the
build:

* **FIX-1** -- bank2 reset offset `0x4000` -> `0x8000` (blank screen on boot).
* **FIX-2** -- `memmap_w()` ROM range guard uses the architectural `0xC000` limit.
* **FIX-6** -- RTC device swapped MM58274C (binary) -> MM58174A (BCD).
* **FIX-8** -- RTC day-of-week host-encoding remap (`1=Mon..7=Sun`).
* **FIX-10** -- serial RX `rxd_w` start-bit edge guard, plus removal of a debug
  `popmessage()` left in `cts_w`.
* **FIX-13** -- NMI vector fetch in paged-RAM mode (ROM read-shadow at
  `0x0066-0x0068` + a port-`0x80` POWSAV handler).
* **FIX-14** -- DSR handshake read inverted to match the Hunter's RS-232
  control-input inversion (verified 2026-06-18).

The build script applies the patch files first, then copies this file verbatim
over `src/mame/husky/hunter2.cpp`, so the canonical driver is the single source
of truth for everything above. Full narrative for each fix is in
[`../../../CHANGES.md`](../../../CHANGES.md); the patch/no-patch breakdown is in
[`../../../patches/PATCHES_README.md`](../../../patches/PATCHES_README.md).
