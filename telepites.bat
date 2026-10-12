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
if "%INTERACTIVE%"=="0" goto :CONFIRMED
rem Elobb a felhasznalo kivalasztotta a celmappat.
rem A gepszintu telepites admin gyerekben fut, a CDP teszt viszont
rem UTANA a telepitot indito NEM emelt jogosultsagu felhasznalonal.
if "%NNC_TEST_SKIP_LAUNCH%"=="1" goto :INSTALL_FILES
fltmc >nul 2>&1
if not errorlevel 1 goto :INSTALL_FILES
echo [INFO] Egy Windows UAC engedely kell a kozos inditoikonok telepitesehez.
set "NNC_INSTALLER_SELF=%~f0"
set "NNC_INSTALLER_DEST=%INSTALL_DIR%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=Start-Process -FilePath $env:NNC_INSTALLER_SELF -ArgumentList ([char]34 + $env:NNC_INSTALLER_DEST + [char]34 + ' /elevated-child') -Verb RunAs -Wait -PassThru; exit $p.ExitCode"
if errorlevel 1 goto :ELEVATION_FAIL
goto :VERIFY_BROWSER

:INSTALL_FILES
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
call :COPY_SCRIPT "%SCRIPT_SETUP%" "%INSTALL_DIR%\setup_browser.ps1"
if errorlevel 1 goto :SCRIPT_FAIL
call :COPY_SCRIPT "%SCRIPT_START%" "%INSTALL_DIR%\start_opencart_browser.ps1"
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
rem A BAT-ot mar adminisztratorkent inditottak. A bongeszot nem
rem nyithatjuk meg emelt jogosultsagokkal. Ellenorizzuk a MEGLEVO CDP-t.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_DIR%\start_opencart_browser.ps1" -Browser Auto -CheckOnly
if errorlevel 1 goto :NEED_NORMAL_LAUNCH
echo [OK] A CDP mar fut es elerheto.
goto :SUCCESS

:NEED_NORMAL_LAUNCH
echo [HIBA] A gepi fajlok felkerultek, de a CDP inditasa meg NEM ellenorzott.
echo [INFO] A BAT-ot NORMAL dupla kattintassal futtasd, ne jobb klikk/Run as admin.
echo [INFO] A telepito magatol ker majd UAC engedelyt, es normal
echo [INFO] felhasznalokent ellenorzi a bongeszo valodi mukodeset.
goto :FAIL

:COPY_SCRIPT
rem Nem irjuk felul ugyanazzal az utvonallal sajat magat.
if /I "%~f1"=="%~f2" exit /b 0
if exist "%~2" (
    copy /B /Y "%~2" "%~2.backup_%RANDOM%_%RANDOM%" >nul
    if errorlevel 1 exit /b 1
)
copy /B /Y "%~1" "%~2" >nul
if errorlevel 1 exit /b 1
fc /B "%~1" "%~2" >nul
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