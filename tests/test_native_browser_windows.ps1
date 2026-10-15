$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$stage = Join-Path $env:RUNNER_TEMP ('nnc-native-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
$exe = Join-Path $stage 'name - number copy.exe'
$fake = Join-Path $stage 'fake-browser.exe'
Copy-Item -LiteralPath (Join-Path $root 'name - number copy.exe') -Destination $exe
Copy-Item -LiteralPath (Join-Path $root 'start_opencart_browser.ps1') -Destination $stage
& go build -buildvcs=false -trimpath -ldflags '-H windowsgui -s -w' -o $fake ./tests/fake_browser
if ($LASTEXITCODE -ne 0) { throw 'Native browser fixture build failed' }
$busy = @([Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners() | ForEach-Object Port)
$port = if ($busy -notcontains 9222) { 9222 } elseif ($busy -notcontains 9223) { 9223 } else { throw 'No free test CDP port; leave live browsers intact.' }
$browser = if ($port -eq 9222) { 'Edge' } else { 'Chrome' }
$config = @{ Primary=$browser; Browsers=@{} }
$config.Browsers[$browser] = @{ Exe=$fake; Port=$port }
[IO.File]::WriteAllText((Join-Path $stage 'opencart_browser_config.json'),($config | ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)))
$userRoot = Join-Path $stage 'profil é ! & ( )'
$legacyName = if ($browser -eq 'Edge') { 'OpenCartEdgeDebug' } else { 'OpenCartChromeDebug' }
$profile = Join-Path $userRoot "$legacyName\User Data"
New-Item -ItemType Directory -Path $profile -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $profile 'existing-login.txt'),'keep existing login')
try {
    # The compatibility wrapper must return while its browser descendant stays open.
    $wrapper = Join-Path $stage 'start_opencart_browser.ps1'
    $process = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$wrapper+'"'),'-Browser','Auto','-TestUserRoot',('"'+$userRoot+'"')) -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(30000)) { throw 'Native launcher did not finish after startup' }
    if ($process.ExitCode -ne 0) { throw 'Native browser launch did not prove healthy CDP' }
    $live = Invoke-RestMethod -Uri "http://127.0.0.1:$port/json/version" -TimeoutSec 2
    if (-not $live.Browser) { throw 'Compatibility wrapper returned only after browser termination' }
    $argv = Get-Content -LiteralPath (Join-Path $profile 'test-browser-argv.json') -Raw | ConvertFrom-Json
    foreach ($expected in @('--remote-debugging-address=127.0.0.1',"--remote-debugging-port=$port",('--user-data-dir=' + $profile),'--no-first-run')) {
        if ($argv -notcontains $expected) { throw "Windows native argv changed: $expected" }
    }
    if ([IO.File]::ReadAllText((Join-Path $profile 'existing-login.txt')) -ne 'keep existing login') { throw 'Native launcher changed existing login profile' }
    Write-Host 'PASS: actual native child process, literal Unicode/metacharacter profile argv, loopback-only CDP, Auto selection and legacy login-profile reuse.'
} finally {
    try { Invoke-WebRequest -Uri "http://127.0.0.1:$port/shutdown" -UseBasicParsing -TimeoutSec 2 | Out-Null } catch { }
}

Start-Sleep -Milliseconds 300
# Existing normal Brave profile: no real browser/profile is touched.
$portProbe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
$portProbe.Start()
$existingPort = $portProbe.LocalEndpoint.Port
$portProbe.Stop()
$userRoot = Join-Path $stage 'meglevo normal profil é ! (teszt)'
$normal = Join-Path $userRoot 'BraveSoftware\Brave-Browser\User Data'
$oldSeparate = Join-Path $userRoot 'OpenCartBraveDebug\User Data'
New-Item -ItemType Directory -Path $normal,$oldSeparate -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $normal 'existing-login.txt'),'NORMAL LOGIN KEEP')
[IO.File]::WriteAllText((Join-Path $oldSeparate 'old-login.txt'),'OLD SEPARATE KEEP')
$config = @{ Primary='Brave'; BraveProfileMode='Existing'; Browsers=@{Brave=@{Exe=$fake;Port=$existingPort}} }
[IO.File]::WriteAllText((Join-Path $stage 'opencart_browser_config.json'),($config | ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)))
function Invoke-ExistingBrave([int]$Expected) {
    $p = Start-Process -FilePath $exe -ArgumentList @('--start-browser','Brave','--test-user-root',('"' + $userRoot + '"')) -WindowStyle Hidden -PassThru
    if (-not $p.WaitForExit(30000)) { throw 'Normal-profile launcher did not finish after startup' }
    if ($p.ExitCode -ne $Expected) { throw "Existing Brave result: $($p.ExitCode), expected $Expected" }
}
try {
    Invoke-ExistingBrave 0
    $argvPath = Join-Path $normal 'test-browser-argv.json'
    $argv = Get-Content -LiteralPath $argvPath -Raw | ConvertFrom-Json
    if ($argv -notcontains ('--user-data-dir=' + $normal)) { throw 'Normal Brave profile was not used directly' }
    if (Test-Path -LiteralPath (Join-Path $oldSeparate 'test-browser-argv.json')) { throw 'Launcher silently used isolated profile' }
    $launchTime = (Get-Item -LiteralPath $argvPath).LastWriteTimeUtc
    Invoke-ExistingBrave 0
    if ((Get-Item -LiteralPath $argvPath).LastWriteTimeUtc -ne $launchTime) { throw 'Reused browser was relaunched' }
    $recordPath = Join-Path $userRoot 'NameNumberCopy\BrowserProfiles\brave-launch.json'
    $recordText = [IO.File]::ReadAllText($recordPath)
    $record = $recordText | ConvertFrom-Json
    $record.Profile = $oldSeparate
    [IO.File]::WriteAllText($recordPath,($record | ConvertTo-Json -Depth 4))
    Invoke-ExistingBrave 1
    [IO.File]::WriteAllText($recordPath,$recordText)
    if ([IO.File]::ReadAllText((Join-Path $normal 'existing-login.txt')) -ne 'NORMAL LOGIN KEEP' -or
        [IO.File]::ReadAllText((Join-Path $oldSeparate 'old-login.txt')) -ne 'OLD SEPARATE KEEP') { throw 'Login/profile data changed' }
} finally {
    try { Invoke-WebRequest -Uri ("http://127.0.0.1:" + $existingPort + "/shutdown") -UseBasicParsing -TimeoutSec 2 | Out-Null } catch { }
}
Start-Sleep -Milliseconds 300
$waiting = Start-Process -FilePath $fake -ArgumentList '--fixture-wait-only' -WindowStyle Hidden -PassThru
try {
    $started = [DateTime]::UtcNow
    Invoke-ExistingBrave 1
    if (([DateTime]::UtcNow - $started).TotalSeconds -gt 5) { throw 'Already-running normal Brave was not diagnosed promptly' }
} finally {
    # This is the exact fixture process created above, never a host browser.
    if (-not $waiting.HasExited) { $waiting.Kill(); $waiting.WaitForExit() }
}
Write-Host 'PASS: existing normal Brave directory/login retained without copying; validated process/port/profile reuse; wrong profile rejected; already-running browser diagnosed without closing it.'
