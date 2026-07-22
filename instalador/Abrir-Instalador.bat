@echo off
REM Abre o instalador visual S.I.L. (clique duplo)
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Abrir-Instalador.ps1"
if errorlevel 1 pause
