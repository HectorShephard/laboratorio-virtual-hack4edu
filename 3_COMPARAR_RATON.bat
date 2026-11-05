@echo off
setlocal
cd /d "%~dp0"
if not exist "runtime\Godot.exe" (
  echo Primero ejecuta 1_PREPARAR.bat.
  pause
  exit /b 1
)
"runtime\Godot.exe" --path godot --rendering-method gl_compatibility -- --mouse
if errorlevel 1 pause
