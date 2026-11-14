@echo off
rem ============================================================
rem  BOTICAS FELICIDAD - Enciende todo con un solo doble clic:
rem  1) MySQL  2) Backend (Cloud Functions)  3) Celular virtual  4) App
rem ============================================================
title Boticas Felicidad - Iniciando
set "RAIZ=%~dp0"
set "SDK=%LOCALAPPDATA%\Android\Sdk"
set "ADB=%SDK%\platform-tools\adb.exe"
set "API=http://127.0.0.1:5001/nortfarma-a7928/us-central1"

echo [1/4] Base de datos MySQL...
powershell -NoProfile -Command "if (Get-NetTCPConnection -LocalPort 3306 -State Listen -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }"
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -FilePath 'C:\Users\diego\mysql-portable\mysql-8.4.11-winx64\bin\mysqld.exe' -ArgumentList '--defaults-file=\"C:\Users\diego\mysql-portable\my.ini\"' -WindowStyle Hidden"
  echo       encendida.
) else (
  echo       ya estaba encendida.
)

echo [2/4] Backend...
powershell -NoProfile -Command "if (Get-NetTCPConnection -LocalPort 5001 -State Listen -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }"
if errorlevel 1 (
  start "Backend Boticas Felicidad - NO CERRAR" /min cmd /k "%RAIZ%backend_nodejs\iniciar_emulador.bat"
)
echo       esperando a que responda (la primera vez tarda 1 o 2 minutos)...
:esperar_api
curl -s -m 5 "%API%/salud" | find "ok" >nul
if errorlevel 1 (
  timeout /t 3 /nobreak >nul
  goto esperar_api
)
echo       listo.

rem Despierta las funciones en segundo plano: la primera llamada a cada una es lenta.
for %%f in (obtenerPerfil obtenerCategorias consultarCatalogo obtenerProducto misPedidos obtenerPedido validarCarrito listarDirecciones obtenerBoticas obtenerUbigeos cotizarEnvio registrarPedido bandejaPedidos misEntregas resumenAdmin) do (
  start "" /b curl -s -m 90 -o nul -X POST -H "Content-Type: application/json" -d "{\"data\":{}}" "%API%/%%f"
)

echo [3/4] Celular virtual...
tasklist /FI "IMAGENAME eq qemu-system-x86_64.exe" | find /I "qemu" >nul
if errorlevel 1 start "" "%SDK%\emulator\emulator.exe" -avd Medium_Phone_API_37.0
"%ADB%" wait-for-device
:esperar_celular
for /f "delims=" %%b in ('"%ADB%" shell getprop sys.boot_completed 2^>nul') do set "LISTO=%%b"
if not "%LISTO%"=="1" (
  timeout /t 3 /nobreak >nul
  goto esperar_celular
)
rem Pantalla siempre encendida mientras se usa.
"%ADB%" shell svc power stayon true >nul 2>&1
"%ADB%" shell input keyevent 224 >nul 2>&1
"%ADB%" shell wm dismiss-keyguard >nul 2>&1
echo       listo.

echo [4/4] Abriendo la app (la primera vez tarda 1 o 2 minutos)...
echo.
echo   NO CIERRES esta ventana ni la del Backend mientras uses la app.
echo   Para apagar todo: doble clic en APAGAR_TODO.bat
echo.
title Boticas Felicidad - App (no cerrar)
cd /d "%RAIZ%app_flutter"
call flutter run -d emulator-5554 --dart-define-from-file=config/claves.json
pause