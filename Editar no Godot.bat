@echo off
setlocal
cd /d "%~dp0"
set "GODOT="
if defined GODOT_EXE if exist "%GODOT_EXE%" set "GODOT=%GODOT_EXE%"
if not defined GODOT if exist "C:\Godot\Godot_v4.7.2-stable_win64.exe" set "GODOT=C:\Godot\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT for %%F in (godot.exe Godot.exe) do if not defined GODOT set "GODOT=%%~$PATH:F"
if not defined GODOT (
  echo Nao encontrei o Godot 4.7. Defina GODOT_EXE.
  pause
  exit /b 1
)
start "" "%GODOT%" --editor --path "%~dp0."
endlocal
