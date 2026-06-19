# Third-Party Notices

### Trademark notice

MAME is a registered trademark of Gregory Ember. This repository is an
independent project and is not affiliated with, endorsed by, or sponsored by
the MAME project or its contributors. The MAME name is used only to identify
the upstream emulator and source tree that this project patches.

---

This repository contains driver source code, patches, and tooling for use with
MAME and related software. The following third-party components are referenced
or required to build and run the resulting binary.

---

## 1. MAME

**Project:** MAME -- Multiple Arcade Machine Emulator  
**URL:** https://www.mamedev.org/  
**Source:** https://github.com/mamedev/mame  

MAME as a project is distributed under GPL-2.0-or-later because it contains
code under multiple GPL-compatible licences. Many individual MAME source files
are licensed under BSD 3-Clause or other GPL-compatible licences.

Modified MAME source files and binaries produced from them must be distributed
in compliance with the applicable MAME licences, including GPL-2.0-or-later for
the combined program.

Full text: https://www.gnu.org/licenses/old-licenses/gpl-2.0.html

The patches in `patches/` are modifications to MAME source files and are
therefore also subject to the GPL-2.0-or-later. `src/mame/husky/husky-hunter2.cpp`
is a modified/canonical copy of the upstream MAME Hunter driver with this
project's changes applied. It remains subject to the licence terms of the
upstream MAME file and any additional compatible terms shown in its SPDX header.

**Corresponding source:** The exact MAME version patched, and the patches themselves,
are documented in `SOURCE-CODE.md`.

---

## 2. SDL2 (Simple DirectMedia Layer)

**Project:** SDL2  
**URL:** https://www.libsdl.org/  
**Source:** https://github.com/libsdl-org/SDL  
**License:** zlib License  
Full text: https://www.zlib.net/zlib_license.html

SDL2 is used by MAME's SDL OSD backend. It is not modified by this project.

---

## 3. DOSBox-X (optional, for HCOM file transfer)

**Project:** DOSBox-X  
**URL:** https://dosbox-x.com/  
**Source:** https://github.com/joncampbell123/dosbox-x  
**License:** GNU General Public License v2.0  
Full text: https://www.gnu.org/licenses/old-licenses/gpl-2.0.html

DOSBox-X is an optional dependency used to run HCOM.EXE for file transfer
to/from the physical Husky Hunter via serial. DOSBox-X is not modified or
distributed by this project.

---

## 4. Tera Term (optional, for serial terminal)

**Project:** Tera Term  
**URL:** https://teratermproject.github.io/  
**Source:** https://github.com/TeraTermProject/teraterm  
**License:** BSD 2-Clause License  
Full text: https://opensource.org/licenses/BSD-2-Clause

Tera Term is an optional dependency used as a serial terminal to communicate
with the emulated Husky Hunter. The file `TERATERM-hunter-mame.INI` is a
configuration file for Tera Term and is provided under the BSD 3-Clause
License (same as this project). Tera Term itself is not modified or
distributed by this project.

---

## 5. MSYS2 / MinGW-w64 (build toolchain, Windows only)

**Project:** MSYS2  
**URL:** https://www.msys2.org/  
**License:** Various (BSD, MIT, GPL); see https://www.msys2.org/license/

**Project:** MinGW-w64  
**URL:** https://www.mingw-w64.org/  
**License:** Various; see https://sourceforge.net/p/mingw-w64/wiki2/License/

These toolchains are required to build MAME on Windows.

The build script copies the following MinGW-w64 runtime DLLs into the binary
output directory (`output/runtime/`) so that `sdlhunter.exe` runs on standard
Windows installations without requiring MSYS2 to be installed:

| DLL | Licence |
|-----|---------|
| `libgcc_s_seh-1.dll` | GCC Runtime Library Exception (GPL-3.0-or-later with Runtime Library Exception -- permits redistribution with any application) |
| `libstdc++-6.dll` | GCC Runtime Library Exception (same as above) |
| `libwinpthread-1.dll` | MIT License (winpthreads, part of MinGW-w64) |

These files are not modified by this project. The GCC Runtime Library Exception
explicitly permits distributing these runtime libraries alongside applications
without imposing GPL conditions on the application itself. Full exception text:
https://www.gnu.org/licenses/gcc-exception-3.1.html

---

*This file was last updated: 07/05/2026*
