@echo off
REM Instalador visual S.I.L. - execute como Administrador se possivel
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Abrir-Instalador.ps1"
set ERR=%ERRORLEVEL%
if not "%ERR%"=="0" (
  echo.
  echo Falha ao abrir o instalador. Codigo %ERR%
  if exist "%~dp0instalador_erro.txt" type "%~dp0instalador_erro.txt"
  pause
)
exit /b %ERR%
