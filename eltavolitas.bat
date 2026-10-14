@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
set "REMOVE_DIR=%~dp0"
if not "%~1"=="" set "REMOVE_DIR=%~1"
for %%I in ("%REMOVE_DIR%\.") do set "REMOVE_DIR=%%~fI"
if /I "%~2"=="/elevated-child" goto :REMOVE
echo.
echo A nev es rendelesszam masolo es sajat inditoikonjai torlodnek.
echo A telepitett bongeszok, a profilok es mas fajlok megmaradnak.
echo Zard be a masolot es az OpenCart-bongeszot az eltavolitas elott.
set "ANSWER="
set /p "ANSWER=Eltavolitod? (I/N): "
if /I not "%ANSWER%"=="I" goto :CANCELLED
fltmc >nul 2>&1
if not errorlevel 1 goto :REMOVE
set "NNC_ELEVATE_INSTALLER=%~f0"
set "NNC_ELEVATE_DESTINATION=%REMOVE_DIR%"
set "NNC_ELEVATE_CHILD=1"
rem Parse the continuation before the child deletes this same BAT file.
(
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0elevate_installer.ps1"
if errorlevel 1 (endlocal & exit /b 1) else (endlocal & exit 0)
)
:REMOVE
rem Finish the dedicated uninstaller CMD process; /b would reread the deleted BAT.
(
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" -InstallDir "%REMOVE_DIR%"
if errorlevel 1 goto :FAIL
endlocal & exit 0
)
:FAIL
echo [HIBA] Az eltavolitas nem teljes. Zarj be minden futo masolot, majd probald ujra.
pause
endlocal & exit /b 1
:CANCELLED
echo [INFO] Megszakitva, nem tortent eltavolitas.
endlocal & exit /b 1
