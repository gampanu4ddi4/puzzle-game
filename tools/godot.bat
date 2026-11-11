@echo off
rem Shared launcher used by play.bat and edit.bat.
rem 1. Makes sure Godot 4.7.2 is in .tools\godot (downloads it from the official GitHub release if missing).
rem 2. On the first run after cloning, imports the assets (creates the .godot folder).
rem 3. Starts Godot on this project with the arguments given.
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "GDIR=%ROOT%\.tools\godot"
set "GODOT=%GDIR%\Godot_v4.7.2-stable_win64.exe"
set "GODOT_CONSOLE=%GDIR%\Godot_v4.7.2-stable_win64_console.exe"
set "URL=https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip"

if not exist "%GODOT%" (
  echo Godot 4.7.2 not found in .tools\godot. Downloading from the official release, about 86 MB...
  if not exist "%GDIR%" mkdir "%GDIR%"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%URL%' -OutFile '%GDIR%\godot.zip'; Expand-Archive -Force '%GDIR%\godot.zip' '%GDIR%'; Remove-Item '%GDIR%\godot.zip'"
  if not exist "%GODOT%" (
    echo Download failed. Download Godot 4.7.2 for Windows manually and put Godot_v4.7.2-stable_win64.exe in .tools\godot
    pause
    exit /b 1
  )
)

if not exist "%ROOT%\.godot\imported" (
  echo First run: importing assets. This takes about a minute...
  if exist "%GODOT_CONSOLE%" (
    "%GODOT_CONSOLE%" --headless --path "%ROOT%" --import
  ) else (
    "%GODOT%" --headless --path "%ROOT%" --import
  )
)

start "" "%GODOT%" --path "%ROOT%" %*
