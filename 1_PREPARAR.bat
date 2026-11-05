@echo off
setlocal
cd /d "%~dp0"
echo Preparando el laboratorio 3D de prueba...
if exist ".venv\Scripts\python.exe" goto deps
py -3.13 -c "import sys; assert sys.maxsize > 2**32" >nul 2>&1
if not errorlevel 1 goto py313
py -3.12 -c "import sys; assert sys.maxsize > 2**32" >nul 2>&1
if not errorlevel 1 goto py312
py -3.11 -c "import sys; assert sys.maxsize > 2**32" >nul 2>&1
if not errorlevel 1 goto py311
python -c "import sys; assert sys.version_info[:2] in [(3,11),(3,12),(3,13)] and sys.maxsize > 2**32" >nul 2>&1
if not errorlevel 1 goto pythonpath
echo Necesitas Python 3.13, 3.12 o 3.11 de 64 bits.
pause
exit /b 1
:py313
py -3.13 -m venv .venv
goto checkvenv
:py312
py -3.12 -m venv .venv
goto checkvenv
:py311
py -3.11 -m venv .venv
goto checkvenv
:pythonpath
python -m venv .venv
:checkvenv
if errorlevel 1 goto error
:deps
".venv\Scripts\python.exe" -m pip install --upgrade pip
if errorlevel 1 goto error
".venv\Scripts\python.exe" -m pip install -r requirements.txt
if errorlevel 1 goto error
".venv\Scripts\python.exe" prueba_camara.py --check
if errorlevel 1 goto error
".venv\Scripts\python.exe" preparar.py
if errorlevel 1 goto error
echo.
echo Preparado. Abre 2_PROBAR_LAB3D.bat.
pause
exit /b 0
:error
echo.
echo No se completo la preparacion. Conserva el mensaje de error de arriba.
pause
exit /b 1
