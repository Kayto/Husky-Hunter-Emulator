#!/bin/bash
# setup_hcom.sh - Installation script for HuskyHCOM bridge
# Usage: bash setup_hcom.sh


set -e

# Always run from the directory where this script is located
cd "$(dirname "$0")"

echo "=== HuskyHCOM Bridge Installation ==="
echo


# Check for unzip
if ! command -v unzip >/dev/null 2>&1; then
    echo "ERROR: 'unzip' is required. Please install it and rerun this script."
    exit 1
fi

# Check for curl or wget
if command -v curl >/dev/null 2>&1; then
    DL_CMD="curl -L -o"
elif command -v wget >/dev/null 2>&1; then
    DL_CMD="wget -O"
else
    echo "ERROR: Either 'curl' or 'wget' is required to download hcomw.zip."
    exit 1
fi


# Download hcomw.zip if not present
zip_path="./hcomw.zip"
zip_url="https://github.com/TheEPROM9/Husky-Computer-ROM-Images/raw/main/hcomw.zip"
if [ ! -f "$zip_path" ]; then
    echo "hcomw.zip not found. Download from GitHub? [Y/n]"
    read -r dl_ans
    dl_ans=${dl_ans:-Y}
    if [[ "$dl_ans" =~ ^[Yy]$ ]]; then
        echo "Downloading hcomw.zip from $zip_url ..."
        $DL_CMD "$zip_path" "$zip_url"
    else
        echo "Aborted. Please provide hcomw.zip in this folder and rerun."
        exit 1
    fi
fi


# Remove any existing hcomw/ to ensure a clean extraction
if [ -d "hcomw" ]; then
    echo "Removing existing hcomw/ directory to ensure a clean install..."
    rm -rf hcomw
fi

# Extract hcomw.zip into ./hcomw/ (force all files into subfolder)
echo "Extracting $zip_path into ./hcomw/ ..."
mkdir hcomw
unzip -o "$zip_path" -d hcomw

# Check for expected structure
if [ ! -d "hcomw/HCOM.DOS" ]; then
    echo "ERROR: Extraction failed or unexpected archive structure in hcomw/."
    exit 1
fi

if [ ! -d "hcomw/HCOM.DOS" ]; then
    echo "ERROR: Extraction failed or unexpected archive structure."
    exit 1
fi

echo "hcomw/ directory extracted."

# Create HSYNC folder if missing (in HuskyHCOM/)
if [ ! -d "HSYNC" ]; then
    mkdir HSYNC
    echo "Created HSYNC/ folder in HuskyHCOM/."
fi

echo
echo "=== PC installation complete. ==="
echo

# -- NVRAM injection (automatic HCOM.COM install) ---------------------------
# Try to inject HCOM.COM directly into the MAME NVRAM file, bypassing the
# manual serial-download process entirely.  Requires Python 3 and a MAME NVRAM
# file that already exists (i.e. MAME has been run at least once).

_nvram_path=""
for _candidate in "../nvram/hunter_3/nvram" "../nvram/hunter/nvram"; do
    if [ -f "$_candidate" ]; then
        _nvram_path="$_candidate"
        break
    fi
done

_python=""
if command -v python3 >/dev/null 2>&1; then
    _python=python3
elif command -v python >/dev/null 2>&1 && python -c "import sys; sys.exit(0 if sys.version_info[0]==3 else 1)" 2>/dev/null; then
    _python=python
fi

if [ -n "$_python" ] && [ -n "$_nvram_path" ]; then
    echo "Found MAME NVRAM: $_nvram_path"
    echo "Inject HCOM.COM automatically (skip manual serial install)? [Y/n]"
    read -r _inject_ans
    _inject_ans=${_inject_ans:-Y}
    if [[ "$_inject_ans" =~ ^[Yy]$ ]]; then
        $_python ../scripts/inject_hcom.py "$_nvram_path" --inplace
        echo
        echo "HCOM.COM injected. Skip straight to 'Day-to-day use' below."
        echo "See HCOM_SETUP.md for full details."
        exit 0
    fi
