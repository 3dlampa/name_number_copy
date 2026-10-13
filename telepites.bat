@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title Nev es rendelesszam masolo - teljes telepites

rem name - number copy.exe, setup_browser.ps1, start_opencart_browser.ps1
rem KOZOS kicsomagolt mappabol indul, telepitest kovetoen automatikus
rem Brave/Chrome felismeres, CDP-profil, 9222/9223 port es login autostart.
set "SOURCE=%~dp0name - number copy.exe"
set "SCRIPT_SETUP=%~dp0setup_browser.ps1"
set "SCRIPT_START=%~dp0start_opencart_browser.ps1"
set "DEFAULT_DIR=D:\3d lámpa\Photoshop és Illustrator scriptek"
set "INTERACTIVE=1"
set "INSTALL_DIR="
set "BACKUP_CREATED="

if not exist "%SOURCE%" goto :MISSING_SOURCE
if not exist "%SCRIPT_SETUP%" goto :MISSING_SCRIPTS
if not exist "%SCRIPT_START%" goto :MISSING_SCRIPTS
if not exist "%~dp0elevate_installer.ps1" goto :MISSING_SCRIPTS

if not "%~1"=="" goto :USE_ARGUMENT

echo.
echo ============================================================
echo    Nev es rendelesszam masolo - teljes telepites
echo ============================================================
echo.
echo Alapertelmezett telepitesi hely:
echo   %DEFAULT_DIR%
echo.
echo Enter = alapertelmezett. Vagy irj be egy masik TELJES utvonalat.
set "USER_DIR="
set /p "USER_DIR=Telepitesi mappa: "
if defined USER_DIR set "INSTALL_DIR=%USER_DIR%"
if not defined INSTALL_DIR set "INSTALL_DIR=%DEFAULT_DIR%"
goto :INSTALL

:USE_ARGUMENT
set "INTERACTIVE=0"
set "INSTALL_DIR=%~1"

:INSTALL
set "INSTALL_DIR=%INSTALL_DIR:"=%"
if not defined INSTALL_DIR goto :INVALID_DIR
for %%I in ("%INSTALL_DIR%") do set "INSTALL_DIR=%%~fI"
for %%I in ("%SOURCE%") do set "SOURCE=%%~fI"
set "TARGET=%INSTALL_DIR%\name - number copy.exe"

echo.
echo Celmappa: "%INSTALL_DIR%"
echo.
rem A mar letezo mappa NEM hiba: udvariasan megerositest kerunk.
if "%INTERACTIVE%"=="0" goto :CHECK_ELEVATION
rem Elobb a felhasznalo kivalasztotta a celmappat.
rem A gepszintu telepites admin gyerekben fut, a CDP teszt viszont
rem UTANA a telepitot indito NEM emelt jogosultsagu felhasznalonal.
:CHECK_ELEVATION
if "%NNC_TEST_SKIP_LAUNCH%"=="1" goto :INSTALL_FILES
fltmc >nul 2>&1
if not errorlevel 1 goto :INSTALL_FILES
echo [INFO] Egy Windows UAC engedely kell a kozos inditoikonok telepitesehez.
rem Az utvonal adat marad a PowerShell es az emelt CMD kozott.
set "NNC_ELEVATE_INSTALLER=%~f0"
set "NNC_ELEVATE_DESTINATION=%INSTALL_DIR%"
set "NNC_ELEVATE_CHILD=1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0elevate_installer.ps1"
if errorlevel 1 goto :ELEVATION_FAIL
goto :VERIFY_BROWSER

:INSTALL_FILES
if "%INTERACTIVE%"=="0" goto :CONFIRMED
if exist "%TARGET%" goto :ASK_UPDATE
if exist "%INSTALL_DIR%\" goto :ASK_FOLDER
goto :CONFIRMED

:ASK_UPDATE
echo [INFO] Itt mar van egy name - number copy.exe.
echo [INFO] Frissites elott biztonsagi masolatot keszitek.
goto :ASK_CONTINUE
:ASK_FOLDER
echo [INFO] Ez a mappa mar letezik. Hasznalhatom a telepiteshez?
:ASK_CONTINUE
set "ANSWER="
set /p "ANSWER=Folytassam? (I/N): "
if /I not "%ANSWER%"=="I" goto :CANCELLED
:CONFIRMED
if not exist "%INSTALL_DIR%\" mkdir "%INSTALL_DIR%" >nul 2>&1
if not exist "%INSTALL_DIR%\" goto :CREATE_DIR_FAIL

