#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Auto','Brave','Chrome','Edge')][string]$Browser = 'Auto',
    [switch]$AutoStart,
    [switch]$CheckOnly,
    [switch]$FromElevatedInstaller,
    [string]$TestUserRoot = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$configPath = Join-Path $PSScriptRoot 'opencart_browser_config.json'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw 'Hianyzik az OpenCart bongeszo konfiguracioja. Futtasd ujra a telepitot.' }
$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

# A BAT kozvetlen adminisztratori futasakor is NORMAL felhasznaloi bongeszo kell.
# A Windows Task Scheduler InteractiveToken + Limited futtatasa nem ker jelszot.
# A feladatot csak atmenetileg hozzuk letre, utana toroljuk.
if ($FromElevatedInstaller) {
    $taskName = 'NNC-CDP-Install-' + [guid]::NewGuid().ToString('N')
    $scheduler = $null
    $folder = $null
    $registered = $null
    try {
        $session = (Get-Process -Id $PID).SessionId
        if ($session -eq 0) { throw 'Nincs aktiv interaktiv Windows munkamenet (Session 0).' }
        $shells = @(Get-CimInstance Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction Stop |
            Where-Object { $_.SessionId -eq $session })
        if ($shells.Count -lt 1) {
            throw 'Ebben a Windows munkamenetben nem talalhato explorer.exe. Jelentkezz be az asztalra, es ott inditsd a telepitot.'
        }
        $owner = Invoke-CimMethod -InputObject $shells[0] -MethodName GetOwner -ErrorAction Stop
        if ($owner.ReturnValue -ne 0 -or -not $owner.User) { throw 'Nem allapithato meg a bejelentkezett Windows-felhasznalo.' }
        $account = [string]$owner.Domain + '\' + [string]$owner.User
        Write-Host "[INFO] Normal Windows-bongeszo inditasa: $account / munkamenet $session"
        $scheduler = New-Object -ComObject Schedule.Service
        $scheduler.Connect()
        $folder = $scheduler.GetFolder('\')
        $task = $scheduler.NewTask(0)
        $task.RegistrationInfo.Description = 'Ideiglenes OpenCart CDP-kapcsolat ellenorzo inditas'
        $task.Settings.Enabled = $true
        $task.Settings.Hidden = $true
        $task.Settings.AllowDemandStart = $true
        $task.Settings.ExecutionTimeLimit = 'PT2M'
        $task.Principal.UserId = $account
        $task.Principal.LogonType = 3  # InteractiveToken: a felhasznalonak mar be kell lennie jelentkezve
        $task.Principal.RunLevel = 0   # Limited: nem emelt jogosultsag
        $action = $task.Actions.Create(0)
        $action.Path = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $action.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $PSCommandPath + '" -Browser Auto'
        $action.WorkingDirectory = $PSScriptRoot
        $registered = $folder.RegisterTaskDefinition($taskName, $task, 6, $account, $null, 3, $null)
        $null = $registered.Run($null)
        $expected = [string]$config.Primary
        $likelyPort = if ($expected -eq 'Chrome') { 9223 } else { 9222 }
        $portsToCheck = @($likelyPort) + @(9222, 9223) | Select-Object -Unique
        $tested = $false
        for ($i = 0; $i -lt 48; $i++) {
            foreach ($checkPort in $portsToCheck) {
                try {
                    $v = Invoke-RestMethod -Uri "http://127.0.0.1:$checkPort/json/version" -TimeoutSec 2 -ErrorAction Stop
                    $list = Invoke-WebRequest -Uri "http://127.0.0.1:$checkPort/json/list" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
                    if ($v.Browser -and $v.webSocketDebuggerUrl -and $list.StatusCode -eq 200) {
                        Write-Host "[OK] CDP port $checkPort mukodik a bongeszoinditas utan."
                        $tested = $true
                        break
                    }
                } catch { }
            }
            if ($tested) { break }
            Start-Sleep -Milliseconds 500
        }
        if (-not $tested) {
            throw 'A bejelentkezett felhasznalo bongeszojen nem valt elerhetove a 9222/9223 CDP. Ellenorizd a felhasznalo TEMP mappajaban a name_number_copy_browser.log fajlt.'
        }
        return
    } catch {
        Write-Error ("Gepi telepites utan a normal felhasznaloi CDP inditas hibas: " + $_.Exception.Message) -ErrorAction Continue
        exit 1
    } finally {
        if ($null -ne $folder -and $null -ne $registered) {
            try { $folder.DeleteTask($taskName, 0) } catch {
                Write-Warning ("Nem sikerult eltavolitani az ideiglenes Task Scheduler feladatot: " + $taskName)
            }
        }
    }
}
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
    # A telepito altal beallitott gepi alapertelmezett bongeszo az elso.
    # A bejelentkezett felhasznalo sajat telepiteset is felismerjuk.
    $candidates = @([string]$config.Primary) + @('Brave','Chrome','Edge')
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (-not $candidate -or $candidate -notin @('Brave','Chrome','Edge')) { continue }
        if (Find-LocalBrowser $candidate) { $Browser = $candidate; break }
        $saved = $config.Browsers.PSObject.Properties[$candidate]
        if ($saved -and (Test-Path -LiteralPath ([string]$saved.Value.Exe) -PathType Leaf)) {
            $Browser = $candidate
            break
        }
    }
    if ($Browser -eq 'Auto') { throw 'Egyetlen telepitett Chromium bongeszo sem talalhato az aktualis felhasznalonak.' }
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
# Az inditasi hibaknak latniuk kell a kovetkezo ellenorzes soran is.
$log = Join-Path $env:TEMP 'name_number_copy_browser.log'
function Write-StartLog([string]$message) {
    try {
        Add-Content -LiteralPath $log -Encoding UTF8 -Value ("{0} | {1} | {2}" -f (Get-Date -Format o), $Browser, $message) -ErrorAction Stop
    } catch { }
}
function Confirm-CDP {
    try {
        $version = Invoke-RestMethod -Uri "http://127.0.0.1:$port/json/version" -TimeoutSec 3 -ErrorAction Stop
        $listResponse = Invoke-WebRequest -Uri "http://127.0.0.1:$port/json/list" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        if (-not $version.Browser -or -not $version.webSocketDebuggerUrl) { return $false }
        return ($listResponse.StatusCode -eq 200)
    } catch { return $false }
}
try {
    if (Confirm-CDP) {
        Write-StartLog "OK: CDP $port mar elerheto"
        Write-Host "[OK] $Browser - CDP $port elerheto (json/version + json/list)."
        return
    }
    if ($CheckOnly) {
        throw "A $Browser CDP $port portja nem elerheto. A bongeszo nem a megfelelo inditoval fut."
    }
    $args = @(
        '--remote-debugging-address=127.0.0.1',
        "--remote-debugging-port=$port",
        ('--user-data-dir="' + $profile + '"'),
        '--no-first-run'
    )
    Write-StartLog "Bongeszo inditasa; port=$port; profil=$profile"
    Start-Process -FilePath $exe -ArgumentList $args -ErrorAction Stop | Out-Null
    for ($i=0; $i -lt 40; $i++) {
        if (Confirm-CDP) {
            Write-StartLog "OK: CDP $port inditas utan elerheto"
            Write-Host "[OK] $Browser CDP $port mukodik; a masolo eleri a bongeszot."
            return
        }
        Start-Sleep -Milliseconds 500
    }
    throw "A $Browser elindult, de a CDP $port port nem valaszol. Ellenorizd a profilra es portokra vonatkozo bongeszo-szabalyokat. Log: $log"
} catch {
    Write-StartLog ("HIBA: " + $_.Exception.Message)
    Write-Error -Message ("OpenCart bongeszo nem hasznalhato. " + $_.Exception.Message + " | Log: " + $log) -ErrorAction Continue
    exit 1
}
