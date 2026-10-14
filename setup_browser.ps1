#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InstallDir,
    [string]$BravePath = '',
    [string]$ChromePath = '',
    [string]$EdgePath = '',
    [string]$TestRoot = '',
    [switch]$SkipLaunch,
    [switch]$ForceNoBrowsers
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Remove-InstallerBackups([string]$Directory, [string[]]$FileNames) {
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { return }
    # Csak sajat fajlnevek es a regi telepito ket ismert suffixe; nincs rekurzio.
    $names = ($FileNames | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $pattern = '^(?:' + $names + ')\.backup_(?:\d{8}_\d{6}_\d{3}|\d+_\d+)$'
    foreach ($file in (Get-ChildItem -LiteralPath $Directory -File -Force -ErrorAction Stop)) {
        if ($file.Name -match $pattern) {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            Write-Host ("[OK] Regi telepitobackup torolve: {0}" -f $file.Name)
        }
    }
}

$InstallDir = [IO.Path]::GetFullPath($InstallDir)
$launcher = Join-Path $InstallDir 'start_opencart_browser.ps1'
if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
    throw 'A start_opencart_browser.ps1 hianyzik. Csomagold ki a teljes ZIP-et.'
}

function Find-Browser([string]$Name, [string]$Override) {
    if ($ForceNoBrowsers) { return $null }
    if ($Override) {
        if (-not (Test-Path -LiteralPath $Override -PathType Leaf)) { throw "Bongeszo nem talalhato: $Override" }
        return (Resolve-Path -LiteralPath $Override).Path
    }
    if ($TestRoot) { return $null } # CI teszt: tilos a host bongeszoit beolvasni
    $exe = switch ($Name) { 'Brave' { 'brave.exe' }; 'Chrome' { 'chrome.exe' }; 'Edge' { 'msedge.exe' } }
    $sub = switch ($Name) {
        'Brave' { 'BraveSoftware\Brave-Browser\Application\brave.exe' }
        'Chrome' { 'Google\Chrome\Application\chrome.exe' }
        'Edge' { 'Microsoft\Edge\Application\msedge.exe' }
    }
    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($root in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths')) {
        try {
            $key = Get-Item -LiteralPath "$root\$exe" -ErrorAction Stop
            $value = [string]$key.GetValue('')
            if ($value) { $paths.Add([Environment]::ExpandEnvironmentVariables($value.Trim('"'))) }
        } catch { }
    }
    foreach ($prefix in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ($prefix) { $paths.Add((Join-Path $prefix $sub)) }
    }
    try {
        $command = Get-Command $exe -ErrorAction Stop
        if ($command.Source) { $paths.Add($command.Source) }
    } catch { }
    foreach ($path in ($paths | Select-Object -Unique)) {
        if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) { return (Resolve-Path -LiteralPath $path).Path }
    }
    return $null
}

$discovered = [ordered]@{
    Brave  = Find-Browser 'Brave' $BravePath
    Chrome = Find-Browser 'Chrome' $ChromePath
    Edge   = Find-Browser 'Edge' $EdgePath
}
$available = @($discovered.Keys | Where-Object { $discovered[$_] })
if ($available.Count -eq 0) {
    throw 'Nem talalhato Brave, Chrome vagy Microsoft Edge. Telepits Chromium-alapu bongeszot, majd futtasd ujra a telepitot.'
}
$preferred = [string]$available[0]

# A telepito SOHA nem a rendszergazda vagy masik konkret felhasznalo
# Desktop/Startup/LOCALAPPDATA konyvtaraba telepit.
if ($TestRoot) {
    $commonDesktop = Join-Path $TestRoot 'PublicDesktop'
    $commonPrograms = Join-Path $TestRoot 'CommonPrograms'
    $commonStartup = Join-Path $TestRoot 'CommonStartup'
} else {
    $commonDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
    $commonPrograms = [Environment]::GetFolderPath('CommonPrograms')
    $commonStartup = [Environment]::GetFolderPath('CommonStartup')
    $commonData = [Environment]::GetFolderPath('CommonApplicationData')
    if (-not $commonData) { $commonData = $env:ProgramData }
    if (-not $commonDesktop -and $env:PUBLIC) { $commonDesktop = Join-Path $env:PUBLIC 'Desktop' }
    if (-not $commonPrograms -and $commonData) { $commonPrograms = Join-Path $commonData 'Microsoft\Windows\Start Menu\Programs' }
    if (-not $commonStartup -and $commonPrograms) { $commonStartup = Join-Path $commonPrograms 'Startup' }
}
$startMenu = if ($commonPrograms) { Join-Path $commonPrograms 'OpenCart Rendelesmasolo' } else { '' }
foreach ($item in @(
    @{ Key = 'Kozos Asztal'; Path = $commonDesktop },
    @{ Key = 'Kozos Start menu'; Path = $startMenu },
    @{ Key = 'Minden felhasznalo Startup'; Path = $commonStartup }
)) {
    if (-not $item.Path) {
        throw ("Nem erheto el: {0}. A rendszergazda jogosultsag vagy a Windows kozosen hasznalt mappainak ellenorzese szukseges." -f $item.Key)
    }
    try {
        New-Item -ItemType Directory -Force -Path $item.Path -ErrorAction Stop | Out-Null
    } catch {
        throw ("Nem hozhato letre a gepi mappa: {0}. Futtasd a telepitot rendszergazdakent. Reszletek: {1}" -f $item.Path, $_.Exception.Message)
    }
}

