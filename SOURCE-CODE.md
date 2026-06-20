# Corresponding Source Code

This repository contains patches and a canonical patched Hunter driver source file for **MAME**, which is licensed under the GNU General Public License v2.0 or later (GPL-2.0-or-later). In
compliance with the GPL, the complete corresponding source code for the
modified version of MAME used to produce any distributed binary is available
as described below.

- - -

## Base MAME version

**Version:** MAME 0.287
**Release date:** 31 March 2026
**Official source:** https://github.com/mamedev/mame/releases/tag/mame0287
**Direct source tarball:** https://github.com/mamedev/mame/archive/refs/tags/mame0287.tar.gz

- - -

## Modifications

Modifications to **shared MAME files** (devices and the SDL build script) are
provided as patch files in the `patches/` directory of this repository. The
**Hunter driver** itself is provided as a complete canonical source file rather
than a patch (see below):

| Patch file | Affected MAME file | Description |
| ---------- | ------------------ | ----------- |
| `FIX-3-sdl.lua.patch` | `scripts/src/osd/sdl.lua` | SDL build system fix (FIX-3) |
| `FIX-4-hd61830.cpp.patch` | `src/devices/video/hd61830.cpp` | HD61830 LCD controller fix (FIX-4) |
| `FIX-5-null_modem.cpp.patch` | `src/devices/bus/rs232/null_modem.cpp` | Null modem serial fix (FIX-5) |
| `FIX-7-mm58174.cpp.patch` | `src/devices/machine/mm58174.cpp` | MM58174 RTC fix (FIX-7) |
| `FIX-9-nsc810.cpp.patch` | `src/devices/machine/nsc810.cpp` | NSC810 Timer 1 clock/mode-select fix (FIX-9) |
| `FIX-12-nsc810-timer0-mode4.patch` | `src/devices/machine/nsc810.cpp` | NSC810 Timer 0 mode 4 timer-tick output (FIX-12) |

The Hunter driver is provided as a complete canonical source file at
`src/mame/husky/husky-hunter2.cpp`. It carries **all** the driver-local fixes
(FIX-1, FIX-2, FIX-6, FIX-8, FIX-10, FIX-13 and FIX-14), none of which have a
separate patch file (see `patches/PATCHES_README.md` and `CHANGES.md`); the build
copies this file over `src/mame/husky/hunter2.cpp` to bring those fixes into the
build.

To reconstruct the full modified MAME source tree:

1. Download the MAME 0.287 source tarball (link above).
2. Apply each patch in `patches/` in numeric order using `git apply` or `patch -p1`.
3. Copy `src/mame/husky/husky-hunter2.cpp` into the MAME source tree at the same path.

See `build/BUILD_INSTRUCTIONS.md` for full build instructions, or
`build/build_hunter_from_release.sh` for an automated build script.

- - -

## Source availability

The corresponding source code for any binary distributed from this repository
is provided by the files in this repository together with the upstream MAME
0.287 source archive identified above.

To reconstruct the modified source tree, download the upstream MAME source,
apply the patches in `patches/`, and follow `build/BUILD_INSTRUCTIONS.md`.

No separate written offer is required when the binary is distributed together with these source files, patches and build instructions. If a binary is distributed separately, it must be accompanied either by the corresponding source code or by a GPL-compliant written offer to provide that source.

- - -

*This file was last updated: 19/06/2026*