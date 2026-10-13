# clean.ps1 - Revert the RELEASE folder to its clean pre-build state
# By Kayto 05/05/2026
# Licensed under the MIT License. See LICENSE file for details.
#
# Full clean (default) removes all build artefacts, MAME runtime state, and the
# downloaded HCOM utilities:
#   output/             - built binary, DLLs, ROM zip, MAME source tree
#   roms/hunter.zip     - build-generated ROM set
#   cfg/                - MAME runtime config (auto-generated on first run)
#   nvram/              - MAME NVRAM / RAM-disk state
#   config/ui.ini       - MAME-generated UI config (auto-generated on first run)
#   snap/               - MAME screenshots (auto-generated)
#   sta/                - MAME save states (auto-generated)
#   error.log           - MAME error log (auto-generated)
#   build.log           - build-script log (auto-generated)
#   HuskyHCOM/hcomw/    - downloaded HCOM utilities
#   HuskyHCOM/hcomw.zip - downloaded HCOM archive
#
# Keep-HCOM mode (-KeepHcom) removes everything above EXCEPT the HuskyHCOM hcomw
# downloads, so you don't have to re-download the HCOM utilities on the next setup.
#
# Keep-runtime mode (-KeepRuntime) is for Track A users who run the prebuilt
# binary and CANNOT rebuild it without MSYS2. It clears the MAME source tree and
# MAME runtime state, but KEEPS the assets needed to run again (and implies
# -KeepHcom):
#   output/runtime/   - prebuilt sdlhunter.exe + DLLs (and its roms/ copy)
#   roms/hunter.zip   - packaged ROM set
#   HuskyHCOM/hcomw*  - HCOM utilities (hcomw, hcomw.zip)
#
# Build-cleanup mode (-BuildCleanup) removes only:
#   output/mame/     - MAME source tree (~12 GB)
#   Use this if you answered N to the post-build cleanup prompt in
#   build_hunter_from_release.sh and want to reclaim the space later.
#
# Each mode asks "Are you sure?" before deleting, unless -Force is given.
#
# The following are NEVER removed:
#   roms/EPROM*.BIN       - user-supplied ROM images
#   roms/ROMS_README.md   - documentation
#   roms/<any other file> - any other user-placed files
#   HuskyHCOM/HSYNC/      - HCOM file-transfer staging (may hold your own files)
#
# Usage:
#   .\build\clean.ps1                        # full clean (incl. HCOM), interactive
#   .\build\clean.ps1 -KeepHcom              # full clean but keep HCOM downloads
#   .\build\clean.ps1 -KeepRuntime           # keep prebuilt binary, ROMs, HCOM (Track A)
#   .\build\clean.ps1 -Force                 # full clean, skip the confirmation
#   .\build\clean.ps1 -BuildCleanup          # source-tree only, interactive
#   .\build\clean.ps1 -BuildCleanup -Force   # source-tree only, skip confirmation

param(
    [switch]$Force,
    [switch]$BuildCleanup,
    [switch]$KeepHcom,
    [switch]$KeepRuntime
)

$root = Split-Path -Parent $PSScriptRoot   # script is in build/; root is one level up

# ---------------------------------------------------------------------------
# Build-cleanup mode: only remove output/mame/ (MAME source tree)
# ---------------------------------------------------------------------------
if ($BuildCleanup) {
    $mameSrc = Join-Path $root "output\mame"
    if (-not (Test-Path $mameSrc)) {
        Write-Host "Nothing to remove -- output\mame\ does not exist."
        exit 0
    }
    Write-Host "This will permanently delete:"
    Write-Host "  output\mame\  (MAME source tree, ~12 GB)`n"
    if (-not $Force) {
        $answer = Read-Host "Are you sure? This permanently deletes the above [y/N]"
        if ($answer -notmatch '^[Yy]') {
            Write-Host "Aborted."
            exit 0
        }
    }
    Remove-Item $mameSrc -Recurse -Force
    Write-Host "Removed: output\mame\  (MAME source tree)"
    Write-Host "`nBuild cleanup complete."
    exit 0
}

# ---------------------------------------------------------------------------
# Full clean (default). -KeepHcom keeps the HCOM downloads; -KeepRuntime also
# keeps the prebuilt binary and packaged ROM set (and implies -KeepHcom).
# ---------------------------------------------------------------------------
$keepHcomEffective = $KeepHcom -or $KeepRuntime

$toRemove = @()

# output/ : a full clean removes the whole tree; -KeepRuntime removes every
# child EXCEPT output/runtime/ (the prebuilt binary + DLLs that a Track A user
# cannot rebuild without MSYS2).
$outputDir = Join-Path $root "output"
if ($KeepRuntime) {
    if (Test-Path $outputDir) {
        Get-ChildItem $outputDir -Force | Where-Object { $_.Name -ne "runtime" } | ForEach-Object {
            $toRemove += @{ Path = $_.FullName; Label = "output/$($_.Name)  (build artefact)" }
        }
    }
} else {
    $toRemove += @{ Path = $outputDir; Label = "output/  (binary, DLLs, MAME source tree)" }
}

