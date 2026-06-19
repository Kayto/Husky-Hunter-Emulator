@echo off
REM LaunchHunter-Term.bat - Launch Hunter MAME with terminal bridge (single-window)
REM By Kayto 04/05/2026
REM Licensed under the MIT License. See LICENSE file for details.
REM =============================================================
REM  Launch Hunter MAME <-> Terminal bridge (single-window, all-cmd)
REM  - Starts Python TCP relay (serial_bridge.py) silently via pythonw
REM  - Auto-launches Tera Term against the relay
REM  - Runs MAME in this window (waits for it)
REM  - On MAME exit, locates the bridge via wmic (CommandLine tag)
REM    and kills it.
REM
REM  No PowerShell required. Single foreground cmd window.
REM =============================================================
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%\..") do set "MAME_DIR=%%~fI"
for %%I in ("%SCRIPT_DIR%\..\..\..\..") do set "REPO_ROOT=%%~fI"

set "MAME_PORT=5706"
set "TERM_PORT=5707"

set "PYEXE=%REPO_ROOT%\.venv\Scripts\python.exe"
if not exist "%PYEXE%" set "PYEXE=python"
set "PYWEXE=%REPO_ROOT%\.venv\Scripts\pythonw.exe"
if not exist "%PYWEXE%" set "PYWEXE=pythonw"

set "BRIDGE=%MAME_DIR%\scripts\serial_bridge.py"
set "MAMEEXE=%MAME_DIR%\output\runtime\sdlhunter.exe"
set "BRIDGE_TAG=husky_bridge_marker"

if not exist "%BRIDGE%"  ( echo MISSING: %BRIDGE%  & pause & exit /b 1 )
if not exist "%MAMEEXE%" ( echo MISSING: %MAMEEXE% & pause & exit /b 1 )

echo ============================================================
echo   Hunter MAME ^<-^> Terminal bridge
echo ============================================================
echo   bridge ports : MAME=%MAME_PORT%  terminal=%TERM_PORT%
echo   Tera Term INI: TERATERM-hunter-mame.INI (raw TCP, port %TERM_PORT%)
echo.
echo   What this launcher does:
echo     1. Starts the TCP relay (silent, runs as pythonw.exe).
echo     2. Opens Tera Term against 127.0.0.1:%TERM_PORT%.
echo     3. Launches MAME (Husky Hunter, BIOS 4, 352K RAM).
echo     4. When MAME exits, the relay is stopped automatically.
echo.
echo   Tips:
echo     * Type into the Tera Term window to send keys to the Hunter.
echo     * To quit cleanly: close the MAME window (Esc, then close).
echo     * If keys don't appear, make sure Tera Term loaded the
 echo       bundled INI (Setup ^> Save setup should show ...mame.INI).
echo     * BGFX warning from MAME is harmless (falls back to OpenGL).
echo ============================================================
echo.

REM --- start the Python relay silently (pythonw, no console window) ---
echo Starting TCP bridge (silent)...
start "" /B "%PYWEXE%" "%BRIDGE%" --mame-port %MAME_PORT% --term-port %TERM_PORT% --tag %BRIDGE_TAG%

REM --- wait up to ~10s for both listeners to come up ---
set /a tries=0
:waitloop
set "READY1="
set "READY2="
for /f "tokens=*" %%L in ('netstat -an ^| findstr /C:":%MAME_PORT% " ^| findstr /I "LISTENING"') do set "READY1=1"
for /f "tokens=*" %%L in ('netstat -an ^| findstr /C:":%TERM_PORT% " ^| findstr /I "LISTENING"') do set "READY2=1"
if defined READY1 if defined READY2 goto :ready
set /a tries+=1
if %tries% GEQ 40 goto :notready
>nul timeout /t 1 /nobreak
goto :waitloop

:notready
echo Bridge did not start listening on %MAME_PORT% / %TERM_PORT%.
call :killbridge
pause
exit /b 1

:ready
echo   ...bridge listening on 127.0.0.1:%MAME_PORT% (MAME) and 127.0.0.1:%TERM_PORT% (terminal)
echo.

REM --- auto-launch Tera Term (inline) ---
set "TT_INI=%MAME_DIR%\config\TERATERM-hunter-mame.INI"
set "TT="
for %%P in (
  "C:\Program Files (x86)\teraterm5\ttermpro.exe"
  "C:\Program Files\teraterm5\ttermpro.exe"
  "C:\Program Files (x86)\teraterm\ttermpro.exe"
  "C:\Program Files\teraterm\ttermpro.exe"
) do if exist %%~P set "TT=%%~P"

if defined TT (
    if exist "%TT_INI%" (
        echo Starting Tera Term...
        start "" "%TT%" /F="%TT_INI%" /T=1 /TELNET=0 127.0.0.1:%TERM_PORT%
    ) else (
        echo TERATERM-hunter-mame.INI not found at %TT_INI%
        echo   Connect manually: TCP/IP Host=127.0.0.1 Port=%TERM_PORT% Service=Other
    )
) else (
    echo ttermpro.exe not found in standard locations.
    echo   Connect manually: TCP/IP Host=127.0.0.1 Port=%TERM_PORT% Service=Other
)
echo.

REM --- start MAME (foreground; we wait for it) ---
echo Starting MAME (Husky Hunter)...
pushd "%MAME_DIR%"
"%MAMEEXE%" hunter -bios 4 -window -ramsize 352K -rompath roms -inipath config -serial null_modem -bitb socket.127.0.0.1:%MAME_PORT%
popd

REM --- cleanup: tear down the bridge ---
echo.
echo Stopping bridge...
call :killbridge
echo Done. (Press any key to close this window.)
pause >nul
endlocal
exit /b 0

:killbridge
for /f "skip=1 tokens=1" %%P in ('wmic process where "Name='pythonw.exe' and CommandLine like '%%%BRIDGE_TAG%%%'" get ProcessId 2^>nul') do (
    if not "%%P"=="" taskkill /PID %%P /F >nul 2>&1
)
exit /b 0
