# Quick Start

Get the Husky Hunter emulator running in a few steps. First [download this project](#first-download-this-project), then follow one of two routes — choose the one that fits you:

* **[Track A: Run a prebuilt binary](#track-a-run-a-prebuilt-binary)** — use the prebuilt `sdlhunter.exe` (needs Python, no compiler).
* **[Track B: Build it yourself](#track-b-build-it-yourself)** — build `sdlhunter.exe` from source on Windows (MSYS2).

Whichever route you take, supply your own Husky Hunter ROM dumps — they are not, and cannot be, included (see [Can I share this?](#can-i-share-this)).

- - -

## First: download this project

If you don't already have these files on your PC:

1. On the project's GitHub page, click the green **Code** button, then **Download ZIP**.
2. Extract the ZIP somewhere convenient — for example `C:\Husky-Hunter-Emulator`.
3. Open that extracted folder. Every command below is run from there (the "repository root").

> Prefer Git? `git clone <repository-url>` does the same thing.

- - -

## Track A: Run a prebuilt binary

Take this route if you already have the release folder containing `output/runtime/sdlhunter.exe` and its DLLs. You need **Python 3** (a small install from [python.org](https://www.python.org/downloads/)) and your own ROM dumps — but no MSYS2, MinGW64, or compiler. Then:

**1. Add your ROMs.** Copy your six EPROM dumps into the [roms/](roms/) folder:

```
roms\EPROM0.BIN   roms\EPROM1.BIN   roms\EPROM2.BIN
roms\EPROM3.BIN   roms\EPROM4.BIN   roms\EPROM5.BIN
```

**2. Run the setup helper.** From the repository root:

```powershell
python scripts\setup_hunter.py
```

It packages your ROMs into `roms\hunter.zip` (extracting the screen font and checking every CRC), then guides you through the one-time first-run setup — it opens MAME so you can run `FORMAT` and `CLCK`, then **close MAME to return to the script** — and finally offers to install HCOM. Just follow its prompts.

**3. Play.** Launch any time with:

```powershell
.\launchers\LaunchHunterMAME.ps1
```

(or double-click [launchers/LaunchHunterMAME.bat](launchers/LaunchHunterMAME.bat)).

> **HCOM file transfer (optional).** HCOM is proprietary and not included — supply your own copy by extracting `hcomw/` into `HuskyHCOM/` (see [HuskyHCOM/HCOM_SETUP.md](HuskyHCOM/HCOM_SETUP.md), "Obtaining HCOM"). If it's already there, step 2 installs it for you; if not, step 2 **pauses** so you can add it then and press Enter — or skip it and install later. For the full first-run and serial details, see the [README "First run"](README.md#first-run) section.

- - -

## Track B: Build it yourself

Take this route to build `sdlhunter.exe` from source on Windows. Set aside **~12 GB of disk and ~60 minutes**, then:

**1. Install [MSYS2](https://www.msys2.org/)** and open the **MSYS2 MinGW64** shell.

**2. Install the build tools** in that shell:

```bash
pacman -S --needed git make python zip patch mingw-w64-x86_64-gcc mingw-w64-x86_64-SDL2
```

**3. Build.** Change to the repo and run the script:

```bash
cd /e/GitHub/Husky-Hunter-Emulator    # adjust to your checkout
./build/build_hunter_from_release.sh
```

The script clones MAME, applies the patches, builds the binary into `output/runtime/`, and — if your `EPROM*.BIN` files are already in `roms/` — packages `hunter.zip` for you, then guides you through first-run setup.

For full options and troubleshooting, see [build/BUILD_INSTRUCTIONS.md](build/BUILD_INSTRUCTIONS.md).

> Already built it and just need to re-make `hunter.zip` later without opening MSYS2? Run Track A step 2 ([scripts/setup_hunter.py](scripts/setup_hunter.py)) — it re-packages the ROM set in Python.

- - -

## Can I share this?

**You may share `sdlhunter.exe` (and its DLLs) — only if** you distribute it together with all of:

* the source patches, `src/mame/husky/husky-hunter2.cpp`, and [SOURCE-CODE.md](SOURCE-CODE.md) (the GPL corresponding source);
* [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md);
* the "Unofficial / not affiliated with MAME" notice kept intact, with no extra restrictions added to the binary.

**You may not share** these — each person must supply their own:

* the ROM dumps `EPROM*.BIN`;
* the generated `hunter.zip` or `hd61830.bin`;
* HCOM binaries.

Full detail: [README "Licensing"](README.md#licensing) and [SOURCE-CODE.md](SOURCE-CODE.md).
