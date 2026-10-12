#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Auto','Brave','Chrome','Edge')][string]$Browser = 'Auto',
    [switch]$AutoStart,
    [string]$TestUserRoot = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$configPath = Join-Path $PSScriptRoot 'opencart_browser_config.json'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw 'Hianyzik az OpenCart bongeszo konfiguracioja. Futtasd ujra a telepitot.' }
$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
function Find-LocalBrowser([string]$Name) {
    $exe = switch ($Name) { 'Brave' { 'brave.exe' }; 'Chrome' { 'chrome.exe' }; 'Edge' { 'msedge.exe' } }
    $sub = switch ($Name) {
        'Brave' { 'BraveSoftware\Brave-Browser\Application\brave.exe' }
        'Chrome' { 'Google\Chrome\Application\chrome.exe' }
        'Edge' { 'Microsoft\Edge\Application\msedge.exe' }
    }
    $paths = @()
    foreach ($root in @('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths')) {
        try {
            $key = Get-Item -LiteralPath "$root\$exe" -ErrorAction Stop
            $v = [string]$key.GetValue('')
            if ($v) { $paths += [Environment]::ExpandEnvironmentVariables($v.Trim('"')) }
        } catch { }
    }
    foreach ($base in @($env:LOCALAPPDATA, $env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ($base) { $paths += (Join-Path $base $sub) }
    }
    foreach ($p in ($paths | Select-Object -Unique)) {
        if ($p -and (Test-Path -LiteralPath $p -PathType Leaf)) { return (Resolve-Path -LiteralPath $p).Path }
    }
    return $null
}
if ($Browser -eq 'Auto') {
    # Minden fioknal kulon automatikus felismeres: nem az installer admin fiokjatol fugg.
    foreach ($name in @('Brave','Chrome','Edge')) {
        if (Find-LocalBrowser $name) { $Browser = $name; break }
    }
    if ($Browser -eq 'Auto') { $Browser = [string]$config.Primary }
}
$port = if ($Browser -eq 'Chrome') { 9223 } else { 9222 }
$exe = Find-LocalBrowser $Browser
if (-not $exe) {
    $setting = $config.Browsers.PSObject.Properties[$Browser]
    if ($setting) {
        $candidate = [string]$setting.Value.Exe
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { $exe = $candidate }
    }
}
if (-not $exe) { throw "$Browser nem talalhato. Hasznald az Edge-et, vagy telepitsd a Brave/Chrome bongeszot." }

$localData = if ($TestUserRoot) { $TestUserRoot } else { $env:LOCALAPPDATA }
if (-not $localData) { throw 'Nem erheto el a felhasznalo LOCALAPPDATA mappaja.' }
$profile = Join-Path $localData ("NameNumberCopy\BrowserProfiles\" + $Browser)
$legacySuffix = if ($Browser -eq 'Brave') { 'OpenCartBraveDebug\User Data' } elseif ($Browser -eq 'Chrome') { 'OpenCartChromeDebug\User Data' } else { 'OpenCartEdgeDebug\User Data' }
$legacy = Join-Path $localData $legacySuffix
if (Test-Path -LiteralPath $legacy -PathType Container) { $profile = $legacy }
if (-not (Test-Path -LiteralPath $profile -PathType Container)) { New-Item -ItemType Directory -Force -Path $profile | Out-Null }
function Test-CDP([int]$p) {
    try {
        $r = Invoke-RestMethod -Uri "http://127.0.0.1:$p/json/version" -TimeoutSec 2 -ErrorAction Stop
        return ([bool]$r.Browser -and [bool]$r.webSocketDebuggerUrl)
    } catch { return $false }
}
if (Test-CDP $port) { return }
$args = @(
    '--remote-debugging-address=127.0.0.1',
    "--remote-debugging-port=$port",
    ('--user-data-dir="' + $profile + '"'),
    '--no-first-run'
)
Start-Process -FilePath $exe -ArgumentList $args -ErrorAction Stop | Out-Null
for ($i=0; $i -lt 40; $i++) {
    if (Test-CDP $port) { return }
    Start-Sleep -Milliseconds 500
}
throw "A $Browser debugportja ($port) nem erheto el. Masik alkalmazas hasznalhatja, vagy a bongeszo blokkolja."
