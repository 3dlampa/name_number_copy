@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title Nev es rendelesszam masolo - telepites

rem A forras EXE mindig a telepito mellett legyen.
set "SOURCE=%~dp0name - number copy.exe"
set "DEFAULT_DIR=D:\3d lámpa\Photoshop és Illustrator scriptek"
set "INTERACTIVE=1"
set "INSTALL_DIR="
set "BACKUP_CREATED="

if not exist "%SOURCE%" goto :MISSING_SOURCE

rem Lehetoseg telepitesre argumentummal (automatizalt tesztekhez is).
rem Pelda: telepites.bat "E:\Scriptek"
if not "%~1"=="" goto :USE_ARGUMENT

echo.
echo ==============================================================
echo     Nev es rendelesszam masolo - telepites
echo ==============================================================
echo.
echo Alapertelmezett telepitesi hely:
echo   %DEFAULT_DIR%
echo.
echo Nyomj Entert a fenti hely elfogadasahoz,
echo vagy add meg a sajat celmappad TELJES eleresi utjat.
echo Pelda: E:\Munka\Scriptek
echo.
set "USER_DIR="
set /p "USER_DIR=Telepitesi mappa: "
if defined USER_DIR set "INSTALL_DIR=%USER_DIR%"
if not defined INSTALL_DIR set "INSTALL_DIR=%DEFAULT_DIR%"
goto :INSTALL

:USE_ARGUMENT
set "INTERACTIVE=0"
set "INSTALL_DIR=%~1"

:INSTALL
rem Az Explorerbol bemasolt idezojeleket is fogadjuk el.
set "INSTALL_DIR=%INSTALL_DIR:"=%"
if not defined INSTALL_DIR goto :INVALID_DIR
for %%I in ("%INSTALL_DIR%") do set "INSTALL_DIR=%%~fI"
for %%I in ("%SOURCE%") do set "SOURCE=%%~fI"
set "TARGET=%INSTALL_DIR%\name - number copy.exe"

echo.
echo Celmappa: "%INSTALL_DIR%"
echo EXE: "%TARGET%"

rem Ha a BAT es az EXE eleve a celmappaban van, ne masoljuk onmagara.
if /I "%SOURCE%"=="%TARGET%" goto :SAME_FILE

rem A valasztott mappa hianya nem hiba; letrehozzuk.
if not exist "%INSTALL_DIR%\" mkdir "%INSTALL_DIR%" >nul 2>&1
if not exist "%INSTALL_DIR%\" goto :CREATE_DIR_FAIL

rem Elobb biztonsagi mentes, csak utana csere.
if exist "%TARGET%" call :BACKUP_CURRENT
if exist "%TARGET%" if errorlevel 1 goto :BACKUP_FAIL

rem A fajl eloszor ideiglenes nev alatt kerul a celmappaba.
rem A regi EXE-t csak a sikeres masolas utan csereljuk le.
set "STAGING=%TARGET%.installing_%RANDOM%_%RANDOM%"
copy /B /Y "%SOURCE%" "%STAGING%" >nul
if errorlevel 1 goto :COPY_FAIL
move /Y "%STAGING%" "%TARGET%" >nul
if errorlevel 1 goto :MOVE_FAIL

rem A celban a forrasfajl meretet ellenorizzuk.
for %%I in ("%SOURCE%") do set "SOURCE_SIZE=%%~zI"
for %%I in ("%TARGET%") do set "TARGET_SIZE=%%~zI"
if not "%SOURCE_SIZE%"=="%TARGET_SIZE%" goto :VERIFY_FAIL

echo.
echo [OK] Sikeres telepites: "%TARGET%"
if defined BACKUP_CREATED echo [OK] Regi EXE mentese: "%BACKUP_CREATED%"
goto :SUCCESS

:BACKUP_CURRENT
set "STAMP="
for /f %%T in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss_fff"') do set "STAMP=%%T"
if not defined STAMP exit /b 1
set "BACKUP_CREATED=%TARGET%.backup_%STAMP%"
copy /B /Y "%TARGET%" "%BACKUP_CREATED%" >nul
if errorlevel 1 exit /b 1
exit /b 0

:MISSING_SOURCE
echo [HIBA] A "name - number copy.exe" nincs a telepito BAT mellett.
goto :FAIL
:INVALID_DIR
echo [HIBA] Nem ervenyes telepitesi utvonal.
goto :FAIL
:CREATE_DIR_FAIL
echo [HIBA] A celmappa nem erheto el es nem hozhato letre.
goto :FAIL
:BACKUP_FAIL
echo [HIBA] A biztonsagi mentes nem sikerult; az eredeti EXE valtozatlan.
goto :FAIL
:COPY_FAIL
echo [HIBA] Nem sikerult az uj EXE-t a celmappaba masolni.
goto :CLEAN_STAGE
:MOVE_FAIL
echo [HIBA] Nem sikerult az EXE csereje. Zarj be minden futo masolot.
goto :CLEAN_STAGE
:VERIFY_FAIL
echo [HIBA] A fajlmeret-ellenorzes nem sikerult. Ellenorizd a celmappat.
goto :FAIL
:CLEAN_STAGE
if defined STAGING if exist "%STAGING%" del /F /Q "%STAGING%" >nul 2>&1
goto :FAIL
:SAME_FILE
echo [OK] Az EXE mar a kivalasztott helyen van. Nem kellett masolni.
goto :SUCCESS
:SUCCESS
if "%INTERACTIVE%"=="1" pause
endlocal & exit /b 0
:FAIL
echo Telepites megszakitva.
if "%INTERACTIVE%"=="1" pause
endlocal & exit /b 1