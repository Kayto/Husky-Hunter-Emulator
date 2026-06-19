# LaunchHunterMAME.ps1 - Launch Husky Hunter in MAME (custom sdl build)
# By Kayto 04/05/2026
# Licensed under the MIT License. See LICENSE file for details.
#
# BIOS 4 = "DEMOS 2.2 9G06h (6 ROMs)" - our verified 6x8K EPROM set
# ramsize 352K = 16K common + 7 x 48K paged banks (matches physical machine)

param(
    [string]$ExtraArgs = ""
)

$mameDir  = Split-Path -Parent $PSScriptRoot   # launchers/ -> repo root
$mame     = Join-Path $mameDir "output\runtime\sdlhunter.exe"
$romPath  = Join-Path $mameDir "roms"
$iniPath  = Join-Path $mameDir "config"
$mameArgs = @("hunter", "-bios", "4", "-window", "-ramsize", "352K", "-rompath", $romPath, "-inipath", $iniPath)
if ($ExtraArgs) { $mameArgs += $ExtraArgs -split " " }

Write-Host "Launching: $mame $($mameArgs -join ' ')"
Push-Location $mameDir
try { & $mame @mameArgs } finally { Pop-Location }