rem A telepito elejen semmit sem modositunk a bongeszoikonokon.
rem Az EXE mentese megelzi az esetleges felulirast.
if /I "%SOURCE%"=="%TARGET%" goto :INSTALL_SCRIPTS
if exist "%TARGET%" call :BACKUP_CURRENT
if exist "%TARGET%" if errorlevel 1 goto :BACKUP_FAIL
set "STAGING=%TARGET%.installing_%RANDOM%_%RANDOM%"
copy /B /Y "%SOURCE%" "%STAGING%" >nul
if errorlevel 1 goto :COPY_FAIL
move /Y "%STAGING%" "%TARGET%" >nul
if errorlevel 1 goto :MOVE_FAIL
for %%I in ("%SOURCE%") do set "SOURCE_SIZE=%%~zI"
for %%I in ("%TARGET%") do set "TARGET_SIZE=%%~zI"
if not "%SOURCE_SIZE%"=="%TARGET_SIZE%" goto :VERIFY_FAIL

:INSTALL_SCRIPTS
set "COPY_SOURCE=%SCRIPT_SETUP%"
set "COPY_TARGET=%INSTALL_DIR%\setup_browser.ps1"
call :COPY_SCRIPT
if errorlevel 1 goto :SCRIPT_FAIL
set "COPY_SOURCE=%SCRIPT_START%"
set "COPY_TARGET=%INSTALL_DIR%\start_opencart_browser.ps1"
call :COPY_SCRIPT
if errorlevel 1 goto :SCRIPT_FAIL

echo [INFO] Brave/Chrome/Edge gepszintu felismerese es beallitasa...
rem A tesztparameterek kizarolag a CI tesztkornyezetben aktivak.
if "%NNC_TEST_SKIP_LAUNCH%"=="1" goto :SETUP_TEST
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_DIR%\setup_browser.ps1" -InstallDir "%INSTALL_DIR%"
if errorlevel 1 goto :BROWSER_FAIL
if /I "%~2"=="/elevated-child" goto :MACHINE_STAGE_SUCCESS
goto :VERIFY_ADMIN

:MACHINE_STAGE_SUCCESS
echo [OK] Gepszintu telepites sikeres. Normal felhasznaloi CDP teszt folytatodik.
endlocal & exit /b 0

:SETUP_TEST
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_DIR%\setup_browser.ps1" -InstallDir "%INSTALL_DIR%" -BravePath "%NNC_TEST_BRAVE_PATH%" -ChromePath "%NNC_TEST_CHROME_PATH%" -EdgePath "%NNC_TEST_EDGE_PATH%" -TestRoot "%NNC_TEST_ROOT%" -SkipLaunch
if errorlevel 1 goto :BROWSER_FAIL
goto :SUCCESS

:VERIFY_BROWSER
echo [INFO] Valodi bongeszoinditas NORMAL felhasznalokent es CDP teszt...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_DIR%\start_opencart_browser.ps1" -Browser Auto
if errorlevel 1 goto :BROWSER_FAIL
echo [OK] CDP 9222/9223 bongeszo kapcsolat valoban ellenorizve.
goto :SUCCESS

:VERIFY_ADMIN
rem Mar emelt admin joggal fut a telepito. Egy ideiglenes Windows
rem Task Scheduler InteractiveToken/Limited feladat elinditja a bongeszot
rem a JELENLEG BEJELENTKEZETT felhasznalo normal jogosultsagaival.
echo [INFO] Normal felhasznaloi OpenCart bongeszo automatikus inditasa...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_DIR%\start_opencart_browser.ps1" -Browser Auto -FromElevatedInstaller
if errorlevel 1 goto :BROWSER_FAIL
echo [OK] CDP kapcsolat ellenorizve a bejelentkezett felhasznalo alatt.
goto :SUCCESS