# A konfiguracio csak gepi bongeszo-utvonalakat tarol. SOHA nem mentunk ide
# felhasznalonevet, user profil utvonalat, jelszot vagy webshop munkamenetet.
$browsers = [ordered]@{}
foreach ($name in $available) {
    $port = if ($name -eq 'Chrome') { 9223 } else { 9222 }
    $browsers[$name] = @{ Exe = [string]$discovered[$name]; Port = $port }
}
$config = @{
    Version = 3
    Scope = 'Machine'
    Primary = $preferred
    Browsers = $browsers
    UpdatedAt = (Get-Date).ToString('o')
}
$configPath = Join-Path $InstallDir 'opencart_browser_config.json'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$tmp = "$configPath.installing_$stamp"
try {
    [IO.File]::WriteAllText($tmp, ($config | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $configPath -Force
} finally {
    if (Test-Path -LiteralPath $tmp -PathType Leaf) { Remove-Item -LiteralPath $tmp -Force }
}

$wsh = New-Object -ComObject WScript.Shell
$psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
function Set-LauncherShortcut([string]$LinkPath, [string]$Browser, [string]$IconExe, [bool]$AutoStart = $false) {
    $link = $wsh.CreateShortcut($LinkPath)
    $link.TargetPath = $psExe
    $args = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $launcher + '" -Browser ' + $Browser
    if ($AutoStart) { $args += ' -AutoStart' }
    $link.Arguments = $args
    $link.WorkingDirectory = $InstallDir
    $link.IconLocation = "$IconExe,0"
    $link.Description = 'OpenCart CDP inditas, minden felhasznalonak, kulon profillal'
    $link.Save()
}

foreach ($name in $available) {
    $label = "OpenCart - $name.lnk"
    Set-LauncherShortcut (Join-Path $commonDesktop $label) $name $discovered[$name]
    Set-LauncherShortcut (Join-Path $startMenu $label) $name $discovered[$name]
}
$startupLink = Join-Path $commonStartup 'OpenCart Rendelesmasolo - bongeszoinditas.lnk'
Set-LauncherShortcut $startupLink 'Auto' $discovered[$preferred] $true

Remove-InstallerBackups $InstallDir @('name - number copy.exe', 'opencart_browser_config.json', 'setup_browser.ps1', 'start_opencart_browser.ps1', 'elevate_installer.ps1')
foreach ($directory in @($commonDesktop, $startMenu)) {
    Remove-InstallerBackups $directory @('OpenCart - Brave.lnk', 'OpenCart - Chrome.lnk', 'OpenCart - Edge.lnk')
}
Remove-InstallerBackups $commonStartup @('OpenCart Rendelesmasolo - bongeszoinditas.lnk')

# Emelt jogosultsagu telepitobol nem inditunk emelt szintu bongeszot.
# Az OpenCart-bongeszo a kovetkezo Windows-bejelentkezesnel, a NORMAL
# felhasznalo jogaval indul a CommonStartup parancsikonbol.
if (-not $SkipLaunch) {
    Write-Host '[INFO] A bongeszo normal felhasznalokent a kovetkezo Windows-bejelentkezesnel indul.'
    Write-Host '[INFO] Most az OpenCart ikonra kattintva is elindithato normal joggal.'
}
Write-Host ("[OK] Gepi telepites: {0}" -f $preferred) -ForegroundColor Green
Write-Host ("[OK] Osszes Windows-felhasznalo inditoja: {0}" -f $commonStartup)
Write-Host '[OK] A bongeszo adatmappaja az inditaskor felhasznalonkent kulon jon letre.'
Write-Host '[INFO] Nincs sajat user/profil vagy OpenCart-bejelentkezes eltarolva a konfiguracioban.'
