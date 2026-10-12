#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Auto','Brave','Chrome')][string]$Browser = 'Auto',
    [switch]$AutoStart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$configPath = Join-Path $PSScriptRoot 'opencart_browser_config.json'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw 'A bongeszo konfiguracioja hianyzik. Futtasd ujra a telepitot.' }
$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($Browser -eq 'Auto') { $Browser = [string]$config.Primary }
$entry = $config.Browsers.PSObject.Properties[$Browser]
if (-not $entry) { throw "A $Browser bongeszo nincs beallitva." }
$settings = $entry.Value
$port = [int]$settings.Port
$exe = [string]$settings.Exe
$profile = [string]$settings.Profile
if ($port -notin @(9222, 9223)) { throw "Nem engedelyezett port: $port" }
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "A $Browser bongeszo nincs telepitve a mentett helyen: $exe" }
if (-not (Test-Path -LiteralPath $profile -PathType Container)) { New-Item -ItemType Directory -Force -Path $profile | Out-Null }

function Test-CDPPort([int]$Port) {
    try {
        $r = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/version" -TimeoutSec 2 -ErrorAction Stop
        return ([bool]$r.Browser -and [bool]$r.webSocketDebuggerUrl)
    } catch { return $false }
}

if ($AutoStart -and (Test-CDPPort $port)) { return }

$args = @(
    '--remote-debugging-address=127.0.0.1',
    "--remote-debugging-port=$port",
    ('--user-data-dir="' + $profile + '"'),
    '--no-first-run'
)
Start-Process -FilePath $exe -ArgumentList $args -ErrorAction Stop | Out-Null
$ready = $false
for ($i = 0; $i -lt 35; $i++) {
    if (Test-CDPPort $port) { $ready = $true; break }
    Start-Sleep -Milliseconds 500
}
if (-not $ready) { throw "Nem erheto el a bongeszo CDP portja: $Browser / $port. Ellenorizd, nem hasznalja-e mas program a portot." }