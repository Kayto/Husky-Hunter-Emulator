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

The patch file (`patches/FIX-1-2-6-8-hunter2.cpp.patch`) still targets `hunter2.cpp`
(the correct MAME path) and is applied before the copy step, so the copy acts as a
definitive override that supersedes the patch for FIX-1, FIX-2, FIX-6, and FIX-8.

## Driver-local fixes that live only in this file

Several fixes have **no separate patch file** -- they exist only in this canonical
`husky-hunter2.cpp`, and the copy step above is what brings them into the build:

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
