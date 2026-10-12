@echo off
setlocal EnableExtensions
chcp 65001 >nul
title Név és rendelésszám másoló telepítés
set "INSTALL_DIR=D:\3d lámpa\Photoshop és Illustrator scriptek"
set "SOURCE=%~dp0name - number copy.exe"
set "TARGET=%INSTALL_DIR%\name - number copy.exe"
if not exist "%SOURCE%" (
  echo HIBA: Az EXE nincs a BAT mellett.
  pause
  exit /b 2
)
if not exist "%INSTALL_DIR%\" (
  echo HIBA: Nem található a célmappa: "%INSTALL_DIR%"
  pause
  exit /b 3
)
if exist "%TARGET%" (
  for /f %%T in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss_fff"') do set "STAMP=%%T"
  copy /B /Y "%TARGET%" "%TARGET%.backup_%STAMP%" >nul
  if errorlevel 1 (
    echo HIBA: Nem sikerült biztonsági mentést készíteni. Nem írtam felül a programot.
    pause
    exit /b 4
  )
)
copy /B /Y "%SOURCE%" "%TARGET%" >nul
if errorlevel 1 (
  echo HIBA: Nem sikerült felülírni az EXE-t. Ellenőrizd, hogy nem fut-e.
  pause
  exit /b 5
)
echo.
echo KÉSZ. A másoló frissítve: "%TARGET%"
echo A régi EXE biztonsági másolatban megmaradt.
pause
endlocal