:COPY_SCRIPT
rem Ugyanazt a fajlt nem masoljuk sajat magara; nincs utvonalas CALL ujraertelmezes.
if /I "%COPY_SOURCE%"=="%COPY_TARGET%" exit /b 0
if exist "%COPY_TARGET%" (
    copy /B /Y "%COPY_TARGET%" "%COPY_TARGET%.backup_%RANDOM%_%RANDOM%" >nul
    if errorlevel 1 exit /b 1
)
copy /B /Y "%COPY_SOURCE%" "%COPY_TARGET%" >nul
if errorlevel 1 exit /b 1
fc /B "%COPY_SOURCE%" "%COPY_TARGET%" >nul
if errorlevel 1 exit /b 1
exit /b 0

:BACKUP_CURRENT
set "STAMP="
for /f %%T in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss_fff"') do set "STAMP=%%T"
if not defined STAMP exit /b 1
set "BACKUP_CREATED=%TARGET%.backup_%STAMP%"
copy /B /Y "%TARGET%" "%BACKUP_CREATED%" >nul
if errorlevel 1 exit /b 1
exit /b 0

:CANCELLED
echo [INFO] Megszakitva: nem tortent telepites vagy mappafeluliras.
goto :FAIL
:ELEVATION_FAIL
echo [HIBA] A gepi telepiteshez nem kaptunk adminisztratori jogosultsagot.
echo [INFO] Jobb klikk telepites.bat, majd Futtatas rendszergazdakent.
goto :FAIL

:MISSING_SOURCE
echo [HIBA] A name - number copy.exe nincs a telepito mellett.
goto :FAIL
:MISSING_SCRIPTS
echo [HIBA] A bongeszo-beallito .ps1 fajlok hianyoznak. A TELJES ZIP-et csomagold ki.
goto :FAIL
:INVALID_DIR
echo [HIBA] Ervenytelen telepitesi utvonal.
goto :FAIL
:CREATE_DIR_FAIL
echo [HIBA] Nem sikerult a celmappat letrehozni.
goto :FAIL
:BACKUP_FAIL
echo [HIBA] A regi EXE biztonsagi mentese sikertelen. Nincs feluliras.
goto :FAIL
:COPY_FAIL
echo [HIBA] Az uj EXE masolasa sikertelen.
goto :CLEAN_STAGE
:MOVE_FAIL
echo [HIBA] Az uj EXE csereje sikertelen. Zarj be minden futo masolot.
goto :CLEAN_STAGE
:VERIFY_FAIL
echo [HIBA] A telepitett EXE merete nem egyezik a forrassal.
goto :FAIL
:SCRIPT_FAIL
echo [HIBA] A bongeszoindito scriptek masolasa vagy ellenorzese sikertelen.
goto :FAIL
:BROWSER_FAIL
echo [HIBA] A bongeszo/CDP beallitasa NEM mukodik; a telepites nem sikeres.
echo [INFO] Reszletes naplo: %%TEMP%%\name_number_copy_browser.log
echo [INFO] A regi EXE biztonsagi mentese megmarad.
goto :FAIL
:CLEAN_STAGE
if defined STAGING if exist "%STAGING%" del /F /Q "%STAGING%" >nul 2>&1
goto :FAIL
:SUCCESS
echo.
if "%NNC_TEST_SKIP_LAUNCH%"=="1" (
  echo [OK] CI teszt: telepito es bongeszo-parancsikonok tesztelve.
) else (
  echo [OK] Masoloprogram es bongeszo beallitva, a CDP kapcsolat ELLENORIZVE.
)
echo [OK] EXE: "%TARGET%"
if defined BACKUP_CREATED echo [OK] Regi EXE mentese: "%BACKUP_CREATED%"
echo [INFO] A gep MINDEN Windows-felhasznalojanal automatikusan indul a beallitott bongeszo.
echo [INFO] A kozos Asztalon es Start menuben letrejottek az OpenCart - Brave/Chrome/Edge ikonok.
echo [INFO] A bongeszo minden felhasznalonak sajat, elkulonitett OpenCart-profilt hasznal.
if "%INTERACTIVE%"=="1" pause
endlocal & exit /b 0
:FAIL
echo Telepites megszakitva.
if "%INTERACTIVE%"=="1" pause
endlocal & exit /b 1