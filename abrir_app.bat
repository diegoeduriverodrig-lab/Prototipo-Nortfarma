@echo off
rem ============================================================
rem  Abre el celular virtual (emulador) y la app Boticas Felicidad.
rem  Antes: iniciar_mysql.bat y backend_nodejs\iniciar_emulador.bat
rem ============================================================
title Boticas Felicidad - App
set "SDK=%LOCALAPPDATA%\Android\Sdk"
set "ADB=%SDK%\platform-tools\adb.exe"

tasklist /FI "IMAGENAME eq qemu-system-x86_64.exe" | find /I "qemu" >nul
if errorlevel 1 (
  echo Abriendo el celular virtual...
  start "" "%SDK%\emulator\emulator.exe" -avd Medium_Phone_API_37.0
) else (
  echo El celular virtual ya estaba abierto.
)

echo Esperando a que el celular termine de encender...
"%ADB%" wait-for-device
:esperar
for /f "delims=" %%b in ('"%ADB%" shell getprop sys.boot_completed 2^>nul') do set "LISTO=%%b"
if not "%LISTO%"=="1" (
  timeout /t 3 /nobreak >nul
  goto esperar
)

echo Celular listo. Abriendo la app (la primera vez tarda 1 o 2 minutos)...
echo.
echo  Con esta ventana abierta puedes pulsar:  r = recargar cambios   q = cerrar la app
echo.
cd /d "%~dp0app_flutter"
call flutter run -d emulator-5554 --dart-define-from-file=config/claves.json
pause