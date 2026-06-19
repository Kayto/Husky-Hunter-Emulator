@echo off
setlocal

echo.
echo  F = Full clean
echo      Removes: output\ (binary, DLLs, MAME source tree)
echo               roms\hunter.zip  cfg\  nvram\  config\ui.ini
echo               snap\  sta\  error.log  build.log
echo.
echo  B = Build cleanup only  (MAME source tree only, ~12 GB)
echo      Use this if you answered N to the cleanup prompt during the build.
echo.
echo  N = Abort
echo.
echo  Your EPROM*.BIN files in roms\ will NOT be removed by either option.
echo.
choice /C FBN /M "Select:"
if errorlevel 3 (
    echo Aborted.
    pause
    exit /b 0
)
if errorlevel 2 (
    powershell.exe -NoLogo -ExecutionPolicy Bypass -File "%~dp0clean.ps1" -Force -BuildCleanup
    pause
    exit /b 0
)
powershell.exe -NoLogo -ExecutionPolicy Bypass -File "%~dp0clean.ps1" -Force
pause
