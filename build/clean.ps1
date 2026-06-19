# clean.ps1 - Revert the RELEASE folder to its clean pre-build state
# By Kayto 05/05/2026
# Licensed under the MIT License. See LICENSE file for details.
#
# Full clean (default) removes all build artefacts and MAME runtime state:
#   output/          - built binary, DLLs, ROM zip, MAME source tree
#   roms/hunter.zip  - build-generated ROM set
#   cfg/             - MAME runtime config (auto-generated on first run)
#   nvram/           - MAME NVRAM / RAM-disk state
#   config/ui.ini    - MAME-generated UI config (auto-generated on first run)
#   snap/            - MAME screenshots (auto-generated)
#   sta/             - MAME save states (auto-generated)
#   error.log        - MAME error log (auto-generated)
#   build.log        - build-script log (auto-generated)
#
# Build-cleanup mode (-BuildCleanup) removes only:
#   output/mame/     - MAME source tree (~12 GB)
#   Use this if you answered N to the post-build cleanup prompt in
#   build_hunter_from_release.sh and want to reclaim the space later.
#
# The following are NEVER removed:
#   roms/EPROM*.BIN       - user-supplied ROM images
#   roms/ROMS_README.md   - documentation
#   roms/<any other file> - any other user-placed files
#
# Usage:
#   .\build\clean.ps1                        # full clean, interactive
#   .\build\clean.ps1 -Force                 # full clean, skip confirmation
#   .\build\clean.ps1 -BuildCleanup          # source-tree only, interactive
#   .\build\clean.ps1 -BuildCleanup -Force   # source-tree only, skip confirmation

param(
    [switch]$Force,
    [switch]$BuildCleanup
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
        $answer = Read-Host "Proceed? [y/N]"
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
# Full clean
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

$present = $toRemove | Where-Object { Test-Path $_.Path }

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

Write-Host "The following will be permanently deleted:`n"
$present | ForEach-Object { Write-Host "  $($_.Label)" }

if ($preserved.Count -gt 0) {
    Write-Host ""
    Write-Host "Preserved in roms/ (NOT deleted):"
    $preserved | ForEach-Object { Write-Host "  roms/$_" }
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
