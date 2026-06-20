# HCOM Setup

HCOM is a proprietary file-transfer utility for Husky handheld computers. It is not included in this repository and must be obtained separately.

## Obtaining HCOM

Download the original HCOMW distribution archive from:

> **https://github.com/TheEPROM9/Husky-Computer-ROM-Images/blob/main/hcomw.zip**

Click **Download** on the right-hand side of the page.

## Installation

Extract `hcomw.zip` into this folder (`HuskyHCOM/`). The zip contains a `hcomw/` directory; after extraction the structure should be:

```
HuskyHCOM/
  hcomw/
    HCOM.DOS/
      HCOM.EXE
      HCOM.CFG
      HCOM.HLP
      CMDHCOM.EXE
      ...
```

The `hcomw/` folder is not tracked by git. Re-extract if you clone the repository on a new machine.

## HSYNC folder

`HSYNC/` is created automatically the first time HCOM transfers files. It is not tracked by git. Use it as a staging area for files to transfer to or from the Hunter.

## Launching


### Automated Setup (MSYS2 MinGW64)

You can use the automatic setup script to prepare the HCOM bridge environment.

Run it from an **MSYS2 MinGW64** shell (the same shell used to build
`sdlhunter.exe`). `cmd.exe` and PowerShell cannot execute the script -- they
do not provide `bash`, `unzip`, `curl`/`wget`, or POSIX paths.

MSYS2 mounts your Windows drives under `/<drive-letter>/`, so the path looks
like this for an E: drive (replace `e` with yours):

```sh
cd /e/GitHub/Husky-Hunter-Emulator/HuskyHCOM
./setup_hcom.sh
```

(Adjust the path to wherever you cloned the repository.)

This script will:
- Download `hcomw.zip` from the official GitHub repository if not present (requires `curl` or `wget`)
- Extract the HCOM utilities into the correct folder
- Create the `HSYNC/` folder if missing
- Check for required dependencies (`unzip`)

After running the script, use the provided launchers (`LaunchHCOM-MAME.bat` or `LaunchHCOM-MAME.ps1`) from Windows Explorer or PowerShell to start the HCOM bridge.

See the script for details and troubleshooting.

Alternatively, you can launch manually:

Double-click `LaunchHCOM-MAME.bat` (or run `LaunchHCOM-MAME.ps1` directly from PowerShell).

**Requirements:**
- DOSBox-X installed at `C:\DOSBox-X\dosbox-x.exe` (edit `$DosBoxExe` in the `.ps1` if installed elsewhere -- standard DOSBox 0.74 does **not** work, TCP nullmodem is DOSBox-X only)
- `sdlhunter.exe` built at `output\runtime\sdlhunter.exe` (see `build\BUILD_INSTRUCTIONS.md`)

**Workflow:**
1. Run the launcher -- DOSBox-X opens with HCOM ready.
2. In MAME (on the Hunter), type `HCOM` and press Enter.
3. In the DOSBox-X window, type `HCOM` and press Enter.
4. Use `L` in HCOM to switch to `D:` (the `HSYNC/` folder) for file transfers.

## Hunter serial port settings (`COMS`)

Any serial transfer -- the Option B install below, the serial terminal session,
and all day-to-day serial-bridge use -- requires the Hunter's serial port to be
configured first. On the Hunter, type `COMS` and press Enter to open the serial
parameters screen, then set **both** directions to **4800 8N1**:

```
--------- Transmission Parameters ---------
  Rate-4800   Prtcl-none    Pty-8bit
  CTS-n  DTR-n  LF-n  Echo-n  T/O-no  Null-0

---------- Receiving Parameters -----------
  Rate-4800   Prtcl-none    Pty-8bit
  RTS-off  DSR-n  DCD-n  T/O-no  Serig-off
```

> **Use 4800 8N1, not 2400.** The official Husky documentation (and the HCOM
> *Software Download* screen) specifies 2400 8N1, but the working rate over the
> MAME serial bridge is **4800 8N1** -- 2400 produces corruption and failed
> transfers.

These settings persist in the Hunter's NVRAM, so this is a one-time step.

## First-time HCOM.COM install on the emulated Hunter

A factory-fresh Husky Hunter image does not yet have `HCOM.COM` installed.
There are two ways to install it -- pick whichever suits you.

---

### Option A -- Automatic (NVRAM injection, recommended)

`setup_hcom.sh` handles this automatically:

- **If a MAME NVRAM already exists and is freshly formatted** -- the script
  offers to inject immediately.
- **If no NVRAM exists yet** -- the script offers to launch MAME for you. Once
  MAME boots to the Hunter `Ok` prompt, type `FORMAT` and answer `Y` to
  initialise the DEMOS filing system, then quit MAME. The script detects the
  new NVRAM and injects automatically.

> **Important:** injection only works on a **freshly formatted** NVRAM -- one
> where `FORMAT` has been run but no other files have been created yet.
> If you have already been using the emulator and have files on the Hunter,
> skip Option A and use Option B (serial bridge) instead.

You can also run the injection manually from the repository root at any time:

```sh
python3 scripts/inject_hcom.py nvram/hunter_3/nvram --inplace
```

This injects `HCOM.COM` directly into the MAME NVRAM file -- no serial connection needed.  After running, launch MAME normally via `LaunchHCOM-MAME.bat`; `HCOM.COM` will already be present on the Hunter's DEMOS filesystem.

> **Note:** MAME must have been run at least once **and** `FORMAT` typed on the
> Hunter (answer `Y`) to initialise the DEMOS filing system before the manual
> command above will work. `setup_hcom.sh` guides you through this interactively.

---

### Option B -- Manual (serial bridge)

Use HCOM's built-in **Software Download** feature to send `HUNTER.BIN` over the serial bridge.

This step is only needed once per fresh Hunter image.

1. Launch via `LaunchHCOM-MAME.bat` (or `.ps1`). Both the MAME Hunter window and
   the DOSBox-X window will open.
2. In the DOSBox-X window, type `HCOM` and press Enter. HCOM will report a
   **communications failure** -- press any key to dismiss it.
3. Press **S** to open the *Software Download* menu, then select
   **Husky Hunter** from the device list.
4. HCOM displays the *Software Download* instructions screen. If you have not
   already configured the Hunter serial port, do so now via `COMS` -- see
   [Hunter serial port settings](#hunter-serial-port-settings-coms) above. Use
   **4800 8N1**, not the 2400 shown on the HCOM screen.

5. On the Hunter, type `INP 999 HCOM.COM` and press Enter. The Hunter is now
   listening for the download.
6. Press **Enter** in the DOSBox-X HCOM window to start the transfer. HCOM
   shows *Downloading File to Hunter*. Wait for it to complete.
7. On the Hunter, press **SHIFT + ESC** to terminate the download, then run
   `HCOM.COM` (e.g. type HCOM then enter).
8. Back in HCOM (PC), press any key to clear the instructions window, then
   press **C** to connect. Normal HCOM file transfers (option `L` for the
   `HSYNC/` folder, etc.) are now available.

---

## Day-to-day use

Once HCOM.COM is installed (via either option above), use `LaunchHCOM-MAME.bat`
(or `LaunchHCOM-MAME.ps1`) for all future file transfers:

1. Run the launcher -- DOSBox-X opens with HCOM ready.
2. On the Hunter (in MAME), type `HCOM` and press Enter.
3. In the DOSBox-X window, type `HCOM` and press Enter.
4. Use `L` in HCOM to switch to `D:` (the `HSYNC/` folder) for file transfers.
