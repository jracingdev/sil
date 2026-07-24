@echo off
REM Instalador visual S.I.L. - preferir o .exe (pede UAC); fallback no .ps1
cd /d "%~dp0"
if exist "%~dp0SIL-Instalador.exe" (
  start "" "%~dp0SIL-Instalador.exe" %*
  exit /b 0
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Abrir-Instalador.ps1" %*
set ERR=%ERRORLEVEL%
if not "%ERR%"=="0" (
  echo.
  echo Falha ao abrir o instalador. Codigo %ERR%
  if exist "%~dp0instalador_erro.txt" type "%~dp0instalador_erro.txt"
  pause
)
exit /b %ERR%