# roms/hunter.zip : the packaged ROM set -- kept by -KeepRuntime.
if (-not $KeepRuntime) {
    $toRemove += @{ Path = Join-Path $root "roms\hunter.zip"; Label = "roms/hunter.zip  (build-generated ROM set)" }
}

# MAME runtime state (regenerated on the next run).
$toRemove += @(
    @{ Path = Join-Path $root "cfg";           Label = "cfg/  (MAME runtime config)" }
    @{ Path = Join-Path $root "nvram";         Label = "nvram/  (MAME NVRAM / RAM-disk state)" }
    @{ Path = Join-Path $root "config\ui.ini"; Label = "config/ui.ini  (MAME-generated UI config)" }
    @{ Path = Join-Path $root "snap";          Label = "snap/  (MAME screenshots)" }
    @{ Path = Join-Path $root "sta";           Label = "sta/  (MAME save states)" }
    @{ Path = Join-Path $root "error.log";     Label = "error.log  (MAME error log)" }
    @{ Path = Join-Path $root "build.log";     Label = "build.log  (build-script log)" }
)

# HCOM downloads: removed by a full clean, kept when -KeepHcom or -KeepRuntime.
# HuskyHCOM/HSYNC/ is deliberately NOT here -- it is user transfer data and is
# never auto-deleted by any mode (see the "NEVER removed" note above).
$hcomItems = @(
    @{ Path = Join-Path $root "HuskyHCOM\hcomw";     Label = "HuskyHCOM/hcomw/  (downloaded HCOM utilities)" }
    @{ Path = Join-Path $root "HuskyHCOM\hcomw.zip"; Label = "HuskyHCOM/hcomw.zip  (downloaded HCOM archive)" }
)
if (-not $keepHcomEffective) {
    $toRemove += $hcomItems
}

$present = $toRemove | Where-Object { Test-Path $_.Path }

# Items the chosen mode preserves, listed so the user can see what is kept.
$hcomPreserved = @()
if ($keepHcomEffective) {
    $hcomPreserved = $hcomItems | Where-Object { Test-Path $_.Path }
}

$runtimePreserved = @()
if ($KeepRuntime) {
    @(
        @{ Path = Join-Path $root "output\runtime"; Label = "output/runtime/  (prebuilt binary + DLLs)" }
        @{ Path = Join-Path $root "roms\hunter.zip"; Label = "roms/hunter.zip  (packaged ROM set)" }
    ) | Where-Object { Test-Path $_.Path } | ForEach-Object { $runtimePreserved += $_ }
}

# Show user ROM files that will be preserved.
$romsDir = Join-Path $root "roms"
$preserved = @()
if (Test-Path $romsDir) {
    $preserved = Get-ChildItem $romsDir -File |
        Where-Object { $_.Name -ne "hunter.zip" } |
        Select-Object -ExpandProperty Name
}

if ($present.Count -eq 0) {
    Write-Host "Nothing to clean -- already at pre-build state."
    if ($preserved.Count -gt 0) {
        Write-Host ""
        Write-Host "Preserved in roms/ (not touched):"
        $preserved | ForEach-Object { Write-Host "  roms/$_" }
    }
    exit 0
}

if ($KeepRuntime) {
    Write-Host "Track A clean (keeping prebuilt binary, ROMs and HCOM). The following will be permanently deleted:`n"
} elseif ($KeepHcom) {
    Write-Host "Clean (keeping HCOM downloads). The following will be permanently deleted:`n"
} else {
    Write-Host "Full clean. The following will be permanently deleted:`n"
}
$present | ForEach-Object { Write-Host "  $($_.Label)" }

if ($runtimePreserved.Count -gt 0) {
    Write-Host ""
    Write-Host "Preserved (Track A run assets, kept by -KeepRuntime):"
    $runtimePreserved | ForEach-Object { Write-Host "  $($_.Label)" }
}
if ($preserved.Count -gt 0) {
    Write-Host ""
    Write-Host "Preserved in roms/ (NOT deleted):"
    $preserved | ForEach-Object { Write-Host "  roms/$_" }
}
if ($hcomPreserved.Count -gt 0) {
    Write-Host ""
    Write-Host "Preserved (HCOM):"
    $hcomPreserved | ForEach-Object { Write-Host "  $($_.Label)" }
}
if (Test-Path (Join-Path $root "HuskyHCOM\HSYNC")) {
    Write-Host ""
    Write-Host "Preserved (HCOM transfer files, never deleted):"
    Write-Host "  HuskyHCOM/HSYNC/"
}
Write-Host ""

if (-not $Force) {
    $answer = Read-Host "Proceed? [y/N]"
    if ($answer -notmatch '^[Yy]') {
        Write-Host "Aborted."
        exit 0
    }
}

foreach ($item in $present) {
    if (Test-Path $item.Path) {
        Remove-Item $item.Path -Recurse -Force
        Write-Host "Removed: $($item.Label)"
    }
}

if ($KeepRuntime) {
    Write-Host "`nClean complete. Kept your prebuilt binary, ROM set and HCOM."
    Write-Host "Re-run scripts\setup_hunter.py to format the Hunter and re-install HCOM, then play."
} else {
    Write-Host "`nClean complete. Run ./build/build_hunter_from_release.sh to rebuild."
}
