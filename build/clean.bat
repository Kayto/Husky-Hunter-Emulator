@echo off
setlocal

echo.
echo  F = Full clean
echo      Removes: output\ (binary, DLLs, MAME source tree)
echo               roms\hunter.zip  cfg\  nvram\  config\ui.ini
echo               snap\  sta\  error.log  build.log
echo               HuskyHCOM\hcomw\  HuskyHCOM\hcomw.zip  HuskyHCOM\HSYNC\
echo.
echo  K = Keep HCOM
echo      Same as Full, but keeps the HCOM downloads
echo      (HuskyHCOM\hcomw\, hcomw.zip, HSYNC\) so they need not be re-downloaded.
echo.
echo  B = Build cleanup only  (MAME source tree only, ~12 GB)
echo      Use this if you answered N to the cleanup prompt during the build.
echo.
echo  N = Abort
echo.
echo  Your EPROM*.BIN files in roms\ will NOT be removed by any option.
echo  You will be asked "Are you sure?" before anything is deleted.
echo.
choice /C FKBN /M "Select:"
if errorlevel 4 (
    echo Aborted.
    pause
    exit /b 0
)
if errorlevel 3 (
    powershell.exe -NoLogo -ExecutionPolicy Bypass -File "%~dp0clean.ps1" -BuildCleanup
    pause
    exit /b 0
)
if errorlevel 2 (
    powershell.exe -NoLogo -ExecutionPolicy Bypass -File "%~dp0clean.ps1" -KeepHcom
    pause
    exit /b 0
)
powershell.exe -NoLogo -ExecutionPolicy Bypass -File "%~dp0clean.ps1"
pause
