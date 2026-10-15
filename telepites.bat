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
set "DEFAULT_DIR=C:\Scripts"
set "INTERACTIVE=1"
set "INSTALL_DIR="

if not exist "%SOURCE%" goto :MISSING_SOURCE
if not exist "%SCRIPT_SETUP%" goto :MISSING_SCRIPTS
if not exist "%SCRIPT_START%" goto :MISSING_SCRIPTS
if not exist "%~dp0elevate_installer.ps1" goto :MISSING_SCRIPTS
if not exist "%~dp0installer_common.ps1" goto :MISSING_SCRIPTS
if not exist "%~dp0uninstall.ps1" goto :MISSING_SCRIPTS
if not exist "%~dp0eltavolitas.bat" goto :MISSING_SCRIPTS
if not exist "%~dp0HASZNALATI_FELTETELEK.txt" goto :MISSING_SCRIPTS
if not exist "%~dp0VERSION" goto :MISSING_SCRIPTS

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
echo MUKODES: helyi OpenCart-nev/rendelesszam olvasasa, masolas a vagolapra.
echo TELEPITES: EXE es sajat scriptek; kozos Asztal/Start menu ikonok; nincs backup.
echo BONGESZO: Brave meglevo normal profil VAGY kulon OpenCart-profil; helyi CDP 9222/9223.
echo Normal Brave-profilnal a regi belepesek megmaradnak; mas helyi program is elerheti a profil lapjait.
echo A Brave-et nem zarom be. Az elso atallashoz minden Brave-ablakot neked kell bezarnod.
echo Google ujraazonositast nem tudunk megakadalyozni. Chrome/Edge kulon profilja megmarad.
echo Nincs kulso adatkuldes, telemetria, programletoltes vagy vedelmi beallitasmodositas.
echo Admin inditasnal ideiglenes, normal jogu Windows-feladat indul, majd torlodik.
echo Eltavolitas: eltavolitas.bat. Bongeszok es profilok megmaradnak.
echo Reszletes tajekoztato: "%~dp0HASZNALATI_FELTETELEK.txt"
if /I "%~2"=="/elevated-child" goto :CHECK_ELEVATION
set "NNC_AUTOSTART=Off"
set "NNC_BRAVE_PROFILE=Existing"
if /I "%~2"=="/autostart:on" set "NNC_AUTOSTART=On"
if /I "%~3"=="/brave:isolated" set "NNC_BRAVE_PROFILE=Isolated"
if "%INTERACTIVE%"=="0" goto :CHECK_ELEVATION
echo.
if exist "%TARGET%" echo [INFO] A meglevo fajlok backup nelkul frissulnek.
set "ANSWER="
set /p "ANSWER=Automatikus bongeszoinditas MINDEN felhasznalonal bejelentkezeskor? (I/N, Enter=N): "
if /I "%ANSWER%"=="I" set "NNC_AUTOSTART=On"
set "ANSWER="
set /p "ANSWER=Meglevo NORMAL Brave-profilt es belepeseket hasznaljam? (I/N, Enter=I): "
if /I "%ANSWER%"=="N" set "NNC_BRAVE_PROFILE=Isolated"
echo Valasztott Brave-profil: %NNC_BRAVE_PROFILE%
echo Valasztott automatikus inditas: %NNC_AUTOSTART%
set "ANSWER="
set /p "ANSWER=Jovahagyod a fenti telepitest/frissitest? (I/N): "
if /I not "%ANSWER%"=="I" goto :CANCELLED
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
if not exist "%INSTALL_DIR%\" mkdir "%INSTALL_DIR%" >nul 2>&1
if not exist "%INSTALL_DIR%\" goto :CREATE_DIR_FAIL

rem A telepito elejen semmit sem modositunk a bongeszoikonokon.
rem Az EXE staging fajlon keresztul cserelodik; nem keszul backup.
if /I "%SOURCE%"=="%TARGET%" goto :INSTALL_SCRIPTS
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

