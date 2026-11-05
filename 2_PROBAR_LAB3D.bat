@echo off
setlocal
cd /d "%~dp0"
if not exist "runtime\Godot.exe" goto prepare
if not exist ".venv\Scripts\python.exe" goto prepare
echo Iniciando la camara directamente desde Python...
echo Los mensajes de arranque apareceran en esta consola.
".venv\Scripts\python.exe" -u iniciar_lab.py %*
if errorlevel 1 pause
exit /b
:prepare
echo Primero ejecuta 1_PREPARAR.bat con internet.
pause
exit /b 1
