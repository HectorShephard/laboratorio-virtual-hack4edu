@echo off
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
  echo Primero ejecuta 1_PREPARAR.bat.
  pause
  exit /b 1
)
if not exist "registros" mkdir "registros"
echo Cierra el laboratorio 3D y otras apps que usen la camara.
echo Se abrira la misma prueba 2D que funciono antes.
echo Los mensajes se guardaran en registros\camara_sola.log.
echo Pulsa Q en la ventana de camara para cerrar.
".venv\Scripts\python.exe" -u prueba_camara.py %* > "registros\camara_sola.log" 2>&1
if errorlevel 1 (
  echo La prueba encontro un error:
  type "registros\camara_sola.log"
) else (
  echo La prueba termino. Conserva el registro si necesitas revisarlo.
)
pause
