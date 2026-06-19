@echo off
REM LaunchHCOM-MAME.bat - Launch HCOM bridge: DOSBox-X (HCOM.EXE) <-> MAME (Husky Hunter)
REM By Kayto 04/05/2026
REM Licensed under the MIT License. See LICENSE file for details.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0LaunchHCOM-MAME.ps1" %*
