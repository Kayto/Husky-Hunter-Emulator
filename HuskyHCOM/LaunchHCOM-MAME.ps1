# LaunchHCOM-MAME.ps1 - Launch HCOM bridge: DOSBox-X (HCOM.EXE) <-> MAME (Husky Hunter)
# Release repository version -- paths adapted for RELEASE/ structure.
# By Kayto 04/05/2026
# Licensed under the MIT License. See LICENSE file for details.
# =============================================================
#  Starts DOSBox-X listening on TCP 5705 with HCOM.EXE ready,
#  then launches MAME emulating the Hunter, connected as a
#  serial bitbanger client to that same port.
#
#  Prerequisites:
#    - DOSBox-X installed at C:\DOSBox-X\dosbox-x.exe
#      (edit $DosBoxExe below if installed elsewhere)
#    - hcomw\ extracted into HuskyHCOM\hcomw\ alongside this script
#      (see HCOM_SETUP.md for instructions)
#    - sdlhunter.exe built; expected at output\runtime\sdlhunter.exe
#      relative to the repo root (one level above this folder)
#
#  Workflow once both windows are open:
#    Hunter (in MAME):    HCOM
#    PC     (in DOSBox):  HCOM
#
#  Order matters: start HCOM on the Hunter first, then run HCOM in DOSBox-X.
# =============================================
$ErrorActionPreference = 'Stop'

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot   = Split-Path -Parent $ScriptDir                        # RELEASE/
$DosBoxExe  = 'C:\DOSBox-X\dosbox-x.exe'
$DosBoxConf = Join-Path $ScriptDir 'dosbox-hcom-mame.conf'
$MameExe    = Join-Path $RepoRoot 'output\runtime\sdlhunter.exe'
$Port       = 5705

# --- preflight ---
foreach ($p in @($DosBoxExe, $DosBoxConf)) {
    if (-not (Test-Path $p)) { Write-Host "MISSING: $p" -ForegroundColor Red; exit 1 }
}
if (-not (Test-Path $MameExe)) {
    Write-Host "MISSING: $MameExe" -ForegroundColor Red
    Write-Host "  Build sdlhunter.exe first with build\build_hunter_from_release.sh" -ForegroundColor Yellow
    exit 1
}
$hcomExe = Join-Path $ScriptDir 'hcomw\HCOM.DOS\HCOM.EXE'
if (-not (Test-Path $hcomExe)) {
    Write-Host "MISSING: hcomw\HCOM.DOS\HCOM.EXE" -ForegroundColor Red
    Write-Host "  See HCOM_SETUP.md for installation instructions." -ForegroundColor Yellow
    exit 1
}

Write-Host '== HCOM <-> MAME bridge ==' -ForegroundColor Cyan

# --- stop any leftover DOSBox-X and free port 5705 ---
Get-Process dosbox-x -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500

# --- start DOSBox-X (will listen on 5705) ---
# Launch with WorkingDirectory = HuskyHCOM/ so the conf's  mount c "."  maps
# this folder, giving HCOM.EXE access at C:\hcomw\HCOM.DOS\.
Write-Host "Starting DOSBox-X (HCOM, listening on $Port)..." -ForegroundColor Yellow
Start-Process -FilePath $DosBoxExe `
              -ArgumentList @('-conf', "`"$DosBoxConf`"") `
              -WorkingDirectory $ScriptDir

# --- wait for the listener to come up ---
$ready = $false
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Milliseconds 250
    $tcp = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($tcp) { $ready = $true; break }
}
if (-not $ready) {
    Write-Host "DOSBox-X did not start listening on port $Port. Aborting." -ForegroundColor Red
    exit 1
}
Write-Host "  ...DOSBox-X listening on 127.0.0.1:$Port" -ForegroundColor Green

# --- start MAME from repo root so -rompath roms and -inipath config resolve ---
Write-Host 'Starting MAME (Husky Hunter)...' -ForegroundColor Yellow
Push-Location $RepoRoot
try {
    & $MameExe hunter -bios 4 -window -ramsize 352K -rompath roms `
        -inipath config -serial null_modem -bitb "socket.127.0.0.1:$Port"
} finally {
    Pop-Location
}

Write-Host 'MAME exited.' -ForegroundColor Cyan
Write-Host 'DOSBox-X is still running -- close it manually when done.' -ForegroundColor Cyan
