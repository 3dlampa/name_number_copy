#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InstallDir,
    [string]$BravePath = '',
    [string]$ChromePath = '',
    [string]$TestRoot = '',
    [switch]$SkipLaunch,
    [switch]$ForceNoBrowsers
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InstallDir = [IO.Path]::GetFullPath($InstallDir)
if (-not (Test-Path -LiteralPath (Join-Path $InstallDir 'start_opencart_browser.ps1') -PathType Leaf)) {
    throw 'Hianyzik a bongeszoindito script a telepitesi mappabol.'
}

function Find-Browser([string]$Name, [string]$Override) {
    if ($ForceNoBrowsers) { return $null }
    if ($Override) {
        if (-not (Test-Path -LiteralPath $Override -PathType Leaf)) { throw "Nem letezik: $Override" }
        return (Resolve-Path -LiteralPath $Override).Path
    }
    $exe = if ($Name -eq 'Brave') { 'brave.exe' } else { 'chrome.exe' }
    $subdir = if ($Name -eq 'Brave') { 'BraveSoftware\Brave-Browser\Application\brave.exe' } else { 'Google\Chrome\Application\chrome.exe' }
    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($root in @('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths', 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths')) {
        try {
            $item = Get-Item -LiteralPath "$root\$exe" -ErrorAction Stop
            $v = [string]$item.GetValue('')
            if ($v) { $paths.Add([Environment]::ExpandEnvironmentVariables($v.Trim('"'))) }
        } catch { }
    }
    foreach ($prefix in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
        if ($prefix) { $paths.Add((Join-Path $prefix $subdir)) }
    }
    try {
        $command = Get-Command $exe -ErrorAction Stop
        if ($command.Source) { $paths.Add($command.Source) }
    } catch { }
    foreach ($path in ($paths | Select-Object -Unique)) {
        if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $path).Path
        }
    }
    return $null
}

$braveExe = Find-Browser 'Brave' $BravePath
$chromeExe = Find-Browser 'Chrome' $ChromePath
if (-not $braveExe -and -not $chromeExe) {
    throw 'Nem talalhato telepitett Brave vagy Google Chrome. A bongeszo beallitasa nem tortent meg.'
}

$preferred = 'Brave'
try {
    $default = [string](Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice' -ErrorAction Stop).ProgId
    if ($default -match 'Chrome' -and $chromeExe) { $preferred = 'Chrome' }
    elseif ($default -match 'Brave' -and $braveExe) { $preferred = 'Brave' }
} catch { }
if ($preferred -eq 'Brave' -and -not $braveExe) { $preferred = 'Chrome' }
if ($preferred -eq 'Chrome' -and -not $chromeExe) { $preferred = 'Brave' }

if ($TestRoot) {
    $desktop = Join-Path $TestRoot 'Desktop'
    $startMenu = Join-Path $TestRoot 'StartMenu'
    $startup = Join-Path $TestRoot 'Startup'
    $profileRoot = Join-Path $TestRoot 'Profiles'
} else {
    $desktop = [Environment]::GetFolderPath('DesktopDirectory')
    $startMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'OpenCart Rendelesmasolo'
    $startup = [Environment]::GetFolderPath('Startup')
    $profileRoot = Join-Path $env:LOCALAPPDATA 'NameNumberCopy\BrowserProfiles'
}
foreach ($dir in @($desktop, $startMenu, $startup, $profileRoot)) {
    if (-not $dir) { throw 'Hianyzik egy Windows felhasznaloi mappa.' }
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

$browsers = @{}
foreach ($entry in @(@('Brave', $braveExe, 9222, 'OpenCartBraveDebug'), @('Chrome', $chromeExe, 9223, 'OpenCartChromeDebug'))) {
    $name = [string]$entry[0]
    $exe = [string]$entry[1]
    if (-not $exe) { continue }
    $port = [int]$entry[2]
    $newProfile = Join-Path $profileRoot $name
    $profile = $newProfile
    if (-not $TestRoot) {
        $legacy = Join-Path $env:LOCALAPPDATA ([string]$entry[3] + '\User Data')
        if (Test-Path -LiteralPath $legacy -PathType Container) {
            # A korabbi CDP profil meglevo webshop-bejelentkezeseinek megorzese.
            $profile = $legacy
        }
    }
    New-Item -ItemType Directory -Force -Path $profile | Out-Null
    $browsers[$name] = @{ Exe = $exe; Port = $port; Profile = $profile }
}

$configPath = Join-Path $InstallDir 'opencart_browser_config.json'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    Copy-Item -LiteralPath $configPath -Destination "$configPath.backup_$stamp" -ErrorAction Stop
}
$config = @{ Version = 2; Primary = $preferred; Browsers = $browsers; UpdatedAt = (Get-Date).ToString('o') }
$json = $config | ConvertTo-Json -Depth 8
$tmp = "$configPath.new_$stamp"
[IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
Move-Item -LiteralPath $tmp -Destination $configPath -Force

$wsh = New-Object -ComObject WScript.Shell
$psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$launcher = Join-Path $InstallDir 'start_opencart_browser.ps1'
function Set-LauncherShortcut([string]$path, [string]$Browser, [string]$exe, [bool]$AutoStart = $false) {
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Copy-Item -LiteralPath $path -Destination "$path.backup_$stamp" -ErrorAction Stop
    }
    $link = $wsh.CreateShortcut($path)
    $link.TargetPath = $psExe
    $args = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $launcher + '" -Browser ' + $Browser
    if ($AutoStart) { $args += ' -AutoStart' }
    $link.Arguments = $args
    $link.WorkingDirectory = $InstallDir
    $link.IconLocation = "$exe,0"
    $link.Description = 'OpenCart rendelesmasolo: CDP bongeszoport es elkulonitett profil'
    $link.Save()
}

foreach ($name in ($browsers.Keys | Sort-Object)) {
    $exe = [string]$browsers[$name].Exe
    $label = "OpenCart - $name.lnk"
    Set-LauncherShortcut (Join-Path $startMenu $label) $name $exe
    Set-LauncherShortcut (Join-Path $desktop $label) $name $exe
}
$startupLink = Join-Path $startup 'OpenCart Rendelesmasolo - bongeszoinditas.lnk'
Set-LauncherShortcut $startupLink 'Auto' ([string]$browsers[$preferred].Exe) $true

if (-not $SkipLaunch) {
    # Telepiteskor is inditsuk el, es ellenorizzuk, hogy a CDP valoban elerheto.
    & $launcher -Browser Auto -AutoStart
}

Write-Host "[OK] Beallitott bongeszo: $preferred" -ForegroundColor Green
foreach ($name in ($browsers.Keys | Sort-Object)) {
    Write-Host ("[OK] {0}: {1}, port {2}, profil: {3}" -f $name, $browsers[$name].Exe, $browsers[$name].Port, $browsers[$name].Profile)
}
Write-Host "[OK] Automatikus indulasi parancsikon: $startupLink"
Write-Host '[INFO] A normal Brave/Chrome profil, a bongeszo alapertelmezett beallitasai es a taskbar-ikonok valtozatlanok.'