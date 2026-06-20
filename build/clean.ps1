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
#   HuskyHCOM/HSYNC/    - HCOM file-transfer staging folder
#
# Keep-HCOM mode (-KeepHcom) removes everything above EXCEPT the three HuskyHCOM
# items, so you don't have to re-download the HCOM utilities on the next setup.
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
#
# Usage:
#   .\build\clean.ps1                        # full clean (incl. HCOM), interactive
#   .\build\clean.ps1 -KeepHcom              # full clean but keep HCOM downloads
#   .\build\clean.ps1 -Force                 # full clean, skip the confirmation
#   .\build\clean.ps1 -BuildCleanup          # source-tree only, interactive
#   .\build\clean.ps1 -BuildCleanup -Force   # source-tree only, skip confirmation

param(
    [switch]$Force,
    [switch]$BuildCleanup,
    [switch]$KeepHcom
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
# Full clean (default) -- with -KeepHcom, keeps the HCOM downloads
# ---------------------------------------------------------------------------
$toRemove = @(
    @{ Path = Join-Path $root "output";          Label = "output/  (binary, DLLs, MAME source tree)" }
    @{ Path = Join-Path $root "roms\hunter.zip"; Label = "roms/hunter.zip  (build-generated ROM set)" }
    @{ Path = Join-Path $root "cfg";             Label = "cfg/  (MAME runtime config)" }
    @{ Path = Join-Path $root "nvram";           Label = "nvram/  (MAME NVRAM / RAM-disk state)" }
    @{ Path = Join-Path $root "config\ui.ini";   Label = "config/ui.ini  (MAME-generated UI config)" }
    @{ Path = Join-Path $root "snap";            Label = "snap/  (MAME screenshots)" }
    @{ Path = Join-Path $root "sta";             Label = "sta/  (MAME save states)" }
    @{ Path = Join-Path $root "error.log";       Label = "error.log  (MAME error log)" }
    @{ Path = Join-Path $root "build.log";       Label = "build.log  (build-script log)" }
)

# HCOM downloads: removed by a full clean, kept when -KeepHcom is given.
$hcomItems = @(
    @{ Path = Join-Path $root "HuskyHCOM\hcomw";     Label = "HuskyHCOM/hcomw/  (downloaded HCOM utilities)" }
    @{ Path = Join-Path $root "HuskyHCOM\hcomw.zip"; Label = "HuskyHCOM/hcomw.zip  (downloaded HCOM archive)" }
    @{ Path = Join-Path $root "HuskyHCOM\HSYNC";     Label = "HuskyHCOM/HSYNC/  (HCOM file-transfer staging)" }
)
if (-not $KeepHcom) {
    $toRemove += $hcomItems
}

$present = $toRemove | Where-Object { Test-Path $_.Path }

# When keeping HCOM, list the HCOM items that exist so the user sees they're kept.
$hcomPreserved = @()
if ($KeepHcom) {
    $hcomPreserved = $hcomItems | Where-Object { Test-Path $_.Path }
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

if ($KeepHcom) {
    Write-Host "Clean (keeping HCOM downloads). The following will be permanently deleted:`n"
} else {
    Write-Host "Full clean. The following will be permanently deleted:`n"
}
$present | ForEach-Object { Write-Host "  $($_.Label)" }

if ($preserved.Count -gt 0) {
    Write-Host ""
    Write-Host "Preserved in roms/ (NOT deleted):"
    $preserved | ForEach-Object { Write-Host "  roms/$_" }
}
if ($hcomPreserved.Count -gt 0) {
    Write-Host ""
    Write-Host "Preserved (HCOM, kept by -KeepHcom):"
    $hcomPreserved | ForEach-Object { Write-Host "  $($_.Label)" }
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

Write-Host "`nClean complete. Run ./build/build_hunter_from_release.sh to rebuild."
