@echo off
setlocal
title Capivara Caos
cd /d "%~dp0"

rem ---- procura o Godot 4.7 (variavel GODOT_EXE, C:\Godot, PATH)
set "GODOT="
if defined GODOT_EXE if exist "%GODOT_EXE%" set "GODOT=%GODOT_EXE%"
if not defined GODOT if exist "C:\Godot\Godot_v4.7.2-stable_win64.exe" set "GODOT=C:\Godot\Godot_v4.7.2-stable_win64.exe"
if not defined GODOT for %%F in (godot.exe Godot.exe) do if not defined GODOT set "GODOT=%%~$PATH:F"
if not defined GODOT (
  echo Nao encontrei o Godot 4.7.
  echo Defina a variavel GODOT_EXE com o caminho do executavel, ou edite este arquivo.
  pause
  exit /b 1
)

rem ---- primeira execucao: importa os recursos (so demora alguns segundos)
if not exist ".godot\imported" (
  echo Preparando a capivara pela primeira vez...
  "%GODOT%" --headless --import --path "%~dp0." --quit >nul 2>&1
)

start "" "%GODOT%" --path "%~dp0."
endlocal
