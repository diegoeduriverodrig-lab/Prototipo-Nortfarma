@echo off
rem Inicia la API local (emulador de Cloud Functions) usando Node 24 portatil.
rem Requiere que MySQL este iniciado (C:\Users\diego\mysql-portable\iniciar_mysql.bat).
set "PATH=C:\Users\diego\node24\node-v24.21.0-win-x64;%PATH%"
rem El primer arranque puede tardar (antivirus analizando node_modules).
set "FUNCTIONS_DISCOVERY_TIMEOUT=60"
cd /d "%~dp0"
call firebase emulators:start --only functions