elif [ -n "$_python" ] && [ -z "$_nvram_path" ]; then
    echo "No MAME NVRAM found yet."
    echo "MAME must be run, the Hunter filing system formatted, then MAME quit."
    echo "Steps once MAME opens:"
    echo "  1. Wait for the Hunter 'Ok' prompt"
    echo "  2. Type FORMAT and press Enter"
    echo "  3. Answer Y to 'FORMAT?'"
    echo "  4. Quit MAME (close the window or press Ctrl+C)"
    echo "Then return here -- the script will inject HCOM.COM automatically."
    echo
    echo "Launch MAME now and press Enter here when done? [Y/n]"
    read -r _wait_ans
    _wait_ans=${_wait_ans:-Y}
    if [[ "$_wait_ans" =~ ^[Yy]$ ]]; then
        # Try to launch MAME in the background (best-effort)
        _mame_launcher=""
        for _l in "../LaunchHCOM-MAME.bat" "../LaunchHCOM-MAME.ps1" "../sdlhunter.exe"; do
            if [ -f "$_l" ]; then _mame_launcher="$_l"; break; fi
        done
        if [ -n "$_mame_launcher" ]; then
            echo "Launching MAME: $_mame_launcher"
            case "$_mame_launcher" in
                *.bat)  cmd.exe /c "$(cygpath -w "$_mame_launcher")" & ;;
                *.ps1)  powershell.exe -ExecutionPolicy Bypass -File "$(cygpath -w "$_mame_launcher")" & ;;
                *)       "$_mame_launcher" & ;;
            esac
        else
            echo "(Could not find LaunchHCOM-MAME launcher -- start MAME manually.)"
        fi
        echo
        echo "Press Enter once you have run FORMAT on the Hunter and quit MAME..."
        read -r _dummy
        # Re-scan for NVRAM
        for _candidate in "../nvram/hunter_3/nvram" "../nvram/hunter/nvram"; do
            if [ -f "$_candidate" ]; then
                _nvram_path="$_candidate"
                break
            fi
        done
        if [ -n "$_nvram_path" ]; then
            echo "Found NVRAM: $_nvram_path"
            echo "Injecting HCOM.COM..."
            $_python ../scripts/inject_hcom.py "$_nvram_path" --inplace
            echo
            echo "HCOM.COM injected. Skip straight to 'Day-to-day use' in HCOM_SETUP.md."
            exit 0
        else
            echo "NVRAM still not found. Falling back to manual serial install."
            echo "(Or run manually: $_python scripts/inject_hcom.py nvram/hunter_3/nvram --inplace)"
            echo
        fi
    else
        echo "Tip: once MAME has run once, re-run setup_hcom.sh or run:"
        echo "  $_python scripts/inject_hcom.py nvram/hunter_3/nvram --inplace"
        echo "(from the RELEASE root, one level above this folder)"
        echo
    fi
fi

# -- Manual HCOM.COM install (serial bridge) --------------------------------
echo "NEXT STEP: Install HCOM.COM on the emulated Hunter (one-time only)."
echo
echo "  1. Run LaunchHCOM-MAME.bat (or .ps1) from this folder."
echo "     Both the MAME Hunter window and the DOSBox-X window will open."
echo "  2. In the DOSBox-X window, type HCOM and press Enter."
echo "     HCOM will report a communications failure - press any key to dismiss."
echo "  3. Press S to open the Software Download menu, then select Husky Hunter."
echo "  4. Configure the Hunter serial port to match the parameters shown by"
echo "     HCOM, BUT use 4800 baud, not 2400."
echo "       (Official Husky docs and the HCOM screen specify 2400 8N1, but"
echo "        the working rate with the MAME serial bridge is 4800 8N1."
echo "        Using 2400 will produce corruption and a failed download.)"
echo
echo "       --------- Transmission Parameters ---------"
echo "         Rate-4800   Prtcl-none    Pty-8bit"
echo "         CTS-n  DTR-n  LF-n  Echo-n  T/O-no  Null-0"
echo
echo "       ---------- Receiving Parameters -----------"
echo "         Rate-4800   Prtcl-none    Pty-8bit"
echo "         RTS-off  DSR-n  DCD-n  T/O-no  Serig-off"
echo
echo "  5. On the Hunter, type:  INP 999 HCOM.COM   and press Enter."
echo "  6. Press Enter in the DOSBox-X HCOM window to start the transfer."
echo "     Wait for 'Downloading File to Hunter' to complete."
echo "  7. On the Hunter, press SHIFT+ESC to terminate the download, then"
echo "     type HCOM and press Enter to run HCOM.COM."
echo "  8. Back in HCOM (PC), press any key to clear the instructions, then"
echo "     press C to connect."
echo
echo "After that, use LaunchHCOM-MAME.bat for normal day-to-day HCOM transfers."
echo "See HCOM_SETUP.md for full details."