set "COPY_SOURCE=%~dp0elevate_installer.ps1"
set "COPY_TARGET=%INSTALL_DIR%\elevate_installer.ps1"
call :COPY_SCRIPT
if errorlevel 1 goto :SCRIPT_FAIL
set "COPY_SOURCE=%~dp0installer_common.ps1"
set "COPY_TARGET=%INSTALL_DIR%\installer_common.ps1"
call :COPY_SCRIPT
if errorlevel 1 goto :SCRIPT_FAIL
set "COPY_SOURCE=%~dp0uninstall.ps1"
set "COPY_TARGET=%INSTALL_DIR%\uninstall.ps1"
call :COPY_SCRIPT
if errorlevel 1 goto :SCRIPT_FAIL
set "COPY_SOURCE=%~dp0eltavolitas.bat"
set "COPY_TARGET=%INSTALL_DIR%\eltavolitas.bat"
call :COPY_SCRIPT
if errorlevel 1 goto :SCRIPT_FAIL
set "COPY_SOURCE=%~dp0HASZNALATI_FELTETELEK.txt"
set "COPY_TARGET=%INSTALL_DIR%\HASZNALATI_FELTETELEK.txt"
call :COPY_SCRIPT
if errorlevel 1 goto :SCRIPT_FAIL
set "COPY_SOURCE=%~dp0VERSION"
set "COPY_TARGET=%INSTALL_DIR%\VERSION"
call :COPY_SCRIPT
if errorlevel 1 goto :SCRIPT_FAIL

echo [INFO] Brave/Chrome/Edge gepszintu felismerese es beallitasa...
rem A tesztparameterek kizarolag a CI tesztkornyezetben aktivak.
if "%NNC_TEST_SKIP_LAUNCH%"=="1" goto :SETUP_TEST
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_DIR%\setup_browser.ps1" -InstallDir "%INSTALL_DIR%" -AutoStart "%NNC_AUTOSTART%" -BraveProfileMode "%NNC_BRAVE_PROFILE%"
if errorlevel 1 goto :BROWSER_FAIL
if /I "%~2"=="/elevated-child" goto :MACHINE_STAGE_SUCCESS
goto :VERIFY_ADMIN

:MACHINE_STAGE_SUCCESS
echo [OK] Gepszintu telepites sikeres. Normal felhasznaloi CDP teszt folytatodik.
endlocal & exit /b 0

:SETUP_TEST
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_DIR%\setup_browser.ps1" -InstallDir "%INSTALL_DIR%" -AutoStart "%NNC_AUTOSTART%" -BraveProfileMode "%NNC_BRAVE_PROFILE%" -BravePath "%NNC_TEST_BRAVE_PATH%" -ChromePath "%NNC_TEST_CHROME_PATH%" -EdgePath "%NNC_TEST_EDGE_PATH%" -TestRoot "%NNC_TEST_ROOT%" -SkipLaunch
if errorlevel 1 goto :BROWSER_FAIL
goto :SUCCESS

:VERIFY_BROWSER
echo [INFO] Valodi bongeszoinditas NORMAL felhasznalokent es CDP teszt...
"%INSTALL_DIR%\name - number copy.exe" --start-browser Auto
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
copy /B /Y "%COPY_SOURCE%" "%COPY_TARGET%" >nul
if errorlevel 1 exit /b 1
fc /B "%COPY_SOURCE%" "%COPY_TARGET%" >nul
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
echo [HIBA] A fajlok telepitve lehetnek, de a bongeszo/CDP kapcsolat NINCS igazolva.
echo [INFO] Kattints normal felhasznalokent az OpenCart - Brave/Chrome/Edge Asztal-ikonra.
echo [INFO] Ha ott sem indul, a lenti naplo mutatja az inditas es a CDP ellenorzes eredmenyet.
echo [INFO] Reszletes naplo: %%TEMP%%\name_number_copy_browser.log
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
echo [INFO] Backup nem keszul; a korabbi telepitobackupok eltavolitva.
echo [INFO] Automatikus bongeszoinditas: %NNC_AUTOSTART% ^(minden felhasznalonak^).
echo [INFO] Eltavolitas: "%INSTALL_DIR%\eltavolitas.bat"
echo [INFO] A kozos Asztalon es Start menuben letrejottek az OpenCart - Brave/Chrome/Edge ikonok.
echo [INFO] Brave-profil: %NNC_BRAVE_PROFILE%; minden felhasznalo sajat belepeseivel.
echo [INFO] Ha a Brave mar futott, zard be minden ablakat, es inditsd az OpenCart - Brave ikont.
if "%INTERACTIVE%"=="1" pause
endlocal & exit /b 0
:FAIL
echo Telepites megszakitva.
if "%INTERACTIVE%"=="1" pause
endlocal & exit /b 1
