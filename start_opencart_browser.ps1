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
$exe = Join-Path $PSScriptRoot 'name - number copy.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'Hianyzik a masolo EXE. Csomagold ki a teljes ZIP-et.' }
if (-not $FromElevatedInstaller) {
    # Compatibility entrypoint: the native EXE owns discovery/profile/CDP logic.
    $arguments = @('--start-browser', $Browser)
    if ($AutoStart) { $arguments += '--autostart' }
    if ($CheckOnly) { $arguments += '--check-only' }
    if ($TestUserRoot) { $arguments += @('--test-user-root', $TestUserRoot) }
    $process = Start-Process -FilePath $exe -ArgumentList ($arguments | ForEach-Object {
        # Windows argument quoting for the only free-form value (test profile).
        if ($_ -match '[\s"]') { '"' + ($_ -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"' } else { $_ }
    }) -WindowStyle Hidden -Wait -PassThru
    exit $process.ExitCode
}
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
        Write-Host '[INFO] Windows Feladatutemezo csatlakozas...'
        $scheduler.Connect()
        Write-Host '[OK] Feladatutemezo csatlakoztatva.'
        $folder = $scheduler.GetFolder('\')
        $task = $scheduler.NewTask(0)
        $task.RegistrationInfo.Description = 'Ideiglenes OpenCart CDP-kapcsolat ellenorzo inditas'
        $task.Settings.Enabled = $true
        $task.Settings.Hidden = $false
        $task.Settings.AllowDemandStart = $true
        $task.Settings.ExecutionTimeLimit = 'PT2M'
        $task.Principal.UserId = $account
        $task.Principal.LogonType = 3  # InteractiveToken: a felhasznalonak mar be kell lennie jelentkezve
        $task.Principal.RunLevel = 0   # Limited: nem emelt jogosultsag
        $action = $task.Actions.Create(0)
        $action.Path = $exe
        $action.Arguments = '--start-browser Auto'
        $action.WorkingDirectory = $PSScriptRoot
        Write-Host '[INFO] Normal jogu EXE inditofeladat letrehozasa...'
        $registered = $folder.RegisterTaskDefinition($taskName, $task, 6, $account, $null, 3, $null)
        Write-Host '[OK] Ideiglenes feladat letrehozva; EXE inditasa...'
        $null = $registered.Run($null)
        Write-Host '[INFO] CDP-kapcsolatra varakozas, legfeljebb 30 masodperc...'
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        $expected = [string]$config.Primary
        $likelyPort = if ($expected -eq 'Chrome') { 9223 } else { 9222 }
        $portsToCheck = @($likelyPort) + @(9222, 9223) | Select-Object -Unique
        $tested = $false
        while ([DateTime]::UtcNow -lt $deadline) {
            foreach ($checkPort in $portsToCheck) {
                try {
                    $v = Invoke-RestMethod -Uri "http://127.0.0.1:$checkPort/json/version" -TimeoutSec 1 -ErrorAction Stop
                    $list = Invoke-WebRequest -Uri "http://127.0.0.1:$checkPort/json/list" -UseBasicParsing -TimeoutSec 1 -ErrorAction Stop
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
            throw ('30 masodperc alatt nem allt fel a normal felhasznaloi CDP. Feladatallapot: ' + $registered.State + '; eredmenykod: ' + $registered.LastTaskResult + '. Kattints normal felhasznalokent az OpenCart - Brave/Chrome/Edge ikonra. Naplo: %TEMP%\name_number_copy_browser.log')
        }
        return
    } catch {
        Write-Error ("Gepi telepites utan a normal felhasznaloi CDP inditas hibas: " + $_.Exception.Message) -ErrorAction Continue
        exit 1
    } finally {
        if ($null -ne $folder -and $null -ne $registered) {
            try { $folder.DeleteTask($taskName, 0); Write-Host '[OK] Ideiglenes feladat eltavolitva.' } catch {
                throw ("Nem sikerult eltavolitani az ideiglenes Task Scheduler feladatot: " + $taskName)
            }
        }
    }
}
