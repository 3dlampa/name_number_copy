#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$InstallDir, [string]$TestRoot = '')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'installer_common.ps1')
$InstallDir = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
if ($InstallDir -eq [IO.Path]::GetPathRoot($InstallDir).TrimEnd('\')) { throw 'Meghajto gyokeret nem lehet eltavolitasi celkent hasznalni.' }
if ((Get-Item -LiteralPath $InstallDir).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Atiranyitott mappabol nem torlunk.' }
$manifestFile = Join-Path $InstallDir 'installation_manifest.json'
$manifest = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.Product -ne 'NameNumberCopy' -or [IO.Path]::GetFullPath([string]$manifest.InstallDir).TrimEnd('\') -ne $InstallDir) {
    throw 'Hianyzik vagy nem ehhez a mappahoz tartozik a telepitesi jegyzek.'
}
$locations = Get-InstallerLocations $TestRoot
foreach ($directory in @($locations.Desktop, $locations.Menu)) {
    foreach ($browser in @('Brave','Chrome','Edge')) {
        Remove-OwnedShortcut (Join-Path $directory "OpenCart - $browser.lnk") $InstallDir
    }
}
Remove-OwnedShortcut (Join-Path $locations.Startup 'OpenCart Rendelesmasolo - bongeszoinditas.lnk') $InstallDir
$uninstallLink = Join-Path $locations.Menu 'Nev es rendelesszam masolo eltavolitasa.lnk'
if (Test-Path -LiteralPath $uninstallLink -PathType Leaf) {
    $link = (New-Object -ComObject WScript.Shell).CreateShortcut($uninstallLink)
    if ($link.TargetPath -eq (Join-Path $InstallDir 'eltavolitas.bat')) { Remove-Item -LiteralPath $uninstallLink -Force }
}
# Fixed allowlist, no recursive deletion and no paths supplied by the manifest.
foreach ($name in @('name - number copy.exe','opencart_browser_config.json','setup_browser.ps1','start_opencart_browser.ps1',
    'elevate_installer.ps1','installer_common.ps1','VERSION','HASZNALATI_FELTETELEK.txt','eltavolitas.bat','uninstall.ps1')) {
    $target = [IO.Path]::GetFullPath((Join-Path $InstallDir $name))
    if (-not $target.StartsWith($InstallDir + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Ervenytelen eltavolitasi fajl.' }
    if (Test-Path -LiteralPath $target -PathType Leaf) { Remove-Item -LiteralPath $target -Force -ErrorAction Stop }
}
Remove-Item -LiteralPath $manifestFile -Force
# Leave an empty menu directory if another program owns files there; never recurse.
if ((Test-Path -LiteralPath $locations.Menu) -and @(Get-ChildItem -LiteralPath $locations.Menu -Force).Count -eq 0) {
    Remove-Item -LiteralPath $locations.Menu -Force
}
Write-Host '[OK] A masolo, a sajat inditoikonok es az automatikus inditas eltavolitva.'
Write-Host '[INFO] A bongeszok, bejelentkezesek es bongeszoprofilok megmaradtak.'
Write-Host '[INFO] Zard be a nyitott OpenCart-bongeszot. A normal bongeszoikonnal a szokasos profil indul, CDP nelkul.'
Write-Host '[INFO] A megtartott sajat adatok: %LOCALAPPDATA%\NameNumberCopy\BrowserProfiles es esetleges regi OpenCart*Debug profilok.'
